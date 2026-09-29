const { Company, Category, Product } = require('../models');
const { PRODUCT_STATUS } = require('../utils/constants');
const { normalizeMediaUrl } = require('../utils/mediaUrls');

const GENERAL_PRODUCTS_NAME = 'GENERAL PRODUCTS';

function escapeRegex(value = '') {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function productImage(product, req) {
  const images = Array.isArray(product.images) ? [...product.images] : [];
  images.sort((a, b) => (a?.order || 0) - (b?.order || 0));
  const primary = images.find((image) => image?.isPrimary) || images[0];
  return normalizeMediaUrl(primary?.url || '', req);
}

function mapBrand(brand) {
  return {
    id: String(brand._id),
    name: brand.name,
    slug: brand.slug,
    logo: brand.logo || null,
    description: brand.description || '',
    productCount: brand.productCount || 0,
  };
}

async function attachVisibleProductCounts(brands = []) {
  if (brands.length === 0) return brands;
  const brandIds = brands.map((brand) => brand._id);
  const counts = await Product.aggregate([
    {
      $match: {
        ...visibleProductQuery,
        company: { $in: brandIds },
      },
    },
    { $group: { _id: '$company', count: { $sum: 1 } } },
  ]);
  const countByBrandId = new Map(counts.map((item) => [String(item._id), item.count]));
  return brands.map((brand) => ({
    ...brand,
    productCount: countByBrandId.get(String(brand._id)) || 0,
  }));
}

function mapCategory(category) {
  return {
    id: String(category._id),
    name: category.name,
    nameHindi: category.nameHindi || '',
    slug: category.slug,
    description: category.description || '',
    image: category.image?.url || '',
    blurHash: category.image?.blurHash || null,
    productCount: category.productCount || 0,
    brand: category.company ? {
      id: String(category.company._id || category.company),
      name: category.company.name || '',
      slug: category.company.slug || '',
    } : null,
  };
}

function mapProduct(product, req) {
  const images = Array.isArray(product.images)
    ? product.images
        .map((image) => normalizeMediaUrl(image?.url || '', req))
        .filter(Boolean)
    : [];

  return {
    id: String(product._id),
    productId: String(product._id),
    name: product.name,
    nameHindi: product.nameHindi || '',
    slug: product.slug,
    shortDescription: product.shortDescription || '',
    description: product.description || '',
    category: product.categoryRef ? {
      id: String(product.categoryRef._id),
      name: product.categoryRef.name,
      slug: product.categoryRef.slug,
    } : { id: '', name: product.category || '', slug: product.category || '' },
    brand: product.company ? {
      id: String(product.company._id),
      name: product.company.name,
      slug: product.company.slug,
    } : { id: '', name: product.brand || '', slug: '' },
    sku: product.sku || '',
    mrp: product.mrp || 0,
    retailPrice: product.retailPrice || 0,
    wholesalePrice: product.wholesalePrice || 0,
    stock: product.stock || 0,
    inStock: (product.stock || 0) > 0,
    priceUnit: product.priceUnit || '',
    packing: product.packing || '',
    image: productImage(product, req),
    images,
  };
}

async function getRandomFeaturedProducts(req, limit = 5) {
  const sampledProducts = await Product.aggregate([
    { $match: visibleProductQuery },
    {
      $lookup: {
        from: 'companies',
        localField: 'company',
        foreignField: '_id',
        as: 'companyDoc',
      },
    },
    { $unwind: '$companyDoc' },
    {
      $lookup: {
        from: 'categories',
        localField: 'categoryRef',
        foreignField: '_id',
        as: 'categoryDoc',
      },
    },
    { $unwind: '$categoryDoc' },
    {
      $match: {
        'companyDoc.isActive': true,
        'companyDoc.showOnWebsite': { $ne: false },
        'categoryDoc.isActive': true,
        'categoryDoc.showOnWebsite': { $ne: false },
      },
    },
    { $sample: { size: limit } },
    { $project: { _id: 1 } },
  ]);

  if (sampledProducts.length === 0) return [];

  const productIds = sampledProducts.map((product) => product._id);
  const products = await Product.find({ _id: { $in: productIds } })
    .populate('company', 'name slug')
    .populate('categoryRef', 'name slug')
    .lean();
  const productById = new Map(products.map((product) => [String(product._id), product]));

  return productIds
    .map((productId) => productById.get(String(productId)))
    .filter(Boolean)
    .map((product) => mapProduct(product, req));
}

const visibleBrandQuery = {
  isActive: true,
  showOnWebsite: { $ne: false },
};

const visibleCategoryQuery = {
  isActive: true,
  showOnWebsite: { $ne: false },
};

const visibleProductQuery = {
  status: PRODUCT_STATUS.ACTIVE,
  showOnWebsite: { $ne: false },
};

async function findVisibleBrand(slug) {
  return Company.findOne({
    slug,
    ...visibleBrandQuery,
    name: { $ne: GENERAL_PRODUCTS_NAME },
  });
}

exports.getHomeCatalog = async (req, res, next) => {
  try {
    const generalBrand = await Company.findOne({ name: GENERAL_PRODUCTS_NAME });
    const [rawBrands, generalCategories, featuredProducts] = await Promise.all([
      Company.find({
        ...visibleBrandQuery,
        name: { $ne: GENERAL_PRODUCTS_NAME },
      }).sort({ order: 1, name: 1 }).lean(),
      generalBrand
        ? Category.find({
            ...visibleCategoryQuery,
            company: generalBrand._id,
          }).populate('company', 'name slug').sort({ order: 1, name: 1 }).lean()
        : [],
      getRandomFeaturedProducts(req),
    ]);
    const brands = await attachVisibleProductCounts(rawBrands);

    res.json({
      success: true,
      data: {
        brands: brands.map(mapBrand),
        generalCategories: generalCategories.map(mapCategory),
        featuredProducts,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.getBrands = async (req, res, next) => {
  try {
    const rawBrands = await Company.find({
      ...visibleBrandQuery,
      name: { $ne: GENERAL_PRODUCTS_NAME },
    }).sort({ order: 1, name: 1 }).lean();
    const brands = await attachVisibleProductCounts(rawBrands);
    res.json({ success: true, data: brands.map(mapBrand) });
  } catch (error) {
    next(error);
  }
};

exports.getBrandCategories = async (req, res, next) => {
  try {
    const brand = await findVisibleBrand(req.params.brandSlug);
    if (!brand) return res.status(404).json({ success: false, message: 'Brand not found' });

    const categories = await Category.find({
      ...visibleCategoryQuery,
      company: brand._id,
    }).populate('company', 'name slug').sort({ order: 1, name: 1 }).lean();

    res.json({ success: true, data: { brand: mapBrand(brand), categories: categories.map(mapCategory) } });
  } catch (error) {
    next(error);
  }
};

exports.getProductsByBrandCategory = async (req, res, next) => {
  try {
    const brand = await findVisibleBrand(req.params.brandSlug);
    if (!brand) return res.status(404).json({ success: false, message: 'Brand not found' });

    const category = await Category.findOne({
      ...visibleCategoryQuery,
      company: brand._id,
      slug: req.params.categorySlug,
    }).populate('company', 'name slug');
    if (!category) return res.status(404).json({ success: false, message: 'Category not found' });

    const products = await Product.find({
      ...visibleProductQuery,
      company: brand._id,
      categoryRef: category._id,
    }).populate('company', 'name slug').populate('categoryRef', 'name slug').sort({ createdAt: -1 }).lean();

    res.json({ success: true, data: { brand: mapBrand(brand), category: mapCategory(category), products: products.map((product) => mapProduct(product, req)) } });
  } catch (error) {
    next(error);
  }
};

exports.getGeneralCategories = async (req, res, next) => {
  try {
    const generalBrand = await Company.findOne({ name: GENERAL_PRODUCTS_NAME, isActive: true });
    if (!generalBrand) return res.json({ success: true, data: [] });

    const categories = await Category.find({
      ...visibleCategoryQuery,
      company: generalBrand._id,
    }).populate('company', 'name slug').sort({ order: 1, name: 1 }).lean();

    res.json({ success: true, data: categories.map(mapCategory) });
  } catch (error) {
    next(error);
  }
};

exports.getGeneralCategoryProducts = async (req, res, next) => {
  try {
    const generalBrand = await Company.findOne({ name: GENERAL_PRODUCTS_NAME, isActive: true });
    if (!generalBrand) return res.status(404).json({ success: false, message: 'Category not found' });

    const category = await Category.findOne({
      ...visibleCategoryQuery,
      company: generalBrand._id,
      slug: req.params.categorySlug,
    }).populate('company', 'name slug');
    if (!category) return res.status(404).json({ success: false, message: 'Category not found' });

    const products = await Product.find({
      ...visibleProductQuery,
      company: generalBrand._id,
      categoryRef: category._id,
    }).populate('company', 'name slug').populate('categoryRef', 'name slug').sort({ createdAt: -1 }).lean();

    res.json({ success: true, data: { category: mapCategory(category), products: products.map((product) => mapProduct(product, req)) } });
  } catch (error) {
    next(error);
  }
};

exports.getProducts = async (req, res, next) => {
  try {
    const search = String(req.query.search || '').trim();
    const searchRegex = search ? new RegExp(escapeRegex(search), 'i') : null;

    const products = await Product.find(visibleProductQuery)
      .populate('company', 'name slug isActive showOnWebsite')
      .populate('categoryRef', 'name slug isActive showOnWebsite')
      .sort({ name: 1 })
      .lean();

    let visibleProducts = products.filter((product) => (
      product.company?.isActive !== false
      && product.company?.showOnWebsite !== false
      && product.categoryRef?.isActive !== false
      && product.categoryRef?.showOnWebsite !== false
    ));

    if (searchRegex) {
      visibleProducts = visibleProducts.filter((product) => [
        product.name,
        product.sku,
        product.shortDescription,
        product.description,
        product.company?.name,
        product.categoryRef?.name,
      ].some((value) => searchRegex.test(String(value || ''))));
    }

    res.json({ success: true, data: visibleProducts.map((product) => mapProduct(product, req)) });
  } catch (error) {
    next(error);
  }
};

exports.getProduct = async (req, res, next) => {
  try {
    const query = {
      ...visibleProductQuery,
      slug: req.params.productSlug,
    };

    const product = await Product.findOne(query)
      .populate('company', 'name slug isActive showOnWebsite')
      .populate('categoryRef', 'name slug isActive showOnWebsite')
      .lean();

    if (!product || product.company?.isActive === false || product.company?.showOnWebsite === false || product.categoryRef?.isActive === false || product.categoryRef?.showOnWebsite === false) {
      return res.status(404).json({ success: false, message: 'Product not found' });
    }

    res.json({ success: true, data: mapProduct(product, req) });
  } catch (error) {
    next(error);
  }
};
