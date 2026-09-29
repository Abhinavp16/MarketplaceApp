const mongoose = require('mongoose');
const { Order, Payment, StockLog } = require('../../models');
const { NotFoundError, BadRequestError } = require('../../utils/errors');
const { paginate, formatPaginationResponse } = require('../../utils/helpers');
const { ORDER_STATUS, PAYMENT_STATUS } = require('../../utils/constants');
const { recordAudit } = require('../../services/auditService');
const { creditAffiliateCommissionForOrder } = require('../../services/affiliateCommissionService');
const notificationService = require('../../services/notificationService');
const {
  acceptOrder,
  rejectOrder,
  commitInventory,
  releaseInventory,
} = require('../../services/orderApprovalService');

exports.getOrders = async (req, res, next) => {
  try {
    const { status, orderType, acceptanceStatus, dateFrom, dateTo, search, userId } = req.query;
    const { page, limit, skip } = paginate(req.query.page, req.query.limit);

    const query = {};
    if (status) query.status = status;
    if (orderType) query.orderType = orderType;
    if (acceptanceStatus) query.acceptanceStatus = acceptanceStatus;
    if (userId) query.userId = userId;
    if (dateFrom || dateTo) {
      query.createdAt = {};
      if (dateFrom) query.createdAt.$gte = new Date(dateFrom);
      if (dateTo) query.createdAt.$lte = new Date(dateTo);
    }
    if (search) {
      query.$or = [
        { orderNumber: { $regex: search, $options: 'i' } },
        { 'customerSnapshot.name': { $regex: search, $options: 'i' } },
        { 'customerSnapshot.phone': { $regex: search, $options: 'i' } },
      ];
    }

    const pendingApprovalQuery = { ...query, acceptanceStatus: 'pending' };
    const [orders, total, pendingApprovalTotal] = await Promise.all([
      Order.find(query)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      Order.countDocuments(query),
      Order.countDocuments(pendingApprovalQuery),
    ]);

    const orderIds = orders.map((order) => order._id);
    const payments = orderIds.length > 0
      ? await Payment.find({ orderId: { $in: orderIds } })
          .select('_id orderId status amount method upiId screenshotUrl rejectionReason holdReason heldAt')
          .lean()
      : [];
    const paymentsByOrderId = new Map(
      payments.map((payment) => [String(payment.orderId), payment])
    );
    const ordersWithPayments = orders.map((order) => ({
      ...order,
      payment: paymentsByOrderId.get(String(order._id)) || null,
    }));

    res.json({
      success: true,
      ...formatPaginationResponse(ordersWithPayments, total, page, limit),
      approvalCounts: { pending: pendingApprovalTotal },
    });
  } catch (error) {
    next(error);
  }
};

exports.getOrderById = async (req, res, next) => {
  try {
    const order = await Order.findById(req.params.id)
      .populate('userId', 'name email phone')
      .populate('negotiationId')
      .populate('acceptedBy', 'name email')
      .populate('rejectedBy', 'name email');

    if (!order) {
      throw new NotFoundError('Order not found', 'ORDER_NOT_FOUND');
    }

    const payment = await Payment.findOne({ orderId: order._id });

    res.json({
      success: true,
      data: {
        ...order.toObject(),
        payment,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.updateOrderStatus = async (req, res, next) => {
  const session = await mongoose.startSession();
  try {
    const { status, note } = req.body;
    let order;

    await session.withTransaction(async () => {
      order = await Order.findById(req.params.id).session(session);
      if (!order) throw new NotFoundError('Order not found', 'ORDER_NOT_FOUND');

      const allowedTransitions = {
        [ORDER_STATUS.PENDING_PAYMENT]: [ORDER_STATUS.CANCELLED],
        [ORDER_STATUS.PAYMENT_UPLOADED]: [ORDER_STATUS.CANCELLED],
        [ORDER_STATUS.PAYMENT_VERIFIED]: [ORDER_STATUS.PROCESSING, ORDER_STATUS.CANCELLED],
        [ORDER_STATUS.PROCESSING]: [ORDER_STATUS.SHIPPED, ORDER_STATUS.CANCELLED],
        [ORDER_STATUS.SHIPPED]: [ORDER_STATUS.DELIVERED],
      };
      if (!allowedTransitions[order.status]?.includes(status)) {
        throw new BadRequestError(`Cannot transition from ${order.status} to ${status}`, 'INVALID_STATUS_TRANSITION');
      }

      if (status === ORDER_STATUS.PROCESSING) {
        if (order.acceptanceStatus === 'pending') {
          throw new BadRequestError('Retail order must be accepted before processing', 'ORDER_AWAITING_ACCEPTANCE');
        }
        if (order.acceptanceStatus === null) {
          await commitInventory(order, req.user._id, session, `Order ${order.orderNumber} confirmed`);
        }
      }

      if (status === ORDER_STATUS.CANCELLED) {
        if (order.acceptanceStatus === 'pending') {
          throw new BadRequestError(
            'Pending customer orders must be rejected with a reason',
            'ORDER_REJECTION_REQUIRED',
          );
        }
        const legacyCommittedStatuses = [ORDER_STATUS.PROCESSING, ORDER_STATUS.SHIPPED, ORDER_STATUS.DELIVERED];
        if (!order.inventoryCommittedAt && order.acceptanceStatus === null && legacyCommittedStatuses.includes(order.status)) {
          order.inventoryCommittedAt = order.updatedAt || order.createdAt || new Date();
        }
        await releaseInventory(order, req.user._id, session);
      }

      order.addStatusHistory(status, note, req.user._id);
      if (status === ORDER_STATUS.DELIVERED) order.deliveredAt = new Date();
      await order.save({ session });
    });

    await recordAudit({
      actorId: req.user._id,
      action: status === ORDER_STATUS.CANCELLED ? 'order.cancelled' : 'order.status_updated',
      entityType: 'order',
      entityId: order._id,
      metadata: { status, note: note || null },
    });

    try {
      await notificationService.sendOrderStatusUpdate(order.userId, order._id, status);
    } catch (error) {
      console.error('Failed to send order status notification:', error.message);
    }

    res.json({
      success: true,
      message: 'Order status updated',
      data: {
        orderNumber: order.orderNumber,
        status: order.status,
      },
    });
  } catch (error) {
    next(error);
  } finally {
    await session.endSession();
  }
};

exports.acceptOrder = async (req, res, next) => {
  try {
    const { order, alreadyAccepted } = await acceptOrder({ orderId: req.params.id, actorId: req.user._id });
    res.json({
      success: true,
      message: alreadyAccepted ? 'Order was already accepted' : 'Order accepted',
      data: { orderNumber: order.orderNumber, acceptanceStatus: order.acceptanceStatus, status: order.status },
    });
  } catch (error) {
    next(error);
  }
};

exports.rejectOrder = async (req, res, next) => {
  try {
    const order = await rejectOrder({ orderId: req.params.id, actorId: req.user._id, reason: req.body.reason });
    res.json({
      success: true,
      message: 'Order rejected',
      data: { orderNumber: order.orderNumber, acceptanceStatus: order.acceptanceStatus, status: order.status },
    });
  } catch (error) {
    next(error);
  }
};

exports.markPaymentCompleted = async (req, res, next) => {
  const session = await mongoose.startSession();
  try {
    let order;
    let payment;
    await session.withTransaction(async () => {
      order = await Order.findById(req.params.id).session(session);
      if (!order) throw new NotFoundError('Order not found', 'ORDER_NOT_FOUND');
      if (order.status !== ORDER_STATUS.PENDING_PAYMENT) {
        throw new BadRequestError('Only pending payment orders can be marked as completed', 'INVALID_ORDER_STATUS');
      }
      if (order.acceptanceStatus === 'pending') {
        throw new BadRequestError('Retail order must be accepted before payment confirmation', 'ORDER_AWAITING_ACCEPTANCE');
      }

      payment = await Payment.findOne({ orderId: order._id }).session(session);
      if (!payment) {
        [payment] = await Payment.create([{
          orderId: order._id,
          userId: order.userId,
          amount: order.total,
          method: 'office_manual',
          status: PAYMENT_STATUS.VERIFIED,
          verifiedBy: req.user._id,
          verifiedAt: new Date(),
        }], { session });
      } else {
        if (![PAYMENT_STATUS.PENDING, PAYMENT_STATUS.REJECTED, PAYMENT_STATUS.HELD].includes(payment.status)) {
          throw new BadRequestError('Payment has already been processed for this order', 'PAYMENT_ALREADY_PROCESSED');
        }
        payment.method = 'office_manual';
        payment.amount = payment.amount || order.total;
        payment.status = PAYMENT_STATUS.VERIFIED;
        payment.verifiedBy = req.user._id;
        payment.verifiedAt = new Date();
        payment.rejectionReason = null;
        payment.holdReason = null;
        payment.heldBy = null;
        payment.heldAt = null;
        await payment.save({ session });
      }

      order.addStatusHistory(ORDER_STATUS.PAYMENT_VERIFIED, 'Payment marked complete in office', req.user._id);
      if (order.acceptanceStatus === 'accepted') {
        if (!order.inventoryCommittedAt) {
          throw new BadRequestError('Accepted order inventory is not committed', 'INVENTORY_NOT_COMMITTED');
        }
        order.addStatusHistory(ORDER_STATUS.PROCESSING, 'Order auto-confirmed after payment verification', req.user._id);
      }
      await order.save({ session });
    });

    await recordAudit({
      actorId: req.user._id,
      action: 'payment.marked_complete_in_office',
      entityType: 'order',
      entityId: order._id,
      metadata: { paymentId: String(payment._id) },
    });

    if (order.acceptanceStatus === 'accepted') {
      await creditAffiliateCommissionForOrder(order._id);
    }

    try {
      await notificationService.sendPaymentVerified(
        order.userId,
        order._id,
        order.orderNumber,
      );
    } catch (error) {
      console.error('Failed to send payment verified notification:', error.message);
    }

    res.json({
      success: true,
      message: 'Payment marked completed',
      data: {
        orderNumber: order.orderNumber,
        status: order.status,
        paymentId: payment._id,
      },
    });
  } catch (error) {
    next(error);
  } finally {
    await session.endSession();
  }
};

exports.shipOrder = async (req, res, next) => {
  try {
    const { trackingNumber, courierName } = req.body;

    const order = await Order.findById(req.params.id);
    if (!order) {
      throw new NotFoundError('Order not found', 'ORDER_NOT_FOUND');
    }

    if (order.status !== ORDER_STATUS.PROCESSING) {
      throw new BadRequestError('Only processing orders can be shipped', 'INVALID_ORDER_STATUS');
    }

    order.trackingNumber = trackingNumber;
    order.courierName = courierName;
    order.shippedAt = new Date();
    order.addStatusHistory(ORDER_STATUS.SHIPPED, `Shipped via ${courierName}. Tracking: ${trackingNumber}`, req.user._id);

    await order.save();

    await recordAudit({
      actorId: req.user._id,
      action: 'order.shipped',
      entityType: 'order',
      entityId: order._id,
      metadata: { courierName, trackingNumber },
    });

    try {
      await notificationService.sendOrderStatusUpdate(
        order.userId,
        order._id,
        ORDER_STATUS.SHIPPED,
      );
    } catch (error) {
      console.error('Failed to send shipped notification:', error.message);
    }

    res.json({
      success: true,
      message: 'Order shipped',
      data: {
        orderNumber: order.orderNumber,
        status: order.status,
        trackingNumber: order.trackingNumber,
        courierName: order.courierName,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.deleteOrder = async (req, res, next) => {
  let session = null;

  try {
    const order = await Order.findById(req.params.id).lean();
    if (!order) {
      throw new NotFoundError('Order not found', 'ORDER_NOT_FOUND');
    }
    if (order.negotiationId) {
      throw new BadRequestError(
        'Orders created from negotiations cannot be deleted',
        'NEGOTIATION_ORDER_DELETE_NOT_ALLOWED',
      );
    }

    const payment = await Payment.findOne({ orderId: order._id }).lean();
    const canDelete =
      order.status === ORDER_STATUS.CANCELLED ||
      payment?.status === PAYMENT_STATUS.REJECTED;

    if (!canDelete) {
      throw new BadRequestError(
        'Only cancelled orders or orders with rejected payments can be deleted',
        'ORDER_DELETE_NOT_ALLOWED'
      );
    }

    try {
      session = await mongoose.startSession();
      session.startTransaction();

      await Payment.deleteMany({ orderId: order._id }).session(session);
      await StockLog.deleteMany({ orderId: order._id }).session(session);
      await Order.deleteOne({ _id: order._id }).session(session);

      await session.commitTransaction();
    } catch (transactionError) {
      if (session) {
        await session.abortTransaction();
      }

      await Payment.deleteMany({ orderId: order._id });
      await StockLog.deleteMany({ orderId: order._id });
      await Order.deleteOne({ _id: order._id });

      if (transactionError) {
        console.warn('Order delete transaction fallback executed:', transactionError.message);
      }
    } finally {
      if (session) {
        await session.endSession();
      }
    }

    res.json({
      success: true,
      message: 'Order deleted successfully',
      data: {
        orderId: String(order._id),
        orderNumber: order.orderNumber,
      },
    });
  } catch (error) {
    if (session) {
      try {
        await session.endSession();
      } catch (_) {}
    }
    next(error);
  }
};
