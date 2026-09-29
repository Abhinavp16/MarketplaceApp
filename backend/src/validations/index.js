const Joi = require('joi');
const { isRegistrationPhoneValid } = require('../utils/phoneValidation');
const {
  TERMS_VERSION,
  PRIVACY_POLICY_VERSION,
} = require('../config/legalAcceptance');

// Accept any TLD (the demo uses reserved *.example addresses).
const emailRule = Joi.string().email({ tlds: { allow: false } });

const registrationPhoneRule = Joi.string()
  .pattern(/^[6-9]\d{9}$/)
  .custom((value, helpers) => (
    isRegistrationPhoneValid(value)
      ? value
      : helpers.error('string.registrationPhone')
  ))
  .messages({
    'string.pattern.base': 'Phone number must be a valid 10-digit Indian mobile number starting with 6, 7, 8, or 9.',
    'string.registrationPhone': 'Phone number cannot use repeated or sequential digits.',
  });

const discountRuleSchema = Joi.object({
  minPurchaseAmount: Joi.number().min(0).required(),
  discountType: Joi.string().valid('percentage', 'fixed').required(),
  discountValue: Joi.number().min(0).required(),
  maxDiscountAmount: Joi.number().min(0).allow('', null),
});

const storeUrlRule = Joi.string().trim().uri({ scheme: ['http', 'https'] });

const mobilePlatformSettingsSchema = () => Joi.object({
  enabled: Joi.boolean(),
  latestVersion: Joi.when('enabled', {
    is: true,
    then: Joi.string().trim().min(1).required(),
    otherwise: Joi.string().trim().allow(''),
  }),
  latestBuildNumber: Joi.when('enabled', {
    is: true,
    then: Joi.number().integer().positive().required(),
    otherwise: Joi.number().integer().min(0),
  }),
  storeUrl: Joi.when('enabled', {
    is: true,
    then: storeUrlRule.required(),
    otherwise: storeUrlRule,
  }),
  title: Joi.when('enabled', {
    is: true,
    then: Joi.string().trim().min(1).max(200).required(),
    otherwise: Joi.string().trim().allow('').max(200),
  }),
  message: Joi.when('enabled', {
    is: true,
    then: Joi.string().trim().min(1).max(1000).required(),
    otherwise: Joi.string().trim().allow('').max(1000),
  }),
}).unknown(false);

const mobilePlatformSettingsSchemas = {
  android: mobilePlatformSettingsSchema(),
  ios: mobilePlatformSettingsSchema(),
};

const legalAcceptanceSchema = {
  termsAccepted: Joi.boolean().valid(true).required(),
  privacyPolicyAccepted: Joi.boolean().valid(true).required(),
  termsVersion: Joi.string().valid(TERMS_VERSION).required(),
  privacyPolicyVersion: Joi.string().valid(PRIVACY_POLICY_VERSION).required(),
};

const authValidation = {
  register: Joi.object({
    name: Joi.string().required().max(100),
    email: emailRule.required(),
    password: Joi.string().min(8).required(),
    phone: registrationPhoneRule.required(),
    role: Joi.string().valid('buyer').default('buyer'),
    marketingConsent: Joi.boolean().default(false),
    ...legalAcceptanceSchema,
  }),

  registerWholesaler: Joi.object({
    name: Joi.string().required().max(100),
    email: emailRule.required(),
    password: Joi.string().min(8).required(),
    phone: registrationPhoneRule.required(),
    businessName: Joi.string().required().max(200),
    gstNumber: Joi.string().allow('', null),
    marketingConsent: Joi.boolean().default(false),
    ...legalAcceptanceSchema,
  }),

  login: Joi.object({
    email: emailRule.required(),
    password: Joi.string().required(),
  }),

  staffLogin: Joi.object({
    username: Joi.string().trim().lowercase().pattern(/^[a-z0-9._-]{3,32}$/).required(),
    password: Joi.string().required(),
  }),

  magicLinkVerify: Joi.object({
    token: Joi.string().required(),
  }),

  loginPhone: Joi.object({
    phone: Joi.string().required().min(10).max(15),
    password: Joi.string().required(),
    expectedRole: Joi.string().valid('buyer', 'wholesaler').optional(),
  }),

  registerPhone: Joi.object({
    name: Joi.string().required().max(100),
    phone: registrationPhoneRule.required(),
    password: Joi.string().min(6).required(),
    ...legalAcceptanceSchema,
  }),

  registerPhoneWholesaler: Joi.object({
    name: Joi.string().required().max(100),
    phone: registrationPhoneRule.required(),
    password: Joi.string().min(6).required(),
    businessName: Joi.string().allow('', null).max(200),
    ...legalAcceptanceSchema,
  }),

  refreshToken: Joi.object({
    refreshToken: Joi.string().required(),
  }),

  updatePreferences: Joi.object({
    language: Joi.string().valid('en', 'hi').required(),
  }),

  updateProfile: Joi.object({
    name: Joi.string().max(100),
    avatar: Joi.string().uri().allow('', null),
    phone: Joi.string().allow('', null),
    address: Joi.string().allow('', null).max(500),
  }),

  fcmToken: Joi.object({
    fcmToken: Joi.string().required(),
  }),
  convertWholesaler: Joi.object({
    businessName: Joi.string().required().max(200),
    gstNumber: Joi.string().allow('', null).max(15),
    businessAddress: Joi.string().required().max(500),
    contactPerson: Joi.string().required().max(100),
    phone: Joi.string().required(),
    shopLocationLat: Joi.number().required().min(-90).max(90),
    shopLocationLng: Joi.number().required().min(-180).max(180),
    shopLocationLabel: Joi.string().allow('', null).max(300),
  }),

  requestAccountDeletion: Joi.object({}),

  publicAccountDeletionRequest: Joi.object({
    name: Joi.string().trim().max(100).required(),
    phone: registrationPhoneRule.required(),
  }),
};

const productValidation = {
  list: Joi.object({
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(50).default(20),
    categoryId: Joi.string().hex().length(24).allow('', null),
    category: Joi.string().allow('', null),
    subcategory: Joi.string().allow('', null),
    brand: Joi.string().allow('', null),
    minPrice: Joi.number().min(0),
    maxPrice: Joi.number().min(0),
    inStock: Joi.boolean(),
    featured: Joi.boolean(),
    hot: Joi.boolean(),
    sort: Joi.string().valid('price', '-price', 'name', '-name', 'createdAt', '-createdAt'),
  }),

  search: Joi.object({
    q: Joi.string().trim().allow('', null),
    page: Joi.number().integer().min(1).default(1),
    limit: Joi.number().integer().min(1).max(50).default(20),
    categoryId: Joi.string().hex().length(24).allow('', null),
    brandId: Joi.string().hex().length(24).allow('', null),
    category: Joi.string().allow('', null),
    brand: Joi.string().allow('', null),
  }),
};

const cartValidation = {
  addItem: Joi.object({
    productId: Joi.string().required(),
    variantId: Joi.string().allow('', null),
    quantity: Joi.number().integer().min(1).default(1),
  }),

  updateItem: Joi.object({
    quantity: Joi.number().integer().min(1).required(),
  }),
};

const negotiationValidation = {
  create: Joi.object({
    productId: Joi.string().required(),
    variantId: Joi.string().allow('', null),
    quantity: Joi.number().integer().min(1).required(),
    pricePerUnit: Joi.number().min(0).required(),
    message: Joi.string().max(500).allow('', null),
  }),
};

const orderValidation = {
  shippingAddress: Joi.object({
    fullName: Joi.string().required().max(100),
    phone: Joi.string().required(),
    addressLine1: Joi.string().required().max(200),
    addressLine2: Joi.string().allow('', null).max(200),
    city: Joi.string().required().max(100),
    state: Joi.string().required().max(100),
    pincode: Joi.string().required().max(10),
  }),

  createFromCart: Joi.object({
    items: Joi.array().items(
      Joi.object({
        productId: Joi.string().required(),
        variantId: Joi.string().allow('', null),
        quantity: Joi.number().integer().min(1).required(),
      })
    ).min(1),
    shippingAddress: Joi.object({
      fullName: Joi.string().required().max(100),
      phone: Joi.string().required(),
      addressLine1: Joi.string().required().max(200),
      addressLine2: Joi.string().allow('', null).max(200),
      city: Joi.string().required().max(100),
      state: Joi.string().required().max(100),
      pincode: Joi.string().required().max(10),
    }).required(),
    customerNote: Joi.string().max(500).allow('', null),
    couponCode: Joi.string().trim().uppercase().allow('', null),
    affiliateCode: Joi.string().trim().uppercase().allow('', null),
  }),

  previewCoupon: Joi.object({
    couponCode: Joi.string().trim().uppercase().required(),
    subtotal: Joi.number().min(0),
  }),

  createFromNegotiation: Joi.object({
    negotiationId: Joi.string().required(),
    shippingAddress: Joi.object({
      fullName: Joi.string().required().max(100),
      phone: Joi.string().required(),
      addressLine1: Joi.string().required().max(200),
      addressLine2: Joi.string().allow('', null).max(200),
      city: Joi.string().required().max(100),
      state: Joi.string().required().max(100),
      pincode: Joi.string().required().max(10),
    }).required(),
    customerNote: Joi.string().max(500).allow('', null),
    couponCode: Joi.string().trim().uppercase().allow('', null),
    affiliateCode: Joi.string().trim().uppercase().allow('', null),
  }),
};

const adminValidation = {
  createProduct: Joi.object({
    name: Joi.string().required().max(200),
    nameHindi: Joi.string().allow('', null).max(200),
    description: Joi.string().required(),
    shortDescription: Joi.string().max(300),
    category: Joi.string().required(),
    categoryId: Joi.string().allow('', null),
    subCategory: Joi.string().allow('', null),
    tags: Joi.array().items(Joi.string()),
    // 3-Tier Pricing
    mrp: Joi.number().min(0).required(),
    retailPrice: Joi.number().min(0).required(),
    wholesalePrice: Joi.number().min(0).required(),
    minWholesaleQuantity: Joi.number().integer().min(1).default(10),
    negotiationEnabled: Joi.boolean().default(true),
    sku: Joi.string().required(),
    stock: Joi.number().integer().min(0).default(0),
    lowStockThreshold: Joi.number().integer().min(0).default(5),
    priceUnit: Joi.string().allow('', null),
    packing: Joi.string().allow('', null),
    variants: Joi.array().items(Joi.any()).default([]).strip(),
    images: Joi.array().items(Joi.object({
      url: Joi.string().required(),
      publicId: Joi.string().required(),
      isPrimary: Joi.boolean().default(false),
      order: Joi.number().default(0),
    })),
    specifications: Joi.array().items(Joi.object({
      key: Joi.string().required(),
      value: Joi.string().required(),
    })),
    status: Joi.string().valid('active', 'draft', 'archived').default('draft'),
    isFeatured: Joi.boolean().default(false),
    isHot: Joi.boolean().default(false),
    labelIds: Joi.array().items(Joi.string()),
    rating: Joi.number().min(0).max(5).default(4.5),
    purchaseCountMin: Joi.number().integer().min(0).default(0),
    purchaseCountMax: Joi.number().integer().min(0).default(0),
    company: Joi.string().allow('', null),
    videoUrl: Joi.string().allow('', null),
    shippingTerms: Joi.string().allow('', null),
    priceChangeMode: Joi.string().valid('schedule_24h', 'immediate').optional(),
  }),

  updateProduct: Joi.object({
    name: Joi.string().max(200),
    nameHindi: Joi.string().allow('', null).max(200),
    description: Joi.string(),
    shortDescription: Joi.string().max(300),
    category: Joi.string(),
    categoryId: Joi.string().allow('', null),
    subCategory: Joi.string().allow('', null),
    tags: Joi.array().items(Joi.string()),
    // 3-Tier Pricing
    mrp: Joi.number().min(0),
    retailPrice: Joi.number().min(0),
    wholesalePrice: Joi.number().min(0),
    minWholesaleQuantity: Joi.number().integer().min(1),
    negotiationEnabled: Joi.boolean(),
    stock: Joi.number().integer().min(0),
    lowStockThreshold: Joi.number().integer().min(0),
    priceUnit: Joi.string().allow('', null),
    packing: Joi.string().allow('', null),
    variants: Joi.array().items(Joi.any()).strip(),
    images: Joi.array().items(Joi.object({
      url: Joi.string().required(),
      publicId: Joi.string().required(),
      isPrimary: Joi.boolean().default(false),
      order: Joi.number().default(0),
    })),
    specifications: Joi.array().items(Joi.object({
      key: Joi.string().required(),
      value: Joi.string().required(),
    })),
    status: Joi.string().valid('active', 'draft', 'archived'),
    isFeatured: Joi.boolean(),
    isHot: Joi.boolean(),
    labelIds: Joi.array().items(Joi.string()),
    rating: Joi.number().min(0).max(5),
    purchaseCountMin: Joi.number().integer().min(0),
    purchaseCountMax: Joi.number().integer().min(0),
    company: Joi.string().allow('', null),
    videoUrl: Joi.string().allow('', null),
    shippingTerms: Joi.string().allow('', null),
    priceChangeMode: Joi.string().valid('schedule_24h', 'immediate').optional(),
  }),

  priceChange: Joi.object({
    retailPrice: Joi.number().min(0),
    wholesalePrice: Joi.number().min(0),
    priceChangeMode: Joi.string().valid('immediate', 'schedule_24h', 'schedule_48h', 'custom').required(),
    effectiveAt: Joi.date().iso().when('priceChangeMode', {
      is: 'custom',
      then: Joi.required(),
      otherwise: Joi.optional().allow(null),
    }),
  }).or('retailPrice', 'wholesalePrice'),

  updateStock: Joi.object({
    stock: Joi.number().integer().min(0),
    adjustment: Joi.string().pattern(/^[+-]\d+$/),
    reason: Joi.string().max(200),
  }).or('stock', 'adjustment'),

  counterNegotiation: Joi.object({
    pricePerUnit: Joi.number().min(0).required(),
    message: Joi.string().max(500).allow('', null),
  }),

  holdPayment: Joi.object({
    reason: Joi.string().trim().max(500).required(),
  }),

  createStaff: Joi.object({
    name: Joi.string().trim().max(100).required(),
    username: Joi.string().trim().lowercase().pattern(/^[a-z0-9._-]{3,32}$/).required(),
    password: Joi.string().min(8).required(),
  }),

  resetStaffPassword: Joi.object({
    password: Joi.string().min(8).required(),
  }),

  updateStaffStatus: Joi.object({
    isActive: Joi.boolean().required(),
  }),

  rejectNegotiation: Joi.object({
    reason: Joi.string().max(500).allow('', null),
  }),

  negotiationMessage: Joi.object({
    message: Joi.string().trim().min(1).max(280).required(),
    messageId: Joi.string().trim().pattern(/^[A-Za-z0-9:_-]+$/).max(100),
  }),

  acceptNegotiation: Joi.object({
    message: Joi.string().max(500).allow('', null),
    customerNote: Joi.string().max(500).allow('', null),
    shippingAddress: Joi.object({
      fullName: Joi.string().required().max(100),
      phone: Joi.string().required(),
      addressLine1: Joi.string().required().max(200),
      addressLine2: Joi.string().allow('', null).max(200),
      city: Joi.string().required().max(100),
      state: Joi.string().required().max(100),
      pincode: Joi.string().required().max(10),
    }).allow(null),
  }),

  updateOrderStatus: Joi.object({
    status: Joi.string().valid('processing', 'shipped', 'delivered', 'cancelled').required(),
    note: Joi.string().max(500).allow('', null),
  }),

  rejectOrder: Joi.object({
    reason: Joi.string().trim().min(1).max(500).required(),
  }),

  updateWholesalerCategoryAccess: Joi.object({
    excludedCategories: Joi.array().items(Joi.string().allow('', null)).default([]),
  }),

  shipOrder: Joi.object({
    trackingNumber: Joi.string().required(),
    courierName: Joi.string().required(),
  }),

  rejectPayment: Joi.object({
    reason: Joi.string().required().max(500),
  }),

  updateSettings: Joi.object({
    businessName: Joi.string().max(200),
    businessPhone: Joi.string(),
    businessEmail: emailRule,
    businessAddress: Joi.string(),
    upiId: Joi.string(),
    upiDisplayName: Joi.string(),
    bankName: Joi.string().allow('', null),
    bankAccountNumber: Joi.string().allow('', null),
    bankIfscCode: Joi.string().allow('', null),
    bankAccountHolderName: Joi.string().allow('', null),
    bankTransferEnabled: Joi.boolean(),
    minOrderAmount: Joi.number().min(0),
    defaultBulkMinQuantity: Joi.number().integer().min(1),
    negotiationExpiryDays: Joi.number().integer().min(1),
    lowStockThreshold: Joi.number().integer().min(0),
    features: Joi.object({
      negotiationsEnabled: Joi.boolean(),
      guestCheckout: Joi.boolean(),
      maintenanceMode: Joi.boolean(),
    }),
    mobileApp: Joi.object({
      android: mobilePlatformSettingsSchemas.android,
      ios: mobilePlatformSettingsSchemas.ios,
    }).unknown(false),
    heroBanners: Joi.array().items(Joi.object({
      title: Joi.string().allow('', null),
      subtitle: Joi.string().allow('', null),
      tag: Joi.string().allow('', null),
      imageUrl: Joi.string().allow('', null),
      mediaType: Joi.string().valid('image', 'video_upload', 'youtube').default('image'),
      videoUrl: Joi.when('mediaType', {
        is: Joi.valid('video_upload', 'youtube'),
        then: Joi.string().required(),
        otherwise: Joi.string().allow('', null),
      }),
      linkUrl: Joi.string().allow('', null),
      buttonText: Joi.string().allow('', null),
      buttonIcon: Joi.string().allow('', null),
      isActive: Joi.boolean(),
      order: Joi.number().integer(),
    })),
    promoBanners: Joi.array().items(Joi.object({
      title: Joi.string().required(),
      subtitle: Joi.string().allow('', null),
      tag: Joi.string().allow('', null),
      imageUrl: Joi.string().allow('', null),
      linkUrl: Joi.string().allow('', null),
      buttonText: Joi.string().allow('', null),
      buttonIcon: Joi.string().allow('', null),
      isActive: Joi.boolean(),
      order: Joi.number().integer(),
    })),
    socialLinks: Joi.object({
      whatsapp: Joi.string().allow('', null),
      instagram: Joi.string().allow('', null),
      facebook: Joi.string().allow('', null),
    }),
    checkout: Joi.object({
      mode: Joi.string().valid('whatsapp'),
      orderWhatsappNumber: Joi.string().allow('', null),
      requireLoginForCheckout: Joi.boolean().valid(true),
      createOrderBeforeRedirect: Joi.boolean().valid(true),
      allowNegotiationCheckout: Joi.boolean(),
    }),
  }),

  updateWebsiteSettings: Joi.object({
    heroCards: Joi.array().items(Joi.object({
      image: Joi.string().allow('', null),
      order: Joi.number().integer(),
    })).length(5),
    labels: Joi.array().items(Joi.object({
      id: Joi.string().allow('', null),
      title: Joi.string().required(),
      sourceType: Joi.string().valid('image', 'icon').default('image'),
      image: Joi.string().allow('', null),
      icon: Joi.string().allow('', null),
      isActive: Joi.boolean(),
      order: Joi.number().integer(),
    })),
    productCategories: Joi.array().items(Joi.object({
      name: Joi.string().required(),
      description: Joi.string().allow('', null),
      image: Joi.string().allow('', null),
      products: Joi.array().items(Joi.string().allow('', null)),
      productDetails: Joi.array().items(Joi.object({
        productId: Joi.string().allow('', null),
        name: Joi.string().required(),
        slug: Joi.string().allow('', null),
        category: Joi.string().allow('', null),
        shortDescription: Joi.string().allow('', null),
        description: Joi.string().allow('', null),
        sku: Joi.string().allow('', null),
        mrp: Joi.number().min(0).allow('', null),
        retailPrice: Joi.number().min(0).allow('', null),
        wholesalePrice: Joi.number().min(0).allow('', null),
        stock: Joi.number().min(0).allow('', null),
        status: Joi.string().allow('', null),
        image: Joi.string().allow('', null),
        images: Joi.array().items(Joi.string().allow('', null)),
        priceUnit: Joi.string().allow('', null),
        packing: Joi.string().allow('', null),
        variants: Joi.array().items(Joi.any()).strip(),
        order: Joi.number().integer(),
      })),
      isActive: Joi.boolean(),
      order: Joi.number().integer(),
    })),
    featuredProducts: Joi.array().items(Joi.object({
      name: Joi.string().required(),
      price: Joi.string().allow('', null),
      image: Joi.string().allow('', null),
      badge: Joi.string().allow('', null),
      specs: Joi.array().items(Joi.string().allow('', null)),
      shortDescription: Joi.string().allow('', null),
      priceUnit: Joi.string().allow('', null),
      packing: Joi.string().allow('', null),
      variants: Joi.array().items(Joi.any()).strip(),
      isActive: Joi.boolean(),
      order: Joi.number().integer(),
    })),
    categoriesSection: Joi.object({
      eyebrow: Joi.string().allow('', null),
      title: Joi.string().allow('', null),
      description: Joi.string().allow('', null),
      buttonText: Joi.string().allow('', null),
    }),
    featuredSection: Joi.object({
      eyebrow: Joi.string().allow('', null),
      title: Joi.string().allow('', null),
      description: Joi.string().allow('', null),
      sideText: Joi.string().allow('', null),
      buttonText: Joi.string().allow('', null),
    }),
  }),

  createOffer: Joi.object({
    title: Joi.string().required().max(200),
    description: Joi.string().allow('', null),
    discountType: Joi.string().valid('percentage', 'fixed').default('percentage'),
    discountValue: Joi.number().min(0).required(),
    discountRules: Joi.array().items(discountRuleSchema).default([]),
    code: Joi.string().uppercase().allow('', null),
    targetGroup: Joi.string().valid('buyer', 'wholesaler', 'all').default('all'),
    startDate: Joi.date().iso().default(Date.now),
    endDate: Joi.date().iso().greater(Joi.ref('startDate')).allow('', null),
    imageUrl: Joi.string().uri().allow('', null),
    isActive: Joi.boolean().default(true),
    minPurchaseAmount: Joi.number().min(0).default(0),
    maxDiscountAmount: Joi.number().min(0).allow('', null),
  }),

  updateOffer: Joi.object({
    title: Joi.string().max(200),
    description: Joi.string().allow('', null),
    discountType: Joi.string().valid('percentage', 'fixed'),
    discountValue: Joi.number().min(0),
    discountRules: Joi.array().items(discountRuleSchema),
    code: Joi.string().uppercase().allow('', null),
    targetGroup: Joi.string().valid('buyer', 'wholesaler', 'all'),
    startDate: Joi.date().iso(),
    endDate: Joi.date().iso().greater(Joi.ref('startDate')).allow('', null),
    imageUrl: Joi.string().uri().allow('', null),
    isActive: Joi.boolean(),
    minPurchaseAmount: Joi.number().min(0),
    maxDiscountAmount: Joi.number().min(0).allow('', null),
  }),

  createAffiliateCode: Joi.object({
    code: Joi.string().required().uppercase(),
    personName: Joi.string().required().max(100),
    discountType: Joi.string().valid('percentage', 'fixed').default('percentage'),
    discountValue: Joi.number().min(0).required(),
    discountRules: Joi.array().items(discountRuleSchema).default([]),
    usageLimit: Joi.number().integer().min(0).default(0),
    startDate: Joi.date().iso().default(Date.now),
    endDate: Joi.date().iso().greater(Joi.ref('startDate')).allow('', null),
    isActive: Joi.boolean().default(true),
  }),

  updateAffiliateCode: Joi.object({
    code: Joi.string().uppercase(),
    personName: Joi.string().max(100),
    discountType: Joi.string().valid('percentage', 'fixed'),
    discountValue: Joi.number().min(0),
    discountRules: Joi.array().items(discountRuleSchema),
    usageLimit: Joi.number().integer().min(0),
    startDate: Joi.date().iso(),
    endDate: Joi.date().iso().greater(Joi.ref('startDate')).allow('', null),
    isActive: Joi.boolean(),
  }),

  sendNotification: Joi.object({
    userIds: Joi.array().items(Joi.string().required()).min(1).required(),
    title: Joi.string().required().max(100),
    body: Joi.string().required().max(500),
  }),

  updateAccountDeletionRequest: Joi.object({
    status: Joi.string().valid('in_review', 'rejected').required(),
    identityVerified: Joi.boolean().default(false),
    staffNote: Joi.string().trim().max(1000).allow('', null),
  }),

  completeAccountDeletionRequest: Joi.object({
    staffNote: Joi.string().trim().max(1000).allow('', null),
  }),
};

module.exports = {
  authValidation,
  productValidation,
  cartValidation,
  negotiationValidation,
  orderValidation,
  adminValidation,
  mobilePlatformSettingsSchemas,
};
