const Category = require('../models/Category');
const Product = require('../models/Product');
const Company = require('../models/Company');
const { fillHindiNames, scheduleHindiNameFill } = require('../services/hindiNameService');
const { resolveHindiNameOnSave } = require('../utils/hindiNames');
const { paginate, formatPaginationResponse } = require('../utils/helpers');
const { PRODUCT_STATUS } = require('../utils/constants');

const { normalizeImageObject } = require('../utils/mediaUrls');
const { recordAudit } = require('../services/auditService');
const {
  pickDiscountUpdates,
  discountSnapshot,
  discountChanged,
  presentDiscountFields,
} = require('../utils/productDiscount');
const {
  applyCategoryAccessToProductQuery,
  filterCategoriesForUser,
} = require('../utils/categoryAccess');

// Discount percentages are dealer-margin information: only admins see them.
const presentCategory = (req, category) => presentDiscountFields(req, category);

async function auditCategoryDiscountChange(req, category, before) {
  const after = discountSnapshot(category);
  if (!discountChanged(before, after)) return;
  await recordAudit({
    actorId: req.user?._id,
    action: 'category.discount_updated',
    entityType: 'Category',
    entityId: category._id,
    metadata: { name: category.name, parent: category.parent?._id || category.parent || null, before, after },
  });
}

async function getDescendantCategoryIds(rootId) {
  const descendantIds = [];
  const visitedIds = new Set([String(rootId)]);
  let parentIds = [rootId];

  while (parentIds.length > 0) {
    const children = await Category.find({ parent: { $in: parentIds } })
      .select('_id')
      .lean();
    parentIds = children
      .map((child) => child._id)
      .filter((id) => {
        const key = String(id);
        if (visitedIds.has(key)) return false;
        visitedIds.add(key);
        return true;
      });
    descendantIds.push(...parentIds);
  }

  return descendantIds;
}

async function getProductCountMap(categories = [], user = null, activeOnly = false) {
  if (categories.length === 0) return new Map();

  const categoryIds = categories.map((category) => category._id).filter(Boolean);
  const categoryNames = [...new Set(categories.flatMap((category) => [
    category.name,
    category.slug,
  ]).filter(Boolean))];
  const companyIds = categories
    .map((category) => category.company?._id || category.company)
    .filter(Boolean);
  const categoryById = new Map(
    categories.map((category) => [String(category._id), category]),
  );
  const countsByCategoryId = new Map(
    categories.map((category) => [String(category._id), 0]),
  );

  const filters = [{ categoryRef: { $in: categoryIds } }];
  if (categoryNames.length > 0 && companyIds.length > 0) {
    // Keep showing products that have not yet been migrated to categoryRef.
    filters.push({
      $or: [{ categoryRef: null }, { categoryRef: { $exists: false } }],
      company: { $in: companyIds },
      category: { $in: categoryNames },
    });
  }

  const match = applyCategoryAccessToProductQuery({
    status: activeOnly ? PRODUCT_STATUS.ACTIVE : { $ne: PRODUCT_STATUS.ARCHIVED },
    $or: filters,
  }, user);
  const products = await Product.find(match)
    .select('categoryRef category company')
    .lean();

  products.forEach((product) => {
    const referencedCategoryId = String(product.categoryRef || '');
    if (categoryById.has(referencedCategoryId)) {
      countsByCategoryId.set(
        referencedCategoryId,
        (countsByCategoryId.get(referencedCategoryId) || 0) + 1,
      );
      return;
    }

    const legacyCategory = categories.find((category) => {
      const companyId = String(category.company?._id || category.company || '');
      return (
        companyId === String(product.company || '') &&
        [category.name, category.slug].filter(Boolean).includes(product.category)
      );
    });

    if (legacyCategory) {
      const categoryId = String(legacyCategory._id);
      countsByCategoryId.set(
        categoryId,
        (countsByCategoryId.get(categoryId) || 0) + 1,
      );
    }
  });

  return countsByCategoryId;
}

async function resolveCompanyId(value) {
  const raw = String(value || '').trim();
  if (!raw) return null;

  const query = raw.match(/^[0-9a-fA-F]{24}$/)
    ? { _id: raw }
    : { $or: [{ slug: raw }, { name: { $regex: new RegExp(`^${raw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') } }] };

  const company = await Company.findOne(query).select('_id');
  return company?._id || null;
}

// @desc    Get all categories
// @route   GET /api/v1/categories
// @access  Public
exports.getCategories = async (req, res, next) => {
  try {
    const { parent, active, search, company, brand } = req.query;
    // Management UIs fetch the whole tree at once; docs are small.
    const { page, limit, skip } = paginate(req.query.page, req.query.limit, 500);

    const query = {};

    // Filter by parent (null for root categories)
    if (parent === 'root') {
      query.parent = null;
    } else if (parent) {
      query.parent = parent;
    }

    // Filter by active status
    if (active !== undefined) {
      query.isActive = active === 'true';
    }

    // Search by name
    if (search) {
      query.name = { $regex: String(search).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), $options: 'i' };
    }

    const companyFilter = await resolveCompanyId(company || brand);
    if (company || brand) {
      if (!companyFilter) {
        return res.json({
          success: true,
          ...formatPaginationResponse([], 0, page, limit),
        });
      }
      query.company = companyFilter;
    }

    const [categories, total] = await Promise.all([
      Category.find(query)
        .populate('parent', 'name nameHindi slug')
        .populate('company', 'name slug logo')
        .sort({ order: 1, name: 1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      Category.countDocuments(query),
    ]);

    const visibleCategories = filterCategoriesForUser(categories, req.user);
    const countsByCategory = await getProductCountMap(
      visibleCategories,
      req.user,
      active === 'true',
    );
    const categoriesWithCounts = presentCategory(req, visibleCategories.map((category) => ({
      ...category,
      image: normalizeImageObject(category.image, req),
      productCount: countsByCategory.get(String(category._id)) ?? 0,
    })));

    res.json({
      success: true,
      ...formatPaginationResponse(categoriesWithCounts, total, page, limit),
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get single category
// @route   GET /api/v1/categories/:id
// @access  Public
exports.getCategory = async (req, res, next) => {
  try {
    const category = await Category.findById(req.params.id)
      .populate('parent', 'name nameHindi slug')
      .populate('company', 'name slug logo')
      .populate('subcategories');

    if (!category) {
      return res.status(404).json({
        success: false,
        message: 'Category not found',
      });
    }

    const categoryData = category.toObject();
    categoryData.image = normalizeImageObject(categoryData.image, req);
    categoryData.productCount = await Product.countDocuments({
      status: { $ne: PRODUCT_STATUS.ARCHIVED },
      $or: [
        { categoryRef: category._id },
        {
          category: { $in: [category.name, category.slug].filter(Boolean) },
          company: category.company,
        },
      ],
    });

    res.json({
      success: true,
      data: presentCategory(req, categoryData),
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Create category
// @route   POST /api/v1/categories
// @access  Private/Admin
exports.createCategory = async (req, res, next) => {
  try {
    const { name, nameHindi, description, image, parent, order, isActive, company } = req.body;
    const discountUpdates = pickDiscountUpdates(req.body);

    const companyId = await resolveCompanyId(company);
    if (!companyId) {
      return res.status(400).json({
        success: false,
        message: 'Brand is required for category',
      });
    }

    // Check if category with same name exists under the same parent
    // category inside this brand (siblings only — HP names like "3 HP"
    // repeat across categories by design).
    const existingCategory = await Category.findOne({ 
      company: companyId,
      parent: parent || null,
      name: { $regex: new RegExp(`^${name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') } 
    });
    
    if (existingCategory) {
      return res.status(400).json({
        success: false,
        message: 'Category with this name already exists under the same parent category',
      });
    }

    // If parent is specified, verify it exists
    if (parent) {
      const parentCategory = await Category.findById(parent).select('company');
      if (!parentCategory) {
        return res.status(400).json({
          success: false,
          message: 'Parent category not found',
        });
      }
      if (String(parentCategory.company) !== String(companyId)) {
        return res.status(400).json({
          success: false,
          message: 'Parent category must belong to the same brand',
        });
      }
    }

    const hindiDecision = resolveHindiNameOnSave({ incomingHindi: nameHindi, nameChanged: true });
    const category = await Category.create({
      name,
      company: companyId,
      nameHindi: '',
      ...hindiDecision.set,
      description,
      image,
      parent: parent || null,
      order: order || 0,
      isActive: isActive !== undefined ? isActive : true,
      ...discountUpdates,
    });
    await auditCategoryDiscountChange(req, category, discountSnapshot({}));
    if (hindiDecision.generate) scheduleHindiNameFill(Category, category._id);

    res.status(201).json({
      success: true,
      data: category,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Update category
// @route   PUT /api/v1/categories/:id
// @access  Private/Admin
exports.updateCategory = async (req, res, next) => {
  try {
    const { name, nameHindi, description, image, parent, order, isActive, company } = req.body;
    const discountUpdates = pickDiscountUpdates(req.body);

    let category = await Category.findById(req.params.id);

    if (!category) {
      return res.status(404).json({
        success: false,
        message: 'Category not found',
      });
    }

    const discountBefore = discountSnapshot(category);
    const previousCategoryName = category.name;
    const previousCategorySlug = category.slug;
    const previousCompanyId = category.company;
    const nextCompanyId = company !== undefined
      ? await resolveCompanyId(company)
      : category.company;

    if (!nextCompanyId) {
      return res.status(400).json({
        success: false,
        message: 'Brand is required for category',
      });
    }
    const companyChanged = String(nextCompanyId) !== String(previousCompanyId);

    // Check for duplicate name under the same parent category
    // (excluding current category). Siblings only — HP names like "3 HP"
    // repeat across categories by design.
    if ((name && name !== category.name) || String(nextCompanyId) !== String(category.company)) {
      const effectiveParent = parent !== undefined ? (parent || null) : category.parent;
      const existingCategory = await Category.findOne({ 
        company: nextCompanyId,
        parent: effectiveParent,
        name: { $regex: new RegExp(`^${(name || category.name).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') },
        _id: { $ne: req.params.id }
      });
      
      if (existingCategory) {
        return res.status(400).json({
          success: false,
          message: 'Category with this name already exists under the same parent category',
        });
      }
    }

    // Prevent category from being its own parent
    if (parent && parent === req.params.id) {
      return res.status(400).json({
        success: false,
        message: 'Category cannot be its own parent',
      });
    }

    // A category and its parent must always remain in the same brand.
    const effectiveParentId = parent !== undefined ? (parent || null) : category.parent;
    if (effectiveParentId) {
      const parentCategory = await Category.findById(effectiveParentId).select('company');
      if (!parentCategory) {
        return res.status(400).json({
          success: false,
          message: 'Parent category not found',
        });
      }
      if (String(parentCategory.company) !== String(nextCompanyId)) {
        return res.status(400).json({
          success: false,
          message: 'Parent category must belong to the same brand',
        });
      }
    }

    const descendantCategoryIds = companyChanged
      ? await getDescendantCategoryIds(category._id)
      : [];

    const hindiDecision = resolveHindiNameOnSave({
      incomingHindi: nameHindi,
      storedHindi: category.nameHindi,
      storedSource: category.nameHindiSource,
      nameChanged: Boolean(name && name !== category.name),
    });

    category = await Category.findByIdAndUpdate(
      req.params.id,
      {
        name: name || category.name,
        company: nextCompanyId,
        ...hindiDecision.set,
        description: description !== undefined ? description : category.description,
        image: image !== undefined ? image : category.image,
        parent: parent !== undefined ? (parent || null) : category.parent,
        order: order !== undefined ? order : category.order,
        isActive: isActive !== undefined ? isActive : category.isActive,
        ...discountUpdates,
      },
      { new: true, runValidators: true }
    ).populate('parent', 'name nameHindi slug').populate('company', 'name slug logo');
    await auditCategoryDiscountChange(req, category, discountBefore);
    if (hindiDecision.generate) scheduleHindiNameFill(Category, category._id);

    const canonicalCategoryValue = category.slug || category.name;
    const legacyCategoryValues = [previousCategoryName, previousCategorySlug]
      .filter(Boolean);
    const productAssociationFilters = [{ categoryRef: category._id }];

    if (legacyCategoryValues.length > 0) {
      productAssociationFilters.push({
        categoryRef: null,
        company: previousCompanyId,
        category: { $in: legacyCategoryValues },
      });
    }

    // A category rename must never orphan products. Existing ID-linked products
    // stay linked, while legacy name-linked products are upgraded to categoryRef.
    await Product.updateMany(
      { $or: productAssociationFilters },
      {
        $set: {
          categoryRef: category._id,
          category: canonicalCategoryValue,
          company: category.company?._id || category.company,
        },
      },
    );

    if (descendantCategoryIds.length > 0) {
      await Promise.all([
        Category.updateMany(
          { _id: { $in: descendantCategoryIds } },
          { $set: { company: nextCompanyId } },
        ),
        Product.updateMany(
          { categoryRef: { $in: descendantCategoryIds } },
          { $set: { company: nextCompanyId } },
        ),
      ]);
    }

    res.json({
      success: true,
      data: category,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Delete category
// @route   DELETE /api/v1/categories/:id
// @access  Private/Admin
exports.deleteCategory = async (req, res, next) => {
  try {
    const category = await Category.findById(req.params.id);

    if (!category) {
      return res.status(404).json({
        success: false,
        message: 'Category not found',
      });
    }

    // Check if category has subcategories
    const subcategories = await Category.countDocuments({ parent: req.params.id });
    if (subcategories > 0) {
      return res.status(400).json({
        success: false,
        message: 'Cannot delete category with subcategories. Delete subcategories first.',
      });
    }

    // Check if category has products
    const products = await Product.countDocuments({
      category: { $in: [category.name, category.slug].filter(Boolean) },
      company: category.company,
      status: { $ne: PRODUCT_STATUS.ARCHIVED },
    });
    if (products > 0) {
      return res.status(400).json({
        success: false,
        message: `Cannot delete category with ${products} product(s). Reassign products first.`,
      });
    }

    await category.deleteOne();

    res.json({
      success: true,
      message: 'Category deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Update product count for category
// @route   Internal use
exports.updateProductCount = async (categorySlug, companyId = null) => {
  try {
    const query = { 
      category: categorySlug,
      status: { $ne: PRODUCT_STATUS.ARCHIVED }
    };
    if (companyId) query.company = companyId;
    const count = await Product.countDocuments(query);
    
    const categoryQuery = { slug: categorySlug };
    if (companyId) categoryQuery.company = companyId;
    await Category.findOneAndUpdate(
      categoryQuery,
      { productCount: count }
    );
  } catch (error) {
    console.error('Error updating category product count:', error);
  }
};

// @desc    Generate missing Hindi names for categories
// @route   POST /api/v1/categories/hindi-names/generate-missing
// @access  Private/Admin
exports.generateMissingHindiNames = async (req, res, next) => {
  try {
    const requestedBatchSize = Number(req.body?.batchSize ?? req.query.batchSize ?? 0);
    const limit = Number.isFinite(requestedBatchSize) && requestedBatchSize > 0
      ? Math.min(requestedBatchSize, 5000)
      : 0;
    // 'missing' fills empty Hindi names; 'repair' also regenerates broken ones.
    const mode = (req.body?.mode || req.query.mode) === 'repair' ? 'repair' : 'missing';
    const stats = await fillHindiNames(Category, { mode, limit });

    res.json({
      success: true,
      message: stats.processed === 0
        ? 'No categories require Hindi name conversion'
        : `Hindi name conversion completed. Updated ${stats.updated} categories.`,
      data: {
        processed: stats.processed,
        updated: stats.updated,
        skipped: stats.skipped,
        failed: stats.failed,
        failedCategories: stats.failedItems.slice(0, 50),
      },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Reorder categories with new sequential order numbers
// @route   POST /api/v1/categories/reorder
// @access  Private/Admin
exports.reorderCategories = async (req, res, next) => {
  try {
    const { updates } = req.body;

    // Validate input
    if (!Array.isArray(updates) || updates.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'updates array is required and must not be empty',
      });
    }

    // Validate each update has categoryId and order
    for (const update of updates) {
      if (!update.categoryId || typeof update.order !== 'number' || update.order < 1) {
        return res.status(400).json({
          success: false,
          message: 'Each update must have categoryId (string) and order (number >= 1)',
        });
      }
    }

    // Perform bulk updates
    const bulkOps = updates.map((update) => ({
      updateOne: {
        filter: { _id: update.categoryId },
        update: { $set: { order: update.order } },
      },
    }));

    const result = await Category.bulkWrite(bulkOps, { ordered: false });

    // Fetch updated categories
    const categoryIds = updates.map((u) => u.categoryId);
    const updatedCategories = await Category.find({
      _id: { $in: categoryIds },
    })
      .populate('parent', 'name nameHindi slug')
      .populate('company', 'name slug logo')
      .lean();

    const countsByCategory = await getProductCountMap(updatedCategories, req.user);
    const categoriesWithCounts = updatedCategories.map((category) => ({
      ...category,
      image: normalizeImageObject(category.image, req),
      productCount: countsByCategory.get(String(category._id)) ?? 0,
    }));

    res.json({
      success: true,
      message: 'Categories reordered successfully',
      data: {
        updated: result.modifiedCount,
        matched: result.matchedCount,
        categories: categoriesWithCounts,
      },
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get categories with nested subcategories (hierarchical)
// @route   GET /api/v1/categories/with-subcategories
// @access  Public
exports.getCategoriesWithSubcategories = async (req, res, next) => {
  try {
    const { company, brand, active } = req.query;

    // Query for root categories (parent is null, undefined, or doesn't exist)
    const query = { $or: [{ parent: null }, { parent: { $exists: false } }] };

    // Filter by active status
    if (active !== undefined) {
      query.isActive = active === 'true';
    }

    const companyFilter = await resolveCompanyId(company || brand);
    if (company || brand) {
      if (!companyFilter) {
        return res.json({
          success: true,
          data: [],
        });
      }
      query.company = companyFilter;
    }

    // Fetch root categories
    const rootCategories = await Category.find(query)
      .populate('company', 'name slug logo isActive')
      .sort({ order: 1, name: 1 })
      .lean();

    const catalogRootCategories = active === 'true'
      ? rootCategories.filter((category) => category.company?.isActive === true)
      : rootCategories;
    const visibleRootCategories = filterCategoriesForUser(catalogRootCategories, req.user);
    const rootCategoryIds = visibleRootCategories.map((c) => c._id);

    // Fetch all subcategories for these root categories
    const subcategoryQuery = { parent: { $in: rootCategoryIds } };
    if (active !== undefined) {
      subcategoryQuery.isActive = active === 'true';
    }

    const allSubcategories = await Category.find(subcategoryQuery)
      .sort({ order: 1, name: 1 })
      .lean();

    const visibleSubcategories = filterCategoriesForUser(allSubcategories, req.user);

    // Get product counts for all categories (root + subcategories)
    const allCategories = [...visibleRootCategories, ...visibleSubcategories];
    const countsByCategory = await getProductCountMap(
      allCategories,
      req.user,
      active === 'true',
    );

    // Build nested structure
    const subcategoriesByParent = new Map();
    visibleSubcategories.forEach((subcat) => {
      const parentId = String(subcat.parent);
      if (!subcategoriesByParent.has(parentId)) {
        subcategoriesByParent.set(parentId, []);
      }
      subcategoriesByParent.get(parentId).push({
        id: subcat._id,
        name: subcat.name,
        nameHindi: subcat.nameHindi,
        slug: subcat.slug,
        order: subcat.order,
        image: normalizeImageObject(subcat.image, req),
        productCount: countsByCategory.get(String(subcat._id)) ?? 0,
      });
    });

    // Format response with nested subcategories
    const categoriesWithNested = visibleRootCategories.map((category) => ({
      id: category._id,
      name: category.name,
      nameHindi: category.nameHindi,
      slug: category.slug,
      company: category.company
        ? {
            id: category.company._id,
            name: category.company.name,
            slug: category.company.slug,
            logo: normalizeImageObject(category.company.logo, req),
          }
        : null,
      order: category.order,
      image: normalizeImageObject(category.image, req),
      productCount: countsByCategory.get(String(category._id)) ?? 0,
      subcategories: subcategoriesByParent.get(String(category._id)) || [],
    }));

    res.json({
      success: true,
      data: categoriesWithNested,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Get subcategories of a parent category
// @route   GET /api/v1/categories/:parentId/subcategories
// @access  Public
exports.getSubcategories = async (req, res, next) => {
  try {
    const { parentId } = req.params;

    const parentCategory = await Category.findById(parentId).lean();
    if (!parentCategory) {
      return res.status(404).json({
        success: false,
        message: 'Parent category not found',
      });
    }

    const subcategories = await Category.find({ parent: parentId })
      .sort({ order: 1, name: 1 })
      .lean();

    const visibleSubcategories = filterCategoriesForUser(subcategories, req.user);
    const countsByCategory = await getProductCountMap(visibleSubcategories, req.user);

    const subcategoriesWithCounts = visibleSubcategories.map((subcat) => ({
      id: subcat._id,
      name: subcat.name,
      nameHindi: subcat.nameHindi,
      slug: subcat.slug,
      order: subcat.order,
      image: normalizeImageObject(subcat.image, req),
      productCount: countsByCategory.get(String(subcat._id)) ?? 0,
    }));

    res.json({
      success: true,
      data: subcategoriesWithCounts,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Reorder subcategories within a parent
// @route   POST /api/v1/categories/reorder-subcategories
// @access  Private/Admin
exports.reorderSubcategories = async (req, res, next) => {
  try {
    const { parentId, subcategoryIds } = req.body;

    if (!parentId) {
      return res.status(400).json({
        success: false,
        message: 'parentId is required',
      });
    }

    if (!Array.isArray(subcategoryIds) || subcategoryIds.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'subcategoryIds array is required and must not be empty',
      });
    }

    // Update order for each subcategory
    const bulkOps = subcategoryIds.map((subcatId, index) => ({
      updateOne: {
        filter: { _id: subcatId, parent: parentId },
        update: { $set: { order: index + 1 } },
      },
    }));

    const result = await Category.bulkWrite(bulkOps, { ordered: false });

    // Fetch updated subcategories
    const updatedSubcategories = await Category.find({ parent: parentId })
      .sort({ order: 1 })
      .lean();

    const countsByCategory = await getProductCountMap(updatedSubcategories, req.user);
    const formattedSubcategories = updatedSubcategories.map((subcat) => ({
      id: subcat._id,
      name: subcat.name,
      order: subcat.order,
      productCount: countsByCategory.get(String(subcat._id)) ?? 0,
    }));

    res.json({
      success: true,
      message: 'Subcategories reordered successfully',
      data: {
        updated: result.modifiedCount,
        subcategories: formattedSubcategories,
      },
    });
  } catch (error) {
    next(error);
  }
};
