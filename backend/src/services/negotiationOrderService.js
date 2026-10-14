const { Order, Product, User, Negotiation } = require('../models');
const { NotFoundError, BadRequestError, ConflictError, ForbiddenError } = require('../utils/errors');
const { ORDER_STATUS, ORDER_TYPES, NEGOTIATION_STATUS, NEGOTIATION_ACTIONS } = require('../utils/constants');
const { getVariantById, buildVariantSnapshot } = require('../utils/productVariants');
const { recordAudit } = require('./auditService');
const notificationService = require('./notificationService');

const { getMinimumWholesaleQuantity: minimumInPieces } = require('../utils/packSize');
const { assertPurchasable, purchaseBlockCode } = require('../utils/productAvailability');

const getMinimumWholesaleQuantity = (product) => minimumInPieces(product, 10);

const REQUIRED_ADDRESS_FIELDS = ['fullName', 'phone', 'addressLine1', 'city', 'state', 'pincode'];

const round2 = (value) => Math.round((Number(value) + Number.EPSILON) * 100) / 100;

// Delivery charge the admin enters when accepting (₹, never negative).
const toDeliveryFee = (value) => round2(Math.max(0, Number(value) || 0));

const formatRupees = (value) => Number(value || 0).toLocaleString('en-IN', { maximumFractionDigits: 2 });

/**
 * Resolve the shipping address for an admin/staff-created negotiation order.
 * Priority: explicit address in request body -> wholesaler's most recent
 * order address -> profile-derived address. Throws BadRequestError listing
 * missing fields when nothing complete is available.
 */
async function resolveAcceptAddress({ bodyAddress, wholesaler }) {
  if (bodyAddress && REQUIRED_ADDRESS_FIELDS.every((f) => String(bodyAddress[f] || '').trim())) {
    return { shippingAddress: bodyAddress, source: 'provided' };
  }

  const lastOrder = await Order.findOne({ userId: wholesaler._id })
    .sort({ createdAt: -1 })
    .select('shippingAddress')
    .lean();
  if (lastOrder?.shippingAddress && REQUIRED_ADDRESS_FIELDS.every((f) => String(lastOrder.shippingAddress[f] || '').trim())) {
    return { shippingAddress: lastOrder.shippingAddress, source: 'last_order' };
  }

  const profileAddress = {
    fullName: wholesaler.name,
    phone: wholesaler.phone,
    addressLine1: wholesaler.address || wholesaler.businessInfo?.businessAddress || '',
    addressLine2: wholesaler.businessInfo?.businessName || '',
    city: '',
    state: '',
    pincode: '',
  };
  const missing = REQUIRED_ADDRESS_FIELDS.filter((f) => !String(profileAddress[f] || '').trim());
  if (missing.length === 0) {
    return { shippingAddress: profileAddress, source: 'profile' };
  }
  throw new BadRequestError(
    `Wholesaler address is incomplete (missing: ${missing.join(', ')}). Enter the full shipping address to confirm this order.`,
    'ADDRESS_INCOMPLETE',
  );
}

function emitToNegotiationRoom(io, negotiationId, event, payload) {
  try {
    const instance = io || null;
    if (instance) instance.to(`negotiation-${negotiationId}`).emit(event, payload);
  } catch (err) {
    console.error(`Failed to emit ${event} for negotiation ${negotiationId}:`, err.message);
  }
}

// Sends a notification template in the wholesaler's language.
async function notifyWholesaler(userId, templateKey, params, data) {
  try {
    await notificationService.sendLocalizedToUser(userId, templateKey, params, data);
  } catch (err) {
    console.error('Failed to send negotiation order notification:', err.message);
  }
}

/**
 * Accept a negotiation (admin or staff) AND create the confirmed order.
 * Idempotent: if the negotiation already has an order, returns it.
 */
async function acceptNegotiationAndCreateOrder({
  negotiationId,
  actor,
  message,
  shippingAddress: bodyAddress,
  customerNote,
  deliveryCharge = 0,
  io,
}) {
  let negotiation = await Negotiation.findById(negotiationId);
  if (!negotiation) {
    throw new NotFoundError('Negotiation not found', 'NEGOTIATION_NOT_FOUND');
  }

  if (negotiation.orderId) {
    const existingOrder = await Order.findById(negotiation.orderId).lean();
    if (existingOrder) {
      return { negotiation, order: existingOrder, alreadyConverted: true };
    }

    const danglingOrderId = negotiation.orderId;
    negotiation = await Negotiation.findOneAndUpdate(
      { _id: negotiation._id, orderId: danglingOrderId },
      { $set: { status: NEGOTIATION_STATUS.ACCEPTED, orderId: null } },
      { new: true, runValidators: true },
    );
    if (!negotiation) {
      const currentNegotiation = await Negotiation.findById(negotiationId);
      const currentOrder = currentNegotiation?.orderId
        ? await Order.findById(currentNegotiation.orderId).lean()
        : null;
      if (currentNegotiation && currentOrder) {
        return { negotiation: currentNegotiation, order: currentOrder, alreadyConverted: true };
      }
      throw new ConflictError(
        'Negotiation order link changed while it was being repaired. Review it and try again.',
        'NEGOTIATION_ORDER_REPAIR_CONFLICT',
      );
    }
  }

  const orphanedOrder = await Order.findOne({ negotiationId: negotiation._id }).lean();
  if (orphanedOrder) {
    const recoveredNegotiation = await finalizeNegotiation({
      negotiation,
      order: orphanedOrder,
      actor,
      message,
      recoverExisting: true,
    });
    if (recoveredNegotiation) {
      const [product, wholesaler] = await Promise.all([
        Product.findById(negotiation.productId),
        User.findById(negotiation.wholesalerId),
      ]);
      await runPostConversionEffects({
        negotiation: recoveredNegotiation,
        order: orphanedOrder,
        actor,
        product,
        wholesaler,
        io,
      });
      return {
        negotiation: recoveredNegotiation,
        order: orphanedOrder,
        alreadyConverted: true,
        addressSource: 'existing_order',
      };
    }
    throw new BadRequestError(
      'An existing order could not be linked in the current negotiation status',
      'NEGOTIATION_ORDER_CONFLICT',
    );
  }

  if (![NEGOTIATION_STATUS.PENDING, NEGOTIATION_STATUS.COUNTERED, NEGOTIATION_STATUS.ACCEPTED].includes(negotiation.status)) {
    throw new BadRequestError(
      'Cannot accept in the current negotiation status',
      'INVALID_NEGOTIATION_STATUS',
    );
  }

  if (negotiation.status !== NEGOTIATION_STATUS.ACCEPTED && negotiation.expiresAt <= new Date()) {
    await Negotiation.updateOne(
      { _id: negotiation._id, status: { $in: [NEGOTIATION_STATUS.PENDING, NEGOTIATION_STATUS.COUNTERED] } },
      { $set: { status: NEGOTIATION_STATUS.EXPIRED } },
    );
    throw new BadRequestError('Negotiation has expired', 'NEGOTIATION_EXPIRED');
  }

  const product = await Product.findById(negotiation.productId);
  if (!product) {
    throw new NotFoundError('Product not found', 'PRODUCT_NOT_FOUND');
  }
  assertPurchasable(product);

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
      'MIN_WHOLESALE_QUANTITY_NOT_MET',
    );
  }

  const wholesaler = await User.findById(negotiation.wholesalerId);
  if (!wholesaler) {
    throw new NotFoundError('Wholesaler not found', 'USER_NOT_FOUND');
  }

  const { shippingAddress, source } = await resolveAcceptAddress({
    bodyAddress,
    wholesaler,
  });

  const acceptedPricePerUnit = negotiation.finalPricePerUnit ?? negotiation.currentPricePerUnit;
  const acceptedTotalPrice = negotiation.finalTotalPrice ?? negotiation.currentTotalPrice;
  const subtotal = acceptedTotalPrice;
  const orderItems = [{
    productId: product._id,
    variantId: null,
    productSnapshot: {
      name: product.name,
      nameHindi: product.nameHindi || negotiation.productSnapshot?.nameHindi || '',
      sku: product.sku,
      image: product.primaryImage,
    },
    variantSnapshot: buildVariantSnapshot(product, resolved.variant),
    quantity: negotiation.requestedQuantity,
    pricePerUnit: acceptedPricePerUnit,
    totalPrice: acceptedTotalPrice,
  }];

  const actorLabel = actor.role === 'staff' ? `Member ${actor.name}` : `Admin ${actor.name}`;
  const deliveryFee = toDeliveryFee(deliveryCharge);
  const deliveryNote = deliveryFee > 0 ? ` · delivery ₹${formatRupees(deliveryFee)} added` : '';
  let order;
  let createdOrder = false;
  try {
    order = await Order.create({
      userId: wholesaler._id,
      customerSnapshot: {
        name: wholesaler.name,
        email: wholesaler.email,
        phone: wholesaler.phone,
        businessName: wholesaler.businessInfo?.businessName,
      },
      orderType: ORDER_TYPES.WHOLESALE,
      negotiationId: negotiation._id,
      negotiationIds: [negotiation._id],
      items: orderItems,
      subtotal,
      deliveryFee,
      discount: 0,
      total: round2(subtotal + deliveryFee),
      shippingAddress,
      customerNote,
      adminNote: `Negotiation ${negotiation.negotiationNumber} accepted by ${actorLabel} — order confirmed from negotiation chat.${deliveryNote}`,
      statusHistory: [{
        status: ORDER_STATUS.PENDING_PAYMENT,
        note: `Negotiation ${negotiation.negotiationNumber} accepted by ${actorLabel} — order confirmed${deliveryNote}`,
        updatedBy: actor.id,
      }],
    });
    createdOrder = true;
  } catch (error) {
    if (error?.code !== 11000) throw error;
    order = await Order.findOne({ negotiationId: negotiation._id }).lean();
    if (!order) throw error;
  }

  const finalizedNegotiation = await finalizeNegotiation({ negotiation, order, actor, message });
  if (!finalizedNegotiation) {
    const currentNegotiation = await Negotiation.findById(negotiation._id);
    if (!currentNegotiation?.orderId) {
      if (createdOrder) {
        await Order.deleteOne({ _id: order._id, negotiationId: negotiation._id });
      }
      throw new ConflictError(
        'Negotiation changed while the order was being confirmed. Review it and try again.',
        'NEGOTIATION_CHANGED',
      );
    }
    const currentOrder = currentNegotiation?.orderId
      ? await Order.findById(currentNegotiation.orderId).lean()
      : null;
    if (!currentOrder) {
      throw new ConflictError(
        'Negotiation was converted without a recoverable order. Review it and try again.',
        'NEGOTIATION_ORDER_MISSING',
      );
    }
    return {
      negotiation: currentNegotiation || negotiation,
      order: currentOrder,
      alreadyConverted: true,
      addressSource: createdOrder ? source : 'existing_order',
    };
  }

  await runPostConversionEffects({
    negotiation: finalizedNegotiation,
    order,
    actor,
    product,
    wholesaler,
    io,
  });

  return {
    negotiation: finalizedNegotiation,
    order,
    alreadyConverted: false,
    addressSource: createdOrder ? source : 'existing_order',
  };
}

async function runPostConversionEffects({ negotiation, order, actor, product, wholesaler, io }) {
  const actorLabel = actor.role === 'staff' ? `Member ${actor.name}` : `Admin ${actor.name}`;
  if (product) {
    await Product.findByIdAndUpdate(product._id, { $inc: { orderCount: 1 } });
  }
  await recordAudit({
    actorId: actor.id,
    action: 'negotiation.accepted_with_order',
    entityType: 'negotiation',
    entityId: negotiation._id,
    metadata: {
      pricePerUnit: negotiation.finalPricePerUnit,
      orderId: String(order._id),
      orderNumber: order.orderNumber,
    },
  });

  if (wholesaler) {
    await notifyWholesaler(wholesaler._id, 'requirementAccepted', {
      productName: negotiation.productSnapshot.name,
      productNameHindi: negotiation.productSnapshot.nameHindi,
      price: negotiation.finalPricePerUnit,
      orderNumber: order.orderNumber,
    }, {
      type: 'negotiation_accepted',
      negotiationId: negotiation._id.toString(),
      orderId: order._id.toString(),
      orderNumber: order.orderNumber,
    });
  }

  emitToNegotiationRoom(io, negotiation._id.toString(), 'negotiation-accepted', {
    negotiationId: negotiation._id.toString(),
    orderId: order._id.toString(),
    orderNumber: order.orderNumber,
    finalPricePerUnit: negotiation.finalPricePerUnit,
    finalTotalPrice: negotiation.finalTotalPrice,
    acceptedBy: actorLabel,
    timestamp: new Date(),
  });
}

async function finalizeNegotiation({ negotiation, order, actor, message, recoverExisting = false }) {
  const actorLabel = actor.role === 'staff' ? `Member ${actor.name}` : `Admin ${actor.name}`;
  const acceptedPricePerUnit = negotiation.finalPricePerUnit ?? negotiation.currentPricePerUnit;
  const acceptedTotalPrice = negotiation.finalTotalPrice ?? negotiation.currentTotalPrice;
  const acceptanceAlreadyRecorded = negotiation.status === NEGOTIATION_STATUS.ACCEPTED ||
    (negotiation.history || []).some((entry) => entry.action === NEGOTIATION_ACTIONS.ACCEPTED);
  const update = {
    $set: {
      status: NEGOTIATION_STATUS.CONVERTED,
      finalPricePerUnit: acceptedPricePerUnit,
      finalTotalPrice: acceptedTotalPrice,
      orderId: order._id,
    },
  };
  if (!acceptanceAlreadyRecorded) {
    update.$push = {
      history: {
        action: NEGOTIATION_ACTIONS.ACCEPTED,
        by: 'admin',
        actorId: actor.id,
        actorRole: actor.role,
        pricePerUnit: acceptedPricePerUnit,
        totalPrice: acceptedTotalPrice,
        message: message || `Accepted by ${actorLabel}`,
      },
    };
  }

  return Negotiation.findOneAndUpdate(
    {
      _id: negotiation._id,
      orderId: null,
      status: negotiation.status,
      currentOfferBy: negotiation.currentOfferBy,
      currentPricePerUnit: negotiation.currentPricePerUnit,
      currentTotalPrice: negotiation.currentTotalPrice,
      ...(recoverExisting || negotiation.status === NEGOTIATION_STATUS.ACCEPTED
        ? {}
        : { expiresAt: { $gt: new Date() } }),
    },
    update,
    { new: true, runValidators: true },
  );
}

const OPEN_FOR_ACCEPT = [NEGOTIATION_STATUS.PENDING, NEGOTIATION_STATUS.COUNTERED, NEGOTIATION_STATUS.ACCEPTED];

// Puts a negotiation back the way it was before finalizeNegotiation (used when
// a combined order has to be undone).
async function revertFinalizedNegotiation(original, orderId) {
  const pushedAcceptance = !(original.status === NEGOTIATION_STATUS.ACCEPTED ||
    (original.history || []).some((entry) => entry.action === NEGOTIATION_ACTIONS.ACCEPTED));
  const update = {
    $set: {
      status: original.status,
      orderId: null,
      finalPricePerUnit: original.finalPricePerUnit ?? null,
      finalTotalPrice: original.finalTotalPrice ?? null,
    },
  };
  if (pushedAcceptance) update.$pop = { history: 1 };
  await Negotiation.updateOne({ _id: original._id, orderId }, update);
}

/**
 * Accept several requirements the wholesaler sent together (one requirement
 * group) into ONE order with one delivery charge. All or nothing: every
 * selected requirement is checked first; if one changes while the order is
 * being made, the order is removed and the others are put back.
 */
async function acceptRequirementGroupAndCreateOrder({
  groupId,
  negotiationIds,
  actor,
  message,
  shippingAddress: bodyAddress,
  customerNote,
  deliveryCharge = 0,
  io,
}) {
  const ids = [...new Set((negotiationIds || []).map(String))];
  const negotiations = await Negotiation.find({ _id: { $in: ids } });
  if (ids.length === 0 || negotiations.length !== ids.length) {
    throw new NotFoundError('Some requirements were not found', 'NEGOTIATION_NOT_FOUND');
  }
  negotiations.sort((a, b) => ids.indexOf(String(a._id)) - ids.indexOf(String(b._id)));

  const wholesalerIds = new Set(negotiations.map((n) => String(n.wholesalerId)));
  if (negotiations.some((n) => n.requestGroup?.id !== groupId) || wholesalerIds.size !== 1) {
    throw new BadRequestError('These requirements are not part of the same requirement', 'REQUIREMENT_GROUP_MISMATCH');
  }

  const products = await Product.find({ _id: { $in: negotiations.map((n) => n.productId) } });
  const productById = new Map(products.map((product) => [String(product._id), product]));
  const now = new Date();
  const problems = [];
  const lines = [];
  for (const negotiation of negotiations) {
    const name = negotiation.productSnapshot?.name || negotiation.negotiationNumber;
    if (negotiation.orderId) {
      problems.push({ id: String(negotiation._id), name, code: 'ALREADY_ORDERED' });
      continue;
    }
    if (!OPEN_FOR_ACCEPT.includes(negotiation.status)) {
      problems.push({ id: String(negotiation._id), name, code: 'INVALID_NEGOTIATION_STATUS' });
      continue;
    }
    if (negotiation.status !== NEGOTIATION_STATUS.ACCEPTED && negotiation.expiresAt <= now) {
      problems.push({ id: String(negotiation._id), name, code: 'NEGOTIATION_EXPIRED' });
      continue;
    }
    const product = productById.get(String(negotiation.productId));
    const resolved = product ? getVariantById(product, null) : null;
    if (!resolved) {
      problems.push({ id: String(negotiation._id), name, code: 'PRODUCT_NOT_FOUND' });
      continue;
    }
    const blocked = purchaseBlockCode(product);
    if (blocked) {
      problems.push({ id: String(negotiation._id), name, code: blocked });
      continue;
    }
    if (resolved.variant.stock < negotiation.requestedQuantity) {
      problems.push({ id: String(negotiation._id), name, code: 'INSUFFICIENT_STOCK' });
      continue;
    }
    if (negotiation.requestedQuantity < getMinimumWholesaleQuantity(product)) {
      problems.push({ id: String(negotiation._id), name, code: 'MIN_WHOLESALE_QUANTITY_NOT_MET' });
      continue;
    }
    lines.push({ negotiation, product, resolved });
  }
  if (problems.length > 0) {
    const error = new BadRequestError(
      `These products can't be accepted: ${problems.map((problem) => problem.name).join(', ')}`,
      problems[0].code,
    );
    error.details = { items: problems };
    throw error;
  }

  const wholesaler = await User.findById(negotiations[0].wholesalerId);
  if (!wholesaler) {
    throw new NotFoundError('Wholesaler not found', 'USER_NOT_FOUND');
  }
  const { shippingAddress } = await resolveAcceptAddress({ bodyAddress, wholesaler });

  const orderItems = lines.map(({ negotiation, product, resolved }) => ({
    productId: product._id,
    variantId: null,
    productSnapshot: {
      name: product.name,
      nameHindi: product.nameHindi || negotiation.productSnapshot?.nameHindi || '',
      sku: product.sku,
      image: product.primaryImage,
    },
    variantSnapshot: buildVariantSnapshot(product, resolved.variant),
    quantity: negotiation.requestedQuantity,
    pricePerUnit: negotiation.finalPricePerUnit ?? negotiation.currentPricePerUnit,
    totalPrice: negotiation.finalTotalPrice ?? negotiation.currentTotalPrice,
  }));
  const subtotal = round2(orderItems.reduce((sum, item) => sum + Number(item.totalPrice || 0), 0));
  const deliveryFee = toDeliveryFee(deliveryCharge);
  const total = round2(subtotal + deliveryFee);
  const requestNumber = negotiations[0].requestGroup.number || '';
  const actorLabel = actor.role === 'staff' ? `Member ${actor.name}` : `Admin ${actor.name}`;
  const summary = `Requirement ${requestNumber} (${lines.length} products) accepted by ${actorLabel}` +
    (deliveryFee > 0 ? ` · delivery ₹${formatRupees(deliveryFee)} added` : '');

  const order = await Order.create({
    userId: wholesaler._id,
    customerSnapshot: {
      name: wholesaler.name,
      email: wholesaler.email,
      phone: wholesaler.phone,
      businessName: wholesaler.businessInfo?.businessName,
    },
    orderType: ORDER_TYPES.WHOLESALE,
    negotiationId: negotiations[0]._id,
    negotiationIds: negotiations.map((n) => n._id),
    items: orderItems,
    subtotal,
    deliveryFee,
    discount: 0,
    total,
    shippingAddress,
    customerNote,
    adminNote: `${summary} — one order.`,
    statusHistory: [{
      status: ORDER_STATUS.PENDING_PAYMENT,
      note: `${summary} — order confirmed`,
      updatedBy: actor.id,
    }],
  });

  const finalized = [];
  for (const { negotiation } of lines) {
    const updated = await finalizeNegotiation({ negotiation, order, actor, message });
    if (!updated) {
      for (const done of finalized) {
        await revertFinalizedNegotiation(done.original, order._id);
      }
      await Order.deleteOne({ _id: order._id });
      const error = new ConflictError(
        `${negotiation.productSnapshot?.name || 'A product'} changed while the order was being made. Review it and try again.`,
        'NEGOTIATION_CHANGED',
      );
      error.details = { items: [{ id: String(negotiation._id), name: negotiation.productSnapshot?.name, code: 'NEGOTIATION_CHANGED' }] };
      throw error;
    }
    finalized.push({ original: negotiation, updated });
  }

  for (const { updated } of finalized) {
    await Product.findByIdAndUpdate(updated.productId, { $inc: { orderCount: 1 } });
    await recordAudit({
      actorId: actor.id,
      action: 'negotiation.accepted_with_order',
      entityType: 'negotiation',
      entityId: updated._id,
      metadata: {
        pricePerUnit: updated.finalPricePerUnit,
        orderId: String(order._id),
        orderNumber: order.orderNumber,
        requestNumber,
      },
    });
    emitToNegotiationRoom(io, updated._id.toString(), 'negotiation-accepted', {
      negotiationId: updated._id.toString(),
      orderId: order._id.toString(),
      orderNumber: order.orderNumber,
      finalPricePerUnit: updated.finalPricePerUnit,
      finalTotalPrice: updated.finalTotalPrice,
      acceptedBy: actorLabel,
      timestamp: new Date(),
    });
  }

  // One notification for the whole requirement.
  await notifyWholesaler(wholesaler._id, 'requirementGroupAccepted', {
    requestNumber,
    count: lines.length,
    orderNumber: order.orderNumber,
    total: formatRupees(total),
  }, {
    type: 'negotiation_accepted',
    negotiationId: finalized[0].updated._id.toString(),
    orderId: order._id.toString(),
    orderNumber: order.orderNumber,
  });

  return { order, negotiations: finalized.map(({ updated }) => updated) };
}

const DECLINABLE = [NEGOTIATION_STATUS.PENDING, NEGOTIATION_STATUS.COUNTERED];

// Declines requirements (admin or member). With groupId, every open product
// in that requirement is declined and the wholesaler gets one notification.
async function declineNegotiations({ negotiationId = null, groupId = null, reason = '', actor, io }) {
  const text = String(reason || '').trim();
  let negotiations;
  if (groupId) {
    negotiations = await Negotiation.find({ 'requestGroup.id': groupId });
    if (negotiations.length === 0) throw new NotFoundError('Requirement not found', 'REQUIREMENT_GROUP_NOT_FOUND');
  } else {
    const negotiation = await Negotiation.findById(negotiationId);
    if (!negotiation) throw new NotFoundError('Negotiation not found', 'NEGOTIATION_NOT_FOUND');
    negotiations = [negotiation];
  }

  const open = negotiations.filter((n) => DECLINABLE.includes(n.status));
  if (open.length === 0) {
    throw new BadRequestError('Nothing left to decline: these requirements are already accepted, ordered or declined', 'INVALID_NEGOTIATION_STATUS');
  }

  for (const negotiation of open) {
    negotiation.history.push({
      action: NEGOTIATION_ACTIONS.REJECTED,
      by: 'admin',
      actorId: actor.id,
      actorRole: actor.role,
      message: text || undefined,
    });
    negotiation.status = NEGOTIATION_STATUS.REJECTED;
    negotiation.rejectedAt = new Date();
    await negotiation.save();
    emitToNegotiationRoom(io, negotiation._id.toString(), 'negotiation-rejected', {
      negotiationId: negotiation._id.toString(),
      reason: text || null,
      timestamp: new Date(),
    });
  }

  const first = open[0];
  await recordAudit({
    actorId: actor.id,
    action: groupId ? 'requirement_group.declined' : 'negotiation.declined',
    entityType: 'negotiation',
    entityId: first._id,
    metadata: {
      negotiationIds: open.map((n) => String(n._id)),
      requestNumber: first.requestGroup?.number || null,
      reason: text || null,
      role: actor.role,
    },
  }).catch(() => null);

  try {
    if (groupId) {
      await notificationService.sendLocalizedToUser(first.wholesalerId, text ? 'requirementGroupDeclinedWithReason' : 'requirementGroupDeclined', {
        requestNumber: first.requestGroup?.number || '',
        count: open.length,
        reason: text,
      }, {
        type: 'negotiation_rejected',
        negotiationId: first._id.toString(),
      });
    } else {
      await notificationService.sendLocalizedToUser(first.wholesalerId, text ? 'requirementDeclinedWithReason' : 'requirementDeclined', {
        productName: first.productSnapshot.name,
        productNameHindi: first.productSnapshot.nameHindi,
        reason: text,
      }, {
        type: 'negotiation_rejected',
        negotiationId: first._id.toString(),
      });
    }
  } catch (error) {
    console.error('Failed to send requirement declined notification:', error.message);
  }

  return {
    declined: open.map((n) => String(n._id)),
    skipped: negotiations.filter((n) => !open.includes(n)).map((n) => String(n._id)),
    requestNumber: first.requestGroup?.number || null,
  };
}

module.exports = {
  declineNegotiations,
  acceptNegotiationAndCreateOrder,
  acceptRequirementGroupAndCreateOrder,
  resolveAcceptAddress,
  emitToNegotiationRoom,
  notifyWholesaler,
};
