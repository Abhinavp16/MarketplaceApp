const { Product, User, DeviceToken, Notification, PriceChangeCampaign, PriceChangeAudit } = require('../models');
const logger = require('../utils/logger');
const { USER_ROLES, NOTIFICATION_TYPES, PRODUCT_STATUS } = require('../utils/constants');
const notificationService = require('./notificationService');
const { normalizeLanguage, renderNotification } = require('./notificationTemplates');

const PRICE_CHANGE_POLL_INTERVAL_MS = 60 * 1000;

const CAMPAIGN_STAGES = [
  {
    key: NOTIFICATION_TYPES.PRICE_CHANGE_CAMPAIGN_STARTED,
    thresholdMs: 24 * 60 * 60 * 1000,
    title: 'Price update scheduled',
    body: 'New prices will apply after 24 hours.',
  },
  {
    key: NOTIFICATION_TYPES.PRICE_CHANGE_CAMPAIGN_12H,
    thresholdMs: 12 * 60 * 60 * 1000,
    title: 'Price update reminder',
    body: 'Most product prices will update in 12 hours.',
  },
  {
    key: NOTIFICATION_TYPES.PRICE_CHANGE_CAMPAIGN_6H,
    thresholdMs: 6 * 60 * 60 * 1000,
    title: 'Price update reminder',
    body: 'Most product prices will update in 6 hours.',
  },
  {
    key: NOTIFICATION_TYPES.PRICE_CHANGE_CAMPAIGN_20M,
    thresholdMs: 20 * 60 * 1000,
    title: 'Price update reminder',
    body: 'Prices on many products will update in 20 minutes.',
  },
];

const FINAL_STAGE = {
  key: NOTIFICATION_TYPES.PRICE_CHANGE_CAMPAIGN_APPLIED,
  title: 'Prices updated',
  body: 'New prices are now applied.',
};

function clearPendingFields(target) {
  target.pendingRetailPrice = null;
  target.pendingWholesalePrice = null;
  target.priceChangeScheduledAt = null;
  target.priceChangeEffectiveAt = null;
  target.pendingPriceChangeAudit = null;
}

async function fetchScheduledProducts() {
  return Product.find({
    status: { $ne: PRODUCT_STATUS.ARCHIVED },
    priceChangeEffectiveAt: { $ne: null },
  })
    .select('_id orderCount purchaseCountMax priceChangeEffectiveAt')
    .lean();
}

function computeCampaignEffectiveAt(products = []) {
  let maxTimestamp = null;

  for (const product of products) {
    const timestamps = [];
    if (product?.priceChangeEffectiveAt) {
      timestamps.push(new Date(product.priceChangeEffectiveAt).getTime());
    }

    for (const timestamp of timestamps) {
      if (!Number.isFinite(timestamp)) continue;
      if (maxTimestamp === null || timestamp > maxTimestamp) {
        maxTimestamp = timestamp;
      }
    }
  }

  return maxTimestamp === null ? null : new Date(maxTimestamp);
}

function pickRepresentativeProductIds(products = []) {
  const normalized = products.map((product) => ({
    id: String(product._id),
    score: Number(product.orderCount || product.purchaseCountMax || 0),
  }));

  const topSelling = [...normalized]
    .sort((left, right) => right.score - left.score)
    .slice(0, 5)
    .map((item) => item.id);

  const remaining = normalized
    .filter((item) => !topSelling.includes(item.id))
    .sort(() => Math.random() - 0.5)
    .slice(0, 3)
    .map((item) => item.id);

  return [...new Set([...topSelling, ...remaining])];
}

// Notification template for each campaign stage (English + Hindi).
const CAMPAIGN_TEMPLATE_BY_STAGE = {
  [NOTIFICATION_TYPES.PRICE_CHANGE_CAMPAIGN_STARTED]: 'priceCampaignStarted',
  [NOTIFICATION_TYPES.PRICE_CHANGE_CAMPAIGN_12H]: 'priceCampaign12h',
  [NOTIFICATION_TYPES.PRICE_CHANGE_CAMPAIGN_6H]: 'priceCampaign6h',
  [NOTIFICATION_TYPES.PRICE_CHANGE_CAMPAIGN_20M]: 'priceCampaign20m',
  [NOTIFICATION_TYPES.PRICE_CHANGE_CAMPAIGN_APPLIED]: 'priceCampaignApplied',
};

function formatCampaignEffectiveAt(effectiveAt, language = 'en') {
  const date = new Date(effectiveAt);
  if (Number.isNaN(date.getTime())) {
    return language === 'hi' ? 'तय तारीख' : 'the scheduled date';
  }

  // Hindi month names, but digits always stay 1, 2, 3.
  return date.toLocaleString(language === 'hi' ? 'hi-IN' : 'en-IN', {
    numberingSystem: 'latn',
    timeZone: 'Asia/Kolkata',
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  });
}

function getCampaignNotificationBody(stage, campaign) {
  if (stage.key === NOTIFICATION_TYPES.PRICE_CHANGE_CAMPAIGN_STARTED) {
    return `New prices will apply on ${formatCampaignEffectiveAt(campaign.effectiveAt)} IST.`;
  }

  return stage.body;
}

function buildCampaignNotification(stage, campaign, language) {
  const templateKey = CAMPAIGN_TEMPLATE_BY_STAGE[stage.key];
  if (!templateKey) {
    return { title: stage.title, body: getCampaignNotificationBody(stage, campaign) };
  }
  return renderNotification(templateKey, language, {
    when: formatCampaignEffectiveAt(campaign.effectiveAt, language),
  });
}

async function broadcastCampaignNotification(stage, campaign) {
  const appUsers = await User.find({
    role: { $in: [USER_ROLES.BUYER, USER_ROLES.WHOLESALER] },
  }).select('_id preferredLanguage').lean();

  if (!appUsers.length) {
    return;
  }

  const data = {
    type: stage.key,
    campaignId: String(campaign._id),
    effectiveAt: campaign.effectiveAt ? new Date(campaign.effectiveAt).toISOString() : '',
  };

  // One broadcast per language so everyone gets the message in their language.
  const usersByLanguage = new Map();
  for (const user of appUsers) {
    const language = normalizeLanguage(user.preferredLanguage);
    if (!usersByLanguage.has(language)) usersByLanguage.set(language, []);
    usersByLanguage.get(language).push(user._id);
  }

  for (const [language, userIds] of usersByLanguage) {
    const notification = buildCampaignNotification(stage, campaign, language);
    const tokens = await DeviceToken.find({
      userId: { $in: userIds },
      isActive: true,
    }).select('fcmToken');
    const fcmTokens = [...new Set(tokens.map((token) => token.fcmToken).filter(Boolean))];

    if (fcmTokens.length > 0) {
      try {
        await notificationService.sendToMultipleDevices(
          fcmTokens,
          notification,
          { ...data, language },
          {
            androidDataOnly: true,
          }
        );
      } catch (error) {
        logger.error('Failed to send price campaign notification:', error);
      }
    }

    try {
      await Notification.insertMany(
        userIds.map((userId) => ({
          userId,
          title: notification.title,
          body: notification.body,
          type: stage.key,
          data: { ...data, language },
        }))
      );
    } catch (error) {
      logger.error('Failed to persist price campaign notifications:', error);
    }
  }
}

async function getActiveCampaign() {
  return PriceChangeCampaign.findOne({ status: 'active' }).sort({ createdAt: -1 });
}

async function registerPriceChangeCampaign() {
  const scheduledProducts = await fetchScheduledProducts();
  if (!scheduledProducts.length) {
    return null;
  }

  const effectiveAt = computeCampaignEffectiveAt(scheduledProducts);
  if (!effectiveAt) {
    return null;
  }

  const includedProductIds = [...new Set(scheduledProducts.map((product) => String(product._id)))];
  const representativeProductIds = pickRepresentativeProductIds(scheduledProducts);
  let campaign = await getActiveCampaign();

  if (!campaign) {
    campaign = await PriceChangeCampaign.create({
      status: 'active',
      startAt: new Date(),
      effectiveAt,
      includedProductIds,
      representativeProductIds,
      sentStages: [],
      lastMergedAt: new Date(),
    });
  } else {
    campaign.effectiveAt = effectiveAt;
    campaign.includedProductIds = includedProductIds;
    campaign.representativeProductIds = representativeProductIds;
    campaign.lastMergedAt = new Date();
    await campaign.save();
  }

  await sendDueCampaignStages();
  return campaign;
}

async function sendDueCampaignStages() {
  const campaign = await getActiveCampaign();
  if (!campaign) {
    return;
  }

  const now = Date.now();
  const effectiveAt = new Date(campaign.effectiveAt).getTime();
  const remainingMs = effectiveAt - now;
  const sentStages = new Set(campaign.sentStages || []);

  for (const stage of CAMPAIGN_STAGES) {
    if (sentStages.has(stage.key)) {
      continue;
    }

    const shouldSend =
      stage.key === NOTIFICATION_TYPES.PRICE_CHANGE_CAMPAIGN_STARTED
        ? true
        : remainingMs <= stage.thresholdMs;

    if (!shouldSend) {
      continue;
    }

    await broadcastCampaignNotification(stage, campaign);
    campaign.sentStages = [...new Set([...(campaign.sentStages || []), stage.key])];
    await campaign.save();
  }
}

async function finalizeCompletedCampaignIfNeeded() {
  const campaign = await getActiveCampaign();
  if (!campaign) {
    return;
  }

  const scheduledProducts = await fetchScheduledProducts();
  if (scheduledProducts.length > 0) {
    campaign.includedProductIds = [...new Set(scheduledProducts.map((product) => String(product._id)))];
    campaign.representativeProductIds = pickRepresentativeProductIds(scheduledProducts);
    const effectiveAt = computeCampaignEffectiveAt(scheduledProducts);
    if (effectiveAt) {
      campaign.effectiveAt = effectiveAt;
    }
    campaign.lastMergedAt = new Date();
    await campaign.save();
    return;
  }

  const sentStages = new Set(campaign.sentStages || []);
  if (!sentStages.has(FINAL_STAGE.key)) {
    await broadcastCampaignNotification(FINAL_STAGE, campaign);
    campaign.sentStages = [...new Set([...(campaign.sentStages || []), FINAL_STAGE.key])];
  }

  campaign.status = 'completed';
  campaign.completedAt = new Date();
  await campaign.save();
}

async function processDuePriceChanges() {
  const now = new Date();
  const dueProducts = await Product.find({
    priceChangeEffectiveAt: { $lte: now },
  });

  for (const product of dueProducts) {
    let didChange = false;
    const pendingAuditId = product.pendingPriceChangeAudit;

    if (product.priceChangeEffectiveAt && product.priceChangeEffectiveAt <= now) {
      const nextRetail = product.pendingRetailPrice;
      const nextWholesale = product.pendingWholesalePrice;

      if (nextRetail !== null && nextRetail !== undefined) {
        product.retailPrice = nextRetail;
      }
      if (nextWholesale !== null && nextWholesale !== undefined) {
        product.wholesalePrice = nextWholesale;
      }

      clearPendingFields(product);
      didChange = true;
    }

    if (!didChange) {
      continue;
    }

    await product.save();

    if (pendingAuditId) {
      await PriceChangeAudit.updateOne(
        { _id: pendingAuditId, status: 'scheduled' },
        { $set: { status: 'applied', appliedAt: now } }
      );
    }
  }
}

async function runPriceSchedulerTick() {
  await processDuePriceChanges();
  await registerPriceChangeCampaign();
  await finalizeCompletedCampaignIfNeeded();
}

let schedulerHandle = null;

function startPriceChangeScheduler() {
  if (schedulerHandle) {
    return schedulerHandle;
  }

  schedulerHandle = setInterval(() => {
    runPriceSchedulerTick().catch((error) => {
      logger.error('Product price scheduler failed:', error);
    });
  }, PRICE_CHANGE_POLL_INTERVAL_MS);

  runPriceSchedulerTick().catch((error) => {
    logger.error('Initial product price scheduler run failed:', error);
  });

  return schedulerHandle;
}

module.exports = {
  startPriceChangeScheduler,
  processDuePriceChanges,
  registerPriceChangeCampaign,
  clearPendingFields,
};
