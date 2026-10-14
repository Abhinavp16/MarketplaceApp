const { Negotiation, User, Settings } = require('../../models');
const { NotFoundError, BadRequestError } = require('../../utils/errors');
const { paginate, formatPaginationResponse } = require('../../utils/helpers');
const { NEGOTIATION_STATUS, NEGOTIATION_ACTIONS } = require('../../utils/constants');
const notificationService = require('../../services/notificationService');
const { recordAudit } = require('../../services/auditService');
const {
  acceptNegotiationAndCreateOrder,
  acceptRequirementGroupAndCreateOrder,
  emitToNegotiationRoom,
  declineNegotiations,
  notifyWholesaler,
} = require('../../services/negotiationOrderService');

// Derive "who approved" from the accepted history entry (no schema change).
async function attachApprovers(negotiations) {
  const actorIds = [];
  const approverByNegotiation = new Map();
  for (const n of negotiations) {
    const accepted = (n.history || []).filter((h) => h.action === NEGOTIATION_ACTIONS.ACCEPTED).pop();
    if (accepted?.actorId) {
      actorIds.push(accepted.actorId);
      approverByNegotiation.set(String(n._id), {
        role: accepted.actorRole || 'admin',
        userId: String(accepted.actorId),
      });
    } else if (accepted) {
      approverByNegotiation.set(String(n._id), { role: 'admin', userId: null });
    }
  }
  let usersById = new Map();
  if (actorIds.length > 0) {
    const users = await User.find({ _id: { $in: actorIds } })
      .select('name username email')
      .lean();
    usersById = new Map(users.map((u) => [String(u._id), u]));
  }
  return negotiations.map((n) => {
    const approver = approverByNegotiation.get(String(n._id)) || null;
    if (approver?.userId) {
      const user = usersById.get(approver.userId);
      approver.name = user?.name || user?.username || user?.email || 'Member';
    } else if (approver) {
      approver.name = 'Admin';
    }
    return { ...n, approvedBy: approver };
  });
}

// Escape user input before building $regex queries (prevents regex injection).
const escapeRegExp = (value) => String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

exports.getNegotiations = async (req, res, next) => {
  try {
    const { status, search } = req.query;
    const { page, limit, skip } = paginate(req.query.page, req.query.limit);

    const query = {};
    if (status) query.status = status;

    const term = String(search || '').trim().slice(0, 100);
    if (term) {
      const safe = escapeRegExp(term);
      const or = [
        { negotiationNumber: { $regex: safe, $options: 'i' } },
        { 'productSnapshot.name': { $regex: safe, $options: 'i' } },
      ];
      // wholesalerId is a ref, so resolve matching users first (capped fan-out).
      const users = await User.find({
        $or: [
          { name: { $regex: safe, $options: 'i' } },
          { email: { $regex: safe, $options: 'i' } },
          { phone: { $regex: safe, $options: 'i' } },
          { 'businessInfo.businessName': { $regex: safe, $options: 'i' } },
        ],
      }).select('_id').limit(50).lean();
      if (users.length > 0) {
        or.push({ wholesalerId: { $in: users.map((u) => u._id) } });
      }
      query.$or = or;
    }

    let negotiations = await Negotiation.find(query)
      .populate('wholesalerId', 'name email phone businessInfo.businessName')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean();

    const total = await Negotiation.countDocuments(query);
    const withApprovers = await attachApprovers(negotiations);

    const formatted = withApprovers.map(n => ({
      id: n._id,
      negotiationNumber: n.negotiationNumber,
      wholesaler: {
        id: n.wholesalerId._id,
        name: n.wholesalerId.name,
        email: n.wholesalerId.email,
        phone: n.wholesalerId.phone,
        businessName: n.wholesalerId.businessInfo?.businessName,
      },
      product: {
        id: n.productId,
        name: n.productSnapshot.name,
        price: n.productSnapshot.price,
        image: n.productSnapshot.image,
        priceUnit: n.productSnapshot.priceUnit || '',
        packing: n.productSnapshot.packing || '',
      },
      requestGroup: n.requestGroup?.id ? n.requestGroup : null,
      requestedQuantity: n.requestedQuantity,
      requestedPricePerUnit: n.requestedPricePerUnit,
      requestedTotalPrice: n.requestedTotalPrice,
      currentPricePerUnit: n.currentPricePerUnit,
      currentTotalPrice: n.currentTotalPrice,
      status: n.status,
      currentOfferBy: n.currentOfferBy,
      expiresAt: n.expiresAt,
      createdAt: n.createdAt,
      orderId: n.orderId ? String(n.orderId) : null,
      approvedBy: n.approvedBy,
    }));

    res.json({
      success: true,
      ...formatPaginationResponse(formatted, total, page, limit),
    });
  } catch (error) {
    next(error);
  }
};

exports.getNegotiationById = async (req, res, next) => {
  try {
    const negotiation = await Negotiation.findById(req.params.id)
      .populate('wholesalerId', 'name email phone address businessInfo')
      .populate('history.actorId', 'name username email')
      .populate('orderId', 'orderNumber status total statusHistory trackingNumber courierName shippedAt deliveredAt shippingAddress');

    if (!negotiation) {
      throw new NotFoundError('Negotiation not found', 'NEGOTIATION_NOT_FOUND');
    }

    const data = negotiation.toObject();
    const accepted = (data.history || []).filter((h) => h.action === NEGOTIATION_ACTIONS.ACCEPTED).pop();
    data.approvedBy = accepted
      ? {
          role: accepted.actorRole || 'admin',
          userId: accepted.actorId?._id ? String(accepted.actorId._id) : null,
          name: accepted.actorId?.name || accepted.actorId?.username || (accepted.actorRole === 'staff' ? 'Member' : 'Admin'),
        }
      : null;

    // Last order address helps prefill the accept dialog.
    let lastOrderAddress = null;
    if (!data.orderId) {
      const { Order } = require('../../models');
      const lastOrder = await Order.findOne({ userId: negotiation.wholesalerId._id || negotiation.wholesalerId })
        .sort({ createdAt: -1 })
        .select('shippingAddress')
        .lean();
      lastOrderAddress = lastOrder?.shippingAddress || null;
    }

    res.json({
      success: true,
      data: { ...data, lastOrderAddress },
    });
  } catch (error) {
    next(error);
  }
};

// Admin chat message inside a negotiation (persisted + live + notified).
exports.sendMessage = async (req, res, next) => {
  try {
    const { message } = req.body;

    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      throw new BadRequestError('Message cannot be empty', 'INVALID_MESSAGE');
    }
    if (message.length > 280) {
      throw new BadRequestError('Message too long (max 280 characters)', 'MESSAGE_TOO_LONG');
    }

    const negotiation = await Negotiation.findById(req.params.id);
    if (!negotiation) {
      throw new NotFoundError('Negotiation not found', 'NEGOTIATION_NOT_FOUND');
    }
    if ([NEGOTIATION_STATUS.REJECTED, NEGOTIATION_STATUS.EXPIRED].includes(negotiation.status)) {
      throw new BadRequestError('Cannot send message in this negotiation status', 'INVALID_STATUS');
    }

    const entry = {
      action: NEGOTIATION_ACTIONS.MESSAGE,
      by: 'admin',
      actorId: req.user._id,
      actorRole: 'admin',
      message: message.trim(),
      messageId: `${req.user._id}-${Date.now()}`,
      timestamp: new Date(),
    };
    negotiation.history.push(entry);
    await negotiation.save();

    emitToNegotiationRoom(req.app.locals.io, negotiation._id.toString(), 'receive-message', {
      negotiationId: negotiation._id.toString(),
      message: message.trim(),
      userId: String(req.user._id),
      userRole: 'admin',
      timestamp: new Date(),
      messageId: entry.messageId,
    });

    await notifyWholesaler(negotiation.wholesalerId, 'requirementMessage', {
      message: message.trim().slice(0, 120),
    }, {
      type: 'negotiation_update',
      negotiationId: negotiation._id.toString(),
    });

    res.json({ success: true, message: 'Message sent' });
  } catch (error) {
    next(error);
  }
};

exports.acceptNegotiation = async (req, res, next) => {
  try {
    const { message, shippingAddress, customerNote, deliveryCharge } = req.body;

    const actorName = req.user.name || req.user.email || 'Admin';
    const { negotiation, order, alreadyConverted, addressSource } =
      await acceptNegotiationAndCreateOrder({
        negotiationId: req.params.id,
        actor: { id: req.user._id, role: 'admin', name: actorName },
        message,
        shippingAddress,
        customerNote,
        deliveryCharge,
        io: req.app.locals.io,
      });
    if (!order) {
      throw new BadRequestError('Negotiation order could not be recovered. Please retry.', 'NEGOTIATION_ORDER_MISSING');
    }

    res.json({
      success: true,
      message: alreadyConverted
        ? 'Negotiation was already converted to an order'
        : 'Negotiation accepted — order confirmed',
      data: {
        status: negotiation.status,
        finalPricePerUnit: negotiation.finalPricePerUnit,
        finalTotalPrice: negotiation.finalTotalPrice,
        orderId: String(order._id),
        orderNumber: order.orderNumber,
        deliveryFee: order.deliveryFee || 0,
        total: order.total,
        addressSource,
      },
    });
  } catch (error) {
    next(error);
  }
};

// All products of one requirement (sent together from the cart), for the
// combined accept form.
exports.getRequirementGroup = async (req, res, next) => {
  try {
    const negotiations = await Negotiation.find({ 'requestGroup.id': req.params.groupId })
      .populate('wholesalerId', 'name email phone address businessInfo')
      .populate('orderId', 'orderNumber status total')
      .sort({ createdAt: 1 })
      .lean();
    if (negotiations.length === 0) {
      throw new NotFoundError('Requirement not found', 'NEGOTIATION_NOT_FOUND');
    }
    const wholesaler = negotiations[0].wholesalerId;
    const { Order } = require('../../models');
    const lastOrder = await Order.findOne({ userId: wholesaler._id })
      .sort({ createdAt: -1 })
      .select('shippingAddress')
      .lean();
    const now = new Date();
    res.json({
      success: true,
      data: {
        requestGroup: negotiations[0].requestGroup,
        wholesaler: {
          id: wholesaler._id,
          name: wholesaler.name,
          email: wholesaler.email,
          phone: wholesaler.phone,
          address: wholesaler.address,
          businessInfo: wholesaler.businessInfo,
        },
        lastOrderAddress: lastOrder?.shippingAddress || null,
        items: negotiations.map((n) => {
          const pricePerUnit = n.finalPricePerUnit ?? n.currentPricePerUnit;
          const totalPrice = n.finalTotalPrice ?? n.currentTotalPrice;
          const isExpired = n.status !== NEGOTIATION_STATUS.ACCEPTED && n.expiresAt <= now;
          return {
            id: n._id,
            negotiationNumber: n.negotiationNumber,
            product: {
              id: n.productId,
              name: n.productSnapshot.name,
              image: n.productSnapshot.image,
              priceUnit: n.productSnapshot.priceUnit || '',
              packing: n.productSnapshot.packing || '',
            },
            requestedQuantity: n.requestedQuantity,
            pricePerUnit,
            totalPrice,
            status: n.status,
            isExpired,
            order: n.orderId ? { id: n.orderId._id, orderNumber: n.orderId.orderNumber } : null,
            canAccept: !n.orderId &&
              [NEGOTIATION_STATUS.PENDING, NEGOTIATION_STATUS.COUNTERED, NEGOTIATION_STATUS.ACCEPTED].includes(n.status) &&
              !isExpired,
          };
        }),
      },
    });
  } catch (error) {
    next(error);
  }
};

// Accept the selected products of a requirement into ONE order.
exports.acceptRequirementGroup = async (req, res, next) => {
  try {
    const { negotiationIds, message, shippingAddress, customerNote, deliveryCharge } = req.body;
    const actorName = req.user.name || req.user.email || 'Admin';
    const { order, negotiations } = await acceptRequirementGroupAndCreateOrder({
      groupId: req.params.groupId,
      negotiationIds,
      actor: { id: req.user._id, role: 'admin', name: actorName },
      message,
      shippingAddress,
      customerNote,
      deliveryCharge,
      io: req.app.locals.io,
    });
    res.json({
      success: true,
      message: `Requirement accepted — ${negotiations.length} products in one order`,
      data: {
        orderId: String(order._id),
        orderNumber: order.orderNumber,
        subtotal: order.subtotal,
        deliveryFee: order.deliveryFee,
        total: order.total,
        negotiationIds: negotiations.map((n) => String(n._id)),
      },
    });
  } catch (error) {
    next(error);
  }
};

// Declines a requirement. Admin and member panels (req.user.role).
exports.rejectNegotiation = async (req, res, next) => {
  try {
    const result = await declineNegotiations({
      negotiationId: req.params.id,
      reason: req.body?.reason,
      actor: { id: req.user._id, role: req.user.role === 'staff' ? 'staff' : 'admin' },
      io: req.app.locals.io,
    });
    res.json({ success: true, message: 'Requirement declined', data: result });
  } catch (error) {
    next(error);
  }
};

// Declines every open product in a requirement (sent together from the cart).
exports.rejectRequirementGroup = async (req, res, next) => {
  try {
    const result = await declineNegotiations({
      groupId: req.params.groupId,
      reason: req.body?.reason,
      actor: { id: req.user._id, role: req.user.role === 'staff' ? 'staff' : 'admin' },
      io: req.app.locals.io,
    });
    res.json({
      success: true,
      message: `Requirement ${result.requestNumber || ''} declined (${result.declined.length} products)`.replace('  ', ' '),
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

exports.counterNegotiation = async (req, res, next) => {
  try {
    const { pricePerUnit, message } = req.body;

    const negotiation = await Negotiation.findById(req.params.id);
    if (!negotiation) {
      throw new NotFoundError('Negotiation not found', 'NEGOTIATION_NOT_FOUND');
    }

    if (![NEGOTIATION_STATUS.PENDING, NEGOTIATION_STATUS.COUNTERED].includes(negotiation.status)) {
      throw new BadRequestError('Cannot counter in current status', 'INVALID_NEGOTIATION_STATUS');
    }

    if (negotiation.expiresAt <= new Date()) {
      const settings = await Settings.getSettings();
      negotiation.expiresAt = new Date(Date.now() + settings.negotiationExpiryDays * 24 * 60 * 60 * 1000);
    }

    const totalPrice = negotiation.requestedQuantity * pricePerUnit;

    negotiation.history.push({
      action: NEGOTIATION_ACTIONS.COUNTERED,
      by: 'admin',
      actorId: req.user._id,
      actorRole: 'admin',
      pricePerUnit,
      totalPrice,
      message,
    });

    negotiation.status = NEGOTIATION_STATUS.COUNTERED;
    negotiation.currentOfferBy = 'admin';
    negotiation.currentPricePerUnit = pricePerUnit;
    negotiation.currentTotalPrice = totalPrice;

    await negotiation.save();

    emitToNegotiationRoom(req.app.locals.io, negotiation._id.toString(), 'negotiation-countered', {
      negotiationId: negotiation._id.toString(),
      pricePerUnit,
      totalPrice,
      message: message || null,
      timestamp: new Date(),
    });

    // Send push notification to user
    try {
      await notificationService.sendLocalizedToUser(negotiation.wholesalerId, 'requirementNewPrice', {
        productName: negotiation.productSnapshot.name,
        productNameHindi: negotiation.productSnapshot.nameHindi,
        price: pricePerUnit,
      }, {
        type: 'negotiation_countered',
        negotiationId: negotiation._id.toString(),
      });
    } catch (notifErr) {
      console.error('Failed to send negotiation counter notification:', notifErr.message);
    }

    res.json({
      success: true,
      message: 'Counter offer sent',
      data: {
        status: negotiation.status,
        currentPricePerUnit: negotiation.currentPricePerUnit,
        currentTotalPrice: negotiation.currentTotalPrice,
      },
    });
  } catch (error) {
    next(error);
  }
};

// Admin: remove a declined requirement from the Deal Desk (and the database).
exports.deleteDeclinedNegotiation = async (req, res, next) => {
  try {
    const negotiation = await Negotiation.findById(req.params.id).select('status negotiationNumber').lean();
    if (!negotiation) throw new NotFoundError('Negotiation not found', 'NEGOTIATION_NOT_FOUND');
    if (negotiation.status !== NEGOTIATION_STATUS.REJECTED) {
      throw new BadRequestError('Only declined requirements can be deleted', 'NEGOTIATION_NOT_DECLINED');
    }
    await Negotiation.deleteOne({ _id: negotiation._id, status: NEGOTIATION_STATUS.REJECTED });
    await recordAudit({
      actorId: req.user._id,
      action: 'negotiation.deleted',
      entityType: 'negotiation',
      entityId: negotiation._id,
      metadata: { negotiationNumber: negotiation.negotiationNumber },
    }).catch(() => null);
    res.json({ success: true, message: 'Declined requirement deleted', data: { deleted: 1 } });
  } catch (error) {
    next(error);
  }
};

// Admin: clear every declined requirement from the Deal Desk.
exports.clearDeclinedNegotiations = async (req, res, next) => {
  try {
    const declined = await Negotiation.find({ status: NEGOTIATION_STATUS.REJECTED }).select('_id').lean();
    if (declined.length === 0) {
      return res.json({ success: true, message: 'No declined requirements to clear', data: { deleted: 0 } });
    }
    const { deletedCount } = await Negotiation.deleteMany({ _id: { $in: declined.map((n) => n._id) }, status: NEGOTIATION_STATUS.REJECTED });
    await recordAudit({
      actorId: req.user._id,
      action: 'negotiation.declined_cleared',
      entityType: 'negotiation',
      entityId: declined[0]._id,
      metadata: { count: deletedCount },
    }).catch(() => null);
    res.json({ success: true, message: `Cleared ${deletedCount} declined requirement${deletedCount === 1 ? '' : 's'}`, data: { deleted: deletedCount } });
  } catch (error) {
    next(error);
  }
};
