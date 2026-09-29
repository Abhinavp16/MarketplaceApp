const mongoose = require('mongoose');
const { normalizeSearchText } = require('../utils/searchQuery');
const slugify = require('slugify');
const { PRODUCT_STATUS } = require('../utils/constants');
const {
  getProductStockTotal,
} = require('../utils/productVariants');

const variantAttributeSchema = new mongoose.Schema({
  key: {
    type: String,
    required: true,
    trim: true,
  },
  value: {
    type: String,
    required: true,
    trim: true,
  },
}, { _id: false });

const variantSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Variant name is required'],
    trim: true,
    maxlength: [120, 'Variant name cannot exceed 120 characters'],
  },
  sku: {
    type: String,
    required: [true, 'Variant SKU is required'],
    trim: true,
    uppercase: true,
  },
  attributes: [variantAttributeSchema],
  mrp: {
    type: Number,
    required: [true, 'Variant MRP is required'],
    min: [0, 'Variant MRP cannot be negative'],
  },
  retailPrice: {
    type: Number,
    required: [true, 'Variant retail price is required'],
    min: [0, 'Variant retail price cannot be negative'],
  },
  wholesalePrice: {
    type: Number,
    required: [true, 'Variant wholesale price is required'],
    min: [0, 'Variant wholesale price cannot be negative'],
  },
  pendingRetailPrice: {
    type: Number,
    default: null,
    min: [0, 'Pending variant retail price cannot be negative'],
  },
  pendingWholesalePrice: {
    type: Number,
    default: null,
    min: [0, 'Pending variant wholesale price cannot be negative'],
  },
  priceChangeScheduledAt: {
    type: Date,
    default: null,
  },
  priceChangeEffectiveAt: {
    type: Date,
    default: null,
  },
  stock: {
    type: Number,
    default: 0,
    min: [0, 'Variant stock cannot be negative'],
  },
  lowStockThreshold: {
    type: Number,
    default: 5,
    min: [0, 'Variant low stock threshold cannot be negative'],
  },
  minOrderQuantity: {
    type: Number,
    default: 1,
    min: [1, 'Minimum order quantity must be at least 1'],
  },
  priceUnit: {
    type: String,
    default: '',
    trim: true,
  },
  packing: {
    type: String,
    default: '',
    trim: true,
  },
  isActive: {
    type: Boolean,
    default: true,
  },
  order: {
    type: Number,
    default: 0,
  },
}, { _id: true });

const productSchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Product name is required'],
    trim: true,
    maxlength: [200, 'Name cannot exceed 200 characters'],
  },
  nameHindi: {
    type: String,
    trim: true,
    default: '',
  },
  // Normalized nameHindi used only by search (spelling variants, digits).
  searchTextHindi: {
    type: String,
    default: '',
    select: false,
  },
  // 'manual' = typed by an admin (never overwritten); 'auto' = generated.
  nameHindiSource: {
    type: String,
    enum: ['auto', 'manual', null],
    default: null,
  },
  slug: {
    type: String,
    unique: true,
    lowercase: true,
  },
  description: {
    type: String,
    default: '',
  },
  shortDescription: {
    type: String,
    maxlength: [300, 'Short description cannot exceed 300 characters'],
  },

  category: {
    type: String,
    required: [true, 'Category is required'],
    index: true,
  },
  categoryRef: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Category',
    default: null,
  },
  brand: {
    type: String,
    default: '',
  },
  subCategory: {
    type: String,
    default: null,
  },
  tags: [{
    type: String,
    trim: true,
  }],

  // 3-Tier Pricing System
  mrp: {
    type: Number,
    required: [true, 'MRP is required'],
    min: [0, 'MRP cannot be negative'],
  },
  retailPrice: {
    type: Number,
    required: [true, 'Retail price is required'],
    min: [0, 'Retail price cannot be negative'],
  },
  wholesalePrice: {
    type: Number,
    required: [true, 'Wholesale price is required'],
    min: [0, 'Wholesale price cannot be negative'],
  },
  pendingRetailPrice: {
    type: Number,
    default: null,
    min: [0, 'Pending retail price cannot be negative'],
  },
  pendingWholesalePrice: {
    type: Number,
    default: null,
    min: [0, 'Pending wholesale price cannot be negative'],
  },
  priceChangeScheduledAt: {
    type: Date,
    default: null,
  },
  priceChangeEffectiveAt: {
    type: Date,
    default: null,
  },
  pendingPriceChangeAudit: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'PriceChangeAudit',
    default: null,
  },

  // Bulk/Wholesale settings
  minWholesaleQuantity: {
    type: Number,
    default: 10,
    min: [1, 'Minimum wholesale quantity must be at least 1'],
  },
  negotiationEnabled: {
    type: Boolean,
    default: true,
  },

  sku: {
    type: String,
    required: [true, 'SKU is required'],
    unique: true,
    uppercase: true,
  },
  stock: {
    type: Number,
    required: true,
    min: [0, 'Stock cannot be negative'],
    default: 0,
  },
  lowStockThreshold: {
    type: Number,
    default: 5,
  },
  priceUnit: {
    type: String,
    default: '',
    trim: true,
  },
  packing: {
    type: String,
    default: '',
    trim: true,
  },
  trackInventory: {
    type: Boolean,
    default: true,
  },
  variants: [variantSchema],

  images: [{
    url: { type: String, required: true },
    publicId: { type: String, required: true },
    blurHash: { type: String, default: null },
    isPrimary: { type: Boolean, default: false },
    order: { type: Number, default: 0 },
  }],

  specifications: [{
    key: { type: String, required: true },
    value: { type: String, required: true },
  }],

  videoUrl: {
    type: String,
    default: null,
    trim: true,
  },

  shippingTerms: {
    type: String,
    default: 'Delivery, payment, and return arrangements depend on the product, order, and location. Contact the seller to confirm the applicable terms before payment or dispatch.',
  },

  metaTitle: {
    type: String,
    maxlength: [70, 'Meta title cannot exceed 70 characters'],
  },
  metaDescription: {
    type: String,
    maxlength: [160, 'Meta description cannot exceed 160 characters'],
  },

  status: {
    type: String,
    enum: Object.values(PRODUCT_STATUS),
    default: PRODUCT_STATUS.ACTIVE,
  },
  showOnWebsite: {
    type: Boolean,
    default: true,
  },
  isFeatured: {
    type: Boolean,
    default: false,
  },
  isHot: {
    type: Boolean,
    default: false,
  },

  company: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Company',
    default: null,
  },
  labelIds: [{
    type: String,
    trim: true,
  }],

  viewCount: {
    type: Number,
    default: 0,
  },
  orderCount: {
    type: Number,
    default: 0,
  },
  negotiationCount: {
    type: Number,
    default: 0,
  },
  rating: {
    type: Number,
    default: 4.5,
    min: [0, 'Rating cannot be less than 0'],
    max: [5, 'Rating cannot exceed 5'],
  },
  purchaseCountMin: {
    type: Number,
    default: 0,
    min: [0, 'Purchase count min cannot be negative'],
  },
  purchaseCountMax: {
    type: Number,
    default: 0,
    min: [0, 'Purchase count max cannot be negative'],
  },
}, {
  timestamps: true,
});

productSchema.index({ slug: 1 }, { unique: true });
productSchema.index({ sku: 1 }, { unique: true });
productSchema.index({ category: 1, status: 1 });
productSchema.index({ company: 1, category: 1, status: 1 });
productSchema.index({ categoryRef: 1, status: 1 });
productSchema.index({ status: 1, isFeatured: -1 });
productSchema.index({ showOnWebsite: 1, status: 1 });
productSchema.index({ retailPrice: 1 });
productSchema.index({ wholesalePrice: 1 });
productSchema.index({ stock: 1 });
productSchema.index({ name: 'text', description: 'text', tags: 'text' });

productSchema.pre('save', function (next) {
  this.variants = [];

  if (this.isModified('nameHindi') || this.isNew) {
    this.searchTextHindi = normalizeSearchText(this.nameHindi);
  }

  if (this.isModified('name') || !this.slug) {
    this.slug = slugify(this.name, { lower: true, strict: true });
  }
  next();
});

productSchema.virtual('inStock').get(function () {
  return getProductStockTotal(this) > 0;
});

productSchema.virtual('isLowStock').get(function () {
  const totalStock = getProductStockTotal(this);
  return totalStock > 0 && totalStock <= this.lowStockThreshold;
});

productSchema.virtual('primaryImage').get(function () {
  const primary = this.images.find(img => img.isPrimary);
  return primary ? primary.url : (this.images[0]?.url || null);
});

productSchema.virtual('primaryBlurHash').get(function () {
  const primary = this.images.find(img => img.isPrimary);
  return primary ? primary.blurHash : (this.images[0]?.blurHash || null);
});

productSchema.set('toJSON', { virtuals: true });
productSchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('Product', productSchema);
