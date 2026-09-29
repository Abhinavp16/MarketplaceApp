const mongoose = require('mongoose');
const BRAND = require('../../config/brand');
const { Product, StockLog, WebsiteSettings, Category, Settings, PriceChangeAudit } = require('../../models');
const { NotFoundError, BadRequestError } = require('../../utils/errors');
const { paginate, formatPaginationResponse, generateSKU } = require('../../utils/helpers');
const { deleteImage } = require('../../config/cloudinary');
const { saveBuffer } = require('../../config/storage');
const { fillHindiNames, generateHindiName, scheduleHindiNameFill } = require('../../services/hindiNameService');
const { resolveHindiNameOnSave } = require('../../utils/hindiNames');
const { PRODUCT_STATUS } = require('../../utils/constants');
const { createPriceSnapshotWorkbookBuffer } = require('../../utils/priceSnapshotWorkbook');
const { updateProductCount } = require('../categoryController');
const { v4: uuidv4 } = require('uuid');
const sharp = require('sharp');
const slugify = require('slugify');
const { encode } = require('blurhash');
const {
  normalizeVariantsForPersistence,
  getEffectivePricing,
} = require('../../utils/productVariants');
const { buildDiscountMap, discountsFor } = require('../../services/productDiscountService');
const {
  registerPriceChangeCampaign,
  clearPendingFields,
} = require('../../services/productPriceSchedulerService');

const PRICE_CHANGE_MODE_SCHEDULED = 'schedule_24h';
const PRICE_CHANGE_MODE_IMMEDIATE = 'immediate';
const PRICE_CHANGE_DELAY_MS = 24 * 60 * 60 * 1000;

function numberOrNull(value) {
  if (value === null || value === undefined || value === '') {
    return null;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function syncScheduledBasePrices(product, updateData, mode, scheduledAt, effectiveAt) {
  const hasRetailChange =
    updateData.retailPrice !== undefined &&
    Number(updateData.retailPrice) !== Number(product.retailPrice);
  const hasWholesaleChange =
    updateData.wholesalePrice !== undefined &&
    Number(updateData.wholesalePrice) !== Number(product.wholesalePrice);

  if (mode === PRICE_CHANGE_MODE_IMMEDIATE) {
    if (hasRetailChange || hasWholesaleChange) {
      clearPendingFields(updateData);
    } else {
      updateData.pendingRetailPrice = product.pendingRetailPrice ?? null;
      updateData.pendingWholesalePrice = product.pendingWholesalePrice ?? null;
      updateData.priceChangeScheduledAt = product.priceChangeScheduledAt ?? null;
      updateData.priceChangeEffectiveAt = product.priceChangeEffectiveAt ?? null;
    }
    return [];
  }

  if (!hasRetailChange && !hasWholesaleChange) {
    updateData.pendingRetailPrice = product.pendingRetailPrice ?? null;
    updateData.pendingWholesalePrice = product.pendingWholesalePrice ?? null;
    updateData.priceChangeScheduledAt = product.priceChangeScheduledAt ?? null;
    updateData.priceChangeEffectiveAt = product.priceChangeEffectiveAt ?? null;
    return [];
  }

  const nextPendingRetail = hasRetailChange
    ? Number(updateData.retailPrice)
    : numberOrNull(product.pendingRetailPrice);
  const nextPendingWholesale = hasWholesaleChange
    ? Number(updateData.wholesalePrice)
    : numberOrNull(product.pendingWholesalePrice);

  updateData.pendingRetailPrice = nextPendingRetail;
  updateData.pendingWholesalePrice = nextPendingWholesale;
  updateData.priceChangeScheduledAt = scheduledAt;
  updateData.priceChangeEffectiveAt = effectiveAt;

  if (hasRetailChange) {
    updateData.retailPrice = product.retailPrice;
  }
  if (hasWholesaleChange) {
    updateData.wholesalePrice = product.wholesalePrice;
  }

  return [{
    productId: product._id,
    productName: product.name,
    currentRetailPrice: product.retailPrice,
    newRetailPrice: nextPendingRetail,
    currentWholesalePrice: product.wholesalePrice,
    newWholesalePrice: nextPendingWholesale,
    effectiveAt,
  }];
}

async function uploadFilesToStorage(files, folder = 'products') {
  const results = [];
  for (let i = 0; i < files.length; i++) {
    const file = files[i];
    const webpBuffer = await sharp(file.buffer).webp({ quality: 80 }).toBuffer();
    const saved = await saveBuffer({
      buffer: webpBuffer,
      folder,
      filename: `${uuidv4()}.webp`,
      contentType: 'image/webp',
      metadata: { originalName: file.originalname },
    });

    // Generate BlurHash for preview
    let blurHash = null;
    try {
      const { data: pixels, info: { width, height } } = await sharp(file.buffer)
        .raw()
        .ensureAlpha()
        .resize(32, 32, { fit: 'inside' })
        .toBuffer({ resolveWithObject: true });
      
      blurHash = encode(new Uint8ClampedArray(pixels), width, height, 4, 4);
    } catch (err) {
      console.error('Error generating blurhash:', err);
    }

    results.push({ url: saved.url, publicId: saved.publicId, blurHash });
  }
  return results;
}

function toLabelIdArray(labelIds = []) {
  if (Array.isArray(labelIds)) {
    return labelIds;
  }

  if (typeof labelIds === 'string') {
    const trimmed = labelIds.trim();
    if (!trimmed) return [];

    try {
      const parsed = JSON.parse(trimmed);
      if (Array.isArray(parsed)) {
        return parsed;
      }
    } catch (_) {}

    return trimmed.split(',').map((value) => value.trim()).filter(Boolean);
  }

  return [];
}

async function normalizeProductLabelIds(labelIds = []) {
  const incomingValues = toLabelIdArray(labelIds)
    .map((value) => {
      if (value && typeof value === 'object') {
        return String(value.id || value.title || '').trim();
      }
      return String(value || '').trim();
    })
    .filter(Boolean);

  if (incomingValues.length === 0) {
    return [];
  }

  const settings = await WebsiteSettings.getSettings();
  const labels = Array.isArray(settings?.labels) ? settings.labels : [];

  const matchedIds = incomingValues
    .map((value) => {
      const normalizedValue = value.toLowerCase();
      const match = labels.find((label) => {
        const labelId = String(label?.id || '').trim().toLowerCase();
        const labelTitle = String(label?.title || '').trim().toLowerCase();
        return normalizedValue === labelId || normalizedValue === labelTitle;
      });

      if (!match) {
        return value;
      }

      const resolvedId = String(match.id || '').trim();
      return resolvedId || value;
    })
    .filter(Boolean);

  return [...new Set(matchedIds)];
}

function parseStructuredField(value, fallback) {
  if (typeof value !== 'string') return value ?? fallback;

  try {
    return JSON.parse(value);
  } catch (_) {
    return fallback;
  }
}

function prepareProductData(productData) {
  const prepared = { ...productData };

  if (typeof prepared.specifications === 'string') {
    prepared.specifications = parseStructuredField(prepared.specifications, []);
  }
  if (typeof prepared.tags === 'string') {
    prepared.tags = parseStructuredField(prepared.tags, []);
  }
  if (typeof prepared.variants === 'string') {
    prepared.variants = parseStructuredField(prepared.variants, []);
  }

  prepared.variants = normalizeVariantsForPersistence(prepared.variants, prepared);

  return prepared;
}

async function applyCategoryBrand(productData, currentProduct = null) {
  const categoryId = String(productData.categoryId || productData.categoryRef || '').trim();
  let category = null;

  if (categoryId) {
    category = await Category.findById(categoryId).select('name slug company');
  } else if (productData.category && productData.company) {
    category = await Category.findOne({
      company: productData.company,
      $or: [
        { name: productData.category },
        { slug: productData.category },
      ],
    }).select('name slug company');
  }

  delete productData.categoryId;

  if (!category) {
    if (currentProduct && !categoryId && productData.category === undefined) {
      return productData;
    }
    throw new BadRequestError('Select a valid brand category', 'INVALID_CATEGORY');
  }

  productData.categoryRef = category._id;
  productData.category = category.slug || category.name;
  productData.company = category.company;
  return productData;
}

function buildPriceChangeRow({
  product,
  scope,
}) {
  const currentRetailPrice = Number(product.retailPrice ?? 0);
  const currentWholesalePrice = Number(product.wholesalePrice ?? 0);
  const newRetailPrice = product.pendingRetailPrice ?? null;
  const newWholesalePrice = product.pendingWholesalePrice ?? null;
  const scheduledAt = product.priceChangeScheduledAt || null;
  const effectiveAt = product.priceChangeEffectiveAt || null;
  const productName = String(product.name || '').trim();
  const searchText = [
    productName,
    product.sku,
    product.category,
  ]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();

  return {
    id: String(product._id),
    productId: String(product._id),
    productName,
    productSku: String(product.sku || '').trim(),
    category: String(product.category || '').trim(),
    scope,
    variantId: null,
    variantName: '',
    variantSku: '',
    oldRetailPrice: currentRetailPrice,
    newRetailPrice,
    oldWholesalePrice: currentWholesalePrice,
    newWholesalePrice,
    scheduledAt,
    effectiveAt,
    searchText,
  };
}

exports.getPriceSnapshot = async (req, res, next) => {
  try {
    const [products, settings] = await Promise.all([
      Product.find({ status: { $ne: PRODUCT_STATUS.ARCHIVED } })
        .select('name sku category categoryRef company retailPrice wholesalePrice pendingRetailPrice pendingWholesalePrice priceChangeScheduledAt priceChangeEffectiveAt pendingPriceChangeAudit')
        .populate({
          path: 'categoryRef',
          select: 'name company',
          populate: { path: 'company', select: 'name' },
        })
        .populate('company', 'name')
        .populate('pendingPriceChangeAudit', 'scheduleType')
        .lean(),
      Settings.getSettings(),
    ]);

    const productIds = products.map((product) => product._id);
    const immediateAudits = productIds.length === 0
      ? []
      : await PriceChangeAudit.find({
        product: { $in: productIds },
        scheduleType: 'immediate',
        status: 'applied',
      })
        .select('product previousRetailPrice newRetailPrice previousWholesalePrice newWholesalePrice effectiveAt appliedAt createdAt')
        .sort({ product: 1, appliedAt: -1, createdAt: -1 })
        .lean();
    const latestImmediateAuditByProduct = new Map();
    for (const audit of immediateAudits) {
      const productId = String(audit.product);
      if (!latestImmediateAuditByProduct.has(productId)) {
        latestImmediateAuditByProduct.set(productId, audit);
      }
    }

    const snapshotProducts = products
      .map((product) => {
        const hasScheduledChange = product.pendingRetailPrice !== null
          && product.pendingRetailPrice !== undefined
          || product.pendingWholesalePrice !== null
          && product.pendingWholesalePrice !== undefined;
        const immediateAudit = hasScheduledChange
          ? null
          : latestImmediateAuditByProduct.get(String(product._id));
        const hasImmediateRetailChange = immediateAudit?.newRetailPrice !== null
          && immediateAudit?.newRetailPrice !== undefined;
        const hasImmediateWholesaleChange = immediateAudit?.newWholesalePrice !== null
          && immediateAudit?.newWholesalePrice !== undefined;

        return {
          name: String(product.name || '').trim(),
          sku: String(product.sku || '').trim(),
          category: String(product.categoryRef?.name || product.category || 'Uncategorized').trim() || 'Uncategorized',
          retailPrice: hasImmediateRetailChange
            ? immediateAudit.previousRetailPrice
            : product.retailPrice,
          wholesalePrice: hasImmediateWholesaleChange
            ? immediateAudit.previousWholesalePrice
            : product.wholesalePrice,
          pendingRetailPrice: hasScheduledChange
            ? product.pendingRetailPrice ?? null
            : hasImmediateRetailChange ? immediateAudit.newRetailPrice : null,
          pendingWholesalePrice: hasScheduledChange
            ? product.pendingWholesalePrice ?? null
            : hasImmediateWholesaleChange ? immediateAudit.newWholesalePrice : null,
          scheduleType: hasScheduledChange
            ? product.pendingPriceChangeAudit?.scheduleType || ''
            : immediateAudit?.scheduleType || '',
          effectiveAt: hasScheduledChange
            ? product.priceChangeEffectiveAt || null
            : immediateAudit?.appliedAt || immediateAudit?.effectiveAt || null,
          changeStatus: immediateAudit ? 'Applied immediately' : '',
          companyName: product.company?.name || product.categoryRef?.company?.name || '',
        };
      })
      .sort((left, right) => {
        const companyComparison = left.companyName.localeCompare(right.companyName, 'en', { sensitivity: 'base' });
        if (companyComparison) return companyComparison;
        const categoryComparison = left.category.localeCompare(right.category, 'en', { sensitivity: 'base' });
        if (categoryComparison) return categoryComparison;
        const productComparison = left.name.localeCompare(right.name, 'en', { sensitivity: 'base' });
        if (productComparison) return productComparison;
        return left.sku.localeCompare(right.sku, 'en', { sensitivity: 'base' });
      });

    const companyName = settings?.businessName
      || snapshotProducts.find((product) => product.companyName)?.companyName
      || BRAND.name;
    const exportedAt = new Date();
    const buffer = await createPriceSnapshotWorkbookBuffer({
      companyName,
      exportedAt,
      products: snapshotProducts,
    });
    const fileDate = exportedAt.toISOString().slice(0, 10);
    const fileName = `product-price-snapshot-${fileDate}.xlsx`;

    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
    res.setHeader('Content-Length', buffer.length);
    res.send(Buffer.from(buffer));
  } catch (error) {
    next(error);
  }
};

exports.getProducts = async (req, res, next) => {
  try {
    const { status, category, categoryId, search, sort } = req.query;
    const { page, limit, skip } = paginate(req.query.page, req.query.limit);

    const query = {};
    const filters = [];

    if (status) {
      query.status = status;
    } else {
      query.status = { $ne: PRODUCT_STATUS.ARCHIVED };
    }

    if (categoryId) {
      if (!mongoose.isValidObjectId(categoryId)) {
        throw new BadRequestError('Invalid category ID', 'INVALID_CATEGORY_ID');
      }

      const selectedCategory = await Category.findById(categoryId)
        .select('_id name slug company')
        .lean();

      if (!selectedCategory) {
        throw new NotFoundError('Category not found', 'CATEGORY_NOT_FOUND');
      }

      const legacyCategoryValues = [selectedCategory.name, selectedCategory.slug]
        .filter(Boolean);

      // categoryRef is the authoritative relationship. The legacy fallback keeps
      // categories with older products fully visible until their data is migrated.
      filters.push({
        $or: [
          { categoryRef: selectedCategory._id },
          {
            company: selectedCategory.company,
            category: { $in: legacyCategoryValues },
          },
        ],
      });
    } else if (category) {
      query.category = category;
    }

    if (search) {
      filters.push({
        $or: [
          { name: { $regex: search, $options: 'i' } },
          { sku: { $regex: search, $options: 'i' } },
        ],
      });
    }

    if (filters.length > 0) {
      query.$and = filters;
    }

    let sortOption = { createdAt: -1 };
    if (sort) {
      const [field, order] = sort.split(':');
      sortOption = { [field]: order === 'asc' ? 1 : -1 };
    }

    const [products, total] = await Promise.all([
      Product.find(query).sort(sortOption).skip(skip).limit(limit).lean(),
      Product.countDocuments(query),
    ]);
    const discountMap = await buildDiscountMap(products);
    const sanitizedProducts = products.map(({ variants, ...product }) => ({
      ...product,
      variants: [],
      effectivePricing: getEffectivePricing(product, discountsFor(discountMap, product)),
    }));

    res.json({
      success: true,
      ...formatPaginationResponse(sanitizedProducts, total, page, limit),
    });
  } catch (error) {
    next(error);
  }
};

exports.getPriceChanges = async (req, res, next) => {
  try {
    const { page, limit, skip } = paginate(req.query.page, req.query.limit);
    const search = String(req.query.search || '').trim().toLowerCase();

    const products = await Product.find({
      status: { $ne: PRODUCT_STATUS.ARCHIVED },
      priceChangeEffectiveAt: { $ne: null },
    })
      .select('name sku category retailPrice wholesalePrice pendingRetailPrice pendingWholesalePrice priceChangeScheduledAt priceChangeEffectiveAt')
      .sort({ priceChangeEffectiveAt: 1, updatedAt: -1 })
      .lean();

    const rows = [];

    for (const product of products) {
      if (product.priceChangeEffectiveAt) {
        rows.push(buildPriceChangeRow({ product, scope: 'product' }));
      }

    }

    const filteredRows = search
      ? rows.filter((row) => row.searchText.includes(search))
      : rows;

    const paginatedRows = filteredRows.slice(skip, skip + limit);

    res.json({
      success: true,
      ...formatPaginationResponse(paginatedRows, filteredRows.length, page, limit),
    });
  } catch (error) {
    next(error);
  }
};

exports.getProductById = async (req, res, next) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) {
      throw new NotFoundError('Product not found', 'PRODUCT_NOT_FOUND');
    }

    const data = product.toObject();
    data.variants = [];
    data.effectivePricing = getEffectivePricing(data, discountsFor(await buildDiscountMap([data]), data));

    res.json({
      success: true,
      data,
    });
  } catch (error) {
    next(error);
  }
};

exports.createProduct = async (req, res, next) => {
  try {
    const productData = await applyCategoryBrand(prepareProductData(req.body));

    if (!productData.sku) {
      productData.sku = generateSKU(productData.category, productData.name);
    }

    productData.slug = slugify(productData.name, { lower: true, strict: true });

    if (req.files && req.files.length > 0) {
      const uploaded = await uploadFilesToStorage(req.files, 'products');
      productData.images = uploaded.map((img, index) => ({
        url: img.url,
        publicId: img.publicId,
        isPrimary: index === 0,
        order: index,
      }));
    }

    if (productData.labelIds !== undefined) {
      productData.labelIds = await normalizeProductLabelIds(productData.labelIds);
    }

    delete productData.nameHindiSource;
    const hindiDecision = resolveHindiNameOnSave({ incomingHindi: productData.nameHindi, nameChanged: true });
    Object.assign(productData, hindiDecision.set);

    const product = await Product.create(productData);
    if (hindiDecision.generate) scheduleHindiNameFill(Product, product._id);
    if (product.category) {
      await updateProductCount(product.category, product.company);
    }

    res.status(201).json({
      success: true,
      message: 'Product created successfully',
      data: product,
    });
  } catch (error) {
    next(error);
  }
};

exports.updateProduct = async (req, res, next) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) {
      throw new NotFoundError('Product not found', 'PRODUCT_NOT_FOUND');
    }

    const previousCategory = product.category;
    const previousCompany = product.company;
    const updateData = await applyCategoryBrand(prepareProductData(req.body), product);
    const priceChangeMode = req.body.priceChangeMode || PRICE_CHANGE_MODE_SCHEDULED;
    const requestedRetailPrice = updateData.retailPrice;
    const requestedWholesalePrice = updateData.wholesalePrice;
    const hasRetailChange = requestedRetailPrice !== undefined && Number(requestedRetailPrice) !== Number(product.retailPrice);
    const hasWholesaleChange = requestedWholesalePrice !== undefined && Number(requestedWholesalePrice) !== Number(product.wholesalePrice);
    delete updateData.priceChangeMode;
    delete updateData.retailPrice;
    delete updateData.wholesalePrice;

    if (updateData.name && updateData.name !== product.name) {
      updateData.slug = slugify(updateData.name, { lower: true, strict: true });
    }

    if (req.files && req.files.length > 0) {
      const uploaded = await uploadFilesToStorage(req.files, 'products');
      const newImages = uploaded.map((img, index) => ({
        url: img.url,
        publicId: img.publicId,
        isPrimary: false,
        order: product.images.length + index,
      }));
      updateData.images = [...product.images, ...newImages];
    }

    if (updateData.labelIds !== undefined) {
      updateData.labelIds = await normalizeProductLabelIds(updateData.labelIds);
    }

    let priceChangeResult = null;
    if (hasRetailChange || hasWholesaleChange) {
      const { applyProductPriceChange } = require('../../services/productPriceChangeService');
      priceChangeResult = await applyProductPriceChange({
        product,
        performedBy: req.user,
        retailPrice: hasRetailChange ? requestedRetailPrice : undefined,
        wholesalePrice: hasWholesaleChange ? requestedWholesalePrice : undefined,
        mode: priceChangeMode,
      });
    }

    delete updateData.nameHindiSource;
    const hindiDecision = resolveHindiNameOnSave({
      incomingHindi: updateData.nameHindi,
      storedHindi: product.nameHindi,
      storedSource: product.nameHindiSource,
      nameChanged: Boolean(updateData.name && updateData.name !== product.name),
    });
    delete updateData.nameHindi;
    Object.assign(updateData, hindiDecision.set);

    updateData.variants = [];
    Object.assign(product, updateData);
    await product.save();
    if (hindiDecision.generate) scheduleHindiNameFill(Product, product._id);

    if (priceChangeResult?.isScheduled) {
      await registerPriceChangeCampaign();
    }

    await Promise.all(
      [
        [previousCategory, previousCompany],
        [product.category, product.company],
      ]
        .filter(([categorySlug]) => Boolean(categorySlug))
        .map(([categorySlug, companyId]) => updateProductCount(categorySlug, companyId))
    );

    res.json({
      success: true,
      message: 'Product updated successfully',
      data: product,
    });
  } catch (error) {
    next(error);
  }
};

exports.deleteProduct = async (req, res, next) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) {
      throw new NotFoundError('Product not found', 'PRODUCT_NOT_FOUND');
    }

    const previousCategory = product.category;
    product.status = 'archived';
    await product.save();
    if (previousCategory) {
      await updateProductCount(previousCategory, product.company);
    }

    res.json({
      success: true,
      message: 'Product archived successfully',
    });
  } catch (error) {
    next(error);
  }
};

exports.updateStock = async (req, res, next) => {
  try {
    const { stock, adjustment, reason } = req.body;

    const product = await Product.findById(req.params.id);
    if (!product) {
      throw new NotFoundError('Product not found', 'PRODUCT_NOT_FOUND');
    }

    const previousStock = product.stock;
    let newStock;
    let action;
    let quantityChange;

    if (stock !== undefined) {
      // Absolute set
      newStock = Math.max(0, parseInt(stock));
      quantityChange = newStock - previousStock;
      action = 'manual_set';
    } else if (adjustment) {
      // Relative adjustment (+N or -N)
      const adjustmentValue = parseInt(adjustment);
      newStock = previousStock + adjustmentValue;
      if (newStock < 0) {
        throw new BadRequestError(
          `Cannot reduce stock below 0. Current: ${previousStock}, Adjustment: ${adjustmentValue}`,
          'STOCK_BELOW_ZERO'
        );
      }
      quantityChange = adjustmentValue;
      action = 'manual_adjust';
    } else {
      throw new BadRequestError('Provide stock or adjustment', 'MISSING_STOCK_PARAM');
    }

    // Atomic update with guard for adjustments
    if (action === 'manual_adjust' && quantityChange < 0) {
      const result = await Product.findOneAndUpdate(
        { _id: req.params.id, stock: { $gte: Math.abs(quantityChange) } },
        { $inc: { stock: quantityChange } },
        { new: true }
      );
      if (!result) {
        throw new BadRequestError(
          'Stock changed concurrently. Please refresh and retry.',
          'STOCK_RACE_CONDITION'
        );
      }
      newStock = result.stock;
    } else {
      if (action === 'manual_set') {
        product.stock = newStock;
      } else {
        product.stock = previousStock + quantityChange;
        newStock = product.stock;
      }
      await product.save();
    }

    await StockLog.create({
      productId: product._id,
      action,
      quantityChange,
      previousStock,
      newStock,
      reason: reason || `Manual ${action === 'manual_set' ? 'set to ' + newStock : 'adjustment ' + (quantityChange > 0 ? '+' : '') + quantityChange}`,
      performedBy: req.user._id,
    });

    res.json({
      success: true,
      message: 'Stock updated successfully',
      data: {
        productId: product._id,
        previousStock,
        newStock,
        change: quantityChange,
        reason,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.getStockLogs = async (req, res, next) => {
  try {
    const { page, limit, skip } = paginate(req.query.page, req.query.limit);

    const query = { productId: req.params.id };

    const [logs, total] = await Promise.all([
      StockLog.find(query)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate('performedBy', 'name')
        .populate('orderId', 'orderNumber')
        .lean(),
      StockLog.countDocuments(query),
    ]);

    res.json({
      success: true,
      ...formatPaginationResponse(logs, total, page, limit),
    });
  } catch (error) {
    next(error);
  }
};

exports.deleteProductImage = async (req, res, next) => {
  try {
    const { id, imageId } = req.params;

    const product = await Product.findById(id);
    if (!product) {
      throw new NotFoundError('Product not found', 'PRODUCT_NOT_FOUND');
    }

    const imageIndex = product.images.findIndex(
      img => img._id.toString() === imageId || img.publicId === imageId
    );

    if (imageIndex === -1) {
      throw new NotFoundError('Image not found', 'IMAGE_NOT_FOUND');
    }

    const image = product.images[imageIndex];
    await deleteImage(image.publicId);

    product.images.splice(imageIndex, 1);

    if (image.isPrimary && product.images.length > 0) {
      product.images[0].isPrimary = true;
    }

    await product.save();

    res.json({
      success: true,
      message: 'Image deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

exports.generateMissingHindiNames = async (req, res, next) => {
  try {
    const requestedBatchSize = Number(req.body?.batchSize ?? req.query.batchSize ?? 0);
    const limit = Number.isFinite(requestedBatchSize) && requestedBatchSize > 0
      ? Math.min(requestedBatchSize, 5000)
      : 0;
    // 'missing' fills empty Hindi names; 'repair' also regenerates broken ones.
    const mode = (req.body?.mode || req.query.mode) === 'repair' ? 'repair' : 'missing';
    const stats = await fillHindiNames(Product, {
      mode,
      limit,
      extraFilter: { status: { $ne: PRODUCT_STATUS.ARCHIVED } },
    });

    res.json({
      success: true,
      message: stats.processed === 0
        ? 'No products require Hindi name conversion'
        : `Hindi name conversion completed. Updated ${stats.updated} products.`,
      data: {
        processed: stats.processed,
        updated: stats.updated,
        skipped: stats.skipped,
        failed: stats.failed,
        failedProducts: stats.failedItems.slice(0, 50),
      },
    });
  } catch (error) {
    next(error);
  }
};

// Suggests a Hindi name for the admin form (admin reviews before saving).
exports.suggestHindiName = async (req, res, next) => {
  try {
    const text = String(req.body?.text || '').trim().slice(0, 200);
    if (!text) throw new BadRequestError('Text is required', 'TEXT_REQUIRED');
    const suggestion = await generateHindiName(text);
    if (!suggestion) {
      return res.status(503).json({
        success: false,
        message: 'Hindi suggestion is unavailable right now. Please try again.',
        code: 'HINDI_SUGGESTION_UNAVAILABLE',
      });
    }
    res.json({ success: true, data: { text, suggestion } });
  } catch (error) {
    next(error);
  }
};

exports.changeProductPrice = async (req, res, next) => {
  try {
    const product = await Product.findById(req.params.id);
    if (!product) {
      throw new NotFoundError('Product not found', 'PRODUCT_NOT_FOUND');
    }

    const { applyProductPriceChange } = require('../../services/productPriceChangeService');
    const { registerPriceChangeCampaign } = require('../../services/productPriceSchedulerService');
    const result = await applyProductPriceChange({
      product,
      performedBy: req.user,
      retailPrice: req.body.retailPrice,
      wholesalePrice: req.body.wholesalePrice,
      mode: req.body.priceChangeMode,
      customEffectiveAt: req.body.effectiveAt,
    });

    if (result.isScheduled) {
      await registerPriceChangeCampaign();
    }

    res.json({
      success: true,
      message: result.isScheduled ? 'Price change scheduled successfully' : 'Price updated successfully',
      data: {
        product: result.product.toObject(),
        audit: result.audit.toObject(),
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Return permanent, admin-facing price-change audit history. Pending rows stay
 * available from /price-changes; this endpoint is intentionally history-only.
 */
exports.getPriceChangeHistory = async (req, res, next) => {
  try {
    const { PriceChangeAudit } = require('../../models');
    const { page, limit, skip } = paginate(req.query.page, req.query.limit);
    const search = String(req.query.search || '').trim();
    const status = String(req.query.status || '').trim();
    const query = {};

    if (status) {
      query.status = status;
    }

    if (search) {
      query.$or = [
        { productName: { $regex: search, $options: 'i' } },
        { productSku: { $regex: search, $options: 'i' } },
        { category: { $regex: search, $options: 'i' } },
      ];
    }

    const [audits, total] = await Promise.all([
      PriceChangeAudit.find(query)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate('performedBy', 'name email')
        .lean(),
      PriceChangeAudit.countDocuments(query),
    ]);

    const rows = audits.map((audit) => ({
      id: String(audit._id),
      productId: String(audit.product),
      productName: audit.productName,
      productSku: audit.productSku,
      category: audit.category,
      oldRetailPrice: audit.previousRetailPrice,
      newRetailPrice: audit.newRetailPrice,
      oldWholesalePrice: audit.previousWholesalePrice,
      newWholesalePrice: audit.newWholesalePrice,
      scheduleType: audit.scheduleType,
      status: audit.status,
      scheduledAt: audit.scheduledAt,
      effectiveAt: audit.effectiveAt,
      appliedAt: audit.appliedAt,
      supersededAt: audit.supersededAt,
      performedBy: audit.performedBy?.name || audit.performedByName || 'Admin',
    }));

    res.json({
      success: true,
      ...formatPaginationResponse(rows, total, page, limit),
    });
  } catch (error) {
    next(error);
  }
};
