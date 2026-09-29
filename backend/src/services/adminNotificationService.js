const { AdminNotification, User, DeviceToken } = require('../models');
const notificationService = require('./notificationService');

function getSocketServer() {
  try {
    // Lazy require avoids any module load-order cycle with the socket service.
    // eslint-disable-next-line global-require
    const NegotiationSocketService = require('./negotiationSocketService');
    return typeof NegotiationSocketService.getIO === 'function'
      ? NegotiationSocketService.getIO()
      : null;
  } catch (err) {
    console.error('Failed to resolve socket server for admin notification:', err.message);
    return null;
  }
}

/**
 * Fan out an event to admins.
 *
 * Persists a shared inbox record, emits a realtime socket event to the
 * `admins` room, and sends FCM push to admins' registered devices
 * (web push included). Delivery failures never throw - notifications must
 * never break the business request that triggered them.
 *
 * @param {Object} event
 * @param {string} event.type one of AdminNotification types
 * @param {string} event.title
 * @param {string} event.body
 * @param {'info'|'warning'|'urgent'} [event.severity]
 * @param {string|null} [event.link] deep link inside the admin panel, e.g. "/orders/123"
 * @param {{id?,name?,role?}} [event.actor]
 * @param {Object} [event.metadata]
 * @param {boolean} [event.push] default true - set false for noisy/low-value events
 */
async function notifyAdmins(event = {}) {
  const {
    type = 'general',
    title = 'Admin notification',
    body = '',
    severity = 'info',
    link = null,
    actor = {},
    metadata = {},
    push = true,
    includeStaff = false,
  } = event;

  let record = null;
  try {
    record = await AdminNotification.create({
      title,
      body,
      type,
      severity,
      link,
      actor: {
        id: actor.id || null,
        name: actor.name || '',
        role: actor.role || '',
      },
      metadata,
    });
  } catch (err) {
    console.error('Failed to store admin notification:', err.message);
    return null;
  }

  const payload = {
    id: String(record._id),
    type,
    title,
    body,
    severity,
    link,
    createdAt: record.createdAt,
  };

  // Realtime delivery to open admin panels.
  try {
    const io = getSocketServer();
    if (io) io.to('admins').emit('admin-notification', payload);
  } catch (err) {
    console.error('Failed to emit admin notification over socket:', err.message);
  }

  // Push delivery (includes web push for the installed PWA / admin tab).
  if (push) {
    try {
      const admins = await User.find({ role: { $in: includeStaff ? ['admin', 'staff'] : ['admin'] }, isActive: true })
        .select('_id')
        .lean();
      const adminIds = admins.map((admin) => admin._id);
      if (adminIds.length > 0) {
        const tokens = await DeviceToken.find({
          userId: { $in: adminIds },
          isActive: true,
        }).select('fcmToken');
        const fcmTokens = [...new Set(tokens.map((token) => token.fcmToken).filter(Boolean))];
        if (fcmTokens.length > 0) {
          await notificationService.sendToMultipleDevices(
            fcmTokens,
            { title, body },
            { type, link: link || '', notificationId: String(record._id) },
          );
        }
      }
    } catch (err) {
      console.error('Failed to push admin notification via FCM:', err.message);
    }
  }

  return record;
}

const LOW_STOCK_DEDUP_HOURS = 24;

/**
 * Notify admins when a product's stock falls at or below its threshold.
 * De-duplicated: at most one stock_low alert per product per 24h.
 *
 * @param {Object} product mongoose product document (after deduction)
 */
async function maybeNotifyLowStock(product) {
  try {
    if (!product || product.isActive === false) return null;
    const stock = Number(product.stock ?? 0);
    const threshold = Number(product.lowStockThreshold ?? 5);
    if (stock > threshold) return null;

    const since = new Date(Date.now() - LOW_STOCK_DEDUP_HOURS * 60 * 60 * 1000);
    const recent = await AdminNotification.findOne({
      type: 'stock_low',
      'metadata.productId': String(product._id),
      createdAt: { $gte: since },
    }).select('_id');
    if (recent) return null;

    return notifyAdmins({
      type: 'stock_low',
      severity: stock === 0 ? 'urgent' : 'warning',
      title: stock === 0 ? `Out of stock: ${product.name}` : `Low stock: ${product.name}`,
      body: stock === 0
        ? `${product.name} is out of stock.`
        : `${product.name} has ${stock} left (threshold ${threshold}).`,
      link: '/products',
      metadata: { productId: String(product._id), stock, threshold },
    });
  } catch (err) {
    console.error('Failed to check low stock for admin notification:', err.message);
    return null;
  }
}

module.exports = { notifyAdmins, maybeNotifyLowStock };
