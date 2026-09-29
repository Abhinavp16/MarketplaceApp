require('dotenv').config();
// These integration tests write to MONGODB_URI: only ever run them on the local demo DB.
require('../src/config/demoGuard').assertDemoDatabase();
const assert = require('assert');
const mongoose = require('mongoose');
const { Order, Product, User, Payment, StockLog, AuditLog, Notification } = require('../src/models');
const { ORDER_STATUS, PAYMENT_STATUS } = require('../src/utils/constants');
const { acceptOrder, rejectOrder } = require('../src/services/orderApprovalService');
const orderController = require('../src/controllers/admin/orderController');

const created = { users: [], products: [], orders: [] };

function address() {
  return {
    fullName: 'Approval Test',
    phone: '9876543210',
    addressLine1: '1 Test Road',
    city: 'Sample City',
    state: 'Demo State',
    pincode: '000000',
  };
}

async function makeOrder({ user, product, acceptanceStatus = 'pending', orderType = 'retail', quantity = 2 }) {
  const order = await Order.create({
    userId: user._id,
    customerSnapshot: { name: user.name, email: user.email, phone: user.phone },
    orderType,
    acceptanceStatus,
    items: [{
      productId: product._id,
      productSnapshot: { name: product.name, sku: product.sku },
      quantity,
      pricePerUnit: product.retailPrice,
      totalPrice: product.retailPrice * quantity,
    }],
    subtotal: product.retailPrice * quantity,
    total: product.retailPrice * quantity,
    shippingAddress: address(),
    statusHistory: [{ status: ORDER_STATUS.PENDING_PAYMENT, note: 'Approval test' }],
  });
  created.orders.push(order._id);
  return order;
}

async function invoke(handler, req) {
  let payload;
  let error;
  await handler(req, { json(value) { payload = value; } }, (value) => { error = value; });
  if (error) throw error;
  return payload;
}

function testSchemaAndRoutes() {
  const historical = new Order();
  assert.strictEqual(historical.acceptanceStatus, null);
  for (const field of [
    'acceptedAt', 'acceptedBy', 'rejectedAt', 'rejectedBy', 'rejectionReason',
    'inventoryCommittedAt', 'inventoryReleasedAt',
  ]) {
    assert.ok(Order.schema.path(field), `Order.${field} must exist`);
  }

  for (const routePath of ['../src/routes/adminRoutes', '../src/routes/staffRoutes']) {
    const router = require(routePath);
    assert.ok(router.stack.some((layer) => layer.route?.path === '/orders/:id/accept' && layer.route.methods.put));
    assert.ok(router.stack.some((layer) => layer.route?.path === '/orders/:id/reject' && layer.route.methods.put));
  }
}

async function runLifecycle() {
  await mongoose.connect(process.env.MONGODB_URI);
  const suffix = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const buyer = await User.create({
    name: 'Approval Buyer', email: `approval-buyer-${suffix}@test.local`, phone: `9${Date.now().toString().slice(-9)}`,
    passwordHash: 'test-password-hash', role: 'buyer', isActive: true,
  });
  const admin = await User.create({
    name: 'Approval Admin', email: `approval-admin-${suffix}@test.local`, phone: `8${Date.now().toString().slice(-9)}`,
    passwordHash: 'test-password-hash', role: 'admin', isActive: true,
  });
  created.users.push(buyer._id, admin._id);

  const product = await Product.create({
    name: 'Approval Product', slug: `approval-product-${suffix}`, description: 'Order approval test', category: 'test',
    mrp: 120, retailPrice: 100, wholesalePrice: 90, sku: `APP-${suffix}`, stock: 10, status: 'active',
  });
  created.products.push(product._id);

  const acceptedOrder = await makeOrder({ user: buyer, product });
  const first = await acceptOrder({ orderId: acceptedOrder._id, actorId: admin._id });
  const second = await acceptOrder({ orderId: acceptedOrder._id, actorId: admin._id });
  assert.strictEqual(first.alreadyAccepted, false);
  assert.strictEqual(second.alreadyAccepted, true);
  assert.strictEqual((await Product.findById(product._id)).stock, 8);
  assert.strictEqual(await StockLog.countDocuments({ orderId: acceptedOrder._id, action: 'order_deduct' }), 1);

  await invoke(orderController.markPaymentCompleted, {
    params: { id: String(acceptedOrder._id) }, user: admin,
  });
  let updated = await Order.findById(acceptedOrder._id);
  assert.strictEqual(updated.status, ORDER_STATUS.PROCESSING);
  assert.strictEqual((await Product.findById(product._id)).stock, 8, 'payment must not deduct accepted inventory twice');
  assert.strictEqual((await Payment.findOne({ orderId: acceptedOrder._id })).status, PAYMENT_STATUS.VERIFIED);

  await invoke(orderController.updateOrderStatus, {
    params: { id: String(acceptedOrder._id) }, body: { status: ORDER_STATUS.CANCELLED, note: 'Test cancellation' }, user: admin,
  });
  updated = await Order.findById(acceptedOrder._id);
  assert.ok(updated.inventoryReleasedAt);
  assert.strictEqual((await Product.findById(product._id)).stock, 10);
  assert.strictEqual(await StockLog.countDocuments({ orderId: acceptedOrder._id, action: 'cancel_restore' }), 1);
  await assert.rejects(
    acceptOrder({ orderId: acceptedOrder._id, actorId: admin._id }),
    (error) => error.code === 'ORDER_NOT_REVIEWABLE',
  );

  const rejectedOrder = await makeOrder({ user: buyer, product });
  await assert.rejects(
    invoke(orderController.updateOrderStatus, {
      params: { id: String(rejectedOrder._id) },
      body: { status: ORDER_STATUS.CANCELLED, note: 'Bypass rejection' },
      user: admin,
    }),
    (error) => error.code === 'ORDER_REJECTION_REQUIRED',
  );
  await assert.rejects(
    rejectOrder({ orderId: rejectedOrder._id, actorId: admin._id, reason: '   ' }),
    (error) => error.code === 'REJECTION_REASON_REQUIRED',
  );
  await rejectOrder({ orderId: rejectedOrder._id, actorId: admin._id, reason: 'Cannot fulfil this order' });
  const rejected = await Order.findById(rejectedOrder._id);
  assert.strictEqual(rejected.acceptanceStatus, 'rejected');
  assert.strictEqual(rejected.status, ORDER_STATUS.CANCELLED);
  assert.strictEqual((await Product.findById(product._id)).stock, 10);

  const paymentRecoveryOrder = await makeOrder({ user: buyer, product });
  await acceptOrder({ orderId: paymentRecoveryOrder._id, actorId: admin._id });
  await Payment.create({
    orderId: paymentRecoveryOrder._id,
    userId: buyer._id,
    amount: paymentRecoveryOrder.total,
    method: 'upi_manual',
    status: PAYMENT_STATUS.REJECTED,
    rejectionReason: 'Unreadable proof',
  });
  await invoke(orderController.markPaymentCompleted, {
    params: { id: String(paymentRecoveryOrder._id) }, user: admin,
  });
  assert.strictEqual(
    (await Payment.findOne({ orderId: paymentRecoveryOrder._id })).status,
    PAYMENT_STATUS.VERIFIED,
  );
  assert.strictEqual(
    (await Order.findById(paymentRecoveryOrder._id)).status,
    ORDER_STATUS.PROCESSING,
  );

  const wholesale = await makeOrder({ user: buyer, product, orderType: 'wholesale', acceptanceStatus: null });
  await assert.rejects(
    acceptOrder({ orderId: wholesale._id, actorId: admin._id }),
    (error) => error.code === 'ORDER_NOT_REVIEWABLE',
  );
  assert.strictEqual((await Order.findById(wholesale._id)).acceptanceStatus, null);
}

async function cleanup() {
  if (created.orders.length) {
    await Promise.all([
      Payment.deleteMany({ orderId: { $in: created.orders } }),
      StockLog.deleteMany({ orderId: { $in: created.orders } }),
      AuditLog.deleteMany({ entityId: { $in: created.orders } }),
      Notification.deleteMany({ userId: { $in: created.users } }),
      Order.deleteMany({ _id: { $in: created.orders } }),
    ]);
  }
  if (created.products.length) await Product.deleteMany({ _id: { $in: created.products } });
  if (created.users.length) await User.deleteMany({ _id: { $in: created.users } });
  if (mongoose.connection.readyState) await mongoose.disconnect();
}

async function run() {
  testSchemaAndRoutes();
  try {
    await runLifecycle();
    console.log('Order approval tests passed');
  } finally {
    await cleanup();
  }
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
