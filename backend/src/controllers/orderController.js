const { Order, Cart, Product, Negotiation, Settings, AffiliateCode, Offer } = require('../models');
const { NotFoundError, BadRequestError, UnauthorizedError } = require('../utils/errors');
const { paginate, formatPaginationResponse } = require('../utils/helpers');
const { ORDER_STATUS, ORDER_TYPES, NEGOTIATION_STATUS, USER_ROLES } = require('../utils/constants');
const { createOrderWorkbookBuffer, sanitizeFileNamePart } = require('../utils/orderWorkbook');
const { orderWhatsAppNumber } = require('../config/publicBusiness');
const { createOrderReceiptPdfBuffer } = require('../utils/orderReceiptPdf');
const {
  normalizeObjectIdLike,
  getVariantById,
  getPriceForUser,
  buildVariantSnapshot,
  getVariantDisplayName,
} = require('../utils/productVariants');
const { buildDiscountMap, discountsFor } = require('../services/productDiscountService');
const { round2 } = require('../utils/productDiscount');
const { withDisplayNotes } = require('../utils/roleLabels');
const { notifyAdmins } = require('../services/adminNotificationService');

const cartItemKey = (productId, variantId) => `${productId}:${variantId || 'default'}`;

const calculateDiscount = (subtotal, discountType, discountValue, maxDiscountAmount) => {
  let discount = 0;

  if (discountType === 'percentage') {
    discount = (subtotal * discountValue) / 100;
  } else {
    discount = discountValue;
  }

  if (maxDiscountAmount && discount > maxDiscountAmount) {
    discount = maxDiscountAmount;
  }

  if (discount > subtotal) {
    discount = subtotal;
  }

  return Number(discount.toFixed(2));
};

const normalizeDiscountRules = (rules = []) => {
  if (!Array.isArray(rules)) return [];
  return rules
    .map((rule) => ({
      minPurchaseAmount: Number(rule?.minPurchaseAmount || 0),
      discountType: rule?.discountType === 'fixed' ? 'fixed' : 'percentage',
      discountValue: Number(rule?.discountValue || 0),
      maxDiscountAmount: rule?.maxDiscountAmount === null || rule?.maxDiscountAmount === undefined || rule?.maxDiscountAmount === ''
        ? undefined
        : Number(rule.maxDiscountAmount),
    }))
    .filter((rule) => rule.discountValue >= 0 && rule.minPurchaseAmount >= 0)
    .sort((a, b) => b.minPurchaseAmount - a.minPurchaseAmount);
};

const pickDiscountRule = (subtotal, rules, fallback) => {
  const normalizedRules = normalizeDiscountRules(rules);
  if (normalizedRules.length > 0) {
    const matchedRule = normalizedRules.find((rule) => subtotal >= rule.minPurchaseAmount);
    if (!matchedRule) {
      const minRequired = Math.min(...normalizedRules.map((rule) => rule.minPurchaseAmount));
      return { matchedRule: null, minRequired };
    }
    return { matchedRule, minRequired: matchedRule.minPurchaseAmount };
  }

  return {
    matchedRule: {
      minPurchaseAmount: Number(fallback?.minPurchaseAmount || 0),
      discountType: fallback?.discountType || 'percentage',
      discountValue: Number(fallback?.discountValue || 0),
      maxDiscountAmount: fallback?.maxDiscountAmount,
    },
    minRequired: Number(fallback?.minPurchaseAmount || 0),
  };
};

const validateAffiliateCandidate = (affiliate) => {
  const now = new Date();

  if (!affiliate.isActive) {
    throw new BadRequestError('Invalid or expired coupon code', 'INVALID_COUPON');
  }

  if (new Date(affiliate.startDate) > now) {
    throw new BadRequestError('Invalid or expired coupon code', 'INVALID_COUPON');
  }

  if (affiliate.endDate && new Date(affiliate.endDate) < now) {
    throw new BadRequestError('Invalid or expired coupon code', 'INVALID_COUPON');
  }

  if (affiliate.usageLimit !== 0 && affiliate.usageCount >= affiliate.usageLimit) {
    throw new BadRequestError('Invalid or expired coupon code', 'INVALID_COUPON');
  }
};

const resolveCouponDiscount = async ({ couponCode, subtotal, userRole }) => {
  if (!couponCode || !couponCode.trim()) {
    return {
      discountSource: null,
      discount: 0,
      offerCode: null,
      affiliateCode: null,
      affiliateMeta: null,
    };
  }

  const normalizedCode = couponCode.trim().toUpperCase();
  const now = new Date();

  const affiliate = await AffiliateCode.findOne({ code: normalizedCode });
  if (affiliate) {
    validateAffiliateCandidate(affiliate);

    const { matchedRule, minRequired } = pickDiscountRule(subtotal, affiliate.discountRules, {
      minPurchaseAmount: 0,
      discountType: affiliate.discountType,
      discountValue: affiliate.discountValue,
      maxDiscountAmount: undefined,
    });

    if (!matchedRule) {
      throw new BadRequestError(
        `Minimum purchase amount for this coupon is ₹${minRequired}`,
        'COUPON_MIN_PURCHASE_NOT_MET'
      );
    }

    const discount = calculateDiscount(
      subtotal,
      matchedRule.discountType,
      matchedRule.discountValue,
      matchedRule.maxDiscountAmount
    );

    if (discount <= 0) {
      throw new BadRequestError('Coupon is not applicable for this order', 'COUPON_NOT_APPLICABLE');
    }

    return {
      discountSource: 'affiliate',
      discount,
      offerCode: null,
      affiliateCode: affiliate.code,
      affiliateMeta: {
        id: affiliate._id,
        personName: affiliate.personName,
      },
    };
  }

  const targetGroup = userRole === USER_ROLES.WHOLESALER
    ? USER_ROLES.WHOLESALER
    : USER_ROLES.BUYER;

  const offer = await Offer.findOne({
    code: normalizedCode,
    isActive: true,
    startDate: { $lte: now },
    targetGroup: { $in: [targetGroup, 'all'] },
    $or: [
      { endDate: null },
      { endDate: { $exists: false } },
      { endDate: { $gte: now } },
    ],
  });

  if (!offer) {
    throw new BadRequestError('Invalid or expired coupon code', 'INVALID_COUPON');
  }

  const { matchedRule, minRequired } = pickDiscountRule(subtotal, offer.discountRules, {
    minPurchaseAmount: offer.minPurchaseAmount || 0,
    discountType: offer.discountType,
    discountValue: offer.discountValue,
    maxDiscountAmount: offer.maxDiscountAmount,
  });

  if (!matchedRule || subtotal < (minRequired || 0)) {
    throw new BadRequestError(
      `Minimum purchase amount for this coupon is ₹${minRequired}`,
      'COUPON_MIN_PURCHASE_NOT_MET'
    );
  }

  const discount = calculateDiscount(
    subtotal,
    matchedRule.discountType,
    matchedRule.discountValue,
    matchedRule.maxDiscountAmount
  );

  if (discount <= 0) {
    throw new BadRequestError('Coupon is not applicable for this order', 'COUPON_NOT_APPLICABLE');
  }

  return {
    discountSource: 'offer',
    offerCode: offer.code,
    affiliateCode: null,
    affiliateMeta: null,
    discount,
  };
};

const resolveCheckoutSettings = async () => {
  const settings = await Settings.getSettings();
  const checkout = settings.checkout || {};
  const whatsappNumber = orderWhatsAppNumber;

  return {
    settings,
    checkout: {
      mode: 'whatsapp',
      orderWhatsappNumber: whatsappNumber,
      requireLoginForCheckout: true,
      createOrderBeforeRedirect: true,
      allowNegotiationCheckout: checkout.allowNegotiationCheckout !== false,
    },
  };
};

const sanitizePhoneForWhatsApp = (value = '') => {
  const digits = String(value).replace(/[^\d]/g, '');
  if (!digits) return '';
  if (digits.length === 10) {
    return `91${digits}`;
  }
  if (digits.length === 12 && digits.startsWith('91')) {
    return digits;
  }
  return digits;
};

const buildOrderMessage = ({
  orderNumber,
  orderType,
  user,
  shippingAddress,
  items,
  subtotal,
  deliveryFee,
  discount,
  total,
  customerNote,
}) => {
  const lines = [
    'Hello, I would like to place an order.',
    '',
    orderNumber ? `Order Ref: ${orderNumber}` : 'Order Ref: New WhatsApp enquiry',
    `Customer: ${user?.name || shippingAddress?.fullName || ''}`,
    `Phone: ${shippingAddress?.phone || user?.phone || ''}`,
  ];

  if (user?.email) {
    lines.push(`Email: ${user.email}`);
  }

  if (user?.businessInfo?.businessName) {
    lines.push(`Business: ${user.businessInfo.businessName}`);
  }

  lines.push(`Order Type: ${orderType === ORDER_TYPES.WHOLESALE ? 'Wholesale' : 'Retail'}`);
  lines.push('');
  lines.push('Items:');

  items.forEach((item, index) => {
    const label = item.variantSnapshot?.displayName || item.productSnapshot?.name;
    const detailParts = [];
    if (item.variantSnapshot?.packing) detailParts.push(item.variantSnapshot.packing);
    if (item.variantSnapshot?.priceUnit) detailParts.push(`per ${item.variantSnapshot.priceUnit}`);

    lines.push(
      `${index + 1}. ${label} | Qty: ${item.quantity} | Rate: ₹${item.pricePerUnit} | Total: ₹${item.totalPrice}`
    );

    if (Array.isArray(item.variantSnapshot?.attributes) && item.variantSnapshot.attributes.length > 0) {
      lines.push(`   Specs: ${item.variantSnapshot.attributes.map((attr) => `${attr.key}: ${attr.value}`).join(', ')}`);
    }

    if (detailParts.length > 0) {
      lines.push(`   Details: ${detailParts.join(', ')}`);
    }
  });

  lines.push('');
  lines.push(`Subtotal: ₹${subtotal}`);
  lines.push(`Delivery: ₹${deliveryFee}`);
  if (discount > 0) {
    lines.push(`Discount: -₹${discount}`);
  }
  lines.push(`Grand Total: ₹${total}`);
  lines.push('');
  lines.push('Shipping Address:');
  lines.push(shippingAddress?.fullName || '');
  lines.push(shippingAddress?.addressLine1 || '');
  if (shippingAddress?.addressLine2) {
    lines.push(shippingAddress.addressLine2);
  }
  lines.push(`${shippingAddress?.city || ''}, ${shippingAddress?.state || ''} - ${shippingAddress?.pincode || ''}`);

  if (customerNote) {
    lines.push('');
    lines.push(`Note: ${customerNote}`);
  }

  return lines.filter((line) => line !== null && line !== undefined).join('\n').trim();
};

const buildWhatsAppPayload = (phoneNumber, message) => {
  const sanitized = sanitizePhoneForWhatsApp(phoneNumber);
  return {
    whatsappNumber: sanitized,
    whatsappMessage: message,
    whatsappUrl: sanitized
      ? `https://wa.me/${sanitized}?text=${encodeURIComponent(message)}`
      : null,
  };
};

const buildCheckoutCaption = ({
  user,
  shippingAddress,
}) => {
  const customerName = user?.name || shippingAddress?.fullName || 'customer';
  return `Hi, I am ${customerName}. Please find my order receipt attached.`;
};

const buildOrderExportPath = (orderId, format = 'pdf') =>
  orderId ? `/orders/${orderId}/export?format=${format}` : null;

const getOwnedOrderOrThrow = async (orderId, userId) => {
  const order = await Order.findOne({
    _id: orderId,
    userId,
  });

  if (!order) {
    throw new NotFoundError('Order not found', 'ORDER_NOT_FOUND');
  }

  return order;
};

const getCurrentCartPricing = async (userId, userRole) => {
  const cart = await Cart.findOne({ userId });
  if (!cart || cart.items.length === 0) {
    throw new BadRequestError('Cart is empty', 'CART_EMPTY');
  }

  const productIds = [...new Set(cart.items.map(item => item.productId.toString()))];
  const products = await Product.find({ _id: { $in: productIds } }).select('mrp retailPrice wholesalePrice stock company categoryRef category');
  const productMap = products.reduce((acc, product) => {
    acc[product._id.toString()] = product;
    return acc;
  }, {});

  const discountMap = await buildDiscountMap(products);
  let subtotal = 0;
  let itemCount = 0;

  for (const item of cart.items) {
    const product = productMap[item.productId.toString()];
    if (!product) continue;

    const resolved = getVariantById(product, null);
    if (!resolved) continue;

    const pricing = getPriceForUser(product, userRole, resolved.variant, discountsFor(discountMap, product));
    subtotal = round2(subtotal + pricing.price * item.quantity);
    itemCount += item.quantity;
  }

  if (subtotal <= 0 || itemCount <= 0) {
    throw new BadRequestError('No valid items in cart', 'CART_EMPTY');
  }

  return { subtotal, itemCount };
};

const buildProductMap = (products = []) => products.reduce((acc, product) => {
  acc[product._id.toString()] = product;
  return acc;
}, {});

const getMinimumWholesaleQuantity = (product) => {
  const value = Number(product?.minWholesaleQuantity);
  return Number.isInteger(value) && value > 0 ? value : 1;
};

// productMap products must include company/categoryRef/category;
// discountMap comes from buildDiscountMap (brand/category % off MRP).
const prepareOrderItems = ({ itemsToProcess, productMap, userRole, discountMap = null }) => {
  const orderItems = [];
  const stockIssues = [];
  let subtotal = 0;

  for (const item of itemsToProcess) {
    const product = productMap[item.productId.toString()];
    const normalizedVariantId = null;

    if (!product) {
      stockIssues.push({
        productId: item.productId.toString(),
        variantId: normalizedVariantId,
        cartItemKey: cartItemKey(item.productId.toString(), normalizedVariantId),
        message: 'Selected product is no longer available',
      });
      continue;
    }

    const resolved = getVariantById(product, null);
    if (!resolved || (!resolved.isLegacy && resolved.variant.isActive === false)) {
      stockIssues.push({
        productId: item.productId.toString(),
        variantId: normalizedVariantId,
        cartItemKey: cartItemKey(item.productId.toString(), normalizedVariantId),
        name: product.name,
        message: 'Selected product is no longer available',
      });
      continue;
    }

    const minimumQuantity = getMinimumWholesaleQuantity(product);
    if (
      userRole === USER_ROLES.WHOLESALER &&
      item.quantity < minimumQuantity
    ) {
      const itemName = getVariantDisplayName(product, resolved.variant);
      stockIssues.push({
        productId: item.productId.toString(),
        variantId: resolved.variantId,
        cartItemKey: cartItemKey(item.productId.toString(), resolved.variantId),
        name: itemName,
        type: 'minimum_wholesale_quantity',
        minimumWholesaleQuantity: minimumQuantity,
        availableStock: resolved.variant.stock,
        requestedQty: item.quantity,
        message: `Minimum wholesale quantity for ${itemName} is ${minimumQuantity}`,
      });
      continue;
    }

    if (resolved.variant.stock < item.quantity) {
      const itemName = getVariantDisplayName(product, resolved.variant);
      stockIssues.push({
        productId: item.productId.toString(),
        variantId: resolved.variantId,
        cartItemKey: cartItemKey(item.productId.toString(), resolved.variantId),
        name: itemName,
        availableStock: resolved.variant.stock,
        requestedQty: item.quantity,
        message: resolved.variant.stock === 0
          ? `${itemName} is out of stock`
          : `Only ${resolved.variant.stock} units of ${itemName} available (you requested ${item.quantity})`,
      });
      continue;
    }

    const pricing = getPriceForUser(product, userRole, resolved.variant, discountsFor(discountMap, product));
    const pricePerUnit = pricing.price;
    const itemTotal = round2(pricePerUnit * item.quantity);

    orderItems.push({
      productId: product._id,
      variantId: resolved.variantId,
      productSnapshot: {
        name: product.name,
        nameHindi: product.nameHindi || '',
        sku: product.sku,
        image: product.primaryImage,
      },
      variantSnapshot: buildVariantSnapshot(product, resolved.variant),
      quantity: item.quantity,
      pricePerUnit,
      mrpPerUnit: pricing.mrp || null,
      discountPercent: pricing.discountPercent,
      discountSource: pricing.discountSource,
      discountSourceName: pricing.discountSourceName,
      totalPrice: itemTotal,
    });
    subtotal = round2(subtotal + itemTotal);
  }

  return { orderItems, subtotal, stockIssues };
};

exports.previewCouponForCart = async (req, res, next) => {
  try {
    const { couponCode, subtotal: requestedSubtotal } = req.body;
    const userRole = req.user?.role || USER_ROLES.BUYER;

    let subtotal = 0;
    let itemCount = 0;

    if (requestedSubtotal !== undefined && requestedSubtotal !== null) {
      subtotal = parseFloat(requestedSubtotal);
      itemCount = 1;
    } else {
      if (!req.user?._id) {
        throw new BadRequestError(
          'Login required to apply coupon from cart',
          'LOGIN_REQUIRED_FOR_CART_COUPON'
        );
      }
      const cartPricing = await getCurrentCartPricing(req.user._id, req.user.role);
      subtotal = cartPricing.subtotal;
      itemCount = cartPricing.itemCount;
    }

    const {
      discountSource,
      offerCode,
      affiliateCode,
      affiliateMeta,
      discount,
    } = await resolveCouponDiscount({
      couponCode,
      subtotal,
      userRole,
    });

    const deliveryFee = subtotal > 0 ? 50 : 0;
    const totalBeforeDiscount = subtotal + deliveryFee;
    const payableTotal = Math.max(totalBeforeDiscount - discount, 0);

    res.json({
      success: true,
      message: 'Coupon applied successfully',
      data: {
        couponCode: offerCode || affiliateCode,
        discountSource,
        affiliateCode,
        affiliatePersonName: affiliateMeta?.personName || null,
        itemCount,
        subtotal,
        deliveryFee,
        totalBeforeDiscount,
        discount,
        payableTotal,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.getMyOrders = async (req, res, next) => {
  try {
    const { status } = req.query;
    const { page, limit, skip } = paginate(req.query.page, req.query.limit);
    const { checkout } = await resolveCheckoutSettings();

    const query = { userId: req.user._id };
    if (status) query.status = status;

    const [orders, total] = await Promise.all([
      Order.find(query)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      Order.countDocuments(query),
    ]);

    const formatted = orders.map((order) => ({
      id: order._id,
      orderNumber: order.orderNumber,
      orderType: order.orderType,
      negotiationId: order.negotiationId ? String(order.negotiationId) : null,
      items: order.items.map((item) => ({
        productId: item.productId ? String(item.productId) : null,
        name: item.variantSnapshot?.displayName || item.productSnapshot.name,
        nameHindi: item.productSnapshot?.nameHindi || '',
        quantity: item.quantity,
        pricePerUnit: item.pricePerUnit,
        mrpPerUnit: item.mrpPerUnit ?? null,
        discountPercent: item.discountPercent ?? null,
        discountSource: item.discountSource ?? null,
        totalPrice: item.totalPrice,
        image: item.productSnapshot.image,
        variantId: item.variantId || null,
        variantSnapshot: item.variantSnapshot || null,
      })),
      subtotal: order.subtotal,
      deliveryFee: order.deliveryFee,
      discount: order.discount,
      total: order.total,
      shippingAddress: order.shippingAddress,
      customerNote: order.customerNote,
      status: order.status,
      acceptanceStatus: order.acceptanceStatus,
      acceptedAt: order.acceptedAt,
      rejectedAt: order.rejectedAt,
      rejectionReason: order.rejectionReason,
      statusHistory: withDisplayNotes(order.statusHistory),
      trackingNumber: order.trackingNumber,
      courierName: order.courierName,
      shippedAt: order.shippedAt,
      deliveredAt: order.deliveredAt,
      createdAt: order.createdAt,
      checkoutMethod: 'whatsapp',
      exportPath: buildOrderExportPath(order._id, 'pdf'),
      ...buildWhatsAppPayload(
        checkout.orderWhatsappNumber,
        buildCheckoutCaption({
          user: req.user,
          shippingAddress: order.shippingAddress,
        })
      ),
    }));

    res.json({
      success: true,
      ...formatPaginationResponse(formatted, total, page, limit),
    });
  } catch (error) {
    next(error);
  }
};

exports.createOrderFromCart = async (req, res, next) => {
  try {
    const userRole = req.user?.role || 'guest';
    const { items, shippingAddress, customerNote, affiliateCode, couponCode } = req.body;
    const inputCode = (couponCode || affiliateCode || '').trim().toUpperCase();
    const { checkout } = await resolveCheckoutSettings();

    if (checkout.requireLoginForCheckout && !req.user?._id) {
      throw new UnauthorizedError(
        'Login required for ordering',
        'LOGIN_REQUIRED_FOR_ORDERING'
      );
    }

    let productIds = [];
    let cart = null;
    let itemsToProcess = [];
    const directItems = Array.isArray(items) && items.length > 0;

    if (directItems) {
      itemsToProcess = items;
      productIds = items.map((item) => item.productId);
    } else {
      if (!req.user?._id) {
        throw new BadRequestError(
          'Login required to checkout from cart',
          'LOGIN_REQUIRED_FOR_CART_CHECKOUT'
        );
      }
      cart = await Cart.findOne({ userId: req.user._id });
      if (!cart || cart.items.length === 0) {
        throw new BadRequestError('Cart is empty', 'CART_EMPTY');
      }
      itemsToProcess = cart.items;
      productIds = cart.items.map((item) => item.productId);
    }

    const products = await Product.find({ _id: { $in: productIds } });
    const productMap = buildProductMap(products);
    const discountMap = await buildDiscountMap(products);
    const { orderItems, subtotal, stockIssues } = prepareOrderItems({ itemsToProcess, productMap, userRole, discountMap });

    if (stockIssues.length > 0) {
      const msg = stockIssues.map((issue) => issue.message).join('; ');
      const code = stockIssues.some(
        (issue) => issue.type === 'minimum_wholesale_quantity'
      )
        ? 'MIN_WHOLESALE_QUANTITY_NOT_MET'
        : 'INSUFFICIENT_STOCK';
      return res.status(400).json({
        success: false,
        message: msg,
        code,
        data: { issues: stockIssues },
      });
    }

    if (orderItems.length === 0) {
      throw new BadRequestError('No valid items in cart', 'CART_EMPTY');
    }

    const {
      discountSource,
      offerCode,
      affiliateCode: resolvedAffiliateCode,
      discount,
    } = await resolveCouponDiscount({
      couponCode: inputCode,
      subtotal,
      userRole,
    });
    const deliveryFee = subtotal > 0 ? 50 : 0;
    const total = round2(Math.max(subtotal + deliveryFee - discount, 0));

    let order = null;
    const shouldCreateOrderRecord = checkout.createOrderBeforeRedirect && Boolean(req.user?._id);
    if (shouldCreateOrderRecord) {
      order = await Order.create({
        userId: req.user._id,
        customerSnapshot: {
          name: req.user.name,
          email: req.user.email,
          phone: req.user.phone || shippingAddress?.phone,
          businessName: req.user.businessInfo?.businessName,
        },
        orderType: ORDER_TYPES.RETAIL,
        acceptanceStatus: userRole === USER_ROLES.BUYER ? 'pending' : null,
        items: orderItems,
        subtotal,
        deliveryFee,
        discount,
        discountSource,
        affiliateDiscountAmount: discountSource === 'affiliate' ? discount : 0,
        total,
        shippingAddress,
        customerNote,
        statusHistory: [{
          status: ORDER_STATUS.PENDING_PAYMENT,
          note: userRole === USER_ROLES.BUYER
            ? 'Customer order submitted for approval'
            : 'Order submitted',
        }],
        affiliateCode: resolvedAffiliateCode,
        offerCode,
      });

      if (discountSource === 'offer' && offerCode) {
        await Offer.findOneAndUpdate({ code: offerCode }, { $inc: { usageCount: 1 } });
      } else if (discountSource === 'affiliate' && resolvedAffiliateCode) {
        await AffiliateCode.findOneAndUpdate({ code: resolvedAffiliateCode }, { $inc: { usageCount: 1 } });
      }

      for (const item of orderItems) {
        await Product.findByIdAndUpdate(item.productId, { $inc: { orderCount: 1 } });
      }

      if (!directItems && cart) {
        cart.items = [];
        await cart.save();
      }
    }

    if (order) {
      await notifyAdmins({
        type: 'order_created',
        title: `New order ${order.orderNumber || ''}`.trim(),
        body: `${req.user?.name || 'A customer'} placed an order of ₹${total}.`,
        link: '/orders',
        actor: { id: req.user?._id, name: req.user?.name, role: req.user?.role },
        metadata: { orderId: String(order._id), orderNumber: order.orderNumber, total },
        includeStaff: true,
      });
    }

    const orderMessage = buildCheckoutCaption({
      orderNumber: order?.orderNumber || null,
      user: req.user,
      shippingAddress,
    });

    const whatsappPayload = buildWhatsAppPayload(checkout.orderWhatsappNumber, orderMessage);

    const requiresApproval = order?.acceptanceStatus === 'pending';
    res.status(201).json({
      success: true,
      message: requiresApproval ? 'Order placed. Awaiting acceptance.' : 'Order placed successfully.',
      data: {
        orderId: order?._id || null,
        orderNumber: order?.orderNumber || null,
        subtotal,
        deliveryFee,
        discount,
        total,
        status: order?.status || null,
        acceptanceStatus: order?.acceptanceStatus || null,
        nextAction: requiresApproval ? 'await_acceptance' : 'legacy_checkout',
        requiresWhatsapp: !requiresApproval,
        offerCode: order?.offerCode || offerCode || null,
        affiliateCode: order?.affiliateCode || resolvedAffiliateCode || null,
        discountSource: order?.discountSource || discountSource || null,
        checkoutMethod: 'whatsapp',
        orderRecorded: Boolean(order),
        exportAvailable: Boolean(order),
        exportPath: buildOrderExportPath(order?._id, 'pdf'),
        ...whatsappPayload,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.createOrderFromNegotiation = async (req, res, next) => {
  try {
    const { negotiationId, shippingAddress, customerNote, affiliateCode, couponCode } = req.body;
    const inputCode = (couponCode || affiliateCode || '').trim().toUpperCase();
    const { checkout } = await resolveCheckoutSettings();

    if (!checkout.allowNegotiationCheckout) {
      throw new BadRequestError('Negotiation checkout is currently disabled', 'NEGOTIATION_CHECKOUT_DISABLED');
    }

    const negotiation = await Negotiation.findOne({
      _id: negotiationId,
      wholesalerId: req.user._id,
      status: NEGOTIATION_STATUS.ACCEPTED,
      orderId: null,
      expiresAt: { $gt: new Date() },
    });

    if (!negotiation) {
      throw new NotFoundError('Valid negotiation not found', 'NEGOTIATION_NOT_FOUND');
    }

    const product = await Product.findById(negotiation.productId);
    if (!product) {
      throw new NotFoundError('Product not found', 'PRODUCT_NOT_FOUND');
    }

    const resolved = getVariantById(product, null);
    if (!resolved) {
      throw new BadRequestError('Negotiated product no longer exists', 'PRODUCT_NOT_FOUND');
    }

    if (resolved.variant.stock < negotiation.requestedQuantity) {
      throw new BadRequestError('Insufficient stock', 'INSUFFICIENT_STOCK');
    }

    const minimumQuantity = getMinimumWholesaleQuantity(product);
    if (negotiation.requestedQuantity < minimumQuantity) {
      throw new BadRequestError(
        `Minimum wholesale quantity for ${product.name} is ${minimumQuantity}`,
        'MIN_WHOLESALE_QUANTITY_NOT_MET'
      );
    }

    const subtotal = negotiation.finalTotalPrice;
    const {
      discountSource,
      offerCode,
      affiliateCode: resolvedAffiliateCode,
      discount,
    } = await resolveCouponDiscount({
      couponCode: inputCode,
      subtotal,
      userRole: req.user.role,
    });
    const total = Math.max(subtotal - discount, 0);

    let order = null;
    const orderItems = [{
      productId: product._id,
      variantId: null,
      productSnapshot: {
        name: product.name,
        nameHindi: product.nameHindi || '',
        sku: product.sku,
        image: product.primaryImage,
      },
      variantSnapshot: buildVariantSnapshot(product, resolved.variant),
      quantity: negotiation.requestedQuantity,
      pricePerUnit: negotiation.finalPricePerUnit,
      totalPrice: negotiation.finalTotalPrice,
    }];

    if (checkout.createOrderBeforeRedirect) {
      order = await Order.create({
        userId: req.user._id,
        customerSnapshot: {
          name: req.user.name,
          email: req.user.email,
          phone: req.user.phone || shippingAddress?.phone,
          businessName: req.user.businessInfo?.businessName,
        },
        orderType: ORDER_TYPES.WHOLESALE,
        negotiationId: negotiation._id,
        items: orderItems,
        subtotal,
        discount,
        discountSource,
        affiliateDiscountAmount: discountSource === 'affiliate' ? discount : 0,
        total,
        shippingAddress,
        customerNote,
        statusHistory: [{
          status: ORDER_STATUS.PENDING_PAYMENT,
          note: 'WhatsApp checkout initiated from negotiation',
        }],
        affiliateCode: resolvedAffiliateCode,
        offerCode,
      });

      if (discountSource === 'offer' && offerCode) {
        await Offer.findOneAndUpdate({ code: offerCode }, { $inc: { usageCount: 1 } });
      } else if (discountSource === 'affiliate' && resolvedAffiliateCode) {
        await AffiliateCode.findOneAndUpdate({ code: resolvedAffiliateCode }, { $inc: { usageCount: 1 } });
      }

      negotiation.status = NEGOTIATION_STATUS.CONVERTED;
      negotiation.orderId = order._id;
      await negotiation.save();

      await Product.findByIdAndUpdate(product._id, { $inc: { orderCount: 1 } });

      notifyAdmins({
        type: 'order_created',
        title: `New wholesale order ${order.orderNumber || ''}`.trim(),
        body: `${req.user?.name || 'A wholesaler'} checked out deal ${negotiation.negotiationNumber} for ₹${total}.`,
        link: '/orders',
        actor: { id: req.user?._id, name: req.user?.name, role: req.user?.role },
        metadata: { orderId: String(order._id), orderNumber: order.orderNumber, negotiationId: String(negotiation._id), total },
      });
    }

    const orderMessage = buildCheckoutCaption({
      orderNumber: order?.orderNumber || negotiation.negotiationNumber || null,
      user: req.user,
      shippingAddress,
    });

    const whatsappPayload = buildWhatsAppPayload(checkout.orderWhatsappNumber, orderMessage);

    res.status(201).json({
      success: true,
      message: 'Proceed to WhatsApp to complete this negotiated order.',
      data: {
        orderId: order?._id || null,
        orderNumber: order?.orderNumber || null,
        discount,
        total,
        status: order?.status || null,
        offerCode: order?.offerCode || offerCode || null,
        affiliateCode: order?.affiliateCode || resolvedAffiliateCode || null,
        discountSource: order?.discountSource || discountSource || null,
        checkoutMethod: 'whatsapp',
        orderRecorded: Boolean(order),
        exportAvailable: Boolean(order),
        exportPath: buildOrderExportPath(order?._id, 'pdf'),
        ...whatsappPayload,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.getOrderById = async (req, res, next) => {
  try {
    const order = await getOwnedOrderOrThrow(req.params.id, req.user._id);
    const orderData = order.toObject();

    res.json({
      success: true,
      data: {
        ...orderData,
        statusHistory: withDisplayNotes(orderData.statusHistory),
        payment: null,
        checkoutMethod: 'whatsapp',
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.exportOrderDocument = async (req, res, next) => {
  try {
    const format = String(req.query.format || 'pdf').toLowerCase();
    if (!['pdf', 'xlsx'].includes(format)) {
      throw new BadRequestError('Only pdf and xlsx export are supported', 'UNSUPPORTED_EXPORT_FORMAT');
    }

    const order = await getOwnedOrderOrThrow(req.params.id, req.user._id);
    const { settings, checkout } = await resolveCheckoutSettings();
    const safeOrderNumber = sanitizeFileNamePart(order.orderNumber || String(order._id));
    let buffer;
    let fileName;
    let contentType;

    if (format === 'pdf') {
      buffer = await createOrderReceiptPdfBuffer({
        order,
        settings,
        whatsappNumber: checkout.orderWhatsappNumber,
      });
      fileName = `order-${safeOrderNumber || 'receipt'}.pdf`;
      contentType = 'application/pdf';
    } else {
      buffer = await createOrderWorkbookBuffer({
        order,
        settings,
        whatsappNumber: checkout.orderWhatsappNumber,
      });
      fileName = `order-${safeOrderNumber || 'invoice'}.xlsx`;
      contentType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }

    res.setHeader('Content-Type', contentType);
    res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
    res.setHeader('Content-Length', buffer.length);
    res.send(Buffer.from(buffer));
  } catch (error) {
    next(error);
  }
};
