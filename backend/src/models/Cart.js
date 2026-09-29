const mongoose = require('mongoose');

const cartItemSchema = new mongoose.Schema({
  productId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Product',
    required: true,
  },
  variantId: {
    type: mongoose.Schema.Types.ObjectId,
    default: null,
  },
  variantSnapshot: {
    name: { type: String, default: '' },
    displayName: { type: String, default: '' },
    sku: { type: String, default: '' },
    attributes: [{
      key: { type: String, required: true },
      value: { type: String, required: true },
    }],
    packing: { type: String, default: '' },
    priceUnit: { type: String, default: '' },
  },
  quantity: {
    type: Number,
    required: true,
    min: [1, 'Quantity must be at least 1'],
  },
  priceAtAdd: {
    type: Number,
    required: true,
  },
  addedAt: {
    type: Date,
    default: Date.now,
  },
}, { _id: false });

const cartSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
  },
  items: [cartItemSchema],
}, {
  timestamps: true,
});

cartSchema.index({ userId: 1 }, { unique: true });
cartSchema.index({ 'items.productId': 1 });
cartSchema.index({ 'items.variantId': 1 });

const matchesCartItem = (item, productId, variantId = null) => {
  const sameProduct = item.productId.toString() === productId.toString();
  const itemVariantId = item.variantId ? item.variantId.toString() : null;
  const incomingVariantId = variantId ? variantId.toString() : null;
  return sameProduct && itemVariantId === incomingVariantId;
};

cartSchema.methods.addItem = function (productId, variantId, quantity, price, variantSnapshot = {}) {
  const existingItem = this.items.find(
    item => matchesCartItem(item, productId, variantId)
  );

  if (existingItem) {
    existingItem.quantity += quantity;
    existingItem.priceAtAdd = price;
    existingItem.variantSnapshot = variantSnapshot;
  } else {
    this.items.push({
      productId,
      variantId: variantId || null,
      variantSnapshot,
      quantity,
      priceAtAdd: price,
      addedAt: new Date(),
    });
  }

  return this;
};

cartSchema.methods.updateItemQuantity = function (productId, variantId, quantity) {
  const item = this.items.find(
    item => matchesCartItem(item, productId, variantId)
  );

  if (item) {
    item.quantity = quantity;
  }

  return this;
};

cartSchema.methods.removeItem = function (productId, variantId) {
  this.items = this.items.filter(
    item => !matchesCartItem(item, productId, variantId)
  );

  return this;
};

cartSchema.methods.clearCart = function () {
  this.items = [];
  return this;
};

module.exports = mongoose.model('Cart', cartSchema);
