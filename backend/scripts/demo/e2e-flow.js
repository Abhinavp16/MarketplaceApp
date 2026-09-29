#!/usr/bin/env node
/**
 * End-to-end API flow for the demo backend (uses fetch only).
 *
 *   npm run demo:e2e                       # against http://127.0.0.1:5050/api/v1
 *   BASE_URL=http://127.0.0.1:5050/api/v1 npm run demo:e2e
 *
 * Refuses to run unless GET /demo/info reports demoMode:true. The flow:
 * reset -> wholesaler negotiates -> admin counters/accepts -> one order ->
 * admin processes it (stock drops) -> reset back to baseline -> run the whole
 * flow a second time. Demo credentials come from the seed fixtures.
 */
const assert = require('assert');
const path = require('path');

const BASE_URL = (process.env.BASE_URL || 'http://127.0.0.1:5050/api/v1').replace(/\/+$/, '');
const users = require(path.join(__dirname, 'fixtures', 'users.json'));
const credentials = (key) => users.find((u) => u.key === key);

const LIVE_PRODUCT_NAME = 'Cordless Drill 18V';
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
  const sunriseOrders = orders.json.data.filter((o) => String(o.userId?._id || o.userId) === String(wholesaler.user._id));
  return {
    totalOrders: orders.json.pagination.total,
    sunriseOrders: sunriseOrders.length,
    negotiations: negotiations.json.pagination.total,
    openSunriseDrillNegotiations: negotiations.json.data.filter((n) => (
      String(n.wholesaler.id) === String(wholesaler.user._id)
      && String(n.product.id) === String(productId)
      && ['pending', 'countered', 'accepted'].includes(n.status)
    )).length,
    stock: (product.json.data.product || product.json.data).stock,
  };
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
  assert.ok(list.json.data.length >= 16, 'catalogue should list 16+ products');
  assert.ok(product.primaryImage && product.primaryImage.includes('/uploads/demo/'), 'product images use the /uploads/demo scheme');
  const imageResponse = await fetch(product.primaryImage);
  assert.strictEqual(imageResponse.status, 200, 'product image must be downloadable');
  assert.ok((imageResponse.headers.get('content-type') || '').includes('image/png'));
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
    assert.ok(ok.json.data.products >= 16);
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
