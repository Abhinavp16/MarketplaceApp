const mongoose = require('mongoose');
const slugify = require('slugify');

const companySchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Company name is required'],
    trim: true,
    unique: true,
    maxlength: [100, 'Company name cannot exceed 100 characters'],
  },
  slug: {
    type: String,
    unique: true,
    lowercase: true,
  },
  logo: {
    url: { type: String, default: null },
    publicId: { type: String, default: null },
  },
  description: {
    type: String,
    maxlength: [500, 'Description cannot exceed 500 characters'],
    default: null,
  },
  website: {
    type: String,
    default: null,
  },
  isActive: {
    type: Boolean,
    default: true,
  },
  showOnWebsite: {
    type: Boolean,
    default: true,
  },
  order: {
    type: Number,
    default: 0,
  },
  productCount: {
    type: Number,
    default: 0,
  },
  // Percentage off MRP. null/0 = not set (falls through to the next level).
  customerDiscountPercent: {
    type: Number,
    min: [0, 'Discount cannot be negative'],
    max: [100, 'Discount cannot exceed 100%'],
    default: null,
  },
  wholesalerDiscountPercent: {
    type: Number,
    min: [0, 'Discount cannot be negative'],
    max: [100, 'Discount cannot exceed 100%'],
    default: null,
  },
}, {
  timestamps: true,
});

companySchema.index({ slug: 1 }, { unique: true });
companySchema.index({ name: 1 }, { unique: true });
companySchema.index({ isActive: 1 });
companySchema.index({ showOnWebsite: 1 });
companySchema.index({ isActive: 1, order: 1, name: 1 });

companySchema.pre('save', function (next) {
  if (this.isModified('name') || !this.slug) {
    this.slug = slugify(this.name, { lower: true, strict: true });
  }
  next();
});

companySchema.set('toJSON', { virtuals: true });
companySchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('Company', companySchema);
