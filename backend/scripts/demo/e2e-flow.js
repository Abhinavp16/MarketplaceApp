#!/usr/bin/env node
/**
 * End-to-end API flow for the demo backend (uses fetch only).
 *
 *   npm run demo:e2e                       # against http://127.0.0.1:5050/api/v1
 *   BASE_URL=http://127.0.0.1:5050/api/v1 npm run demo:e2e
 *
 * Refuses to run unless GET /demo/info reports demoMode:true. The flow:
 * reset -> wholesaler negotiates -> admin counters/accepts -> one order ->
 * admin processes it (stock drops) -> buyer cart -> order -> admin accepts with
 * a delivery charge -> paid -> shipped -> delivered -> wholesaler cart ->
 * requirement group -> one order -> declines (staff blocked) -> Coming Soon
 * (cart/negotiation blocked, launch notifies once) -> receipts -> hidden
 * catalogue and price visibility -> reset back to baseline -> run the whole
 * flow a second time. Demo credentials come from the seed fixtures.
 */
const assert = require('assert');
const path = require('path');

const BASE_URL = (process.env.BASE_URL || 'http://127.0.0.1:5050/api/v1').replace(/\/+$/, '');
const users = require(path.join(__dirname, 'fixtures', 'users.json'));
const credentials = (key) => users.find((u) => u.key === key);

const nameOf = (list, prefix) => list.find((p) => p.name.startsWith(prefix));

const LIVE_PRODUCT_NAME = '18V Brushless Cordless Drill Driver, 13 mm Chuck (2 x 2.0 Ah)';
const QUANTITY = 20;
const REQUESTED_PRICE = 4900;
const COUNTER_PRICE = 5050;

const step = (message) => console.log(`  - ${message}`);

async function api(method, route, { token, body, expect = [200, 201] } = {}) {
  const response = await fetch(`${BASE_URL}${route}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let json = null;
  try { json = await response.json(); } catch (_) { /* non-JSON */ }
  const allowed = Array.isArray(expect) ? expect : [expect];
  if (!allowed.includes(response.status)) {
    throw new Error(`${method} ${route} -> ${response.status} (expected ${allowed.join('/')}): ${JSON.stringify(json)}`);
  }
  return { status: response.status, json };
}

async function login(key) {
  const account = credentials(key);
  const isStaff = account.role === 'staff';
  const { json } = await api('POST', isStaff ? '/auth/staff/login' : '/auth/login', {
    body: isStaff
      ? { username: account.username, password: account.password }
      : { email: account.email, password: account.password },
  });
  assert.ok(json.data.accessToken, `${key} login must return an accessToken`);
  assert.strictEqual(json.data.user.role, account.role);
  return { token: json.data.accessToken, user: json.data.user };
}

async function snapshot(admin, wholesaler, productId) {
  const orders = await api('GET', '/admin/orders?limit=50', { token: admin.token });
  const negotiations = await api('GET', '/admin/negotiations?limit=50', { token: admin.token });
  const product = await api('GET', `/admin/products/${productId}`, { token: admin.token });
  const products = await api('GET', '/admin/products?limit=50', { token: admin.token });
  const sunriseOrders = orders.json.data.filter((o) => String(o.userId?._id || o.userId) === String(wholesaler.user._id));
  const comingSoon = products.json.data.filter((p) => p.comingSoon?.enabled);
  const buyer = await login('priya');
  const notifications = await api('GET', '/notifications/my?limit=50', { token: buyer.token });
  return {
    totalOrders: orders.json.pagination.total,
    sunriseOrders: sunriseOrders.length,
    negotiations: negotiations.json.pagination.total,
    pendingNegotiations: negotiations.json.data.filter((n) => n.status === 'pending').length,
    rejectedNegotiations: negotiations.json.data.filter((n) => n.status === 'rejected').length,
    openSunriseDrillNegotiations: negotiations.json.data.filter((n) => (
      String(n.wholesaler.id) === String(wholesaler.user._id)
      && String(n.product.id) === String(productId)
      && ['pending', 'countered', 'accepted'].includes(n.status)
    )).length,
    stock: (product.json.data.product || product.json.data).stock,
    totalProducts: products.json.pagination.total,
    comingSoonProducts: comingSoon.length,
    priyaNotifications: (notifications.json.pagination || {}).total ?? notifications.json.data.length,
  };
}


const SHIPPING = {
  fullName: 'Priya Sharma', phone: '9000000003', addressLine1: '21 Garden Lane', city: 'Sample City', state: 'Demo State', pincode: '000000',
};
const DEMO_RESERVED = 'Approval is reserved for the business owner in this demo';

const productList = async (token) => (await api('GET', '/products?limit=50', { token })).json.data;
const adminProduct = async (admin, id) => {
  const { json } = await api('GET', `/admin/products/${id}`, { token: admin.token });
  return json.data.product || json.data;
};

// (a) Buyer: cart -> order -> admin accepts with a delivery charge -> paid -> shipped -> delivered.
async function buyerOrderPath({ admin, buyer }) {
  const list = await productList(buyer.token);
  const grinder = nameOf(list, '850 W Angle Grinder');
  const washers = nameOf(list, 'Zinc Plated Flat Washer M10');
  assert.ok(grinder && washers, 'buyer sees the grinder and the washer packet product');
  assert.strictEqual(washers.priceUnit, 'Packet');
  assert.strictEqual(washers.packing, '100 pcs');
  assert.strictEqual(washers.packSize, 100, 'pack products report their pack size');
  assert.strictEqual(washers.minCustomerQuantity, 10);

  await api('DELETE', '/cart', { token: buyer.token });
  await api('POST', '/cart/items', { token: buyer.token, body: { productId: grinder.id, quantity: 1 } });
  await api('POST', '/cart/items', { token: buyer.token, body: { productId: washers.id, quantity: 200 } });
  const tooFew = await api('POST', '/orders', {
    token: buyer.token, body: { items: [{ productId: washers.id, quantity: 5 }], shippingAddress: SHIPPING }, expect: [400, 409],
  });
  assert.ok(tooFew.json.error?.code || tooFew.json.data?.issues, `below the customer minimum is refused (${JSON.stringify(tooFew.json).slice(0, 200)})`);
  const cart = await api('GET', '/cart', { token: buyer.token });
  assert.strictEqual((cart.json.data.items || []).length, 2, 'cart holds the two items');

  const stockBefore = {
    grinder: (await adminProduct(admin, grinder.id)).stock,
    washers: (await adminProduct(admin, washers.id)).stock,
  };
  const placed = await api('POST', '/orders', { token: buyer.token, body: { shippingAddress: SHIPPING, customerNote: 'e2e order' } });
  const orderId = String(placed.json.data.orderId);
  assert.strictEqual(placed.json.data.deliveryFee, 0, 'delivery is 0 until the admin sets it');
  assert.strictEqual(placed.json.data.acceptanceStatus, 'pending');
  assert.strictEqual(placed.json.data.subtotal, 2799 + (200 * 6.5));
  const cartAfter = await api('GET', '/cart', { token: buyer.token });
  assert.strictEqual((cartAfter.json.data.items || []).length, 0, 'cart is emptied after ordering');

  // Not payable / not processable before the admin accepts.
  await api('PUT', `/admin/orders/${orderId}/mark-payment-complete`, { token: admin.token, expect: 400 });

  const accepted = await api('PUT', `/admin/orders/${orderId}/accept`, { token: admin.token, body: { deliveryCharge: 120 } });
  assert.strictEqual(accepted.json.data.deliveryFee, 120);
  assert.strictEqual(accepted.json.data.total, placed.json.data.subtotal + 120);
  assert.strictEqual((await adminProduct(admin, grinder.id)).stock, stockBefore.grinder - 1, 'accepting commits stock');
  assert.strictEqual((await adminProduct(admin, washers.id)).stock, stockBefore.washers - 200);

  await api('PUT', `/admin/orders/${orderId}/mark-payment-complete`, { token: admin.token });
  let order = (await api('GET', `/orders/${orderId}`, { token: buyer.token })).json.data;
  assert.strictEqual(order.status, 'processing');
  await api('PUT', `/admin/orders/${orderId}/status`, { token: admin.token, body: { status: 'shipped', note: 'Handed to courier' } });
  await api('PUT', `/admin/orders/${orderId}/status`, { token: admin.token, body: { status: 'delivered', note: 'Delivered' } });
  order = (await api('GET', `/orders/${orderId}`, { token: buyer.token })).json.data;
  assert.strictEqual(order.status, 'delivered');
  assert.strictEqual(order.deliveryFee, 120);
  assert.strictEqual((await adminProduct(admin, grinder.id)).stock, stockBefore.grinder - 1, 'delivery does not move stock again');
  return { orderId, orderNumber: placed.json.data.orderNumber };
}

// (b) Wholesaler cart -> one requirement group -> admin accepts with a delivery charge -> one order.
async function wholesalerCartGroupPath({ admin, wholesaler }) {
  const list = await productList(wholesaler.token);
  const pliers = nameOf(list, 'Slip Joint Pliers');
  const wrench = nameOf(list, 'Adjustable Wrench');
  assert.ok(pliers && wrench);
  await api('DELETE', '/cart', { token: wholesaler.token });
  await api('POST', '/cart/items', { token: wholesaler.token, body: { productId: pliers.id, quantity: 20 } });
  await api('POST', '/cart/items', { token: wholesaler.token, body: { productId: wrench.id, quantity: 20 } });
  const sent = await api('POST', '/negotiations/from-cart', { token: wholesaler.token, body: { message: 'Restock for the month.' } });
  const group = sent.json.data.requestGroup;
  assert.ok(group && group.id && /^REQ-/.test(group.number), 'two products share one REQ number');
  assert.strictEqual(sent.json.data.negotiations.length, 2);
  const ids = sent.json.data.negotiations.map((n) => String(n.id));
  const emptied = await api('GET', '/cart', { token: wholesaler.token });
  assert.strictEqual((emptied.json.data.items || []).length, 0, 'cart is emptied after sending the requirement');

  const detail = await api('GET', `/admin/negotiations/groups/${group.id}`, { token: admin.token });
  assert.ok(detail.json.success);
  const ordersBefore = (await api('GET', '/admin/orders?limit=1', { token: admin.token })).json.pagination.total;
  const accepted = await api('PUT', `/admin/negotiations/groups/${group.id}/accept`, {
    token: admin.token, body: { negotiationIds: ids, deliveryCharge: 250, message: 'Approved together.' },
  });
  assert.strictEqual(accepted.json.data.deliveryFee, 250);
  assert.strictEqual(accepted.json.data.total, accepted.json.data.subtotal + 250);
  assert.strictEqual(accepted.json.data.negotiationIds.length, 2);
  const orderId = accepted.json.data.orderId;
  const ordersAfter = (await api('GET', '/admin/orders?limit=1', { token: admin.token })).json.pagination.total;
  assert.strictEqual(ordersAfter, ordersBefore + 1, 'exactly one order for the whole requirement');
  const order = (await api('GET', `/orders/${orderId}`, { token: wholesaler.token })).json.data;
  assert.strictEqual(order.items.length, 2);
  assert.strictEqual(order.deliveryFee, 250);
  for (const id of ids) {
    const n = (await api('GET', `/negotiations/${id}`, { token: wholesaler.token })).json.data;
    assert.strictEqual(n.status, 'converted');
  }
  // Accepting the same group again must not create a second order.
  await api('PUT', `/admin/negotiations/groups/${group.id}/accept`, {
    token: admin.token, body: { negotiationIds: ids }, expect: [400, 409],
  });
  return { orderId, orderNumber: accepted.json.data.orderNumber };
}

// (c) Declines: admin declines; staff cannot (demo).
async function declinePath({ admin, wholesaler, staff }) {
  const list = await productList(wholesaler.token);
  const tape = nameOf(list, 'Steel Measuring Tape');
  const created = await api('POST', '/negotiations', {
    token: wholesaler.token, body: { productId: tape.id, quantity: 50, pricePerUnit: 100, message: 'Best price please' },
  });
  const id = String(created.json.data.id);
  const blocked = await api('PUT', `/staff/negotiations/${id}/reject`, { token: staff.token, body: { reason: 'no' }, expect: 403 });
  assert.strictEqual(blocked.json.message, DEMO_RESERVED);

  // The seeded two-product requirement waiting for a decision.
  const all = await api('GET', '/admin/negotiations?limit=50&status=pending', { token: admin.token });
  const grouped = all.json.data.find((n) => n.requestGroup?.id && n.requestGroup.number === 'REQ-2026-DEMO01');
  assert.ok(grouped, 'seeded pending requirement group REQ-2026-DEMO01 exists');
  const groupBlocked = await api('PUT', `/staff/negotiations/groups/${grouped.requestGroup.id}/reject`, { token: staff.token, body: {}, expect: 403 });
  assert.strictEqual(groupBlocked.json.message, DEMO_RESERVED);

  const declined = await api('PUT', `/admin/negotiations/${id}/reject`, { token: admin.token, body: { reason: 'Out of stock this week' } });
  assert.ok(declined.json.success);
  const after = (await api('GET', `/negotiations/${id}`, { token: wholesaler.token })).json.data;
  assert.strictEqual(after.status, 'rejected');
  assert.ok(after.rejectedAt, 'a declined requirement records when it was declined');

  const groupDeclined = await api('PUT', `/admin/negotiations/groups/${grouped.requestGroup.id}/reject`, { token: admin.token, body: { reason: 'Please resend next month' } });
  assert.strictEqual(groupDeclined.json.data.declined.length, 2, 'both products of the group are declined');
  const check = (await api('GET', `/admin/negotiations/${grouped.id}`, { token: admin.token })).json.data;
  assert.strictEqual(check.status, 'rejected');
}

// (d) Coming Soon: blocked from cart/requirement; price hiding; launch notifies once.
async function comingSoonPath({ admin, buyer, wholesaler }) {
  const buyerList = await productList(buyer.token);
  const hammer = nameOf(buyerList, '24V Cordless SDS-plus Rotary Hammer');
  const helmet = nameOf(buyerList, 'Auto-Darkening Welding Helmet');
  const saw = nameOf(buyerList, '1200 W Compound Mitre Saw');
  const toolBox = nameOf(buyerList, 'Steel Tool Box');
  for (const item of [hammer, helmet, saw, toolBox]) assert.ok(item && item.comingSoon === true, 'coming soon flag is set');
  assert.ok(hammer.expectedDate && hammer.priceHidden === false && hammer.price === 10999, 'price shown + expected date');
  assert.strictEqual(helmet.priceHidden, true);
  assert.strictEqual(helmet.price, null, 'hidden price is null for buyers');
  assert.strictEqual(helmet.retailPrice, null);
  assert.strictEqual(helmet.mrp, null);
  assert.ok(saw.expectedDate, 'auto-launch product has a date');
  assert.strictEqual(toolBox.expectedDate, null, 'a product without a date');
  const wholesalerList = await productList(wholesaler.token);
  assert.strictEqual(nameOf(wholesalerList, 'Auto-Darkening Welding Helmet').price, null, 'hidden price is also null for wholesalers');

  const cartBlock = await api('POST', '/cart/items', { token: buyer.token, body: { productId: hammer.id, quantity: 1 }, expect: [400, 409] });
  assert.strictEqual(cartBlock.json.error.code, 'PRODUCT_COMING_SOON');
  const negotiationBlock = await api('POST', '/negotiations', {
    token: wholesaler.token, body: { productId: hammer.id, quantity: 3, pricePerUnit: 8000 }, expect: [400, 409],
  });
  assert.strictEqual(negotiationBlock.json.error.code, 'PRODUCT_COMING_SOON');
  const orderBlock = await api('POST', '/orders', {
    token: buyer.token, body: { items: [{ productId: hammer.id, quantity: 1 }], shippingAddress: SHIPPING }, expect: [400, 409],
  });
  assert.strictEqual(orderBlock.status, 400);
  assert.strictEqual(orderBlock.json.code || orderBlock.json.error?.code, 'PRODUCT_COMING_SOON');

  // Notify me (idempotent), then launch by hand.
  await api('POST', `/products/${hammer.id}/notify-me`, { token: buyer.token });
  const countFor = async (user, productId) => {
    const { json } = await api('GET', '/notifications/my?limit=100', { token: user.token });
    return json.data.filter((n) => n.type === 'product_launched' && String(n.data?.productId) === String(productId)).length;
  };
  const sunriseBefore = await countFor(wholesaler, hammer.id);
  const priyaBefore = await countFor(buyer, hammer.id);
  assert.strictEqual(priyaBefore, 0);
  const detail = await adminProduct(admin, hammer.id);
  assert.strictEqual(detail.comingSoon.enabled, true);
  const launched = await api('PUT', `/admin/products/${hammer.id}`, { token: admin.token, body: { comingSoon: { enabled: false } } });
  assert.strictEqual(launched.json.launchNotified, 3, 'Priya, Sunrise and Metro subscribed');
  assert.strictEqual(await countFor(buyer, hammer.id), priyaBefore + 1, 'subscriber got a product_launched notification');
  assert.strictEqual(await countFor(wholesaler, hammer.id), sunriseBefore + 1);
  const again = await api('PUT', `/admin/products/${hammer.id}`, { token: admin.token, body: { comingSoon: { enabled: false } } });
  assert.strictEqual(again.json.launchNotified, 0, 'launching again does not notify again');
  assert.strictEqual(await countFor(buyer, hammer.id), priyaBefore + 1, 'exactly one notification per subscriber');
  const nowAvailable = nameOf(await productList(buyer.token), '24V Cordless SDS-plus Rotary Hammer');
  assert.strictEqual(nowAvailable.comingSoon, false);
  await api('POST', '/cart/items', { token: buyer.token, body: { productId: hammer.id, quantity: 1 } });
  await api('DELETE', '/cart', { token: buyer.token });
}

// (e) Receipt PDFs.
async function receiptPath({ admin, buyer, orders }) {
  for (const { orderId, orderNumber } of orders) {
    const response = await fetch(`${BASE_URL}/admin/orders/${orderId}/receipt`, { headers: { Authorization: `Bearer ${admin.token}` } });
    assert.strictEqual(response.status, 200, `receipt for ${orderNumber}`);
    assert.ok((response.headers.get('content-type') || '').includes('application/pdf'));
    const bytes = Buffer.from(await response.arrayBuffer());
    assert.strictEqual(bytes.subarray(0, 5).toString('latin1'), '%PDF-', 'receipt is a PDF');
    assert.ok(bytes.length > 1500);
  }
  const mine = await fetch(`${BASE_URL}/orders/${orders[0].orderId}/export?format=pdf`, { headers: { Authorization: `Bearer ${buyer.token}` } });
  assert.strictEqual(mine.status, 200);
  assert.ok((mine.headers.get('content-type') || '').includes('application/pdf'));
}

// (f) Hidden catalogue + price visibility.
async function visibilityPath({ admin, buyer, wholesaler }) {
  const sneha = await login('sneha');
  const guest = await productList(undefined);
  const forBuyer = await productList(buyer.token);
  const forSneha = await productList(sneha.token);
  const forWholesaler = await productList(wholesaler.token);
  const forAdmin = await productList(admin.token);
  const bulk = 'Hex Bolt M12 x 80 mm';
  assert.ok(!nameOf(guest, bulk) && !nameOf(forBuyer, bulk), 'hidden category is invisible to guests and customers');
  assert.ok(nameOf(forWholesaler, bulk) && nameOf(forAdmin, bulk), 'hidden category is visible to wholesalers and admin');
  const helmet = 'Industrial Safety Helmet';
  assert.ok(nameOf(forBuyer, helmet), 'other customers see Brightguard');
  assert.ok(!nameOf(forSneha, helmet), 'a brand hidden from one customer is invisible to her');
  assert.ok(nameOf(forWholesaler, helmet) && nameOf(forAdmin, helmet));
  const categoriesForBuyer = (await api('GET', '/products/categories', { token: buyer.token })).json;
  assert.ok(!JSON.stringify(categoriesForBuyer).includes('Contractor Bulk Range'), 'hidden category not listed for customers');
  const website = await api('GET', '/website/catalog/home');
  assert.ok(!JSON.stringify(website.json).includes('Contractor Bulk Range'), 'public website hides it too');

  // Wholesale price is never sent to retail customers.
  const drillForBuyer = nameOf(forBuyer, LIVE_PRODUCT_NAME);
  assert.ok(!('wholesalePrice' in drillForBuyer), 'no wholesalePrice for customers');
  assert.strictEqual(drillForBuyer.price, 6499);
  for (const item of forBuyer) {
    assert.ok(!('wholesalePrice' in item), `no wholesalePrice key for customers (${item.name})`);
    assert.ok(item.price === null || item.price === item.retailPrice, `customers are quoted the retail price (${item.name})`);
  }
  const drillForWholesaler = nameOf(forWholesaler, LIVE_PRODUCT_NAME);
  assert.strictEqual(drillForWholesaler.price, 5200, 'wholesalers see the wholesale price');
}

async function runFlow(label) {
  console.log(`\n== ${label}`);
  const admin = await login('admin');
  const wholesaler = await login('sunrise');
  const buyer = await login('priya');
  const staff = await login('operator');
  step('logged in as admin, wholesaler (Sunrise Trade House), buyer (Priya Sharma) and staff (Demo Operator)');

  const list = await api('GET', '/products?limit=50', { token: wholesaler.token });
  const product = list.json.data.find((p) => p.name === LIVE_PRODUCT_NAME);
  assert.ok(product, `${LIVE_PRODUCT_NAME} must be in the catalogue`);
  assert.ok(list.json.data.length >= 25, 'catalogue should list 25+ products');
  assert.ok(product.primaryImage && product.primaryImage.includes('/uploads/demo/'), 'product images use the /uploads/demo scheme');
  const imageResponse = await fetch(product.primaryImage);
  assert.strictEqual(imageResponse.status, 200, 'product image must be downloadable');
  assert.ok((imageResponse.headers.get('content-type') || '').includes('image/jpeg'));
  const buyerList = await api('GET', '/products?limit=5', { token: buyer.token });
  assert.ok(buyerList.json.data.length > 0, 'buyer can list products');
  step(`catalogue lists ${list.json.data.length} products; ${LIVE_PRODUCT_NAME} is ${product.wholesalePrice} wholesale / ${product.retailPrice} retail; image OK`);

  const before = await snapshot(admin, wholesaler, product.id);
  assert.strictEqual(before.openSunriseDrillNegotiations, 0, 'no open negotiation for the live-run product before the flow');
  step(`baseline: ${before.sunriseOrders} Sunrise orders, stock ${before.stock}, no open negotiation`);

  // 1) Wholesaler negotiates (with a message)
  const created = await api('POST', '/negotiations', {
    token: wholesaler.token,
    body: { productId: product.id, quantity: QUANTITY, pricePerUnit: REQUESTED_PRICE, message: 'We need 20 drills for a new branch. Can you do a better rate?' },
  });
  const negotiationId = created.json.data.id;
  assert.strictEqual(created.json.data.status, 'pending');
  const detail = await api('GET', `/negotiations/${negotiationId}`, { token: wholesaler.token });
  assert.strictEqual(detail.json.data.message, 'We need 20 drills for a new branch. Can you do a better rate?');
  assert.strictEqual(detail.json.data.history[0].message, 'We need 20 drills for a new branch. Can you do a better rate?');
  assert.ok(detail.json.data.expiresAt && new Date(detail.json.data.expiresAt) > new Date());
  step(`wholesaler created ${created.json.data.negotiationNumber} (message stored)`);

  // 2) Admin counters
  const counter = await api('PUT', `/admin/negotiations/${negotiationId}/counter`, {
    token: admin.token, body: { pricePerUnit: COUNTER_PRICE, message: 'Best price for 20 units.' },
  });
  assert.strictEqual(counter.json.data.status, 'countered');
  step(`admin countered at ${COUNTER_PRICE}`);

  // 3) Staff approval is reserved for the owner in demo mode
  const staffAccept = await api('PUT', `/staff/negotiations/${negotiationId}/accept`, { token: staff.token, body: {}, expect: 403 });
  assert.strictEqual(staffAccept.json.message, 'Approval is reserved for the business owner in this demo');
  step('staff accept blocked with 403 (owner-only in demo)');

  // 4) Admin accepts -> exactly one order
  const accept = await api('PUT', `/admin/negotiations/${negotiationId}/accept`, { token: admin.token, body: { message: 'Approved.' } });
  const orderId = accept.json.data.orderId;
  assert.ok(orderId, 'accept returns the created orderId');
  assert.strictEqual(accept.json.data.finalPricePerUnit, COUNTER_PRICE);
  const again = await api('PUT', `/admin/negotiations/${negotiationId}/accept`, { token: admin.token, body: {} });
  assert.strictEqual(again.json.data.orderId, orderId, 'second accept is idempotent (same order)');

  const negotiationAfter = await api('GET', `/negotiations/${negotiationId}`, { token: wholesaler.token });
  assert.strictEqual(negotiationAfter.json.data.status, 'converted');
  assert.strictEqual(String(negotiationAfter.json.data.orderId._id || negotiationAfter.json.data.orderId), orderId);
  const adminOrders = await api('GET', '/admin/orders?limit=100', { token: admin.token });
  const linked = adminOrders.json.data.filter((o) => String(o.negotiationId?._id || o.negotiationId) === String(negotiationId));
  assert.strictEqual(linked.length, 1, 'exactly one order is linked to the negotiation');
  const staffCounter = await api('PUT', `/staff/negotiations/${negotiationId}/counter`, { token: staff.token, body: { pricePerUnit: 1 }, expect: 403 });
  assert.strictEqual(staffCounter.json.message, 'Approval is reserved for the business owner in this demo');
  step(`admin accepted -> order ${accept.json.data.orderNumber}; exactly one order linked; staff counter on converted blocked`);

  // 5) Wholesaler can fetch the order
  const myOrder = await api('GET', `/orders/${orderId}`, { token: wholesaler.token });
  const orderData = myOrder.json.data;
  assert.strictEqual(String(orderData.id || orderData._id), orderId);
  assert.strictEqual(orderData.total, QUANTITY * COUNTER_PRICE);
  const myOrders = await api('GET', '/orders?limit=50', { token: wholesaler.token });
  assert.ok(myOrders.json.data.some((o) => String(o.id) === orderId));
  step(`wholesaler fetched the order (total ${orderData.total})`);

  // 6) Admin moves the order to processing -> stock drops
  await api('PUT', `/admin/orders/${orderId}/mark-payment-complete`, { token: admin.token });
  const processing = await api('PUT', `/admin/orders/${orderId}/status`, { token: admin.token, body: { status: 'processing', note: 'Packed and ready' } });
  assert.strictEqual(processing.json.data.status, 'processing');
  const after = await snapshot(admin, wholesaler, product.id);
  assert.strictEqual(after.stock, before.stock - QUANTITY, `stock should drop by ${QUANTITY}`);
  assert.strictEqual(after.sunriseOrders, before.sunriseOrders + 1, 'exactly one new Sunrise order');
  step(`order processing; stock ${before.stock} -> ${after.stock}`);

  // 7) Staff can still work operational endpoints
  const staffOrders = await api('GET', '/staff/orders?limit=5', { token: staff.token });
  assert.ok(staffOrders.json.data.length > 0);
  step('staff can read orders');

  const buyerOrder = await buyerOrderPath({ admin, buyer });
  step(`buyer cart -> order ${buyerOrder.orderNumber} -> accepted with delivery 120 -> paid -> shipped -> delivered (stock moved at accept)`);
  const groupOrder = await wholesalerCartGroupPath({ admin, wholesaler });
  step(`wholesaler cart -> REQ group -> accepted with delivery 250 -> one order ${groupOrder.orderNumber}`);
  await declinePath({ admin, wholesaler, staff });
  step('requirement + requirement group declined by admin (rejected); staff reject blocked with 403');
  await comingSoonPath({ admin, buyer, wholesaler });
  step('coming soon: cart/requirement/order blocked, hidden price null, launch notified 3 subscribers exactly once');
  await receiptPath({ admin, buyer, orders: [buyerOrder, groupOrder, { orderId, orderNumber: accept.json.data.orderNumber }] });
  step('receipt PDFs served (admin + buyer export)');
  await visibilityPath({ admin, buyer, wholesaler });
  step('hidden category/brand invisible to customers, visible to wholesalers/admin; wholesale price not exposed to customers');
  return { before, after, product };
}

async function main() {
  const info = await (await fetch(`${BASE_URL}/demo/info`)).json().catch(() => ({}));
  if (!info || info.demoMode !== true) {
    console.error(`Refusing to run: ${BASE_URL}/demo/info does not report demoMode:true.`);
    process.exit(1);
  }
  console.log(`Demo API at ${BASE_URL} (${info.brand}, dataset v${info.version}, seeded ${info.seededAt})`);
  const health = await api('GET', '/health');
  assert.strictEqual(health.json.success, true);

  const admin = await login('admin');
  const reset = async () => {
    const wrong = await api('POST', '/admin/demo/reset', { token: admin.token, body: { confirm: 'nope' }, expect: 400 });
    assert.ok(wrong.json.message);
    const noAuth = await api('POST', '/admin/demo/reset', { body: { confirm: 'RESET DEMO' }, expect: 401 });
    assert.ok(noAuth.status === 401);
    const ok = await api('POST', '/admin/demo/reset', { token: admin.token, body: { confirm: 'RESET DEMO' } });
    assert.strictEqual(ok.json.success, true);
    assert.ok(ok.json.data.products >= 25);
    return ok.json.data;
  };

  console.log('\n== Reset to baseline');
  const baseline = await reset();
  console.log(`  - ${JSON.stringify(baseline)}`);

  const first = await runFlow('Run 1');

  console.log('\n== Reset after run 1');
  const resetCounts = await reset();
  const wholesaler = await login('sunrise');
  const adminAfterReset = await login('admin');
  const back = await snapshot(adminAfterReset, wholesaler, first.product.id);
  assert.deepStrictEqual(back, first.before, 'reset returns the demo data to its baseline');
  assert.strictEqual(resetCounts.negotiations, baseline.negotiations);
  console.log('  - baseline restored (orders, negotiations, stock identical to before run 1)');

  const second = await runFlow('Run 2 (after reset)');
  assert.deepStrictEqual(second.before, first.before, 'second run starts from the same baseline');

  console.log('\n== Reset (leave the demo clean)');
  await reset();
  console.log('\nAll demo e2e checks passed.');
}

main().catch((error) => {
  console.error(`\nE2E FAILED: ${error.message}`);
  process.exit(1);
});
