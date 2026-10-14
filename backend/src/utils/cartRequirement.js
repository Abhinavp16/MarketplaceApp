// Turning a wholesaler's cart into Deal Desk requirements (one negotiation
// per product). The whole cart is checked first so that either every item is
// sent or none is.

const { getMinimumWholesaleQuantity, isWholePacks } = require('./packSize');
const { purchaseBlockCode } = require('./productAvailability');

// cartItems: [{ productId, quantity }]; productMap: { [id]: product }.
// Returns { lines: [{ product, quantity }], problems: [{ productId, name, code }] }.
function planCartRequirement(cartItems = [], productMap = {}) {
  const lines = [];
  const problems = [];
  for (const item of cartItems) {
    const productId = String(item.productId);
    const product = productMap[productId];
    const quantity = Number(item.quantity);
    if (!product) {
      problems.push({ productId, name: '', code: 'PRODUCT_NOT_FOUND' });
      continue;
    }
    const blocked = purchaseBlockCode(product);
    if (blocked) {
      problems.push({ productId, name: product.name, code: blocked });
      continue;
    }
    if (!product.negotiationEnabled) {
      problems.push({ productId, name: product.name, code: 'NEGOTIATION_DISABLED' });
      continue;
    }
    if (!Number.isInteger(quantity) || quantity < getMinimumWholesaleQuantity(product)) {
      problems.push({ productId, name: product.name, code: 'MIN_WHOLESALE_QUANTITY_NOT_MET' });
      continue;
    }
    if (!isWholePacks(product, quantity)) {
      problems.push({ productId, name: product.name, code: 'PACK_QUANTITY_REQUIRED' });
      continue;
    }
    lines.push({ product, quantity });
  }
  return { lines, problems };
}

// One admin notification for the whole cart instead of one per product.
function describeCartRequirement(wholesalerName, entries, maxListed = 3) {
  const who = wholesalerName || 'A wholesaler';
  const listed = entries.slice(0, maxListed)
    .map(({ quantity, productName }) => `${quantity} × ${productName}`);
  const more = entries.length - listed.length;
  const items = more > 0 ? `${listed.join(', ')} and ${more} more` : listed.join(', ');
  return {
    title: entries.length === 1
      ? `New deal request ${entries[0].negotiationNumber}`
      : `${entries.length} new deal requests from cart`,
    body: `${who} sent a requirement from the cart: ${items}.`,
  };
}

module.exports = {
  planCartRequirement,
  describeCartRequirement,
};
