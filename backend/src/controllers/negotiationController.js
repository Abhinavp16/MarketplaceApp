const { Negotiation, Product, Settings } = require('../models');
const { NotFoundError, BadRequestError } = require('../utils/errors');
const { paginate, formatPaginationResponse } = require('../utils/helpers');
const { NEGOTIATION_STATUS, NEGOTIATION_ACTIONS } = require('../utils/constants');
const {
  getVariantById,
  getPriceForUser,
} = require('../utils/productVariants');
const { buildDiscountMap, discountsFor } = require('../services/productDiscountService');
const { notifyAdmins } = require('../services/adminNotificationService');

exports.getMyNegotiations = async (req, res, next) => {
  try {
    const { status } = req.query;
    const { page, limit, skip } = paginate(req.query.page, req.query.limit);

    const query = { wholesalerId: req.user._id };
    if (status) query.status = status;

    const [negotiations, total] = await Promise.all([
      Negotiation.find(query)
        .populate('orderId', 'orderNumber status total statusHistory trackingNumber courierName shippedAt deliveredAt')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      Negotiation.countDocuments(query),
    ]);

    const formatted = negotiations.map((negotiation) => {
      const accepted = (negotiation.history || []).filter((h) => h.action === NEGOTIATION_ACTIONS.ACCEPTED).pop();
      return {
        id: negotiation._id,
        negotiationNumber: negotiation.negotiationNumber,
        product: {
          id: negotiation.productId,
          variantId: negotiation.variantId || null,
          name: negotiation.productSnapshot.variantDisplayName || negotiation.productSnapshot.name,
          nameHindi: negotiation.productSnapshot.nameHindi || '',
          image: negotiation.productSnapshot.image,
          currentPrice: negotiation.productSnapshot.price,
        },
        requestedQuantity: negotiation.requestedQuantity,
        requestedPricePerUnit: negotiation.requestedPricePerUnit,
        requestedTotalPrice: negotiation.requestedTotalPrice,
        currentPricePerUnit: negotiation.currentPricePerUnit,
        currentTotalPrice: negotiation.currentTotalPrice,
        status: negotiation.status,
        currentOfferBy: negotiation.currentOfferBy,
        expiresAt: negotiation.expiresAt,
        canPay: negotiation.status === NEGOTIATION_STATUS.ACCEPTED && !negotiation.orderId,
        orderId: negotiation.orderId?._id ? String(negotiation.orderId._id) : null,
        orderNumber: negotiation.orderId?.orderNumber || null,
        approvedByRole: accepted?.actorRole || (accepted ? 'admin' : null),
        createdAt: negotiation.createdAt,
      };
    });

    res.json({
      success: true,
      ...formatPaginationResponse(formatted, total, page, limit),
    });
  } catch (error) {
    next(error);
  }
};

exports.createNegotiation = async (req, res, next) => {
  try {
    const { productId, quantity, pricePerUnit, message } = req.body;

    const product = await Product.findById(productId);
    if (!product) {
      throw new NotFoundError('Product not found', 'PRODUCT_NOT_FOUND');
    }

    if (!product.negotiationEnabled) {
      throw new BadRequestError('Negotiation is not enabled for this product', 'NEGOTIATION_DISABLED');
    }

    const resolved = getVariantById(product, null);
    if (!resolved) {
      throw new NotFoundError('Product not found', 'PRODUCT_NOT_FOUND');
    }

    const discounts = discountsFor(await buildDiscountMap([product]), product);
    const pricing = getPriceForUser(product, req.user.role, resolved.variant, discounts);
    const settings = await Settings.getSettings();
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + settings.negotiationExpiryDays);

    const totalPrice = quantity * pricePerUnit;

    const negotiation = await Negotiation.create({
      wholesalerId: req.user._id,
      productId,
      variantId: null,
      productSnapshot: {
        name: product.name,
        nameHindi: product.nameHindi || '',
        variantName: '',
        variantDisplayName: product.name,
        price: pricing.price,
        mrp: pricing.mrp || null,
        discountPercent: pricing.discountPercent,
        discountSource: pricing.discountSource,
        image: product.primaryImage,
        sku: product.sku,
        variantSku: '',
      },
      requestedQuantity: quantity,
      requestedPricePerUnit: pricePerUnit,
      requestedTotalPrice: totalPrice,
      message,
      history: [{
        action: NEGOTIATION_ACTIONS.REQUESTED,
        by: 'wholesaler',
        pricePerUnit,
        totalPrice,
        message: message || 'Initial request',
      }],
      currentOfferBy: 'wholesaler',
      currentPricePerUnit: pricePerUnit,
      currentTotalPrice: totalPrice,
      expiresAt,
    });

    await Product.findByIdAndUpdate(productId, { $inc: { negotiationCount: 1 } });

    notifyAdmins({
      type: 'negotiation_created',
      title: `New deal request ${negotiation.negotiationNumber}`,
      body: `${req.user?.name || 'A wholesaler'} requested ${quantity} × ${product.name} at ₹${pricePerUnit}/unit.`,
      link: '/negotiations',
      actor: { id: req.user?._id, name: req.user?.name, role: req.user?.role },
      metadata: { negotiationId: String(negotiation._id), negotiationNumber: negotiation.negotiationNumber, productId: String(productId), quantity },
    });

    res.status(201).json({
      success: true,
      message: 'Negotiation request submitted',
      data: {
        id: negotiation._id,
        negotiationNumber: negotiation.negotiationNumber,
        status: negotiation.status,
        expiresAt: negotiation.expiresAt,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.getNegotiationById = async (req, res, next) => {
  try {
    const negotiation = await Negotiation.findOne({
      _id: req.params.id,
      wholesalerId: req.user._id,
    })
      .populate('history.actorId', 'name username')
      .populate('orderId', 'orderNumber status total statusHistory trackingNumber courierName shippedAt deliveredAt shippingAddress');

    if (!negotiation) {
      throw new NotFoundError('Negotiation not found', 'NEGOTIATION_NOT_FOUND');
    }

    const data = negotiation.toObject();
    data.canPay = negotiation.status === NEGOTIATION_STATUS.ACCEPTED && !negotiation.orderId;
    const accepted = (data.history || []).filter((h) => h.action === NEGOTIATION_ACTIONS.ACCEPTED).pop();
    data.approvedBy = accepted
      ? {
          role: accepted.actorRole || 'admin',
          name: accepted.actorId?.name || accepted.actorId?.username || (accepted.actorRole === 'staff' ? 'Member' : 'Admin'),
        }
      : null;

    res.json({
      success: true,
      data,
    });
  } catch (error) {
    next(error);
  }
};

// NOTE: wholesaler accept / counter / reject were removed. Wholesalers
// negotiate through chat messages; only admin & staff accept from the panel.
exports.sendMessage = async (req, res, next) => {
  try {
    const { message, messageId } = req.body;

    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      throw new BadRequestError('Message cannot be empty', 'INVALID_MESSAGE');
    }

    if (message.length > 280) {
      throw new BadRequestError('Message too long (max 280 characters)', 'MESSAGE_TOO_LONG');
    }

    const negotiation = await Negotiation.findOne({
      _id: req.params.id,
      wholesalerId: req.user._id,
    });

    if (!negotiation) {
      throw new NotFoundError('Negotiation not found', 'NEGOTIATION_NOT_FOUND');
    }

    if (['rejected', 'expired'].includes(negotiation.status)) {
      throw new BadRequestError('Cannot send message in this negotiation status', 'INVALID_STATUS');
    }

    const messageEntry = {
      action: 'message',
      by: 'wholesaler',
      message: message.trim(),
      timestamp: new Date(),
      messageId: messageId || `${req.user._id}-${Date.now()}`,
    };

    negotiation.history.push(messageEntry);
    await negotiation.save();

    // Broadcast message via Socket.io
    const io = req.app.locals.io;
    if (io) {
      io.to(`negotiation-${req.params.id}`).emit('receive-message', {
        negotiationId: req.params.id,
        message: message.trim(),
        userId: req.user._id,
        userRole: 'wholesaler',
        timestamp: new Date(),
        messageId: messageEntry.messageId,
      });
    }

    notifyAdmins({
      type: 'negotiation_message',
      title: `New message in ${negotiation.negotiationNumber || 'deal'}`,
      body: `${req.user?.name || 'Wholesaler'}: ${message.trim().slice(0, 120)}`,
      link: '/negotiations',
      actor: { id: req.user?._id, name: req.user?.name, role: req.user?.role },
      metadata: { negotiationId: String(negotiation._id), negotiationNumber: negotiation.negotiationNumber },
      push: false,
    });

    res.json({
      success: true,
      message: 'Message sent',
      data: {
        messageId: messageEntry.messageId,
        timestamp: messageEntry.timestamp,
      },
    });
  } catch (error) {
    next(error);
  }
};
