const logger = require('../utils/logger');
const { Product, ProductAlert } = require('../models');
const notificationService = require('./notificationService');
const { isComingSoon } = require('../utils/productAvailability');

const SWEEP_MINUTES = 15;

// Sends "now available" to everyone who tapped Notify me, once per launch.
// Safe to call more than once: launchNotifiedAt is claimed atomically.
async function notifyLaunch(productId) {
  const product = await Product.findOneAndUpdate(
    { _id: productId, 'comingSoon.launchNotifiedAt': null },
    { $set: { 'comingSoon.launchNotifiedAt': new Date(), 'comingSoon.enabled': false } },
    { new: true },
  ).select('name nameHindi slug comingSoon');
  if (!product) return 0;

  const alerts = await ProductAlert.find({ productId: product._id, notifiedAt: null }).select('userId').lean();
  let sent = 0;
  for (const alert of alerts) {
    try {
      await notificationService.sendLocalizedToUser(alert.userId, 'productLaunched', {
        productName: product.name,
        productNameHindi: product.nameHindi,
      }, {
        type: 'product_launched',
        productId: String(product._id),
        slug: product.slug || '',
      });
      sent += 1;
    } catch (error) {
      logger.warn(`[ProductLaunch] notify failed for ${alert.userId}: ${error.message}`);
    }
  }
  await ProductAlert.updateMany({ productId: product._id, notifiedAt: null }, { $set: { notifiedAt: new Date() } });
  if (alerts.length) logger.info(`[ProductLaunch] ${product.name}: notified ${sent} of ${alerts.length}`);
  return sent;
}

// Products whose auto-launch date has passed: mark live and notify.
async function sweepAutoLaunches(now = new Date()) {
  const due = await Product.find({
    'comingSoon.enabled': true,
    'comingSoon.autoLaunch': true,
    'comingSoon.expectedDate': { $ne: null, $lte: now },
    'comingSoon.launchNotifiedAt': null,
  }).select('_id comingSoon').lean();
  let launched = 0;
  for (const product of due) {
    if (isComingSoon(product, now)) continue;
    await notifyLaunch(product._id);
    launched += 1;
  }
  return launched;
}

// People still waiting for a product.
const waitingCount = (productId) => ProductAlert.countDocuments({ productId, notifiedAt: null });

let sweepHandle = null;

function startProductLaunchScheduler() {
  if (sweepHandle) return sweepHandle;
  const run = () => sweepAutoLaunches().catch((error) => logger.error('Product launch sweep failed:', error));
  sweepHandle = setInterval(run, SWEEP_MINUTES * 60 * 1000);
  sweepHandle.unref?.();
  setTimeout(run, 2 * 60 * 1000).unref?.();
  return sweepHandle;
}

module.exports = { notifyLaunch, sweepAutoLaunches, waitingCount, startProductLaunchScheduler };
