const { Negotiation, User, Settings } = require('../../models');
const { NotFoundError, BadRequestError } = require('../../utils/errors');
const { paginate, formatPaginationResponse } = require('../../utils/helpers');
const { NEGOTIATION_STATUS, NEGOTIATION_ACTIONS } = require('../../utils/constants');
const notificationService = require('../../services/notificationService');
const { recordAudit } = require('../../services/auditService');
const {
  acceptNegotiationAndCreateOrder,
  emitToNegotiationRoom,
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
      },
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
    const { message, shippingAddress, customerNote } = req.body;

    const actorName = req.user.name || req.user.email || 'Admin';
    const { negotiation, order, alreadyConverted, addressSource } =
      await acceptNegotiationAndCreateOrder({
        negotiationId: req.params.id,
        actor: { id: req.user._id, role: 'admin', name: actorName },
        message,
        shippingAddress,
        customerNote,
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
        addressSource,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.rejectNegotiation = async (req, res, next) => {
  try {
    const { reason } = req.body;

    const negotiation = await Negotiation.findById(req.params.id);
    if (!negotiation) {
      throw new NotFoundError('Negotiation not found', 'NEGOTIATION_NOT_FOUND');
    }

    if ([NEGOTIATION_STATUS.REJECTED, NEGOTIATION_STATUS.CONVERTED, NEGOTIATION_STATUS.ACCEPTED].includes(negotiation.status)) {
      throw new BadRequestError('Cannot reject in current status', 'INVALID_NEGOTIATION_STATUS');
    }

    negotiation.history.push({
      action: NEGOTIATION_ACTIONS.REJECTED,
      by: 'admin',
      actorId: req.user._id,
      actorRole: 'admin',
      message: reason,
    });

    negotiation.status = NEGOTIATION_STATUS.REJECTED;
    await negotiation.save();

    emitToNegotiationRoom(req.app.locals.io, negotiation._id.toString(), 'negotiation-rejected', {
      negotiationId: negotiation._id.toString(),
      reason: reason || null,
      timestamp: new Date(),
    });

    // Send push notification to user
    try {
      await notificationService.sendLocalizedToUser(negotiation.wholesalerId, reason ? 'requirementDeclinedWithReason' : 'requirementDeclined', {
        productName: negotiation.productSnapshot.name,
        productNameHindi: negotiation.productSnapshot.nameHindi,
        reason,
      }, {
        type: 'negotiation_rejected',
        negotiationId: negotiation._id.toString(),
      });
    } catch (notifErr) {
      console.error('Failed to send negotiation rejected notification:', notifErr.message);
    }

    res.json({
      success: true,
      message: 'Negotiation rejected',
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
