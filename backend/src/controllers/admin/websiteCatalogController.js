const { Company, Category, Product } = require('../../models');
const { PRODUCT_STATUS } = require('../../utils/constants');

function normalizeBool(value) {
  if (value === undefined || value === null || value === '') return undefined;
  return String(value) === 'true';
}

function regex(value) {
  return new RegExp(String(value || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
}

exports.getBrands = async (req, res, next) => {
  try {
    const showOnWebsite = normalizeBool(req.query.showOnWebsite);
    const query = {};
    if (showOnWebsite !== undefined) query.showOnWebsite = showOnWebsite;
    if (req.query.search) query.name = regex(req.query.search);

    const brands = await Company.find(query)
      .select('name slug logo isActive showOnWebsite productCount order')
      .sort({ order: 1, name: 1 })
      .lean();

    res.json({ success: true, data: brands });
  } catch (error) {
    next(error);
  }
};

exports.getCategories = async (req, res, next) => {
  try {
    const showOnWebsite = normalizeBool(req.query.showOnWebsite);
    const query = {};
    if (showOnWebsite !== undefined) query.showOnWebsite = showOnWebsite;
    if (req.query.company) query.company = req.query.company;
    if (req.query.search) query.name = regex(req.query.search);

    const categories = await Category.find(query)
      .populate('company', 'name slug showOnWebsite')
      .select('name slug company isActive showOnWebsite productCount order')
      .sort({ order: 1, name: 1 })
      .lean();

    res.json({ success: true, data: categories });
  } catch (error) {
    next(error);
  }
};

exports.getProducts = async (req, res, next) => {
  try {
    const showOnWebsite = normalizeBool(req.query.showOnWebsite);
    const query = { status: { $ne: PRODUCT_STATUS.ARCHIVED } };
    if (showOnWebsite !== undefined) query.showOnWebsite = showOnWebsite;
    if (req.query.company) query.company = req.query.company;
    if (req.query.categoryRef) query.categoryRef = req.query.categoryRef;
    if (req.query.search) query.name = regex(req.query.search);

    const products = await Product.find(query)
      .populate('company', 'name slug showOnWebsite')
      .populate('categoryRef', 'name slug showOnWebsite')
      .select('name slug sku brand category company categoryRef status stock showOnWebsite createdAt')
      .sort({ createdAt: -1 })
      .lean();

    res.json({ success: true, data: products });
  } catch (error) {
    next(error);
  }
};

exports.updateVisibility = async (req, res, next) => {
  try {
    const { type, ids, showOnWebsite } = req.body || {};
    if (!['brand', 'category', 'product'].includes(type)) {
      return res.status(400).json({ success: false, message: 'Invalid visibility type' });
    }
    if (!Array.isArray(ids) || ids.length === 0) {
      return res.status(400).json({ success: false, message: 'Select at least one item' });
    }
    if (typeof showOnWebsite !== 'boolean') {
      return res.status(400).json({ success: false, message: 'showOnWebsite must be true or false' });
    }

    const model = type === 'brand' ? Company : type === 'category' ? Category : Product;
    const result = await model.updateMany(
      { _id: { $in: ids } },
      { $set: { showOnWebsite } },
    );

    res.json({
      success: true,
      message: `${type} visibility updated`,
      data: { matchedCount: result.matchedCount, modifiedCount: result.modifiedCount },
    });
  } catch (error) {
    next(error);
  }
};
