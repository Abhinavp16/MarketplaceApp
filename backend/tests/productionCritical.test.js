const assert = require('assert');
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');

function readSource(relativePath) {
  return fs.readFileSync(path.join(__dirname, '..', relativePath), 'utf8');
}

function testAnalyticsConversionWindow() {
  const source = readSource('src/controllers/admin/analyticsController.js');
  const leadRules = require('../src/utils/leadInterest');
  assert.strictEqual(leadRules.LEAD_DELAY_MINUTES, 10, 'leads must appear 10 minutes after the last view');
  assert.strictEqual(leadRules.LEAD_RETENTION_DAYS, 5, 'leads must be kept for 5 days after the last view');
  assert.ok(
    source.includes('LEAD_DELAY_MINUTES * 60 * 1000'),
    'potential-customer delay must come from the shared lead rules',
  );
  assert.ok(
    !source.includes('revert to 6 * 60 * 60 * 1000 after testing'),
    'testing TODO must not remain',
  );
}

function testAdminNegotiationSearch() {
  const source = readSource('src/controllers/admin/negotiationController.js');
  assert.ok(source.includes('query.$or = or;'), 'admin search must apply to the query');
  assert.ok(source.includes('negotiationNumber'), 'search must cover negotiation numbers');
  assert.ok(source.includes('productSnapshot.name'), 'search must cover product names');
  assert.ok(
    source.includes('wholesalerId: { $in:'),
    'search must resolve wholesaler names via User lookup',
  );
}

function testCategoryListTotal() {
  const source = readSource('src/controllers/categoryController.js');
  assert.ok(
    source.includes('formatPaginationResponse(categoriesWithCounts, total, page, limit)'),
    'category list must report the real total, not the page length',
  );
  assert.ok(
    source.includes('paginate(req.query.page, req.query.limit, 500)'),
    'category list must allow management-size pages',
  );
}

function testCategoryBrandHierarchyIntegrity() {
  const categoryController = readSource('src/controllers/categoryController.js');
  assert.ok(
    categoryController.includes('Parent category must belong to the same brand'),
    'category writes must reject cross-brand parent relationships',
  );
  assert.ok(
    categoryController.includes('getDescendantCategoryIds(category._id)'),
    'moving a category between brands must collect its descendants',
  );
  assert.ok(
    categoryController.includes("{ categoryRef: { $in: descendantCategoryIds } }"),
    'moving a category between brands must move descendant products',
  );
}

function testReviewSearchFields() {
  const source = readSource('src/controllers/admin/reviewController.js');
  assert.ok(source.includes('{ name:'), 'review search must query names');
  assert.ok(source.includes('{ role:'), 'review search must query roles');
  assert.ok(source.includes('{ review:'), 'review search must query review text');
  assert.ok(!source.includes('comment:'), 'review search must not use dead fields');
}

async function testPublicHindiWriteIsRemoved() {
  const productRoutes = require('../src/routes/productRoutes');
  const exposed = productRoutes.stack.some((layer) => (
    layer.route?.path === '/:id/hindi-name' && layer.route.methods.patch
  ));
  assert.strictEqual(exposed, false, 'public Hindi-name PATCH must not be registered');
}

function testNegotiationOrderIndexIsUnique() {
  const Order = require('../src/models/Order');
  const index = Order.schema.indexes().find(([fields]) => fields.negotiationId === 1);
  assert.ok(index, 'negotiationId index must exist');
  assert.strictEqual(index[1].unique, true, 'negotiationId index must be unique');
  assert.deepStrictEqual(
    index[1].partialFilterExpression,
    { negotiationId: { $type: 'objectId' } },
    'negotiationId index must exclude null values',
  );
}

async function testMissingSmtpFailsWithoutLoggingSecrets() {
  const originalEnv = {
    SMTP_HOST: process.env.SMTP_HOST,
    SMTP_USER: process.env.SMTP_USER,
    SMTP_PASS: process.env.SMTP_PASS,
  };
  const originalLog = console.log;
  const logs = [];
  delete process.env.SMTP_HOST;
  delete process.env.SMTP_USER;
  delete process.env.SMTP_PASS;
  console.log = (...args) => logs.push(args.join(' '));

  try {
    const { sendMagicLinkEmail } = require('../src/services/emailService');
    await assert.rejects(
      sendMagicLinkEmail('admin@example.com', 'https://admin.example/login?token=secret-token'),
      (error) => error.statusCode === 503 && error.code === 'MAGIC_LINK_EMAIL_UNAVAILABLE',
    );
    assert.ok(!logs.join('\n').includes('secret-token'), 'magic token must never be logged');
    assert.ok(!logs.join('\n').includes('admin@example.com'), 'fallback must not log recipient data');
  } finally {
    console.log = originalLog;
    for (const [key, value] of Object.entries(originalEnv)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
}

async function testMagicLinkTokenLifecycle() {
  const { consumeMagicLink, issueMagicLink, hashMagicToken } = require('../src/services/magicLinkService');
  const records = [{ _id: 'old', email: 'admin@example.com', used: false, createdAt: new Date(1) }];
  const deleted = [];
  const tokenStore = {
    async create(data) {
      const record = { ...data, _id: `new-${records.length}`, used: false, createdAt: new Date(2) };
      records.push(record);
      return record;
    },
    async deleteOne(query) {
      deleted.push(query._id);
    },
    async updateOne(query, update) {
      assert.strictEqual(query._id, 'new-1');
      assert.ok(update.$set.deliveredAt instanceof Date);
    },
    async deleteMany(query) {
      assert.strictEqual(query.email, 'admin@example.com');
      assert.strictEqual(query._id.$lt, 'new-1');
      assert.deepStrictEqual(query.deliveredAt, { $ne: null });
    },
  };

  let deliveredLink = '';
  const candidate = await issueMagicLink({
    email: 'admin@example.com',
    panelUrl: 'https://admin.example',
    expiryMinutes: 5,
    tokenStore,
    randomBytes: () => Buffer.from('raw-token'),
    sendEmail: async (_email, link) => { deliveredLink = link; },
  });
  assert.ok(deliveredLink.endsWith('token=7261772d746f6b656e'));
  assert.strictEqual(candidate.tokenHash, hashMagicToken('7261772d746f6b656e'));
  assert.ok(!JSON.stringify(candidate).includes('token=') && !JSON.stringify(candidate).includes('raw-token'));
  assert.ok(candidate.deliveredAt instanceof Date);
  assert.deepStrictEqual(deleted, []);

  await assert.rejects(
    issueMagicLink({
      email: 'admin@example.com',
      panelUrl: 'https://admin.example',
      expiryMinutes: 5,
      tokenStore: {
        ...tokenStore,
        async updateOne() {
          throw new Error('delivery failure must not mark a token delivered');
        },
      },
      randomBytes: () => Buffer.from('failed-token'),
      sendEmail: async () => { throw new Error('mail unavailable'); },
    }),
    /mail unavailable/,
  );
  assert.deepStrictEqual(deleted, ['new-2'], 'failed candidate must be removed without deleting old tokens');

  let consumable = { _id: 'single-use-token' };
  const consumableStore = {
    async findOneAndDelete() {
      const claimed = consumable;
      consumable = null;
      return claimed;
    },
  };
  const claims = await Promise.all([
    consumeMagicLink('one-time-token', consumableStore),
    consumeMagicLink('one-time-token', consumableStore),
  ]);
  assert.strictEqual(claims.filter(Boolean).length, 1, 'a magic link can only be claimed once');
}

async function testNegotiationAcceptanceStatesAndIdempotency() {
  const models = require('../src/models');
  const auditService = require('../src/services/auditService');
  const notificationService = require('../src/services/notificationService');
  const originals = {
    negotiationFindById: models.Negotiation.findById,
    negotiationFindOneAndUpdate: models.Negotiation.findOneAndUpdate,
    negotiationUpdateOne: models.Negotiation.updateOne,
    orderFindById: models.Order.findById,
    orderFindOne: models.Order.findOne,
    orderCreate: models.Order.create,
    orderDeleteOne: models.Order.deleteOne,
    productFindById: models.Product.findById,
    productFindByIdAndUpdate: models.Product.findByIdAndUpdate,
    userFindById: models.User.findById,
    recordAudit: auditService.recordAudit,
    sendToUser: notificationService.sendToUser,
  };
  let sideEffectCount = 0;
  auditService.recordAudit = async () => { sideEffectCount += 1; };
  notificationService.sendToUser = async () => {};
  const servicePath = require.resolve('../src/services/negotiationOrderService');
  delete require.cache[servicePath];
  const { acceptNegotiationAndCreateOrder } = require(servicePath);

  const ids = {
    negotiation: new mongoose.Types.ObjectId(),
    product: new mongoose.Types.ObjectId(),
    wholesaler: new mongoose.Types.ObjectId(),
    actor: new mongoose.Types.ObjectId(),
  };
  const address = {
    fullName: 'Test Buyer',
    phone: '9135724680',
    addressLine1: '1 Test Road',
    city: 'Sample City',
    state: 'Demo State',
    pincode: '492001',
  };

  function configure(status, currentOfferBy = 'wholesaler', expiresAt = new Date(Date.now() + 60000), options = {}) {
    let order = options.order || null;
    let orderCreates = 0;
    let finalized = false;
    let createdPayload = null;
    const negotiation = {
      _id: ids.negotiation,
      negotiationNumber: 'NEG-TEST',
      wholesalerId: ids.wholesaler,
      productId: ids.product,
      productSnapshot: { name: 'Test Product' },
      requestedQuantity: 5,
      currentOfferBy,
      currentPricePerUnit: 90,
      currentTotalPrice: 450,
      finalPricePerUnit: options.finalPricePerUnit ?? null,
      finalTotalPrice: options.finalTotalPrice ?? null,
      status,
      expiresAt,
      orderId: options.orderId || order?._id || null,
      history: options.history || [],
    };
    const product = {
      _id: ids.product,
      name: 'Test Product',
      sku: 'TEST-1',
      stock: 50,
      minWholesaleQuantity: 1,
    };
    const wholesaler = {
      _id: ids.wholesaler,
      name: 'Test Buyer',
      email: 'buyer@example.com',
      phone: '9135724680',
      businessInfo: {},
    };

    models.Negotiation.findById = async () => negotiation;
    models.Negotiation.updateOne = async () => {
      negotiation.status = 'expired';
    };
    models.Negotiation.findOneAndUpdate = async (query, update) => {
      if (update.$set.status === 'accepted' && update.$set.orderId === null) {
        if (String(query.orderId) !== String(negotiation.orderId)) return null;
        Object.assign(negotiation, update.$set);
        return negotiation;
      }
      if (query.expiresAt && negotiation.expiresAt <= new Date()) return null;
      if (finalized || !['pending', 'countered', 'accepted'].includes(negotiation.status) || negotiation.orderId) return null;
      finalized = true;
      Object.assign(negotiation, update.$set);
      if (update.$push?.history) negotiation.history.push(update.$push.history);
      return negotiation;
    };
    models.Order.findOne = () => ({ lean: async () => order });
    models.Order.findById = (id) => ({
      lean: async () => (order && String(order._id) === String(id) ? order : null),
    });
    models.Order.create = async (payload) => {
      if (order) {
        const duplicate = new Error('duplicate negotiation order');
        duplicate.code = 11000;
        throw duplicate;
      }
      orderCreates += 1;
      createdPayload = payload;
      order = { ...payload, _id: new mongoose.Types.ObjectId(), orderNumber: 'ORD-TEST' };
      return order;
    };
    models.Order.deleteOne = async () => {};
    models.Product.findById = async () => product;
    models.Product.findByIdAndUpdate = async () => product;
    models.User.findById = async () => wholesaler;
    return {
      negotiation,
      getOrderCreates: () => orderCreates,
      getCreatedPayload: () => createdPayload,
    };
  }

  const request = {
    negotiationId: ids.negotiation,
    actor: { id: ids.actor, role: 'admin', name: 'Test Admin' },
    shippingAddress: address,
  };

  try {
    for (const [status, offerBy] of [['pending', 'wholesaler'], ['countered', 'admin']]) {
      sideEffectCount = 0;
      const state = configure(status, offerBy);
      const first = await acceptNegotiationAndCreateOrder(request);
      const second = await acceptNegotiationAndCreateOrder(request);
      assert.strictEqual(first.negotiation.status, 'converted');
      assert.strictEqual(first.order.statusHistory[0].status, 'pending_payment');
      assert.strictEqual(second.alreadyConverted, true);
      assert.strictEqual(state.getOrderCreates(), 1, `${status} acceptance must create one order`);
      assert.strictEqual(sideEffectCount, 1, `${status} acceptance side effects must run once`);
    }

    for (const status of ['converted', 'rejected', 'expired']) {
      configure(status);
      await assert.rejects(
        acceptNegotiationAndCreateOrder(request),
        (error) => error.code === 'INVALID_NEGOTIATION_STATUS',
      );
    }

    configure('pending', 'admin', new Date(Date.now() - 1000));
    await assert.rejects(
      acceptNegotiationAndCreateOrder(request),
      (error) => error.code === 'NEGOTIATION_EXPIRED',
    );

    configure('countered', 'admin');
    const staffResult = await acceptNegotiationAndCreateOrder({
      ...request,
      actor: { id: ids.actor, role: 'staff', name: 'Test Staff' },
    });
    assert.strictEqual(staffResult.alreadyConverted, false);

    sideEffectCount = 0;
    const acceptedHistory = [{ action: 'accepted', pricePerUnit: 85, totalPrice: 425 }];
    const legacyAccepted = configure('accepted', 'admin', new Date(Date.now() - 1000), {
      finalPricePerUnit: 85,
      finalTotalPrice: 425,
      history: acceptedHistory,
    });
    const recoveredLegacy = await acceptNegotiationAndCreateOrder(request);
    assert.strictEqual(recoveredLegacy.negotiation.status, 'converted');
    assert.strictEqual(recoveredLegacy.order.items[0].pricePerUnit, 85);
    assert.strictEqual(recoveredLegacy.order.total, 425);
    assert.strictEqual(legacyAccepted.negotiation.history.length, 1, 'legacy recovery must not append another accepted event');
    assert.strictEqual(legacyAccepted.getOrderCreates(), 1);

    sideEffectCount = 0;
    const danglingId = new mongoose.Types.ObjectId();
    const dangling = configure('converted', 'admin', new Date(Date.now() - 1000), {
      orderId: danglingId,
      finalPricePerUnit: 80,
      finalTotalPrice: 400,
      history: [{ action: 'accepted', pricePerUnit: 80, totalPrice: 400 }],
    });
    const recoveredDangling = await acceptNegotiationAndCreateOrder(request);
    assert.strictEqual(recoveredDangling.negotiation.status, 'converted');
    assert.notStrictEqual(String(recoveredDangling.order._id), String(danglingId));
    assert.strictEqual(dangling.negotiation.history.length, 1, 'dangling-link recovery must preserve accepted history');
    assert.strictEqual(dangling.getCreatedPayload().items[0].pricePerUnit, 80);

    sideEffectCount = 0;
    const validOrder = { _id: new mongoose.Types.ObjectId(), orderNumber: 'ORD-EXISTING' };
    const converted = configure('converted', 'admin', new Date(Date.now() - 1000), { order: validOrder });
    const existing = await acceptNegotiationAndCreateOrder(request);
    assert.strictEqual(existing.alreadyConverted, true);
    assert.strictEqual(existing.order, validOrder);
    assert.strictEqual(converted.getOrderCreates(), 0);
    assert.strictEqual(sideEffectCount, 0, 'idempotent conversion must not repeat side effects');

    sideEffectCount = 0;
    const concurrent = configure('countered', 'admin');
    const results = await Promise.all([
      acceptNegotiationAndCreateOrder(request),
      acceptNegotiationAndCreateOrder(request),
    ]);
    assert.strictEqual(concurrent.getOrderCreates(), 1);
    assert.strictEqual(results.filter((result) => result.alreadyConverted === false).length, 1);
    assert.strictEqual(sideEffectCount, 1);
  } finally {
    models.Negotiation.findById = originals.negotiationFindById;
    models.Negotiation.findOneAndUpdate = originals.negotiationFindOneAndUpdate;
    models.Negotiation.updateOne = originals.negotiationUpdateOne;
    models.Order.findById = originals.orderFindById;
    models.Order.findOne = originals.orderFindOne;
    models.Order.create = originals.orderCreate;
    models.Order.deleteOne = originals.orderDeleteOne;
    models.Product.findById = originals.productFindById;
    models.Product.findByIdAndUpdate = originals.productFindByIdAndUpdate;
    models.User.findById = originals.userFindById;
    auditService.recordAudit = originals.recordAudit;
    notificationService.sendToUser = originals.sendToUser;
  }
}

async function testNegotiationOrderDeletionIsProtected() {
  const models = require('../src/models');
  const originalFindById = models.Order.findById;
  const originalPaymentFindOne = models.Payment.findOne;
  const orderController = require('../src/controllers/admin/orderController');
  let paymentQueried = false;
  const order = {
    _id: new mongoose.Types.ObjectId(),
    negotiationId: new mongoose.Types.ObjectId(),
    status: 'cancelled',
  };

  models.Order.findById = () => ({ lean: async () => order });
  models.Payment.findOne = () => {
    paymentQueried = true;
    return { lean: async () => null };
  };

  try {
    let receivedError;
    await orderController.deleteOrder(
      { params: { id: String(order._id) } },
      { json() { throw new Error('protected order must not be deleted'); } },
      (error) => { receivedError = error; },
    );
    assert.strictEqual(receivedError?.code, 'NEGOTIATION_ORDER_DELETE_NOT_ALLOWED');
    assert.match(receivedError?.message || '', /negotiations cannot be deleted/i);
    assert.strictEqual(paymentQueried, false, 'protected deletion must stop before related records are touched');
  } finally {
    models.Order.findById = originalFindById;
    models.Payment.findOne = originalPaymentFindOne;
  }
}

async function run() {
  await testPublicHindiWriteIsRemoved();
  testNegotiationOrderIndexIsUnique();
  await testMissingSmtpFailsWithoutLoggingSecrets();
  await testMagicLinkTokenLifecycle();
  await testNegotiationAcceptanceStatesAndIdempotency();
  await testNegotiationOrderDeletionIsProtected();
  testAnalyticsConversionWindow();
  testAdminNegotiationSearch();
  testReviewSearchFields();
  testCategoryListTotal();
  testCategoryBrandHierarchyIntegrity();
  console.log('Production critical regression tests passed');
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
