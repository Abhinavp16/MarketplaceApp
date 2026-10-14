const { USER_ROLES } = require('./constants');

// Wholesale (dealer) prices are only for wholesalers and admins. Guests,
// customers, members and the public website never receive them.
const WHOLESALE_PRICE_ROLES = new Set([USER_ROLES.WHOLESALER, USER_ROLES.ADMIN]);
const WHOLESALE_PRICE_FIELDS = ['wholesalePrice', 'pendingWholesalePrice'];

const canSeeWholesalePrices = (role) => WHOLESALE_PRICE_ROLES.has(role);

function withoutWholesalePrices(payload) {
  if (!payload || typeof payload !== 'object') return payload;
  const copy = { ...payload };
  for (const field of WHOLESALE_PRICE_FIELDS) delete copy[field];
  if (Array.isArray(copy.variants)) copy.variants = copy.variants.map(withoutWholesalePrices);
  return copy;
}

/** The product payload with wholesale prices removed unless the role may see them. */
function pricesForRole(payload, role) {
  return canSeeWholesalePrices(role) ? payload : withoutWholesalePrices(payload);
}

module.exports = {
  WHOLESALE_PRICE_FIELDS,
  canSeeWholesalePrices,
  withoutWholesalePrices,
  pricesForRole,
};
