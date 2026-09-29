#!/usr/bin/env node
/**
 * Demo seed / reset.
 *
 *   npm run demo:seed    seeds an EMPTY demo database (refuses if data exists)
 *   npm run demo:reset   wipes ALL collections of the demo database, then seeds
 *
 * The same seedDemo() function backs POST /api/v1/admin/demo/reset.
 * Every entry point calls assertDemoDatabase() first: nothing is touched
 * unless DEMO_MODE=true, the URI is a local mongod and the DB name contains
 * "demo".
 *
 * Fixtures live in scripts/demo/fixtures/*.json (versioned by manifest.json).
 * All ids are deterministic (derived from fixture keys), so user/product ids
 * are identical after every reset and existing access tokens stay valid.
 * All timestamps are relative to the moment of seeding.
 */
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');

const { assertDemoDatabase } = require('../../src/config/demoGuard');
const BRAND = require('../../src/config/brand');
const { getStorageDriver, resolveLocalPath } = require('../../src/config/storage');

const PRIVATE_ASSET_DIR = path.join(__dirname, '..', '..', 'assets', 'demo-private');

const FIXTURE_DIR = path.join(__dirname, 'fixtures');
const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

const readFixture = (name) => JSON.parse(fs.readFileSync(path.join(FIXTURE_DIR, name), 'utf8'));

// Deterministic ObjectId per (namespace, key).
const oid = (namespace, key) => new mongoose.Types.ObjectId(
  crypto.createHash('sha1').update(`tradehub-demo:${namespace}:${key}`).digest('hex').slice(0, 24),
);

// Small deterministic PRNG so analytics look the same after every reset.
function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a += 0x6D2B79F5;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function publicBaseUrl() {
  const configured = (process.env.PUBLIC_BASE_URL || '').trim().replace(/\/+$/, '');
  return configured || `http://localhost:${process.env.PORT || 5050}`;
}

// Product/category/brand images are served from assets/demo-images at /uploads/demo/*.
const imageUrl = (rel) => `${publicBaseUrl()}/uploads/demo/${rel}`;
const imagePublicId = (rel) => `demo/${rel}`;

async function ensureConnected() {
  if (mongoose.connection.readyState === 1) return;
  const uri = String(process.env.MONGODB_URI || '').trim().replace(/^['"]|['"]$/g, '');
  await mongoose.connect(uri, { serverSelectionTimeoutMS: 15000, family: 4 });
}

async function wipeAll(log) {
  const collections = await mongoose.connection.db.listCollections({}, { nameOnly: true }).toArray();
  let wiped = 0;
  for (const { name } of collections) {
    if (name.startsWith('system.')) continue;
    await mongoose.connection.db.collection(name).deleteMany({});
    wiped += 1;
  }
  log(`Wiped ${wiped} collections`);
}

async function ensureIndexes(models) {
  await Promise.all(Object.values(models).map((model) => model.createIndexes().catch(() => null)));
}

// Insert helper that keeps explicit createdAt/updatedAt values.
async function insertDoc(Model, data, createdAt) {
  const doc = new Model({ ...data, createdAt, updatedAt: createdAt });
  await doc.save({ timestamps: false });
  return doc;
}

async function seedDemo({ wipe = true, log = console.log } = {}) {
  // 1) Safety: env first (before connecting), then the live connection.
  assertDemoDatabase();
  await ensureConnected();
  assertDemoDatabase({ actualDbName: mongoose.connection.name });

  const models = require('../../src/models');
  const {
    User, Product, Negotiation, Order, Payment, Analytics, Settings, Company, Category,
    StockLog, Notification, Offer, Review, WebsiteSettings, ProductInterest, AdminNotification,
  } = models;

  if (wipe) {
    await wipeAll(log);
  } else if (await User.estimatedDocumentCount() > 0) {
    throw new Error('Database already contains data. Use "npm run demo:reset" to wipe and re-seed.');
  }
  await ensureIndexes(models);

  const manifest = readFixture('manifest.json');
  const now = new Date();
  const at = (hoursAgo) => new Date(now.getTime() - hoursAgo * HOUR);
  const counts = {};

  // 2) Brands ---------------------------------------------------------------
  const brandFixtures = readFixture('brands.json');
  const brands = {};
  for (const fx of brandFixtures) {
    brands[fx.key] = await insertDoc(Company, {
      _id: oid('brand', fx.key),
      name: fx.name,
      description: fx.description,
      logo: { url: imageUrl(fx.logo), publicId: imagePublicId(fx.logo) },
      isActive: true,
      showOnWebsite: true,
      order: fx.order,
    }, at(90 * 24));
  }
  counts.brands = brandFixtures.length;

  // 3) Categories (parents first) -------------------------------------------
  const categoryFixtures = readFixture('categories.json');
  const categories = {};
  const ordered = [...categoryFixtures.filter((c) => !c.parent), ...categoryFixtures.filter((c) => c.parent)];
  for (const fx of ordered) {
    categories[fx.key] = await insertDoc(Category, {
      _id: oid('category', fx.key),
      name: fx.name,
      nameHindi: fx.nameHindi,
      nameHindiSource: 'manual',
      company: brands[fx.brand]._id,
      parent: fx.parent ? categories[fx.parent]._id : null,
      description: fx.description,
      image: { url: imageUrl(fx.image), publicId: imagePublicId(fx.image) },
      order: fx.order,
      isActive: true,
      showOnWebsite: true,
    }, at(90 * 24));
  }
  counts.categories = categoryFixtures.length;

  // 4) Users ----------------------------------------------------------------
  const userFixtures = readFixture('users.json');
  const users = {};
  for (const fx of userFixtures) {
    const businessInfo = fx.businessInfo ? {
      businessName: fx.businessInfo.businessName,
      gstNumber: fx.businessInfo.gstNumber,
      businessAddress: fx.businessInfo.businessAddress,
      contactPerson: fx.businessInfo.contactPerson,
      shopLocation: fx.businessInfo.shopLocation
        ? { ...fx.businessInfo.shopLocation, capturedAt: at(24 * 60) }
        : undefined,
      status: fx.businessInfo.status || 'none',
      verified: Boolean(fx.businessInfo.verified),
      verifiedAt: fx.businessInfo.verified ? at((fx.businessInfo.verifiedDaysAgo || 30) * 24) : null,
      excludedCategories: [],
      // Private proof keys (files are copied into the private media store below).
      proofImageKeys: (fx.businessInfo.proofFiles || []).map((file) => `private/proofs/${oid('user', fx.key)}/${file}`),
    } : undefined;
    const acceptedAt = at(120 * 24);
    users[fx.key] = await insertDoc(User, {
      _id: oid('user', fx.key),
      name: fx.name,
      email: fx.email,
      phone: fx.phone,
      username: fx.username,
      address: fx.address || null,
      authProvider: 'email',
      passwordHash: fx.password, // hashed by the User model's pre-save hook
      role: fx.role,
      mustChangePassword: Boolean(fx.mustChangePassword),
      preferredLanguage: fx.preferredLanguage || 'en',
      businessInfo,
      phoneVerified: true,
      isActive: true,
      termsAcceptedAt: acceptedAt,
      termsVersion: '2026-08-17',
      privacyPolicyAcceptedAt: acceptedAt,
      privacyPolicyVersion: '2026-08-17',
      lastLoginAt: at(6),
    }, at((fx.businessInfo?.verifiedDaysAgo || 100) * 24));
  }
  counts.users = userFixtures.length;
  const admin = users.admin;

  // Private proof documents (local driver): copied to the private media store,
  // served to admins only through short-lived signed URLs.
  if (getStorageDriver() === 'local') {
    for (const fx of userFixtures) {
      for (const file of fx.businessInfo?.proofFiles || []) {
        const target = resolveLocalPath(`private/proofs/${oid('user', fx.key)}/${file}`, 'private');
        fs.mkdirSync(path.dirname(target), { recursive: true });
        fs.copyFileSync(path.join(PRIVATE_ASSET_DIR, file), target);
      }
    }
  }

  // 5) Products -------------------------------------------------------------
  const productFixtures = readFixture('products.json');
  const products = {};
  const initialStock = {};
  const rng = mulberry32(manifest.version.split('').reduce((sum, ch) => sum + ch.charCodeAt(0), 7));
  for (const fx of productFixtures) {
    const category = categories[fx.category];
    const brand = brands[categoryFixtures.find((c) => c.key === fx.category).brand];
    initialStock[fx.sku] = fx.stock;
    products[fx.sku] = await insertDoc(Product, {
      _id: oid('product', fx.sku),
      name: fx.name,
      nameHindi: fx.nameHindi,
      nameHindiSource: 'manual',
      description: fx.description,
      shortDescription: fx.shortDescription,
      category: category.slug,
      categoryRef: category._id,
      subCategory: category.name,
      brand: brand.name,
      company: brand._id,
      tags: fx.tags,
      mrp: fx.mrp,
      retailPrice: fx.retailPrice,
      wholesalePrice: fx.wholesalePrice,
      minWholesaleQuantity: fx.minWholesaleQuantity,
      negotiationEnabled: fx.negotiationEnabled !== false,
      sku: fx.sku,
      stock: fx.stock,
      lowStockThreshold: 20,
      priceUnit: fx.priceUnit,
      packing: fx.packing,
      images: [{
        url: imageUrl(fx.image),
        publicId: imagePublicId(fx.image),
        blurHash: null,
        isPrimary: true,
        order: 0,
      }],
      specifications: fx.specifications,
      status: 'active',
      showOnWebsite: true,
      isFeatured: Boolean(fx.isFeatured),
      isHot: Boolean(fx.isHot),
      rating: Number((4.2 + rng() * 0.7).toFixed(1)),
    }, at((20 + Math.floor(rng() * 40)) * 24));
  }
  counts.products = productFixtures.length;
  const primaryImageOf = (sku) => products[sku].primaryImage;

  // 6) Orders + payments + stock ledger ---------------------------------------
  const orderFixtures = readFixture('orders.json');
  const negotiationFixtures = readFixture('negotiations.json');
  const stockLogs = [];
  for (const fx of productFixtures) {
    stockLogs.push({
      productId: products[fx.sku]._id,
      action: 'manual_set',
      quantityChange: fx.stock,
      previousStock: 0,
      newStock: fx.stock,
      reason: 'Initial stock (demo dataset)',
      performedBy: admin._id,
      createdAt: at(40 * 24),
      updatedAt: at(40 * 24),
    });
  }

  const runningStock = { ...initialStock };
  const orders = {};
  const payments = [];
  const orderedByAge = [...orderFixtures].sort((a, b) => b.createdHoursAgo - a.createdHoursAgo);
  const actorId = (actor) => (actor === 'admin' ? admin._id : undefined);

  for (const fx of orderedByAge) {
    const user = users[fx.user];
    const items = fx.items.map((item) => {
      const product = products[item.sku];
      return {
        productId: product._id,
        variantId: null,
        productSnapshot: {
          name: product.name,
          nameHindi: product.nameHindi,
          sku: product.sku,
          image: primaryImageOf(item.sku),
        },
        variantSnapshot: { name: '', displayName: '', sku: '', attributes: [], packing: product.packing, priceUnit: product.priceUnit },
        quantity: item.quantity,
        pricePerUnit: item.pricePerUnit,
        totalPrice: item.quantity * item.pricePerUnit,
      };
    });
    const subtotal = items.reduce((sum, item) => sum + item.totalPrice, 0);
    const total = subtotal + (fx.deliveryFee || 0) - (fx.discount || 0);
    const createdAt = at(fx.createdHoursAgo);
    const latestHistory = fx.statusHistory.reduce((min, entry) => Math.min(min, entry.hoursAgo), fx.createdHoursAgo);

    const order = await insertDoc(Order, {
      _id: oid('order', fx.key),
      orderNumber: fx.number,
      userId: user._id,
      customerSnapshot: {
        name: user.name,
        email: user.email,
        phone: user.phone,
        businessName: user.businessInfo?.businessName,
      },
      orderType: fx.type,
      negotiationId: fx.negotiation ? oid('negotiation', fx.negotiation) : null,
      items,
      subtotal,
      deliveryFee: fx.deliveryFee || 0,
      discount: fx.discount || 0,
      total,
      shippingAddress: fx.shippingAddress,
      status: fx.status,
      statusHistory: fx.statusHistory.map((entry) => ({
        status: entry.status,
        note: entry.note,
        timestamp: at(entry.hoursAgo),
        updatedBy: actorId(entry.actor),
      })),
      acceptanceStatus: fx.acceptanceStatus,
      acceptedAt: fx.acceptedHoursAgo ? at(fx.acceptedHoursAgo) : null,
      acceptedBy: fx.acceptedHoursAgo ? admin._id : null,
      rejectedAt: fx.rejectedHoursAgo ? at(fx.rejectedHoursAgo) : null,
      rejectedBy: fx.rejectedHoursAgo ? admin._id : null,
      rejectionReason: fx.rejectionReason || null,
      inventoryCommittedAt: fx.inventoryCommitted ? at(fx.acceptedHoursAgo || fx.createdHoursAgo - 6) : null,
      trackingNumber: fx.trackingNumber || null,
      courierName: fx.courierName || null,
      shippedAt: fx.shippedHoursAgo ? at(fx.shippedHoursAgo) : null,
      deliveredAt: fx.deliveredHoursAgo ? at(fx.deliveredHoursAgo) : null,
      customerNote: fx.customerNote,
      adminNote: fx.adminNote,
    }, createdAt);
    await Order.updateOne({ _id: order._id }, { $set: { updatedAt: at(latestHistory) } });
    orders[fx.key] = order;

    if (fx.inventoryCommitted) {
      for (const item of items) {
        const sku = item.productSnapshot.sku;
        const previousStock = runningStock[sku];
        runningStock[sku] -= item.quantity;
        stockLogs.push({
          productId: item.productId,
          action: 'order_deduct',
          quantityChange: -item.quantity,
          previousStock,
          newStock: runningStock[sku],
          orderId: order._id,
          reason: `Order ${fx.number} confirmed - stock deducted`,
          performedBy: admin._id,
          createdAt: at(fx.acceptedHoursAgo || fx.createdHoursAgo - 6),
          updatedAt: at(fx.acceptedHoursAgo || fx.createdHoursAgo - 6),
        });
      }
    }

    if (fx.payment) {
      const paymentAt = at(fx.payment.uploadedHoursAgo || Math.max(fx.createdHoursAgo - 8, 1));
      const verified = fx.payment.status === 'verified';
      payments.push({
        paymentNumber: fx.payment.number,
        orderId: order._id,
        userId: user._id,
        amount: total,
        method: fx.payment.method,
        screenshotUrl: fx.payment.screenshot ? imageUrl(fx.payment.screenshot) : null,
        screenshotPublicId: fx.payment.screenshot ? imagePublicId(fx.payment.screenshot) : null,
        uploadedAt: fx.payment.screenshot ? paymentAt : null,
        status: fx.payment.status,
        verifiedBy: verified ? admin._id : null,
        verifiedAt: verified ? paymentAt : null,
        createdAt: paymentAt,
        updatedAt: paymentAt,
      });
    }
  }
  counts.orders = orderFixtures.length;
  for (const payment of payments) {
    await insertDoc(Payment, payment, payment.createdAt);
  }
  counts.payments = payments.length;

  // Apply the stock deductions and write the ledger.
  for (const [sku, stock] of Object.entries(runningStock)) {
    if (stock !== initialStock[sku]) {
      await Product.updateOne({ _id: products[sku]._id }, { $set: { stock } });
    }
  }
  for (const log of stockLogs) {
    await insertDoc(StockLog, log, log.createdAt);
  }
  counts.stockLogs = stockLogs.length;

  // 7) Negotiations ---------------------------------------------------------
  const negotiations = {};
  for (const fx of negotiationFixtures) {
    const product = products[fx.sku];
    const wholesaler = users[fx.wholesaler];
    const createdAt = at(fx.createdHoursAgo);
    const qty = fx.requestedQuantity;
    const history = fx.history.map((entry) => ({
      action: entry.action,
      by: entry.by,
      pricePerUnit: entry.pricePerUnit,
      totalPrice: entry.pricePerUnit !== undefined ? entry.pricePerUnit * qty : undefined,
      message: entry.message,
      messageId: entry.action === 'message' ? `${wholesaler._id}-${createdAt.getTime() + entry.hoursAfterCreate * HOUR}` : undefined,
      timestamp: new Date(createdAt.getTime() + entry.hoursAfterCreate * HOUR),
      actorId: entry.actor === 'admin' ? admin._id : null,
      actorRole: entry.actor === 'admin' ? 'admin' : null,
    }));
    const lastEvent = history[history.length - 1].timestamp;
    const negotiation = await insertDoc(Negotiation, {
      _id: oid('negotiation', fx.key),
      negotiationNumber: fx.number,
      wholesalerId: wholesaler._id,
      productId: product._id,
      variantId: null,
      productSnapshot: {
        name: product.name,
        nameHindi: product.nameHindi,
        variantName: '',
        variantDisplayName: product.name,
        price: product.wholesalePrice,
        mrp: product.mrp,
        discountPercent: null,
        discountSource: null,
        image: primaryImageOf(fx.sku),
        sku: product.sku,
        variantSku: '',
      },
      requestedQuantity: qty,
      requestedPricePerUnit: fx.requestedPricePerUnit,
      requestedTotalPrice: qty * fx.requestedPricePerUnit,
      message: fx.message,
      history,
      status: fx.status,
      currentOfferBy: fx.currentOfferBy,
      currentPricePerUnit: fx.currentPricePerUnit,
      currentTotalPrice: fx.currentPricePerUnit * qty,
      finalPricePerUnit: fx.finalPricePerUnit ?? null,
      finalTotalPrice: fx.finalPricePerUnit ? fx.finalPricePerUnit * qty : null,
      orderId: fx.order ? orders[fx.order]._id : null,
      // Explicit expiry relative to the moment of seeding.
      expiresAt: new Date(now.getTime() + fx.expiresInDays * DAY),
    }, createdAt);
    await Negotiation.updateOne({ _id: negotiation._id }, { $set: { updatedAt: lastEvent } });
    negotiations[fx.key] = negotiation;
  }
  counts.negotiations = negotiationFixtures.length;

  // Denormalised counters shown in the admin panel.
  for (const fx of productFixtures) {
    const sku = fx.sku;
    const orderCount = orderFixtures.filter((o) => o.acceptanceStatus !== 'rejected' && o.items.some((i) => i.sku === sku)).length;
    const negotiationCount = negotiationFixtures.filter((n) => n.sku === sku).length;
    await Product.updateOne({ _id: products[sku]._id }, { $set: { orderCount, negotiationCount } });
  }

  // 8) Notifications --------------------------------------------------------
  const notificationFixtures = readFixture('notifications.json');
  const resolveData = (data = {}) => {
    const out = {};
    if (data.negotiation) out.negotiationId = String(negotiations[data.negotiation]._id);
    if (data.order) {
      out.orderId = String(orders[data.order]._id);
      out.orderNumber = orderFixtures.find((o) => o.key === data.order).number;
    }
    return out;
  };
  for (const fx of notificationFixtures.user) {
    await insertDoc(Notification, {
      userId: users[fx.user]._id,
      title: fx.title,
      body: fx.body,
      type: fx.type,
      data: { type: fx.type, ...resolveData(fx.data) },
      isRead: fx.isRead,
    }, at(fx.hoursAgo));
  }
  for (const fx of notificationFixtures.admin) {
    const actor = users[fx.actor];
    await insertDoc(AdminNotification, {
      type: fx.type,
      severity: fx.severity,
      title: fx.title,
      body: fx.body,
      link: fx.link,
      actor: { id: actor._id, name: actor.name, role: actor.role },
      metadata: {},
      readBy: fx.read ? [admin._id] : [],
    }, at(fx.hoursAgo));
  }
  counts.notifications = notificationFixtures.user.length;
  counts.adminNotifications = notificationFixtures.admin.length;

  // 9) Analytics events -----------------------------------------------------
  const analyticsFx = readFixture('analytics.json');
  const arng = mulberry32(analyticsFx.seed);
  const customerUsers = Object.values(users).filter((u) => ['buyer', 'wholesaler'].includes(u.role));
  const sourceEntries = Object.entries(analyticsFx.sources);
  const pickSource = () => {
    let roll = arng();
    for (const [name, weight] of sourceEntries) {
      roll -= weight;
      if (roll <= 0) return name;
    }
    return 'direct';
  };
  const platforms = ['android', 'ios', 'web'];
  const events = [];
  const pushEvent = (product, eventType, when, userId = null) => {
    events.push({
      productId: product._id,
      userId,
      eventType,
      source: pickSource(),
      sessionId: `demo-${Math.floor(arng() * 1e9).toString(36)}`,
      deviceInfo: { platform: platforms[Math.floor(arng() * platforms.length)], appVersion: '1.0.0' },
      timestamp: when,
    });
  };
  const randomWhen = () => {
    // Recent days are busier; business hours favoured.
    const dayOffset = Math.floor(Math.pow(arng(), 1.4) * analyticsFx.windowDays);
    const d = new Date(now.getTime() - dayOffset * DAY);
    d.setHours(8 + Math.floor(arng() * 12), Math.floor(arng() * 60), Math.floor(arng() * 60), 0);
    return d > now ? new Date(now.getTime() - Math.floor(arng() * 5) * HOUR - 60000) : d;
  };
  const randomUser = () => (arng() < 0.6 ? customerUsers[Math.floor(arng() * customerUsers.length)]._id : null);
  const viewsBySku = {};
  for (const fx of productFixtures) {
    const profile = analyticsFx.profiles[fx.sku] || analyticsFx.defaultProfile;
    const product = products[fx.sku];
    for (let i = 0; i < profile.views; i += 1) pushEvent(product, 'view', randomWhen(), randomUser());
    for (let i = 0; i < profile.cartAdds; i += 1) pushEvent(product, 'cart_add', randomWhen(), randomUser());
    for (let i = 0; i < profile.wishlistAdds; i += 1) pushEvent(product, 'wishlist_add', randomWhen(), randomUser());
    for (let i = 0; i < profile.shares; i += 1) pushEvent(product, 'share', randomWhen(), randomUser());
    viewsBySku[fx.sku] = profile.views;
  }
  for (const fx of negotiationFixtures) {
    pushEvent(products[fx.sku], 'negotiation_start', at(fx.createdHoursAgo), users[fx.wholesaler]._id);
  }
  for (const fx of orderFixtures) {
    if (fx.acceptanceStatus === 'rejected') continue;
    for (const item of fx.items) {
      pushEvent(products[item.sku], 'purchase', at(fx.createdHoursAgo), users[fx.user]._id);
    }
  }
  await Analytics.insertMany(events, { ordered: false });
  counts.analyticsEvents = events.length;
  for (const [sku, views] of Object.entries(viewsBySku)) {
    await Product.updateOne({ _id: products[sku]._id }, { $set: { viewCount: views } });
  }

  // Lead interest rows (admin "Potential customers" page).
  const interestFixtures = readFixture('interests.json');
  for (const fx of interestFixtures) {
    const lastViewedAt = new Date(now.getTime() - fx.lastViewedMinutesAgo * 60 * 1000);
    await insertDoc(ProductInterest, {
      userId: users[fx.user]._id,
      productId: products[fx.sku]._id,
      viewCount: fx.viewCount,
      totalWatchSeconds: fx.totalWatchSeconds,
      firstViewedAt: new Date(lastViewedAt.getTime() - 2 * HOUR),
      lastViewedAt,
    }, lastViewedAt);
  }
  counts.productInterests = interestFixtures.length;

  // 10) Marketing content, settings ---------------------------------------
  const marketing = readFixture('marketing.json');
  for (const fx of marketing.reviews) {
    await insertDoc(Review, { ...fx, isActive: true }, at(24 * 10));
  }
  counts.reviews = marketing.reviews.length;
  for (const fx of marketing.offers) {
    const { endInDays, ...rest } = fx;
    await insertDoc(Offer, { ...rest, isActive: true, startDate: at(24 * 5), endDate: new Date(now.getTime() + endInDays * DAY) }, at(24 * 5));
  }
  counts.offers = marketing.offers.length;

  const settings = await Settings.getSettings();
  settings.businessName = BRAND.name;
  settings.businessPhone = BRAND.phone;
  settings.businessEmail = BRAND.email;
  settings.businessAddress = BRAND.address;
  settings.upiId = 'demo@upi';
  settings.upiDisplayName = `${BRAND.name} Payments`;
  settings.bankName = 'Demo Bank';
  settings.bankAccountNumber = '000000000000';
  settings.bankIfscCode = 'DEMO0000000';
  settings.bankAccountHolderName = BRAND.legalName;
  settings.socialLinks = {};
  settings.heroBanners = marketing.heroBanners.map((b) => ({
    title: b.title, subtitle: b.subtitle, tag: b.tag, imageUrl: imageUrl(b.image),
    mediaType: 'image', buttonText: b.buttonText, isActive: true, order: b.order,
  }));
  settings.promoBanners = marketing.promoBanners.map((b) => ({
    title: b.title, subtitle: b.subtitle, tag: b.tag, imageUrl: imageUrl(b.image),
    buttonText: b.buttonText, isActive: true, order: b.order,
  }));
  settings.demo = { seededAt: now, fixtureVersion: manifest.version };
  await settings.save();

  const website = await WebsiteSettings.getSettings();
  website.heroCards = productFixtures.filter((p) => p.isFeatured).slice(0, 5).map((p, order) => ({ image: imageUrl(p.image), order }));
  while (website.heroCards.length < 5) website.heroCards.push({ image: '', order: website.heroCards.length });
  await website.save();

  // 11) Recompute category/brand product counts ---------------------------------
  for (const [key, category] of Object.entries(categories)) {
    const productCount = await Product.countDocuments({ categoryRef: category._id });
    await Category.updateOne({ _id: category._id }, { $set: { productCount } });
  }
  for (const [, category] of Object.entries(categories)) {
    if (category.parent) continue;
    const childIds = Object.values(categories).filter((c) => String(c.parent) === String(category._id)).map((c) => c._id);
    const total = await Product.countDocuments({ categoryRef: { $in: [category._id, ...childIds] } });
    await Category.updateOne({ _id: category._id }, { $set: { productCount: total } });
  }
  for (const brand of Object.values(brands)) {
    await Company.updateOne({ _id: brand._id }, { $set: { productCount: await Product.countDocuments({ company: brand._id }) } });
  }

  log(`Seeded demo dataset v${manifest.version} (${Object.entries(counts).map(([k, v]) => `${k}=${v}`).join(', ')})`);
  return { counts, seededAt: now.toISOString(), version: manifest.version };
}

module.exports = { seedDemo, wipeAll, oid, readFixture };

// CLI ----------------------------------------------------------------------
if (require.main === module) {
  require('dotenv').config({ path: path.join(__dirname, '..', '..', '.env') });
  const args = process.argv.slice(2);
  // These scripts only ever run against a demo database; the guard below
  // still rejects anything that is not a local "*demo*" database.
  if (!process.env.DEMO_MODE) process.env.DEMO_MODE = 'true';
  if (!process.env.MONGODB_URI) process.env.MONGODB_URI = 'mongodb://127.0.0.1:27017/tradehub_demo?replicaSet=rs0';
  const wipe = args.includes('--wipe') || args.includes('--reset');

  seedDemo({ wipe })
    .then(() => mongoose.disconnect())
    .then(() => process.exit(0))
    .catch(async (error) => {
      console.error(`\nDemo seed failed: ${error.message}`);
      try { await mongoose.disconnect(); } catch (_) { /* ignore */ }
      process.exit(1);
    });
}
