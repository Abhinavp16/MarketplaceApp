const mongoose = require('mongoose');
const { Payment, Order } = require('../../models');
const { NotFoundError, BadRequestError } = require('../../utils/errors');
const { paginate, formatPaginationResponse } = require('../../utils/helpers');
const { PAYMENT_STATUS, ORDER_STATUS } = require('../../utils/constants');
const notificationService = require('../../services/notificationService');
const { creditAffiliateCommissionForOrder } = require('../../services/affiliateCommissionService');
const { recordAudit } = require('../../services/auditService');
const { maybeNotifyLowStock } = require('../../services/adminNotificationService');
const { commitInventory } = require('../../services/orderApprovalService');

exports.getPayments = async (req, res, next) => {
  try {
    const { status } = req.query;
    const { page, limit, skip } = paginate(req.query.page, req.query.limit);

    const query = {};
    if (status) query.status = status;

    const [payments, total] = await Promise.all([
      Payment.find(query)
        .populate('orderId', 'orderNumber total customerSnapshot')
        .populate('userId', 'name email phone')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      Payment.countDocuments(query),
    ]);

    res.json({
      success: true,
      ...formatPaginationResponse(payments, total, page, limit),
    });
  } catch (error) {
    next(error);
  }
};

exports.verifyPayment = async (req, res, next) => {
  const session = await mongoose.startSession();
  try {
    let payment;
    let order;
    let lowStockProducts = [];
    await session.withTransaction(async () => {
      payment = await Payment.findById(req.params.id).session(session);
      if (!payment) throw new NotFoundError('Payment not found', 'PAYMENT_NOT_FOUND');
      if (![PAYMENT_STATUS.PENDING, PAYMENT_STATUS.HELD].includes(payment.status)) {
        throw new BadRequestError('Payment already processed', 'PAYMENT_ALREADY_PROCESSED');
      }

      order = await Order.findById(payment.orderId).session(session);
      if (order?.acceptanceStatus === 'pending') {
        throw new BadRequestError('Retail order must be accepted before payment verification', 'ORDER_AWAITING_ACCEPTANCE');
      }

      payment.status = PAYMENT_STATUS.VERIFIED;
      payment.verifiedBy = req.user._id;
      payment.verifiedAt = new Date();
      payment.holdReason = null;
      payment.heldBy = null;
      payment.heldAt = null;
      await payment.save({ session });

      if (order) {
        order.addStatusHistory(ORDER_STATUS.PAYMENT_VERIFIED, 'Payment verified by admin', req.user._id);
        if (order.acceptanceStatus === null) {
          lowStockProducts = await commitInventory(
            order,
            req.user._id,
            session,
            `Order ${order.orderNumber} - payment verified, stock deducted`,
          );
        } else if (!order.inventoryCommittedAt) {
          throw new BadRequestError('Accepted order inventory is not committed', 'INVENTORY_NOT_COMMITTED');
        }
        order.addStatusHistory(ORDER_STATUS.PROCESSING, 'Order auto-confirmed after payment verification', req.user._id);
        await order.save({ session });
      }
    });

    await Promise.all(lowStockProducts.map((product) => maybeNotifyLowStock(product)));
    if (order) await creditAffiliateCommissionForOrder(order._id);

    // Send push notification to customer
    try {
      await notificationService.sendPaymentVerified(
        payment.userId,
        payment.orderId,
        order?.orderNumber || ''
      );
    } catch (notifErr) {
      console.error('Failed to send payment verified notification:', notifErr.message);
    }

    await recordAudit({
      actorId: req.user._id,
      action: 'payment.approved',
      entityType: 'payment',
      entityId: payment._id,
      metadata: { orderId: String(payment.orderId) },
    });

    res.json({
      success: true,
      message: 'Payment verified and order confirmed',
      data: {
        paymentId: payment._id,
        status: payment.status,
      },
    });
  } catch (error) {
    next(error);
  } finally {
    await session.endSession();
  }
};

exports.rejectPayment = async (req, res, next) => {
  try {
    const { reason } = req.body;

    const payment = await Payment.findById(req.params.id);
    if (!payment) {
      throw new NotFoundError('Payment not found', 'PAYMENT_NOT_FOUND');
    }

    if (![PAYMENT_STATUS.PENDING, PAYMENT_STATUS.HELD].includes(payment.status)) {
      throw new BadRequestError('Payment already processed', 'PAYMENT_ALREADY_PROCESSED');
    }

    payment.status = PAYMENT_STATUS.REJECTED;
    payment.rejectionReason = reason;
    payment.verifiedBy = req.user._id;
    payment.verifiedAt = new Date();
    payment.holdReason = null;
    payment.heldBy = null;
    payment.heldAt = null;
    await payment.save();

    const order = await Order.findById(payment.orderId);
    if (order) {
      order.addStatusHistory(ORDER_STATUS.PENDING_PAYMENT, `Payment rejected: ${reason}`, req.user._id);
      await order.save();
    }

    // Send push notification to customer
    try {
      await notificationService.sendPaymentRejected(
        payment.userId,
        payment.orderId,
        order?.orderNumber || '',
        reason
      );
    } catch (notifErr) {
      console.error('Failed to send payment rejected notification:', notifErr.message);
    }

    res.json({
      success: true,
      message: 'Payment rejected',
      data: {
        paymentId: payment._id,
        status: payment.status,
        reason,
      },
    });
  } catch (error) {
    next(error);
  }
};
