const { Product, Analytics, WebsiteSettings, Company, ProductInterest } = require('../models');
const { NotFoundError } = require('../utils/errors');
const { paginate, formatPaginationResponse } = require('../utils/helpers');
const { PRODUCT_STATUS, ANALYTICS_EVENTS } = require('../utils/constants');
const mongoose = require('mongoose');
const {
  getPriceForUser,
  getPendingPriceChangeForUser,
  getProductStockTotal,
} = require('../utils/productVariants');
const { normalizeMediaUrl, normalizeImageObject } = require('../utils/mediaUrls');
const Category = require('../models/Category');
const {
  applyCategoryAccessToProductQuery,
  filterCategoriesForUser,
  isCategoryExcludedForUser,
} = require('../utils/categoryAccess');
const {
  buildCategoryScopeCondition,
  collectCategoryScope,
  pruneCategoriesWithInaccessibleAncestors,
} = require('../services/productSearchService');
const { buildDiscountMap, discountsFor } = require('../services/productDiscountService');
const { isLeadRole, sanitizeWatchSeconds } = require('../utils/leadInterest');
const { buildSearchTerms, groupPattern, normalizeSearchText } = require('../utils/searchQuery');
const logger = require('../utils/logger');

const formatProductCard = (product, userRole, req, discounts = null) => {
  const pricing = getPriceForUser(product, userRole, null, discounts);
  const stock = getProductStockTotal(product);

  return {
    id: product._id,
    name: product.name,
    nameHindi: product.nameHindi,
    slug: product.slug,
    shortDescription: product.shortDescription,
    category: product.category,
    brand: product.brand || product.company?.name || '',
    ...pricing,
    stock,
    inStock: stock > 0,
    priceUnit: product.priceUnit || '',
    packing: product.packing || '',
    primaryImage: normalizeMediaUrl(
      product.images?.find(img => img.isPrimary)?.url || product.images?.[0]?.url,
      req
    ),
    isFeatured: product.isFeatured,
    isHot: product.isHot,
    isNew: product.isNew,
    rating: product.rating,
    purchaseCountMin: product.purchaseCountMin,
    purchaseCountMax: product.purchaseCountMax,
    pendingPriceChange: getPendingPriceChangeForUser(product, userRole, null, discounts),
  };
};

// Products must include company, categoryRef and category for brand/category discounts.
const formatProductCards = async (products, userRole, req) => {
  const discountMap = await buildDiscountMap(products);
  return products.map((product) => formatProductCard(product, userRole, req, discountsFor(discountMap, product)));
};

const isTrueQuery = (value) => value === true || value === 'true';

exports.getProducts = async (req, res, next) => {
  try {
    console.log('Raw req.query:', req.query);
    const { categoryId, category, brand, minPrice, maxPrice, inStock, featured, hot, sort, subcategory } = req.query;
    const { page, limit, skip } = paginate(req.query.page, req.query.limit);
    const userRole = req.user?.role || 'guest';

    console.log('getProducts request - category:', category, 'brand:', brand, 'subcategory:', subcategory);

    const query = { status: PRODUCT_STATUS.ACTIVE };

    // Price filter based on user role
    const priceField = userRole === 'wholesaler' ? 'wholesalePrice' : 'retailPrice';
    
    // Resolve the category so unmigrated name-linked products stay scoped to
    // the correct company instead of colliding with another brand.
    if (categoryId) {
      const categoryDoc = await Category.findById(categoryId)
        .select('name slug company')
        .lean();
      if (!categoryDoc) {
        return res.json({
          success: true,
          ...formatPaginationResponse([], 0, page, limit),
        });
      }
      query.$or = [
        { categoryRef: categoryDoc._id },
        {
          $and: [
            { $or: [{ categoryRef: null }, { categoryRef: { $exists: false } }] },
            { company: categoryDoc.company },
            { category: { $in: [categoryDoc.name, categoryDoc.slug].filter(Boolean) } },
          ],
        },
      ];
    } else if (subcategory) {
      // For subcategory, find the Category document first by slug
      const Category = require('../models/Category');
      const subcatDoc = await Category.findOne({ slug: subcategory }).lean();
      if (subcatDoc) {
        // Filter products where category matches the subcategory name or slug
        const subcatName = subcatDoc.name;
        const subcatSlug = subcatDoc.slug;
        const normalizedName = subcatName.replace(/[-_]+/g, ' ').trim();
        const normalizedSlug = subcatSlug.replace(/[-_]+/g, ' ').trim();
        
        query.category = {
          $in: [subcatName, subcatSlug, normalizedName, normalizedSlug].map(
            (value) => new RegExp(`^${value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i')
          ),
        };
        console.log('Filtering by subcategory name/slug:', { subcatName, subcatSlug, normalizedName, normalizedSlug });
      } else {
        // Fallback: just use the slug directly
        const rawSubcategory = String(subcategory).trim();
        const normalizedSubcategory = rawSubcategory.replace(/[-_]+/g, ' ').trim();
        query.category = {
          $in: [rawSubcategory, normalizedSubcategory].map(
            (value) => new RegExp(`^${value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i')
          ),
        };
      }
    } else if (category) {
      const rawCategory = String(category).trim();
      const normalizedCategory = rawCategory.replace(/[-_]+/g, ' ').trim();
      query.category = {
        $in: [...new Set([rawCategory, normalizedCategory])].map(
          (value) => new RegExp(`^${value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i')
        ),
      };
    }
    
    // Filter by brand (checks both product.brand and product.company)
    if (brand) {
      const matchingCompanies = await Company.find({
        name: { $regex: new RegExp(brand, 'i') }
      }).select('_id');
      const companyIds = matchingCompanies.map(c => c._id);
      
      query.$and = [
        ...(Array.isArray(query.$and) ? query.$and : []),
        {
          $or: [
            { brand: { $regex: new RegExp(brand, 'i') } },
            { company: { $in: companyIds } },
          ],
        },
      ];
    }
    
    if (minPrice) query[priceField] = { ...query[priceField], $gte: Number(minPrice) };
    if (maxPrice) query[priceField] = { ...query[priceField], $lte: Number(maxPrice) };
    if (isTrueQuery(inStock)) query.stock = { $gt: 0 };
    if (isTrueQuery(featured)) query.isFeatured = true;
    if (isTrueQuery(hot)) query.isHot = true;

    applyCategoryAccessToProductQuery(query, req.user);

    console.log('getProducts final query:', JSON.stringify(query));

    let sortOption = { createdAt: -1 };
    if (sort) {
      let sortField = sort.startsWith('-') ? sort.slice(1) : sort;
      // Map 'price' to appropriate field based on role
      if (sortField === 'price') sortField = priceField;
      const sortOrder = sort.startsWith('-') ? -1 : 1;
      sortOption = { [sortField]: sortOrder };
    }

    const [products, total] = await Promise.all([
      Product.find(query)
        .select('name nameHindi slug shortDescription category brand mrp retailPrice wholesalePrice pendingRetailPrice pendingWholesalePrice priceChangeScheduledAt priceChangeEffectiveAt minWholesaleQuantity negotiationEnabled stock priceUnit packing images isFeatured isHot isNew rating purchaseCountMin purchaseCountMax company categoryRef')
        .populate('company', 'name')
        .sort(sortOption)
        .skip(skip)
        .limit(limit)
        .lean(),
      Product.countDocuments(query),
    ]);

    const formattedProducts = await formatProductCards(products, userRole, req);

    res.json({
      success: true,
      ...formatPaginationResponse(formattedProducts, total, page, limit),
    });
  } catch (error) {
    next(error);
  }
};

exports.getProductBySlug = async (req, res, next) => {
  try {
    const userRole = req.user?.role || 'guest';
    const param = req.params.slug;

    // Try public lookup by active slug first.
    let product = await Product.findOne({
      slug: param,
      status: PRODUCT_STATUS.ACTIVE,
    }).lean();

    // If opened from cart/order history, ID may point to a non-active product.
    // Allow ID lookup regardless of status so users can still view item details.
    if (!product && param.match(/^[0-9a-fA-F]{24}$/)) {
      product = await Product.findById(param).lean();
    }

    if (!product) {
      throw new NotFoundError('Product not found', 'PRODUCT_NOT_FOUND');
    }

    if (isCategoryExcludedForUser(req.user, product.category)) {
      throw new NotFoundError('Product not found', 'PRODUCT_NOT_FOUND');
    }

    // Build response with role-based pricing (including brand/category discount)
    const discounts = discountsFor(await buildDiscountMap([product]), product);
    const pricing = getPriceForUser(product, userRole, null, discounts);
    let resolvedLabels = [];
    if (Array.isArray(product.labelIds) && product.labelIds.length > 0) {
      const settings = await WebsiteSettings.getSettings();
      const labelMap = new Map(
        (settings.labels || []).map((label) => [
          String(label?.id || ''),
          {
            id: String(label?.id || ''),
            title: String(label?.title || '').trim(),
            sourceType: label?.sourceType === 'image' ? 'image' : 'icon',
            image: String(label?.image || '').trim(),
            icon: String(label?.icon || '').trim(),
            order: Number.isFinite(label?.order) ? label.order : 0,
          },
        ])
      );

      const labelsByTitle = new Map(
        (settings.labels || []).map((label) => [
          String(label?.title || '').trim(),
          {
            id: String(label?.id || ''),
            title: String(label?.title || '').trim(),
            sourceType: label?.sourceType === 'image' ? 'image' : 'icon',
            image: String(label?.image || '').trim(),
            icon: String(label?.icon || '').trim(),
            order: Number.isFinite(label?.order) ? label.order : 0,
          },
        ])
      );

      resolvedLabels = product.labelIds
        .map((labelId) => {
          const value = String(labelId || '').trim();
          return labelMap.get(value) || labelsByTitle.get(value);
        })
        .filter(Boolean);
    }

    const responseData = {
      ...product,
      id: product._id,
      primaryImage: normalizeMediaUrl(product.primaryImage, req),
      images: Array.isArray(product.images)
        ? product.images.map((image) => normalizeImageObject(image, req))
        : [],
      ...pricing,
      labels: resolvedLabels,
      stock: getProductStockTotal(product),
      pendingPriceChange: getPendingPriceChangeForUser(product, userRole, null, discounts),
    };

    // Remove raw price fields for non-admin users, but keep for wholesalers so they can see customer price
    if (userRole !== 'admin' && userRole !== 'wholesaler') {
      delete responseData.retailPrice;
      delete responseData.wholesalePrice;
    }

    res.json({
      success: true,
      data: responseData,
    });
  } catch (error) {
    next(error);
  }
};

exports.getCategories = async (req, res, next) => {
  try {
    const categoryMatch = applyCategoryAccessToProductQuery({ status: PRODUCT_STATUS.ACTIVE }, req.user);
    const categories = await Product.aggregate([
      { $match: categoryMatch },
      {
        $group: {
          _id: '$category',
          count: { $sum: 1 },
          subCategories: { $addToSet: '$subCategory' },
        },
      },
      {
        $project: {
          name: '$_id',
          count: 1,
          subCategories: {
            $filter: {
              input: '$subCategories',
              cond: { $ne: ['$$this', null] },
            },
          },
        },
      },
      { $sort: { name: 1 } },
    ]);

    const categoryNames = categories
      .map((category) => category.name?.toString().trim())
      .filter(Boolean);
    const normalizedNames = categoryNames.map((name) => name.replace(/[-_]+/g, ' ').trim());
    const slugs = categoryNames
      .map((name) => name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, ''))
      .filter(Boolean);

    const categoryDocs = await Category.find({
      $or: [
        { name: { $in: categoryNames } },
        { name: { $in: normalizedNames } },
        { slug: { $in: slugs } },
      ],
    })
      .select('name nameHindi slug')
      .lean();

    const categoryLookup = new Map();
    const registerCategoryDoc = (key, doc) => {
      if (!key) return;
      categoryLookup.set(key.trim().toLowerCase(), doc);
    };

    for (const doc of categoryDocs) {
      registerCategoryDoc(doc.name, doc);
      registerCategoryDoc(doc.slug, doc);
      registerCategoryDoc((doc.name || '').replace(/[-_]+/g, ' '), doc);
      registerCategoryDoc((doc.slug || '').replace(/[-_]+/g, ' '), doc);
    }

    const enrichedCategories = filterCategoriesForUser(categories.map((category) => {
      const lookupKey = category.name?.toString().trim().toLowerCase() ?? '';
      const normalizedLookupKey = category.name?.toString().replace(/[-_]+/g, ' ').trim().toLowerCase() ?? '';
      const doc = categoryLookup.get(lookupKey) || categoryLookup.get(normalizedLookupKey);

      return {
        ...category,
        nameHindi: doc?.nameHindi || '',
        slug: doc?.slug || '',
      };
    }), req.user);

    res.json({
      success: true,
      data: enrichedCategories,
    });
  } catch (error) {
    next(error);
  }
};

exports.getFeaturedProducts = async (req, res, next) => {
  try {
    const userRole = req.user?.role || 'guest';

    const query = applyCategoryAccessToProductQuery({
      status: PRODUCT_STATUS.ACTIVE,
      isFeatured: true,
    }, req.user);

    const products = await Product.find(query)
      .select('name slug shortDescription category mrp retailPrice wholesalePrice pendingRetailPrice pendingWholesalePrice priceChangeScheduledAt priceChangeEffectiveAt minWholesaleQuantity negotiationEnabled stock priceUnit packing images isFeatured isHot isNew rating purchaseCountMin purchaseCountMax company categoryRef')
      .limit(10)
      .lean();

    const formattedProducts = await formatProductCards(products, userRole, req);

    res.json({
      success: true,
      data: formattedProducts,
    });
  } catch (error) {
    next(error);
  }
};

const SEARCH_RESULT_FIELDS = 'name nameHindi slug shortDescription category brand mrp retailPrice wholesalePrice pendingRetailPrice pendingWholesalePrice priceChangeScheduledAt priceChangeEffectiveAt minWholesaleQuantity negotiationEnabled stock priceUnit packing images isHot isNew rating purchaseCountMin purchaseCountMax company categoryRef createdAt';

// Relevance: words found in the product name (English or Hindi) score
// highest, all words in the name score a bonus; description/category-only
// matches come after. Ties: newest first.
function searchScoreExpression(termGroups) {
  const nameText = {
    $concat: [
      { $ifNull: ['$name', ''] }, ' ',
      { $ifNull: ['$nameHindi', ''] }, ' ',
      { $ifNull: ['$searchTextHindi', ''] },
    ],
  };
  const inName = termGroups.map((variants) => ({
    $regexMatch: { input: nameText, regex: groupPattern(variants), options: 'i' },
  }));
  return {
    $add: [
      ...inName.map((matched) => ({ $cond: [matched, 2, 0] })),
      { $cond: [{ $and: inName }, 3, 0] },
    ],
  };
}

async function runSearch(filter, termGroups, skip, limit) {
  const castFilter = Product.find().cast(Product, filter);
  const [products, total] = await Promise.all([
    termGroups.length > 0
      ? Product.aggregate([
        { $match: castFilter },
        { $addFields: { _searchScore: searchScoreExpression(termGroups) } },
        { $sort: { _searchScore: -1, createdAt: -1, _id: -1 } },
        { $skip: skip },
        { $limit: limit },
        { $project: Object.fromEntries(SEARCH_RESULT_FIELDS.split(' ').map((field) => [field, 1])) },
      ]).then((docs) => Product.populate(docs, { path: 'company', select: 'name' }))
      : Product.find(filter)
        .select(SEARCH_RESULT_FIELDS)
        .populate('company', 'name')
        .sort({ createdAt: -1, _id: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
    Product.countDocuments(filter),
  ]);
  return { products, total };
}

async function findSearchResults({ query, termGroups, termFilterIndex, skip, limit }) {
  const strict = await runSearch(query, termGroups, skip, limit);
  if (strict.total > 0 || termGroups.length < 2) return strict;

  // Nothing matched every word: allow any word, best matches first.
  const relaxed = { ...query, $and: [...(query.$and || [])] };
  const termConditions = relaxed.$and.splice(termFilterIndex, termGroups.length);
  relaxed.$and.push({ $or: termConditions });
  return runSearch(relaxed, termGroups, skip, limit);
}

exports.searchProducts = async (req, res, next) => {
  try {
    const { q, categoryId, brandId, category, brand } = req.query;
    const { page, limit, skip } = paginate(req.query.page, req.query.limit);
    const userRole = req.user?.role || 'guest';

    const query = { status: PRODUCT_STATUS.ACTIVE };
    const andConditions = [];
    // One group of equivalent variants per meaningful word (Hindi, Hinglish,
    // English), e.g. "ड्रिल wala" -> [[ड्रिल, drill, drilling, ...]].
    const termGroups = buildSearchTerms(q);
    const needsCompanyCatalog = Boolean(brandId) || Boolean(brand) || termGroups.length > 0;
    const [allCategories, allCompanies] = await Promise.all([
      Category.find({}).select('_id name nameHindi slug parent company isActive').lean(),
      needsCompanyCatalog
        ? Company.find({ isActive: true }).select('_id name slug').lean()
        : [],
    ]);
    const accessibleCategories = pruneCategoriesWithInaccessibleAncestors(
      allCategories,
      filterCategoriesForUser(
        allCategories.filter((categoryItem) => categoryItem.isActive !== false),
        req.user,
      ),
    );
    const accessibleCategoryIds = new Set(
      accessibleCategories.map((categoryItem) => String(categoryItem._id)),
    );
    const inaccessibleCategories = allCategories.filter(
      (categoryItem) => !accessibleCategoryIds.has(String(categoryItem._id)),
    );

    const includesAny = (values, variants) => values
      .filter(Boolean)
      .map((value) => normalizeSearchText(value))
      .some((value) => variants.some((variant) => value.includes(variant)));
    const termConditions = termGroups.map((variants) => {
      const regex = new RegExp(groupPattern(variants), 'i');
      const companyIds = allCompanies
        .filter((company) => includesAny([company.name, company.slug], variants))
        .map((company) => company._id);
      const categoryScopeById = new Map();
      for (const matched of accessibleCategories.filter((item) => includesAny([item.name, item.nameHindi, item.slug], variants))) {
        for (const scoped of collectCategoryScope(accessibleCategories, matched._id)) {
          categoryScopeById.set(String(scoped._id), scoped);
        }
      }
      const categoryScope = [...categoryScopeById.values()];
      return {
        $or: [
          { name: regex },
          { nameHindi: regex },
          { searchTextHindi: regex },
          { description: regex },
          { shortDescription: regex },
          { category: regex },
          { brand: regex },
          { tags: { $in: [regex] } },
          { sku: regex },
          ...(companyIds.length > 0 ? [{ company: { $in: companyIds } }] : []),
          ...(categoryScope.length > 0 ? [buildCategoryScopeCondition(categoryScope)] : []),
        ],
      };
    });
    // Every word must match; if that finds nothing, any word may match (ranked).
    const termFilterIndex = andConditions.length;
    andConditions.push(...termConditions);

    if (categoryId) {
      const scope = collectCategoryScope(accessibleCategories, categoryId);
      andConditions.push(buildCategoryScopeCondition(scope));
    } else if (category) {
      const escaped = category.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      andConditions.push({ category: { $regex: new RegExp(escaped, 'i') } });
    }

    if (brandId) {
      const company = allCompanies.find((item) => String(item._id) === String(brandId));
      const legacyBrandValues = [company?.name, company?.slug].filter(Boolean);
      andConditions.push({
        $or: [
          { company: mongoose.isValidObjectId(brandId) ? new mongoose.Types.ObjectId(String(brandId)) : brandId },
          ...legacyBrandValues.map((value) => ({
            brand: { $regex: new RegExp(`^${String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') },
          })),
        ],
      });
    } else if (brand) {
      const normalizedBrand = brand.toLowerCase();
      const companyIds = allCompanies
        .filter((company) => [company.name, company.slug]
          .filter(Boolean)
          .some((value) => String(value).toLowerCase().includes(normalizedBrand)))
        .map((company) => company._id);
      const escaped = brand.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      andConditions.push({
        $or: [
          { brand: { $regex: new RegExp(escaped, 'i') } },
          { company: { $in: companyIds } },
        ],
      });
    }

    if (andConditions.length > 0) {
      query.$and = andConditions;
    }

    applyCategoryAccessToProductQuery(query, req.user);
    if (inaccessibleCategories.length > 0) {
      query.$nor = [
        ...(query.$nor || []),
        buildCategoryScopeCondition(inaccessibleCategories),
      ];
    }

    const { products, total } = await findSearchResults({
      query,
      termGroups,
      termFilterIndex,
      skip,
      limit,
    });
    const formattedProducts = await formatProductCards(products, userRole, req);

    res.json({
      success: true,
      ...formatPaginationResponse(formattedProducts, total, page, limit),
    });
  } catch (error) {
    next(error);
  }
};

// Lead tracking (one ProductInterest per customer + product). Failures here
// must never break the request that triggered them.
const canTrackLead = (req) => Boolean(req.user?._id) && isLeadRole(req.user.role);

async function recordLeadView(userId, productId) {
  const now = new Date();
  const update = {
    $inc: { viewCount: 1 },
    $set: { lastViewedAt: now },
    $setOnInsert: { firstViewedAt: now },
  };
  try {
    await ProductInterest.updateOne({ userId, productId }, update, { upsert: true });
  } catch (error) {
    // Two first views at the same moment: the other request created the doc.
    if (error?.code === 11000) {
      await ProductInterest.updateOne({ userId, productId }, update);
      return;
    }
    throw error;
  }
}

async function trackLeadSafely(fn) {
  try {
    await fn();
  } catch (error) {
    logger.warn(`[Leads] tracking failed: ${error.message}`);
  }
}

exports.trackProductView = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { source, sessionId } = req.body;

    const product = await Product.findByIdAndUpdate(id, { $inc: { viewCount: 1 } }).select('_id');

    await Analytics.create({
      productId: id,
      userId: req.user?._id || null,
      eventType: ANALYTICS_EVENTS.VIEW,
      source: source || 'direct',
      sessionId,
      deviceInfo: {
        platform: req.headers['x-platform'],
        appVersion: req.headers['x-app-version'],
      },
    });

    if (product && canTrackLead(req)) {
      await trackLeadSafely(() => recordLeadView(req.user._id, product._id));
    }

    res.json({
      success: true,
      message: 'View tracked',
    });
  } catch (error) {
    next(error);
  }
};

// Sent by the app when the customer leaves the product page (or the app goes
// to the background) with the seconds spent on it.
exports.trackProductWatchTime = async (req, res, next) => {
  try {
    const seconds = sanitizeWatchSeconds(req.body?.seconds);
    if (seconds > 0 && canTrackLead(req) && mongoose.isValidObjectId(req.params.id)) {
      await trackLeadSafely(() => ProductInterest.updateOne(
        { userId: req.user._id, productId: req.params.id },
        { $inc: { totalWatchSeconds: seconds }, $set: { lastViewedAt: new Date() } },
      ));
    }
    res.json({ success: true, message: 'Watch time tracked' });
  } catch (error) {
    next(error);
  }
};

exports.trackProductEvent = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { event, source, sessionId } = req.body;

    const allowedEvents = [ANALYTICS_EVENTS.CART_ADD, ANALYTICS_EVENTS.WISHLIST_ADD, ANALYTICS_EVENTS.SHARE];
    if (!allowedEvents.includes(event)) {
      return res.status(400).json({ success: false, message: 'Invalid event type' });
    }

    await Analytics.create({
      productId: id,
      userId: req.user?._id || null,
      eventType: event,
      source: source || 'direct',
      sessionId,
      deviceInfo: {
        platform: req.headers['x-platform'],
        appVersion: req.headers['x-app-version'],
      },
    });

    if (event === ANALYTICS_EVENTS.CART_ADD && canTrackLead(req)) {
      await trackLeadSafely(() => ProductInterest.updateOne(
        { userId: req.user._id, productId: id },
        { $set: { lastCartAddAt: new Date() } },
      ));
    }

    res.json({ success: true, message: 'Event tracked' });
  } catch (error) {
    next(error);
  }
};

exports.getRelatedProducts = async (req, res, next) => {
  try {
    const { id } = req.params;
    const userRole = req.user?.role || 'guest';
    const limit = parseInt(req.query.limit) || 8;

    const isObjectId = require('mongoose').Types.ObjectId.isValid(id);
    let productQuery = { status: 'active' };
    if (isObjectId && id.length === 24) {
      productQuery._id = id;
    } else {
      productQuery.slug = id;
    }

    const currentProduct = await Product.findOne(productQuery).select('category _id');
    if (!currentProduct) return res.json({ success: true, data: [] });
    if (isCategoryExcludedForUser(req.user, currentProduct.category)) {
      return res.json({ success: true, data: [] });
    }

    const relatedQuery = applyCategoryAccessToProductQuery({
      status: 'active',
      category: currentProduct.category,
      _id: { $ne: currentProduct._id }
    }, req.user);

    const relatedProducts = await Product.find(relatedQuery)
      .select('name nameHindi slug shortDescription category brand mrp retailPrice wholesalePrice pendingRetailPrice pendingWholesalePrice priceChangeScheduledAt priceChangeEffectiveAt minWholesaleQuantity negotiationEnabled stock priceUnit packing images rating isFeatured isHot isNew purchaseCountMin purchaseCountMax company categoryRef')
      .populate('company', 'name')
      .limit(limit)
      .lean();

    const formattedProducts = await formatProductCards(relatedProducts, userRole, req);

    res.json({ success: true, data: formattedProducts });
  } catch (error) {
    next(error);
  }
};

// @desc    List products with a scheduled (pending) price change
// @route   GET /api/v1/products/scheduled-changes
// @access  Private (any authenticated user; wholesale prices included)
exports.getScheduledPriceChanges = async (req, res, next) => {
  try {
    const products = await Product.find({
      status: PRODUCT_STATUS.ACTIVE,
      priceChangeEffectiveAt: { $ne: null },
    })
      .select('name slug wholesalePrice pendingWholesalePrice priceChangeEffectiveAt images')
      .sort({ priceChangeEffectiveAt: 1 })
      .limit(10)
      .lean();

    res.json({
      success: true,
      data: products.map((p) => ({
        id: p._id,
        name: p.name,
        slug: p.slug,
        image: normalizeMediaUrl(
          p.images?.find(img => img.isPrimary)?.url || p.images?.[0]?.url,
          req
        ),
        currentPrice: p.wholesalePrice,
        newPrice: p.pendingWholesalePrice,
        effectiveAt: p.priceChangeEffectiveAt,
      })),
    });
  } catch (error) {
    next(error);
  }
};
