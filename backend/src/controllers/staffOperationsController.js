const mongoose = require('mongoose');
const Category = require('../models/Category');
const { Payment, Order, Negotiation, Product } = require('../models');
const { NotFoundError, BadRequestError, ForbiddenError } = require('../utils/errors');
const { paginate, formatPaginationResponse } = require('../utils/helpers');
const { PAYMENT_STATUS, ORDER_STATUS, NEGOTIATION_STATUS, NEGOTIATION_ACTIONS, PRODUCT_STATUS } = require('../utils/constants');
const { recordAudit } = require('../services/auditService');
const notificationService = require('../services/notificationService');
const { getEffectivePricing } = require('../utils/productVariants');
const { buildDiscountMap, discountsFor } = require('../services/productDiscountService');
const { isDemoMode } = require('../config/demoGuard');

const DEMO_APPROVAL_MESSAGE = 'Approval is reserved for the business owner in this demo';
const DEMO_APPROVAL_CODE = 'DEMO_APPROVAL_RESERVED';

async function notifyWholesaler(userId, templateKey, params, data) {
  try {
    await notificationService.sendLocalizedToUser(userId, templateKey, params, data);
  } catch (error) {
    console.error('Failed to send member negotiation notification:', error.message);
  }
}

exports.getProducts = async (req, res, next) => {
  try {
    const { page, limit, skip } = paginate(req.query.page, req.query.limit);
    const search = String(req.query.search || '').trim();
    const categoryId = String(req.query.categoryId || '').trim();
    const query = { status: { $ne: PRODUCT_STATUS.ARCHIVED } };
    const filters = [];

    if (categoryId) {
      if (!mongoose.isValidObjectId(categoryId)) {
        throw new BadRequestError('Invalid category ID', 'INVALID_CATEGORY_ID');
      }

      const category = await Category.findById(categoryId).select('_id name slug company').lean();
      if (!category) {
        throw new NotFoundError('Category not found', 'CATEGORY_NOT_FOUND');
      }

      const legacyCategoryValues = [category.name, category.slug].filter(Boolean);
      filters.push({
        $or: [
          { categoryRef: category._id },
          { company: category.company, category: { $in: legacyCategoryValues } },
        ],
      });
    }

    if (search) {
      filters.push({
        $or: [
          { name: { $regex: search, $options: 'i' } },
          { sku: { $regex: search, $options: 'i' } },
        ],
      });
    }

    if (filters.length > 0) query.$and = filters;

    const [products, total] = await Promise.all([
      Product.find(query)
        .select('name nameHindi sku category categoryRef company mrp retailPrice wholesalePrice stock status priceUnit packing images.url images.isPrimary')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      Product.countDocuments(query),
    ]);

    const discountMap = await buildDiscountMap(products);
    const productsWithPricing = products.map((product) => ({
      ...product,
      effectivePricing: getEffectivePricing(product, discountsFor(discountMap, product)),
    }));

    res.json({ success: true, ...formatPaginationResponse(productsWithPricing, total, page, limit) });
  } catch (error) {
    next(error);
  }
};

exports.ensurePendingUploadedPayment = async (req, res, next) => {
  try {
    const payment = await Payment.findById(req.params.id);
    if (!payment || payment.status !== PAYMENT_STATUS.PENDING || !payment.screenshotUrl) {
      throw new BadRequestError('Only uploaded pending payments can be approved', 'PAYMENT_NOT_REVIEWABLE');
    }

    const order = await Order.findById(payment.orderId);
    if (!order || order.status !== ORDER_STATUS.PAYMENT_UPLOADED) {
      throw new BadRequestError('Order is not ready for payment review', 'ORDER_NOT_READY_FOR_PAYMENT_REVIEW');
    }

    req.staffPayment = payment;
    next();
  } catch (error) {
    next(error);
  }
};

exports.holdPayment = async (req, res, next) => {
  try {
    const payment = await Payment.findById(req.params.id);
    if (!payment || payment.status !== PAYMENT_STATUS.PENDING || !payment.screenshotUrl) {
      throw new BadRequestError('Only uploaded pending payments can be held', 'PAYMENT_NOT_REVIEWABLE');
    }

    const order = await Order.findById(payment.orderId);
    if (!order || order.status !== ORDER_STATUS.PAYMENT_UPLOADED) {
      throw new BadRequestError('Order is not ready for payment review', 'ORDER_NOT_READY_FOR_PAYMENT_REVIEW');
    }

    payment.status = PAYMENT_STATUS.HELD;
    payment.holdReason = req.body.reason;
    payment.heldBy = req.user._id;
    payment.heldAt = new Date();
    await payment.save();

    order.statusHistory.push({
      status: order.status,
      note: `Payment held for admin review: ${req.body.reason}`,
      updatedBy: req.user._id,
      timestamp: new Date(),
    });
    await order.save();

    await recordAudit({
      actorId: req.user._id,
      action: 'payment.held',
      entityType: 'payment',
      entityId: payment._id,
      metadata: { orderId: String(order._id), reason: req.body.reason },
    });

    res.json({ success: true, message: 'Payment placed on hold for admin review.', data: { paymentId: payment._id, status: payment.status } });
  } catch (error) {
    next(error);
  }
};

exports.getNegotiations = async (req, res, next) => {
  try {
    const { status, search } = req.query;
    const { page, limit, skip } = paginate(req.query.page, req.query.limit);
    const query = {};
    const now = new Date();

    if (status === 'expired') {
      query.expiresAt = { $lte: now };
    } else if (status) {
      query.status = status;
    }
    if (search) {
      const safe = String(search).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      query.$or = [
        { negotiationNumber: { $regex: safe, $options: 'i' } },
        { 'productSnapshot.name': { $regex: safe, $options: 'i' } },
      ];
    }

    const [records, total] = await Promise.all([
      Negotiation.find(query).populate('wholesalerId', 'name email phone businessInfo.businessName').sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      Negotiation.countDocuments(query),
    ]);

    const data = records.map((record) => ({
      ...record,
      isExpired: new Date(record.expiresAt) <= now,
    }));

    res.json({ success: true, ...formatPaginationResponse(data, total, page, limit) });
  } catch (error) {
    next(error);
  }
};

exports.getNegotiationById = async (req, res, next) => {
  try {
    const negotiation = await Negotiation.findById(req.params.id)
      .populate('wholesalerId', 'name email phone businessInfo.businessName');
    if (!negotiation) throw new NotFoundError('Negotiation not found', 'NEGOTIATION_NOT_FOUND');

    res.json({
      success: true,
      data: { ...negotiation.toObject(), isExpired: negotiation.expiresAt <= new Date() },
    });
  } catch (error) {
    next(error);
  }
};

function assertStaffNegotiationAction(negotiation) {
  if ([NEGOTIATION_STATUS.PENDING, NEGOTIATION_STATUS.COUNTERED].includes(negotiation.status) && negotiation.expiresAt <= new Date()) {
    throw new ForbiddenError('Expired negotiations can only be continued by a full admin', 'NEGOTIATION_EXPIRED');
  }
  if (![NEGOTIATION_STATUS.PENDING, NEGOTIATION_STATUS.COUNTERED, NEGOTIATION_STATUS.ACCEPTED, NEGOTIATION_STATUS.CONVERTED].includes(negotiation.status)) {
    throw new BadRequestError('Cannot act in the current negotiation status', 'INVALID_NEGOTIATION_STATUS');
  }
}

exports.acceptNegotiation = async (req, res, next) => {
  try {
    const negotiation = await Negotiation.findById(req.params.id);
    if (!negotiation) throw new NotFoundError('Negotiation not found', 'NEGOTIATION_NOT_FOUND');
    // Demo: only the business owner (admin) may approve a negotiation.
    if (isDemoMode()) throw new ForbiddenError(DEMO_APPROVAL_MESSAGE, DEMO_APPROVAL_CODE);
    assertStaffNegotiationAction(negotiation);

    const staffName = req.user.name || req.user.username || 'Member';
    const { acceptNegotiationAndCreateOrder } = require('../services/negotiationOrderService');
    const { negotiation: updated, order, alreadyConverted } = await acceptNegotiationAndCreateOrder({
      negotiationId: negotiation._id,
      actor: { id: req.user._id, role: 'staff', name: staffName },
      message: req.body.message,
      shippingAddress: req.body.shippingAddress,
      customerNote: req.body.customerNote,
      io: req.app.locals.io,
    });
    if (!order) {
      throw new BadRequestError('Negotiation order could not be recovered. Please retry.', 'NEGOTIATION_ORDER_MISSING');
    }

    res.json({
      success: true,
      message: alreadyConverted ? 'Negotiation was already converted to an order' : 'Negotiation accepted — order confirmed',
      data: { status: updated.status, finalPricePerUnit: updated.finalPricePerUnit, orderId: String(order._id), orderNumber: order.orderNumber },
    });
  } catch (error) {
    next(error);
  }
};

exports.counterNegotiation = async (req, res, next) => {
  try {
    const negotiation = await Negotiation.findById(req.params.id);
    if (!negotiation) throw new NotFoundError('Negotiation not found', 'NEGOTIATION_NOT_FOUND');
    // Demo: staff cannot re-open or alter negotiations that are already approved.
    if (
      isDemoMode()
      && [NEGOTIATION_STATUS.ACCEPTED, NEGOTIATION_STATUS.CONVERTED].includes(negotiation.status)
    ) {
      throw new ForbiddenError(DEMO_APPROVAL_MESSAGE, DEMO_APPROVAL_CODE);
    }
    assertStaffNegotiationAction(negotiation);

    const totalPrice = negotiation.requestedQuantity * req.body.pricePerUnit;
    negotiation.history.push({
      action: NEGOTIATION_ACTIONS.COUNTERED,
      by: 'admin',
      actorId: req.user._id,
      actorRole: 'staff',
      pricePerUnit: req.body.pricePerUnit,
      totalPrice,
      message: req.body.message,
    });
    negotiation.status = NEGOTIATION_STATUS.COUNTERED;
    negotiation.currentOfferBy = 'admin';
    negotiation.currentPricePerUnit = req.body.pricePerUnit;
    negotiation.currentTotalPrice = totalPrice;
    await negotiation.save();

    const { emitToNegotiationRoom } = require('../services/negotiationOrderService');
    emitToNegotiationRoom(req.app.locals.io, negotiation._id.toString(), 'negotiation-countered', {
      negotiationId: negotiation._id.toString(),
      pricePerUnit: req.body.pricePerUnit,
      totalPrice,
      message: req.body.message || null,
      timestamp: new Date(),
    });

    await recordAudit({ actorId: req.user._id, action: 'negotiation.countered', entityType: 'negotiation', entityId: negotiation._id, metadata: { pricePerUnit: req.body.pricePerUnit } });
    await notifyWholesaler(negotiation.wholesalerId, 'requirementNewPrice', {
      productName: negotiation.productSnapshot.name,
      productNameHindi: negotiation.productSnapshot.nameHindi,
      price: req.body.pricePerUnit,
    }, { type: 'negotiation_countered', negotiationId: negotiation._id.toString() });

    res.json({ success: true, message: 'Counter offer sent', data: { status: negotiation.status, currentPricePerUnit: negotiation.currentPricePerUnit } });
  } catch (error) {
    next(error);
  }
};
