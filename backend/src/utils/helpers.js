const crypto = require('crypto');

const generateOrderNumber = () => {
  const year = new Date().getFullYear();
  const random = crypto.randomInt(1000, 9999);
  const timestamp = Date.now().toString().slice(-4);
  return `ORD-${year}-${timestamp}${random}`;
};

const generateNegotiationNumber = () => {
  const year = new Date().getFullYear();
  const random = crypto.randomInt(1000, 9999);
  const timestamp = Date.now().toString().slice(-4);
  return `NGT-${year}-${timestamp}${random}`;
};

// Number shared by products a wholesaler sent together from the cart.
const generateRequestNumber = () => {
  const year = new Date().getFullYear();
  const random = crypto.randomInt(1000, 9999);
  const timestamp = Date.now().toString().slice(-4);
  return `REQ-${year}-${timestamp}${random}`;
};

const generatePaymentNumber = () => {
  const year = new Date().getFullYear();
  const random = crypto.randomInt(1000, 9999);
  const timestamp = Date.now().toString().slice(-4);
  return `PAY-${year}-${timestamp}${random}`;
};

const generateSKU = (category, name) => {
  const catCode = category.substring(0, 3).toUpperCase();
  const nameCode = name.substring(0, 3).toUpperCase();
  const random = crypto.randomInt(100, 999);
  return `${catCode}-${nameCode}-${random}`;
};

const paginate = (page = 1, limit = 20, maxLimit = 50) => {
  // Missing or non-numeric values fall back to the defaults.
  const pageNum = Math.max(1, parseInt(page, 10) || 1);
  const limitNum = Math.min(Math.max(1, parseInt(limit, 10) || 20), maxLimit);
  const skip = (pageNum - 1) * limitNum;

  return { page: pageNum, limit: limitNum, skip };
};

// A query-string value as text, or undefined when it isn't plain text
// (e.g. ?status[x]=y arrives as an object).
const queryText = (value) => (typeof value === 'string' ? value : undefined);

const formatPaginationResponse = (data, total, page, limit) => {
  const totalPages = Math.ceil(total / limit);
  
  return {
    data,
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNext: page < totalPages,
      hasPrev: page > 1,
    },
  };
};

const sanitizeUser = (user) => {
  const userObj = user.toObject ? user.toObject() : { ...user };
  delete userObj.passwordHash;
  delete userObj.__v;
  // Admin-only: which brands are hidden from this customer.
  delete userObj.hiddenBrands;
  if (userObj.businessInfo) {
    delete userObj.businessInfo.proofImageKeys;
    delete userObj.businessInfo.proofImages;
  }
  return userObj;
};

const formatPrice = (price) => {
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0,
  }).format(price);
};

module.exports = {
  queryText,
  generateOrderNumber,
  generateNegotiationNumber,
  generateRequestNumber,
  generatePaymentNumber,
  generateSKU,
  paginate,
  formatPaginationResponse,
  sanitizeUser,
  formatPrice,
};
