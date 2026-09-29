const { Company, Product, Category } = require('../models');
const { NotFoundError, ConflictError } = require('../utils/errors');
const { paginate, formatPaginationResponse } = require('../utils/helpers');
const { PRODUCT_STATUS } = require('../utils/constants');
const { recordAudit } = require('../services/auditService');
const {
  pickDiscountUpdates,
  discountSnapshot,
  discountChanged,
  presentDiscountFields,
} = require('../utils/productDiscount');

// Discount percentages are dealer-margin information: only admins see them.
const presentCompany = (req, company) => presentDiscountFields(req, company);

const auditDiscountChange = async (req, company, before) => {
  const after = discountSnapshot(company);
  if (!discountChanged(before, after)) return;
  await recordAudit({
    actorId: req.user?._id,
    action: 'brand.discount_updated',
    entityType: 'Company',
    entityId: company._id,
    metadata: { name: company.name, before, after },
  });
};

exports.getAllCompanies = async (req, res, next) => {
  try {
    const { active, search } = req.query;
    const { page, limit, skip } = paginate(req.query.page, req.query.limit, 500);

    const query = {};
    if (active !== undefined) {
      query.isActive = active === 'true';
    }
    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
      ];
    }

    const [companies, total] = await Promise.all([
      Company.find(query).sort({ order: 1, name: 1 }).skip(skip).limit(limit).lean(),
      Company.countDocuments(query),
    ]);

    res.json({
      success: true,
      ...formatPaginationResponse(presentCompany(req, companies), total, page, limit),
    });
  } catch (error) {
    next(error);
  }
};

exports.getCompanyById = async (req, res, next) => {
  try {
    const company = await Company.findById(req.params.id);
    
    if (!company) {
      throw new NotFoundError('Company not found', 'COMPANY_NOT_FOUND');
    }

    res.json({
      success: true,
      data: presentCompany(req, company),
    });
  } catch (error) {
    next(error);
  }
};

exports.createCompany = async (req, res, next) => {
  try {
    const { name, description, website, logo, order } = req.body;
    const discountUpdates = pickDiscountUpdates(req.body);

    const existingCompany = await Company.findOne({ 
      name: { $regex: new RegExp(`^${name}$`, 'i') } 
    });
    
    if (existingCompany) {
      throw new ConflictError('Company with this name already exists', 'COMPANY_EXISTS');
    }

    const lastCompany = order === undefined
      ? await Company.findOne().sort({ order: -1 }).select('order').lean()
      : null;
    const company = await Company.create({
      name,
      description,
      website,
      logo,
      order: order ?? ((lastCompany?.order || 0) + 1),
      ...discountUpdates,
    });
    await auditDiscountChange(req, company, discountSnapshot({}));

    res.status(201).json({
      success: true,
      message: 'Company created successfully',
      data: company,
    });
  } catch (error) {
    next(error);
  }
};

exports.updateCompany = async (req, res, next) => {
  try {
    const { name, description, website, logo, isActive, order } = req.body;
    const discountUpdates = pickDiscountUpdates(req.body);

    const company = await Company.findById(req.params.id);
    
    if (!company) {
      throw new NotFoundError('Company not found', 'COMPANY_NOT_FOUND');
    }

    if (name && name !== company.name) {
      const existingCompany = await Company.findOne({ 
        name: { $regex: new RegExp(`^${name}$`, 'i') },
        _id: { $ne: company._id }
      });
      
      if (existingCompany) {
        throw new ConflictError('Company with this name already exists', 'COMPANY_EXISTS');
      }
      company.name = name;
    }

    if (description !== undefined) company.description = description;
    if (website !== undefined) company.website = website;
    if (logo !== undefined) company.logo = logo;
    if (isActive !== undefined) company.isActive = isActive;
    if (order !== undefined) company.order = order;
    const discountBefore = discountSnapshot(company);
    Object.assign(company, discountUpdates);

    await company.save();
    await auditDiscountChange(req, company, discountBefore);

    res.json({
      success: true,
      message: 'Company updated successfully',
      data: company,
    });
  } catch (error) {
    next(error);
  }
};

exports.deleteCompany = async (req, res, next) => {
  try {
    const company = await Company.findById(req.params.id);
    
    if (!company) {
      throw new NotFoundError('Company not found', 'COMPANY_NOT_FOUND');
    }

    // Check if any products are linked to this company
    const productCount = await Product.countDocuments({
      company: company._id,
      status: { $ne: PRODUCT_STATUS.ARCHIVED },
    });
    if (productCount > 0) {
      throw new ConflictError(
        `Cannot delete company. ${productCount} product(s) are linked to it.`,
        'COMPANY_HAS_PRODUCTS'
      );
    }

    const categoryCount = await Category.countDocuments({ company: company._id });
    if (categoryCount > 0) {
      throw new ConflictError(
        `Cannot delete brand. ${categoryCount} categor${categoryCount === 1 ? 'y is' : 'ies are'} linked to it.`,
        'COMPANY_HAS_CATEGORIES'
      );
    }

    await company.deleteOne();

    res.json({
      success: true,
      message: 'Company deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

exports.reorderCompanies = async (req, res, next) => {
  try {
    const { updates } = req.body;
    const companyIds = updates.map((update) => update.companyId);
    const [existingCount, totalCount] = await Promise.all([
      Company.countDocuments({ _id: { $in: companyIds } }),
      Company.countDocuments(),
    ]);

    if (existingCount !== companyIds.length) {
      return res.status(400).json({
        success: false,
        message: 'One or more brands no longer exist',
      });
    }
    if (companyIds.length !== totalCount) {
      return res.status(400).json({
        success: false,
        message: 'Reload all brands before rearranging them',
      });
    }

    const result = await Company.bulkWrite(
      updates.map((update) => ({
        updateOne: {
          filter: { _id: update.companyId },
          update: { $set: { order: update.order } },
        },
      })),
      { ordered: false },
    );
    const companies = await Company.find({ _id: { $in: companyIds } })
      .sort({ order: 1, name: 1 })
      .lean();

    res.json({
      success: true,
      message: 'Brands reordered successfully',
      data: {
        updated: result.modifiedCount,
        matched: result.matchedCount,
        companies,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.getCompanyProducts = async (req, res, next) => {
  try {
    const company = await Company.findById(req.params.id);
    
    if (!company) {
      throw new NotFoundError('Company not found', 'COMPANY_NOT_FOUND');
    }

    const products = await Product.find({ company: company._id })
      .select('name slug retailPrice images status')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      data: {
        company: presentCompany(req, company),
        products,
      },
    });
  } catch (error) {
    next(error);
  }
};
