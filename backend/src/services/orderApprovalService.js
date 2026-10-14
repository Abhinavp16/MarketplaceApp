const mongoose = require('mongoose');
const { Order, Payment, Product, StockLog } = require('../models');
const { BadRequestError, NotFoundError } = require('../utils/errors');
const { ORDER_STATUS, ORDER_TYPES, PAYMENT_STATUS } = require('../utils/constants');
const { recordAudit } = require('./auditService');
const notificationService = require('./notificationService');
const { maybeNotifyLowStock } = require('./adminNotificationService');

const round2 = (value) => Math.round((Number(value) || 0) * 100) / 100;
const formatRupees = (value) => Number(value || 0).toLocaleString('en-IN', { maximumFractionDigits: 2 });

function appendHistory(order, status, note, actorId) {
  order.statusHistory.push({ status, note, updatedBy: actorId, timestamp: new Date() });
}

async function commitInventory(order, actorId, session, reason) {
  if (order.inventoryCommittedAt) return [];

  const updatedProducts = [];
  for (const item of order.items) {
    const product = await Product.findOneAndUpdate(
      { _id: item.productId, stock: { $gte: item.quantity } },
      { $inc: { stock: -item.quantity } },
      { new: true, session },
    );
    if (!product) {
      const existing = await Product.findById(item.productId).session(session);
      if (!existing) {
        throw new BadRequestError(
          `Product ${item.productSnapshot?.name || item.productId} no longer exists`,
          'PRODUCT_NOT_FOUND',
        );
      }
      throw new BadRequestError(
        `Insufficient stock for ${existing.name}. Available: ${existing.stock}, Required: ${item.quantity}`,
        'INSUFFICIENT_STOCK',
      );
    }

    await StockLog.create([{
      productId: item.productId,
      action: 'order_deduct',
      quantityChange: -item.quantity,
      previousStock: product.stock + item.quantity,
      newStock: product.stock,
      orderId: order._id,
      reason,
      performedBy: actorId,
    }], { session });
    updatedProducts.push(product);
  }

  order.inventoryCommittedAt = new Date();
  return updatedProducts;
}

async function releaseInventory(order, actorId, session) {
  if (!order.inventoryCommittedAt || order.inventoryReleasedAt) return false;

  for (const item of order.items) {
    const product = await Product.findByIdAndUpdate(
      item.productId,
      { $inc: { stock: item.quantity } },
      { new: true, session },
    );
    if (!product) {
      throw new BadRequestError(
        `Product ${item.productSnapshot?.name || item.productId} no longer exists`,
        'PRODUCT_NOT_FOUND',
      );
    }

    await StockLog.create([{
      productId: item.productId,
      action: 'cancel_restore',
      quantityChange: item.quantity,
      previousStock: product.stock - item.quantity,
      newStock: product.stock,
      orderId: order._id,
      reason: `Order ${order.orderNumber} cancelled - stock restored`,
      performedBy: actorId,
    }], { session });
  }

  order.inventoryReleasedAt = new Date();
  return true;
}

async function runCustomerNotification(order, accepted, reason) {
  try {
    await notificationService.sendLocalizedToUser(order.userId, accepted ? 'orderAccepted' : 'orderRejected', {
      orderNumber: order.orderNumber,
      total: formatRupees(order.total),
      reason,
    }, {
      type: 'order_update',
      orderId: String(order._id),
      acceptanceStatus: accepted ? 'accepted' : 'rejected',
    });
  } catch (error) {
    console.error('Failed to send order acceptance notification:', error.message);
  }
}

// deliveryCharge: typed by the admin when accepting (>= 0). Left out by older
// admin panels, in which case the order keeps the delivery fee it has.
async function acceptOrder({ orderId, actorId, deliveryCharge }) {
  const session = await mongoose.startSession();
  let result;
  let lowStockProducts = [];

  try {
    await session.withTransaction(async () => {
      const order = await Order.findById(orderId).session(session);
      if (!order) throw new NotFoundError('Order not found', 'ORDER_NOT_FOUND');

      if (order.orderType !== ORDER_TYPES.RETAIL) {
        throw new BadRequestError('Only retail orders require acceptance', 'ORDER_NOT_REVIEWABLE');
      }
      if (order.status === ORDER_STATUS.CANCELLED || order.inventoryReleasedAt) {
        throw new BadRequestError('Cancelled orders cannot be accepted', 'ORDER_NOT_REVIEWABLE');
      }
      if (order.acceptanceStatus === 'accepted') {
        result = { order, alreadyAccepted: true };
        return;
      }
      if (order.acceptanceStatus !== 'pending') {
        throw new BadRequestError('Only pending retail orders can be accepted', 'ORDER_NOT_REVIEWABLE');
      }

      lowStockProducts = await commitInventory(
        order,
        actorId,
        session,
        `Order ${order.orderNumber} accepted - stock deducted`,
      );
      let deliveryNote = '';
      if (deliveryCharge !== undefined && deliveryCharge !== null) {
        order.deliveryFee = round2(Math.max(0, Number(deliveryCharge) || 0));
        order.total = round2(Math.max(order.subtotal + order.deliveryFee - (order.discount || 0), 0));
        if (order.deliveryFee > 0) deliveryNote = ` · delivery ₹${formatRupees(order.deliveryFee)} added`;
        // A screenshot uploaded earlier must match the final amount.
        await Payment.updateMany(
          { orderId: order._id, status: { $in: [PAYMENT_STATUS.PENDING, PAYMENT_STATUS.HELD] } },
          { $set: { amount: order.total } },
          { session },
        );
      }
      order.acceptanceStatus = 'accepted';
      order.acceptedAt = new Date();
      order.acceptedBy = actorId;
      appendHistory(order, order.status, `Retail order accepted; inventory committed${deliveryNote}`, actorId);
      await order.save({ session });
      await recordAudit({
        actorId,
        action: 'order.accepted',
        entityType: 'order',
        entityId: order._id,
        metadata: { orderNumber: order.orderNumber, deliveryFee: order.deliveryFee, total: order.total },
        session,
      });
      result = { order, alreadyAccepted: false };
    });
  } finally {
    await session.endSession();
  }

  if (!result.alreadyAccepted) {
    await runCustomerNotification(result.order, true);
    await Promise.all(lowStockProducts.map((product) => maybeNotifyLowStock(product)));
  }
  return result;
}

async function rejectOrder({ orderId, actorId, reason }) {
  const normalizedReason = String(reason || '').trim();
  if (!normalizedReason) {
    throw new BadRequestError('Rejection reason is required', 'REJECTION_REASON_REQUIRED');
  }

  const session = await mongoose.startSession();
  let order;
  try {
    await session.withTransaction(async () => {
      order = await Order.findById(orderId).session(session);
      if (!order) throw new NotFoundError('Order not found', 'ORDER_NOT_FOUND');
      if (
        order.orderType !== ORDER_TYPES.RETAIL ||
        order.acceptanceStatus !== 'pending' ||
        order.status === ORDER_STATUS.CANCELLED
      ) {
        throw new BadRequestError('Only pending retail orders can be rejected', 'ORDER_NOT_REVIEWABLE');
      }

      order.acceptanceStatus = 'rejected';
      order.rejectedAt = new Date();
      order.rejectedBy = actorId;
      order.rejectionReason = normalizedReason;
      order.addStatusHistory(ORDER_STATUS.CANCELLED, `Order rejected: ${normalizedReason}`, actorId);
      await order.save({ session });
      await recordAudit({
        actorId,
        action: 'order.rejected',
        entityType: 'order',
        entityId: order._id,
        metadata: { orderNumber: order.orderNumber, reason: normalizedReason },
        session,
      });
    });
  } finally {
    await session.endSession();
  }

  await runCustomerNotification(order, false, normalizedReason);
  return order;
}

module.exports = { acceptOrder, rejectOrder, commitInventory, releaseInventory, appendHistory };
