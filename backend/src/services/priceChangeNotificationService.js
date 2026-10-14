const logger = require('../utils/logger');
const { USER_ROLES, NOTIFICATION_TYPES, PRODUCT_STATUS } = require('../utils/constants');
const { renderNotification, normalizeLanguage } = require('./notificationTemplates');
const { getHiddenCatalog, isProductHidden, personalHiddenBrands } = require('../utils/customerVisibility');

// Immediate price changes are announced to app users once the admin has
// stopped saving prices for QUIET_MS (so twenty edits in Price Management
// become one notification), or at the latest MAX_WAIT_MS after the first save.
// Customers hear about customer-price changes, wholesalers about wholesale
// ones. The batch is kept in the database, so whichever server checks first
// after the wait sends it, exactly once.
const QUIET_MS = 100 * 1000;
const MAX_WAIT_MS = 10 * 60 * 1000;

const models = () => require('../models');

/** Adds an immediate price change to the waiting batch (or starts one). */
async function queueImmediatePriceChange({ productId, retailChanged, wholesaleChanged, now = new Date() }) {
  if (!productId || (!retailChanged && !wholesaleChanged)) return;
  const { PriceChangeNotificationBatch } = models();
  const addToSet = {};
  if (retailChanged) addToSet.retailProductIds = productId;
  if (wholesaleChanged) addToSet.wholesaleProductIds = productId;
  const update = {
    $set: { lastChangeAt: now },
    $setOnInsert: { firstChangeAt: now },
    $addToSet: addToSet,
  };
  try {
    await PriceChangeNotificationBatch.updateOne({ status: 'pending' }, update, { upsert: true });
  } catch (error) {
    // Two saves at the same moment both tried to start the batch: join it.
    if (error?.code !== 11000) throw error;
    await PriceChangeNotificationBatch.updateOne({ status: 'pending' }, update);
  }
}

const dueFilter = (now) => ({
  status: 'pending',
  $or: [
    { lastChangeAt: { $lte: new Date(now.getTime() - QUIET_MS) } },
    { firstChangeAt: { $lte: new Date(now.getTime() - MAX_WAIT_MS) } },
  ],
});

/** Whether a batch is waiting and its wait is over. */
async function hasDueBatch(now = new Date()) {
  const { PriceChangeNotificationBatch } = models();
  return Boolean(await PriceChangeNotificationBatch.exists(dueFilter(now)));
}

// Sends one message per language to the given users (push + notification list).
async function notifyUsers(users, buildMessage, data) {
  const { DeviceToken, Notification } = models();
  const notificationService = require('./notificationService');
  const byLanguage = new Map();
  for (const user of users) {
    const language = normalizeLanguage(user.preferredLanguage);
    if (!byLanguage.has(language)) byLanguage.set(language, []);
    byLanguage.get(language).push(user._id);
  }

  for (const [language, userIds] of byLanguage) {
    const message = buildMessage(language);
    const tokens = await DeviceToken.find({ userId: { $in: userIds }, isActive: true }).select('fcmToken').lean();
    const fcmTokens = [...new Set(tokens.map((token) => token.fcmToken).filter(Boolean))];
    if (fcmTokens.length > 0) {
      try {
        await notificationService.sendToMultipleDevices(fcmTokens, message, { ...data, language }, { androidDataOnly: true });
      } catch (error) {
        logger.error('Failed to send price update notification:', error);
      }
    }
    try {
      await Notification.insertMany(userIds.map((userId) => ({
        userId,
        title: message.title,
        body: message.body,
        type: data.type,
        data: { ...data, language },
      })));
    } catch (error) {
      logger.error('Failed to save price update notifications:', error);
    }
  }
}

// The message for one group: the product's name when only one changed.
const messageFor = (products) => (language) => (
  products.length === 1
    ? renderNotification('priceUpdatedOne', language, {
      productName: products[0].name,
      productNameHindi: products[0].nameHindi,
    })
    : renderNotification('priceUpdatedMany', language, { count: products.length })
);

/**
 * Sends the waiting batch if its wait is over. Safe to call from anywhere and
 * from several servers at once: only one claims the batch.
 */
async function flushDuePriceChangeNotification({ now = new Date() } = {}) {
  const { PriceChangeNotificationBatch, Product, User } = models();
  const batch = await PriceChangeNotificationBatch.findOneAndUpdate(
    dueFilter(now),
    { $set: { status: 'sending', claimedAt: now } },
    { new: true },
  );
  if (!batch) return null;

  const summary = { customers: { products: 0, users: 0 }, wholesalers: { products: 0, users: 0 } };
  try {
    const productIds = [...batch.retailProductIds, ...batch.wholesaleProductIds];
    const products = await Product.find({ _id: { $in: productIds }, status: PRODUCT_STATUS.ACTIVE })
      .select('_id name nameHindi company categoryRef')
      .lean();
    const byId = new Map(products.map((product) => [String(product._id), product]));
    const hidden = await getHiddenCatalog();
    const pick = (ids) => ids.map((id) => byId.get(String(id))).filter(Boolean);

    // Customers: their price changed, and the product isn't hidden from them.
    const forCustomers = pick(batch.retailProductIds).filter((product) => !isProductHidden(product, hidden));
    const forWholesalers = pick(batch.wholesaleProductIds);
    const data = (count) => ({
      type: NOTIFICATION_TYPES.PRICE_CHANGE_CAMPAIGN_APPLIED,
      batchId: String(batch._id),
      productCount: String(count),
    });

    for (const [group, role, groupProducts] of [
      ['customers', USER_ROLES.BUYER, forCustomers],
      ['wholesalers', USER_ROLES.WHOLESALER, forWholesalers],
    ]) {
      if (groupProducts.length === 0) continue;
      const users = await User.find({ role, isActive: true }).select('_id role preferredLanguage hiddenBrands').lean();

      // Each user hears only about products they can see: brands hidden from
      // them on their profile are left out. Users seeing the same products
      // share one message.
      const audiences = new Map();
      for (const user of users) {
        const ownHidden = personalHiddenBrands(user);
        const visible = ownHidden.size
          ? groupProducts.filter((product) => !ownHidden.has(String(product.company)))
          : groupProducts;
        if (visible.length === 0) continue;
        const key = visible.map((product) => String(product._id)).join(',');
        if (!audiences.has(key)) audiences.set(key, { products: visible, users: [] });
        audiences.get(key).users.push(user);
      }

      let reached = 0;
      for (const audience of audiences.values()) {
        reached += audience.users.length;
        await notifyUsers(audience.users, messageFor(audience.products), data(audience.products.length));
      }
      summary[group] = { products: groupProducts.length, users: reached };
    }
    logger.info(`[PriceUpdates] announced ${summary.customers.products} customer / ${summary.wholesalers.products} wholesale price change(s)`);
  } finally {
    // Marked sent even if a send failed, so nobody gets the same message twice.
    await PriceChangeNotificationBatch.updateOne(
      { _id: batch._id },
      { $set: { status: 'sent', sentAt: new Date(), sentSummary: summary } },
    );
  }
  return summary;
}

// Request-time trigger (the API on Vercel has no background timers): at most
// every CHECK_EVERY_MS per server, check for a due batch and send it.
const CHECK_EVERY_MS = 15 * 1000;
let lastCheckAt = 0;
let inFlight = null;

function priceUpdateNotifierMiddleware(req, res, next) {
  const now = Date.now();
  if (inFlight || now - lastCheckAt < CHECK_EVERY_MS) return next();
  lastCheckAt = now;
  inFlight = (async () => {
    if (await hasDueBatch()) await flushDuePriceChangeNotification();
  })()
    .catch((error) => logger.error('Price update notifier failed:', error))
    .finally(() => { inFlight = null; });
  // Send before answering, so serverless hosting doesn't stop it halfway.
  // This happens once per batch; every other request only does the check.
  inFlight.then(() => next(), () => next());
  return undefined;
}

let sweepHandle = null;

function startPriceUpdateNotifier() {
  if (sweepHandle) return sweepHandle;
  sweepHandle = setInterval(() => {
    flushDuePriceChangeNotification().catch((error) => logger.error('Price update notifier failed:', error));
  }, CHECK_EVERY_MS);
  sweepHandle.unref?.();
  return sweepHandle;
}

module.exports = {
  QUIET_MS,
  MAX_WAIT_MS,
  queueImmediatePriceChange,
  hasDueBatch,
  flushDuePriceChangeNotification,
  priceUpdateNotifierMiddleware,
  startPriceUpdateNotifier,
};
