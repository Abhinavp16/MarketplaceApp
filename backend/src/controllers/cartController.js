const { Cart, Product } = require('../models');
const { NotFoundError, BadRequestError } = require('../utils/errors');
const {
  getVariantById,
  getPriceForUser,
  buildVariantSnapshot,
  getVariantDisplayName,
} = require('../utils/productVariants');
const { buildDiscountMap, discountsFor } = require('../services/productDiscountService');

const buildCartItemKey = (productId, variantId) => `${productId}:${variantId || 'default'}`;

const resolveVariantForCart = (product, variantId) => {
  const resolved = getVariantById(product, variantId);
  if (!resolved) {
    throw new BadRequestError('Selected product was not found', 'PRODUCT_NOT_FOUND');
  }

  return resolved;
};

const buildProductMap = (products = []) => products.reduce((acc, product) => {
  acc[product._id.toString()] = product;
  return acc;
}, {});

const getMinimumWholesaleQuantity = (product) => {
  const value = Number(product?.minWholesaleQuantity);
  return Number.isInteger(value) && value > 0 ? value : 1;
};

const isWholesaler = (userRole) => userRole === 'wholesaler';

const assertMinimumWholesaleQuantity = (product, userRole, quantity) => {
  const minimumQuantity = getMinimumWholesaleQuantity(product);
  if (isWholesaler(userRole) && quantity < minimumQuantity) {
    throw new BadRequestError(
      `Minimum wholesale quantity for ${product.name} is ${minimumQuantity}`,
      'MIN_WHOLESALE_QUANTITY_NOT_MET'
    );
  }
};

const formatCartItem = (item, product, userRole, discounts = null) => {
  const resolved = getVariantById(product, null);
  if (!resolved) return null;

  const pricing = getPriceForUser(product, userRole, resolved.variant, discounts);
  const currentPrice = pricing.price;
  const productId = item.productId.toString();
  const variantId = null;

  return {
    productId: item.productId,
    variantId,
    cartItemKey: buildCartItemKey(productId, variantId),
    product: {
      id: product._id,
      name: product.name,
      nameHindi: product.nameHindi,
      brand: product.brand || product.company?.name || '',
      category: product.categoryRef?.name || product.category || '',
      slug: product.slug,
      price: pricing.price,
      mrp: pricing.mrp,
      retailPrice: pricing.retailPrice,
      wholesalePrice: pricing.wholesalePrice,
      discountPercent: pricing.discountPercent,
      discountSource: pricing.discountSource,
      discountSourceName: pricing.discountSourceName,
      stock: product.stock,
      minWholesaleQuantity: getMinimumWholesaleQuantity(product),
      image: product.images?.find(img => img.isPrimary)?.url || product.images?.[0]?.url,
      priceUnit: product.priceUnit || '',
      packing: product.packing || '',
    },
    variant: null,
    quantity: item.quantity,
    priceAtAdd: item.priceAtAdd,
    currentPrice,
    priceChanged: item.priceAtAdd !== currentPrice,
    itemTotal: item.quantity * currentPrice,
  };
};

const populateCartItems = async (cart, userRole = 'guest') => {
  const productIds = [...new Set(cart.items.map(item => item.productId.toString()))];
  const products = await Product.find({ _id: { $in: productIds } })
    .select('name nameHindi brand category categoryRef company slug mrp retailPrice wholesalePrice stock priceUnit packing images negotiationEnabled minWholesaleQuantity')
    .populate('company', 'name')
    .populate('categoryRef', 'name nameHindi slug')
    .lean();

  const productMap = buildProductMap(products);
  const discountMap = await buildDiscountMap(products);
  let cartUpdated = false;

  const items = cart.items.map((item) => {
    const product = productMap[item.productId.toString()];
    if (!product) return null;

    const minimumQuantity = getMinimumWholesaleQuantity(product);
    if (
      isWholesaler(userRole) &&
      item.quantity < minimumQuantity &&
      product.stock >= minimumQuantity
    ) {
      item.quantity = minimumQuantity;
      cartUpdated = true;
    }

    return formatCartItem(item, product, userRole, discountsFor(discountMap, product));
  }).filter(Boolean);

  if (cartUpdated) {
    cart.markModified('items');
    await cart.save();
  }

  const subtotal = items.reduce((sum, item) => sum + item.itemTotal, 0);
  const itemCount = items.reduce((sum, item) => sum + item.quantity, 0);
  return { items, subtotal, itemCount };
};

exports.getCart = async (req, res, next) => {
  try {
    const userRole = req.user?.role || 'guest';
    let cart = await Cart.findOne({ userId: req.user._id });

    if (!cart) {
      cart = await Cart.create({ userId: req.user._id, items: [] });
    }

    const data = await populateCartItems(cart, userRole);

    res.json({
      success: true,
      data,
    });
  } catch (error) {
    next(error);
  }
};

exports.addItem = async (req, res, next) => {
  try {
    const userRole = req.user?.role || 'guest';
    const { productId, variantId, quantity } = req.body;

    const product = await Product.findById(productId);
    if (!product) {
      throw new NotFoundError('Product not found', 'PRODUCT_NOT_FOUND');
    }

    const resolved = resolveVariantForCart(product, null);
    const requestedQuantity = Number(quantity);
    if (!Number.isInteger(requestedQuantity) || requestedQuantity < 1) {
      throw new BadRequestError('Quantity must be at least 1', 'INVALID_QUANTITY');
    }

    let cart = await Cart.findOne({ userId: req.user._id });
    if (!cart) {
      cart = new Cart({ userId: req.user._id, items: [] });
    }

    const existingItem = cart.items.find(
      (item) => item.productId.toString() === productId.toString()
    );
    const nextQuantity = (existingItem?.quantity || 0) + requestedQuantity;

    assertMinimumWholesaleQuantity(product, userRole, nextQuantity);
    if (resolved.variant.stock < nextQuantity) {
      throw new BadRequestError('Insufficient stock', 'INSUFFICIENT_STOCK');
    }

    const discounts = discountsFor(await buildDiscountMap([product]), product);
    const pricing = getPriceForUser(product, userRole, resolved.variant, discounts);
    const variantSnapshot = buildVariantSnapshot(product, resolved.variant);

    cart.addItem(productId, null, requestedQuantity, pricing.price, variantSnapshot);
    await cart.save();

    const data = await populateCartItems(cart, userRole);
    res.json({
      success: true,
      message: 'Item added to cart',
      data,
    });
  } catch (error) {
    next(error);
  }
};

exports.updateItemQuantity = async (req, res, next) => {
  try {
    const userRole = req.user?.role || 'guest';
    const { productId } = req.params;
    const variantId = null;
    const { quantity } = req.body;

    const product = await Product.findById(productId);
    if (!product) {
      throw new NotFoundError('Product not found', 'PRODUCT_NOT_FOUND');
    }

    const resolved = resolveVariantForCart(product, variantId);
    const requestedQuantity = Number(quantity);
    if (!Number.isInteger(requestedQuantity) || requestedQuantity < 1) {
      throw new BadRequestError('Quantity must be at least 1', 'INVALID_QUANTITY');
    }

    assertMinimumWholesaleQuantity(product, userRole, requestedQuantity);
    if (resolved.variant.stock < requestedQuantity) {
      throw new BadRequestError('Insufficient stock', 'INSUFFICIENT_STOCK');
    }

    const cart = await Cart.findOne({ userId: req.user._id });
    if (!cart) {
      throw new NotFoundError('Cart not found', 'CART_NOT_FOUND');
    }

    cart.updateItemQuantity(productId, resolved.variantId, requestedQuantity);
    await cart.save();

    const data = await populateCartItems(cart, userRole);
    res.json({
      success: true,
      message: 'Cart updated',
      data,
    });
  } catch (error) {
    next(error);
  }
};

exports.removeItem = async (req, res, next) => {
  try {
    const userRole = req.user?.role || 'guest';
    const { productId } = req.params;
    const variantId = null;

    const cart = await Cart.findOne({ userId: req.user._id });
    if (!cart) {
      throw new NotFoundError('Cart not found', 'CART_NOT_FOUND');
    }

    cart.removeItem(productId, variantId);
    await cart.save();

    const data = await populateCartItems(cart, userRole);
    res.json({
      success: true,
      message: 'Item removed from cart',
      data,
    });
  } catch (error) {
    next(error);
  }
};

exports.validateCart = async (req, res, next) => {
  try {
    const cart = await Cart.findOne({ userId: req.user._id });
    if (!cart || cart.items.length === 0) {
      return res.json({ success: true, data: { valid: true, issues: [] } });
    }

    const userRole = req.user?.role || 'guest';
    const productIds = [...new Set(cart.items.map(item => item.productId.toString()))];
    const products = await Product.find({ _id: { $in: productIds } })
      .select('name stock retailPrice status minWholesaleQuantity')
      .lean();

    const productMap = buildProductMap(products);
    const issues = [];

    for (const item of cart.items) {
      const product = productMap[item.productId.toString()];
      const itemVariantId = null;

      if (!product) {
        issues.push({
          productId: item.productId.toString(),
          variantId: itemVariantId,
          cartItemKey: buildCartItemKey(item.productId.toString(), itemVariantId),
          type: 'unavailable',
          message: 'This product is no longer available',
          availableStock: 0,
          requestedQty: item.quantity,
        });
        continue;
      }

      if (product.status !== 'active') {
        issues.push({
          productId: item.productId.toString(),
          variantId: itemVariantId,
          cartItemKey: buildCartItemKey(item.productId.toString(), itemVariantId),
          name: product.name,
          type: 'unavailable',
          message: `${product.name} is currently unavailable`,
          availableStock: 0,
          requestedQty: item.quantity,
        });
        continue;
      }

      const resolved = getVariantById(product, null);
      if (!resolved) {
        issues.push({
          productId: item.productId.toString(),
          variantId: itemVariantId,
          cartItemKey: buildCartItemKey(item.productId.toString(), itemVariantId),
          name: product.name,
          type: 'unavailable',
          message: 'Selected product is no longer available',
          availableStock: 0,
          requestedQty: item.quantity,
        });
        continue;
      }

      const variantName = getVariantDisplayName(product, resolved.variant);
      const minimumQuantity = getMinimumWholesaleQuantity(product);
      if (isWholesaler(userRole) && item.quantity < minimumQuantity) {
        issues.push({
          productId: item.productId.toString(),
          variantId: itemVariantId,
          cartItemKey: buildCartItemKey(item.productId.toString(), itemVariantId),
          name: variantName,
          type: 'minimum_wholesale_quantity',
          message: `Minimum wholesale quantity for ${variantName} is ${minimumQuantity}`,
          availableStock: resolved.variant.stock,
          requestedQty: item.quantity,
          minimumWholesaleQuantity: minimumQuantity,
        });
        continue;
      }

      if (resolved.variant.stock === 0) {
        issues.push({
          productId: item.productId.toString(),
          variantId: itemVariantId,
          cartItemKey: buildCartItemKey(item.productId.toString(), itemVariantId),
          name: variantName,
          type: 'out_of_stock',
          message: `${variantName} is out of stock`,
          availableStock: 0,
          requestedQty: item.quantity,
        });
      } else if (resolved.variant.stock < item.quantity) {
        issues.push({
          productId: item.productId.toString(),
          variantId: itemVariantId,
          cartItemKey: buildCartItemKey(item.productId.toString(), itemVariantId),
          name: variantName,
          type: 'insufficient_stock',
          message: `Only ${resolved.variant.stock} units of ${variantName} available`,
          availableStock: resolved.variant.stock,
          requestedQty: item.quantity,
        });
      }
    }

    res.json({
      success: true,
      data: {
        valid: issues.length === 0,
        issues,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.clearCart = async (req, res, next) => {
  try {
    const cart = await Cart.findOne({ userId: req.user._id });
    if (cart) {
      cart.clearCart();
      await cart.save();
    }

    res.json({
      success: true,
      message: 'Cart cleared',
    });
  } catch (error) {
    next(error);
  }
};
