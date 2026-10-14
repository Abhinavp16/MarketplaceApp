const { Negotiation, Product, Settings, Cart } = require('../models');
const { NotFoundError, BadRequestError } = require('../utils/errors');
const { paginate, formatPaginationResponse, generateRequestNumber } = require('../utils/helpers');
const crypto = require('crypto');
const { NEGOTIATION_STATUS, NEGOTIATION_ACTIONS } = require('../utils/constants');
const {
  getVariantById,
  getPriceForUser,
} = require('../utils/productVariants');
const { buildDiscountMap, discountsFor } = require('../services/productDiscountService');
const { notifyAdmins } = require('../services/adminNotificationService');
const { planCartRequirement, describeCartRequirement } = require('../utils/cartRequirement');
const { describePack, getPackInfo, isWholePacks } = require('../utils/packSize');
const { assertPurchasable } = require('../utils/productAvailability');

// Fields for a new wholesaler request (shared by the single-product and the
// whole-cart requests).
function buildNegotiationData({ product, user, quantity, pricePerUnit, message, discounts, expiresAt, requestGroup = null }) {
  const resolved = getVariantById(product, null);
  if (!resolved) {
    throw new NotFoundError('Product not found', 'PRODUCT_NOT_FOUND');
  }
  const pricing = getPriceForUser(product, user.role, resolved.variant, discounts);
  const unitPrice = pricePerUnit ?? pricing.price;
  const totalPrice = quantity * unitPrice;
  return {
    wholesalerId: user._id,
    productId: product._id,
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
      priceUnit: product.priceUnit || '',
      packing: product.packing || '',
    },
    requestGroup: requestGroup || { id: null, number: null },
    requestedQuantity: quantity,
    requestedPricePerUnit: unitPrice,
    requestedTotalPrice: totalPrice,
    message,
    history: [{
      action: NEGOTIATION_ACTIONS.REQUESTED,
      by: 'wholesaler',
      pricePerUnit: unitPrice,
      totalPrice,
      message: message || 'Initial request',
    }],
    currentOfferBy: 'wholesaler',
    currentPricePerUnit: unitPrice,
    currentTotalPrice: totalPrice,
    expiresAt,
  };
}

async function negotiationExpiryDate() {
  const settings = await Settings.getSettings();
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + settings.negotiationExpiryDays);
  return expiresAt;
}

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
          priceUnit: negotiation.productSnapshot.priceUnit || '',
          packing: negotiation.productSnapshot.packing || '',
        },
        requestGroup: negotiation.requestGroup?.id ? negotiation.requestGroup : null,
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
        // Lets the app keep a deal under Active until its order is paid.
        orderStatus: negotiation.orderId?.status || null,
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

    assertPurchasable(product);

    if (!product.negotiationEnabled) {
      throw new BadRequestError('Negotiation is not enabled for this product', 'NEGOTIATION_DISABLED');
    }

    if (!isWholePacks(product, quantity)) {
      throw new BadRequestError(
        `${product.name} is sold in full ${describePack(product)}`,
        'PACK_QUANTITY_REQUIRED',
      );
    }

    const discounts = discountsFor(await buildDiscountMap([product]), product);
    const negotiation = await Negotiation.create(buildNegotiationData({
      product,
      user: req.user,
      quantity,
      pricePerUnit,
      message,
      discounts,
      expiresAt: await negotiationExpiryDate(),
    }));

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


// Sends every product in the wholesaler's cart to the Deal Desk as a
// requirement (one negotiation per product, at the wholesaler's current
// price) and empties the cart. Nothing is sent if any item can't be.
exports.createFromCart = async (req, res, next) => {
  const created = [];
  try {
    const { message } = req.body;
    const cart = await Cart.findOne({ userId: req.user._id });
    if (!cart || cart.items.length === 0) {
      throw new BadRequestError('Cart is empty', 'CART_EMPTY');
    }

    const productIds = [...new Set(cart.items.map((item) => item.productId.toString()))];
    const products = await Product.find({ _id: { $in: productIds } });
    const productMap = Object.fromEntries(products.map((product) => [product._id.toString(), product]));
    const { lines, problems } = planCartRequirement(cart.items, productMap);
    if (problems.length > 0) {
      const error = new BadRequestError(
        `Some cart items can't be sent as a requirement: ${problems.map((problem) => problem.name || problem.productId).join(', ')}`,
        problems[0].code,
      );
      error.details = { items: problems };
      throw error;
    }

    const discountMap = await buildDiscountMap(lines.map((line) => line.product));
    const expiresAt = await negotiationExpiryDate();
    // One requirement number for everything sent together (accepted into one order).
    const requestGroup = lines.length > 1
      ? { id: crypto.randomUUID(), number: generateRequestNumber() }
      : null;
    for (const { product, quantity } of lines) {
      const negotiation = await Negotiation.create(buildNegotiationData({
        product,
        user: req.user,
        quantity,
        message,
        discounts: discountsFor(discountMap, product),
        expiresAt,
        requestGroup,
      }));
      created.push({ negotiation, product, quantity });
    }

    await Product.bulkWrite(created.map(({ product }) => ({
      updateOne: { filter: { _id: product._id }, update: { $inc: { negotiationCount: 1 } } },
    })));
    const sentIds = new Set(created.map(({ product }) => product._id.toString()));
    cart.items = cart.items.filter((item) => !sentIds.has(item.productId.toString()));
    await cart.save();

    const entries = created.map(({ negotiation, product, quantity }) => ({
      negotiationNumber: negotiation.negotiationNumber,
      productName: product.name,
      quantity,
    }));
    notifyAdmins({
      type: 'negotiation_created',
      ...describeCartRequirement(req.user?.name, entries),
      link: '/negotiations',
      actor: { id: req.user?._id, name: req.user?.name, role: req.user?.role },
      metadata: {
        negotiationIds: created.map(({ negotiation }) => String(negotiation._id)),
        negotiationNumbers: entries.map((entry) => entry.negotiationNumber),
        source: 'cart',
      },
    });

    res.status(201).json({
      success: true,
      message: 'Requirement sent',
      data: {
        requestGroup,
        negotiations: created.map(({ negotiation, product, quantity }) => ({
          id: negotiation._id,
          negotiationNumber: negotiation.negotiationNumber,
          productId: product._id,
          productName: product.name,
          quantity,
          status: negotiation.status,
          expiresAt: negotiation.expiresAt,
        })),
      },
    });
  } catch (error) {
    // Undo a half-finished send so a retry doesn't create duplicates.
    if (created.length > 0 && !res.headersSent) {
      await Negotiation.deleteMany({ _id: { $in: created.map(({ negotiation }) => negotiation._id) } })
        .catch(() => {});
    }
    next(error);
  }
};
exports.getNegotiationById = async (req, res, next) => {
  try {
    const negotiation = await Negotiation.findOne({
      _id: req.params.id,
      wholesalerId: req.user._id,
    })
      .populate('history.actorId', 'name')
      .populate('orderId', 'orderNumber status total statusHistory trackingNumber courierName shippedAt deliveredAt shippingAddress');

    if (!negotiation) {
      throw new NotFoundError('Negotiation not found', 'NEGOTIATION_NOT_FOUND');
    }

    const data = negotiation.toObject();
    // Wholesalers see who acted by name only (no member usernames or ids).
    data.history = (data.history || []).map((entry) => ({
      ...entry,
      actorId: entry.actorId?.name ? { name: entry.actorId.name } : null,
    }));
    data.canPay = negotiation.status === NEGOTIATION_STATUS.ACCEPTED && !negotiation.orderId;
    const accepted = (data.history || []).filter((h) => h.action === NEGOTIATION_ACTIONS.ACCEPTED).pop();
    data.approvedBy = accepted
      ? {
          role: accepted.actorRole || 'admin',
          name: accepted.actorId?.name || (accepted.actorRole === 'staff' ? 'Member' : 'Admin'),
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
