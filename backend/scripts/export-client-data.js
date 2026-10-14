#!/usr/bin/env node
/**
 * Human-readable export of one client's business data: CSV files plus one XLSX
 * workbook (one sheet per dataset). Read-only; it never writes to the database.
 *
 *   node scripts/export-client-data.js --out <dir> [--slug <slug>] [--db <name>]
 *        [--clients-dir <dir>] [--formats csv,xlsx]
 *   npm run export:client-data -- --out ./export
 *
 * Datasets: products, products_catalog_import (importer template format), brands, categories, customers, orders, order items,
 * order status history, payments, negotiations (requirements), negotiation
 * history, price history (PriceChangeAudit), stock logs. A counts.json with the
 * row count of every dataset is written next to the files.
 *
 * Secrets are never exported: customer rows are built from an explicit allow-list
 * of fields (no password hashes, tokens, refresh tokens, FCM tokens, Google ids,
 * private proof-image keys), and payments leave out screenshot links.
 *
 * Safety: the database is taken from MONGODB_URI. The script refuses to run when
 *  - --db is given and differs from the connected database,
 *  - --slug is given and that client's declared MONGO_DB_NAME (deploy/clients/<slug>/.env,
 *    when that folder is reachable) differs from the connected database,
 *  - the connected database is declared by a DIFFERENT client in deploy/clients/*.
 * Inside the deploy stack the clients folder is not available, so export-client.sh
 * passes --slug and --db explicitly.
 */
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');

// ----------------------------------------------------------------------------
// Safety checks (pure, exported for tests)
// ----------------------------------------------------------------------------

const stripQuotes = (value) => String(value || '').trim().replace(/^["']|["']$/g, '');

/** Reads MONGO_DB_NAME from every <clientsDir>/<slug>/.env. Returns { slug: dbName }. */
function readDeclaredDatabases(clientsDir) {
  const declared = {};
  if (!clientsDir || !fs.existsSync(clientsDir)) return declared;
  for (const entry of fs.readdirSync(clientsDir, { withFileTypes: true })) {
    if (!entry.isDirectory() || entry.name === 'example') continue;
    const envFile = path.join(clientsDir, entry.name, '.env');
    if (!fs.existsSync(envFile)) continue;
    const match = fs.readFileSync(envFile, 'utf8').match(/^MONGO_DB_NAME=(.*)$/m);
    if (match) declared[entry.name] = stripQuotes(match[1]);
  }
  return declared;
}

/**
 * Throws when exporting `connectedDb` would risk mixing up clients.
 * declared: { slug: dbName } from readDeclaredDatabases (may be empty).
 */
function assertSafeTarget({ connectedDb, explicitDb = null, slug = null, declared = {} }) {
  if (!connectedDb) throw new Error('Could not determine the connected database name');
  if (explicitDb && explicitDb !== connectedDb) {
    throw new Error(`--db "${explicitDb}" does not match the connected database "${connectedDb}"`);
  }
  if (slug) {
    if (Object.prototype.hasOwnProperty.call(declared, slug) && declared[slug] !== connectedDb) {
      throw new Error(`Client "${slug}" declares database "${declared[slug]}", but the connected database is "${connectedDb}"`);
    }
  }
  const owners = Object.keys(declared).filter((name) => declared[name] === connectedDb);
  const foreign = owners.filter((name) => name !== slug);
  if (foreign.length > 0) {
    throw new Error(
      `The connected database "${connectedDb}" belongs to client "${foreign[0]}". `
      + `Pass --slug ${foreign[0]} (and --db ${connectedDb}) if you really mean to export that client.`,
    );
  }
  return true;
}

// ----------------------------------------------------------------------------
// Cell formatting
// ----------------------------------------------------------------------------

const iso = (value) => {
  if (!value) return '';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '' : date.toISOString();
};
const text = (value) => (value === undefined || value === null ? '' : String(value));
const yesNo = (value) => (value ? 'yes' : 'no');
const idOf = (value) => (value ? String(value) : '');

/** CSV cell: quotes when needed, and neutralises spreadsheet formulas (CSV injection). */
function csvCell(value) {
  if (value === undefined || value === null) return '';
  let out = typeof value === 'boolean' ? (value ? 'true' : 'false') : String(value);
  if (typeof value !== 'number' && /^[=+@\t\r]/.test(out)) out = `'${out}`;
  if (typeof value !== 'number' && /^-/.test(out) && !/^-?\d+(\.\d+)?$/.test(out)) out = `'${out}`;
  if (/[",\r\n]/.test(out)) out = `"${out.replace(/"/g, '""')}"`;
  return out;
}

// ----------------------------------------------------------------------------
// Output sinks
// ----------------------------------------------------------------------------

function openCsv(filePath, headers) {
  const stream = fs.createWriteStream(filePath, { encoding: 'utf8' });
  stream.write('﻿'); // BOM so Excel reads UTF-8 correctly
  stream.write(`${headers.map(csvCell).join(',')}\r\n`);
  return {
    write: (row) => stream.write(`${row.map(csvCell).join(',')}\r\n`),
    close: () => new Promise((resolve, reject) => {
      stream.on('error', reject);
      stream.end(resolve);
    }),
  };
}

function openSheet(workbook, name, headers) {
  const sheet = workbook.addWorksheet(name.slice(0, 31), { views: [{ state: 'frozen', ySplit: 1 }] });
  const headerRow = sheet.addRow(headers);
  headerRow.font = { bold: true };
  headerRow.commit();
  return {
    write: (row) => sheet.addRow(row.map((cell) => (cell === undefined ? null : cell))).commit(),
    close: async () => { await sheet.commit(); },
  };
}

// ----------------------------------------------------------------------------
// Datasets
// ----------------------------------------------------------------------------

function cursorOf(query) {
  return query.lean().cursor();
}

async function loadLookups(models) {
  const { User, Product, Company, Category, Order } = models;
  const map = async (Model, fields, build) => {
    const out = new Map();
    for await (const doc of Model.find({}).select(fields).lean().cursor()) out.set(String(doc._id), build(doc));
    return out;
  };
  return {
    users: await map(User, 'name email phone role businessInfo.businessName', (u) => ({
      name: u.name || '', email: u.email || '', phone: u.phone || '', role: u.role || '',
      business: (u.businessInfo && u.businessInfo.businessName) || '',
    })),
    products: await map(Product, 'name sku', (p) => ({ name: p.name || '', sku: p.sku || '' })),
    companies: await map(Company, 'name', (c) => c.name || ''),
    categories: await map(Category, 'name parent', (c) => ({ name: c.name || '', parent: c.parent ? String(c.parent) : '' })),
    orders: await map(Order, 'orderNumber', (o) => o.orderNumber || ''),
  };
}

// A dataset: { key, sheet, headers, rows(models, lookups) -> async iterable of arrays }
function buildDatasets() {
  const datasets = [];
  const add = (dataset) => datasets.push(dataset);

  add({
    key: 'products',
    sheet: 'Products',
    headers: [
      'Product ID', 'SKU', 'Name', 'Hindi name', 'Brand', 'Category', 'Sub category', 'Status',
      'Show on website', 'Featured', 'Hot', 'Coming soon', 'Coming soon: show price', 'Coming soon: expected date',
      'MRP', 'Retail price', 'Wholesale price', 'Pending retail price', 'Pending wholesale price', 'Price change effective at',
      'Min wholesale qty', 'Min customer qty', 'Negotiation enabled', 'Price unit', 'Pack', 'Stock', 'Low stock threshold',
      'Track inventory', 'Tags', 'Short description', 'Description', 'Image URLs', 'Created at', 'Updated at',
    ],
    async* rows({ Product }, lookups) {
      for await (const p of cursorOf(Product.find({}).sort({ createdAt: 1 }))) {
        const cs = p.comingSoon || {};
        yield [
          idOf(p._id), text(p.sku), text(p.name), text(p.nameHindi),
          p.company ? (lookups.companies.get(String(p.company)) || text(p.brand)) : text(p.brand),
          text(p.category), text(p.subCategory), text(p.status),
          yesNo(p.showOnWebsite), yesNo(p.isFeatured), yesNo(p.isHot),
          yesNo(cs.enabled), cs.enabled ? yesNo(cs.showPrice) : '', iso(cs.expectedDate),
          p.mrp, p.retailPrice, p.wholesalePrice,
          p.pendingRetailPrice ?? '', p.pendingWholesalePrice ?? '', iso(p.priceChangeEffectiveAt),
          p.minWholesaleQuantity, p.minCustomerQuantity, yesNo(p.negotiationEnabled), text(p.priceUnit), text(p.packing),
          p.stock, p.lowStockThreshold, yesNo(p.trackInventory),
          (p.tags || []).join('; '), text(p.shortDescription), text(p.description),
          (p.images || []).map((image) => image.url).join(' | '),
          iso(p.createdAt), iso(p.updatedAt),
        ];
      }
    },
  });

  // Same columns as the catalog import template (docs/catalog-import-sample.csv), so a
  // client's catalog can be loaded into another stack with `npm run catalog:import`.
  const yn = (value) => (value ? 'Yes' : 'No');
  const categoryPath = (lookups, p) => {
    const names = [];
    let id = p.categoryRef ? String(p.categoryRef) : '';
    for (let guard = 0; id && guard < 10; guard += 1) {
      const category = lookups.categories.get(id);
      if (!category) break;
      names.unshift(category.name);
      id = category.parent;
    }
    return names.length ? names.join(' > ') : text(p.category);
  };
  add({
    key: 'products_catalog_import',
    sheet: 'Catalog import format',
    headers: [
      'SKU', 'Name', 'Hindi Name', 'Brand', 'Category', 'Subcategory', 'Description', 'Short Description', 'MRP', 'Retail Price',
      'Wholesale Price', 'Min Wholesale Qty', 'Min Customer Qty', 'Unit', 'Packing', 'Pack Type', 'Pack Size', 'Stock',
      'Low Stock Alert', 'Status', 'Negotiation', 'Featured', 'Hot', 'Tags',
    ],
    async* rows({ Product }, lookups) {
      for await (const p of cursorOf(Product.find({}).sort({ createdAt: 1 }))) {
        yield [
          text(p.sku), text(p.name), text(p.nameHindi),
          p.company ? (lookups.companies.get(String(p.company)) || text(p.brand)) : text(p.brand),
          categoryPath(lookups, p), '', text(p.description), text(p.shortDescription), p.mrp, p.retailPrice, p.wholesalePrice,
          p.minWholesaleQuantity, p.minCustomerQuantity, text(p.priceUnit), text(p.packing), '', '', p.stock,
          p.lowStockThreshold, text(p.status), yn(p.negotiationEnabled), yn(p.isFeatured), yn(p.isHot), (p.tags || []).join(', '),
        ];
      }
    },
  });

  add({
    key: 'brands',
    sheet: 'Brands',
    headers: ['Brand ID', 'Name', 'Active', 'Show on website', 'Hidden from customers', 'Customer discount %', 'Wholesaler discount %', 'Website', 'Description', 'Created at'],
    async* rows({ Company }) {
      for await (const c of cursorOf(Company.find({}).sort({ order: 1, name: 1 }))) {
        yield [idOf(c._id), text(c.name), yesNo(c.isActive), yesNo(c.showOnWebsite), yesNo(c.hideFromCustomers),
          c.customerDiscountPercent ?? '', c.wholesalerDiscountPercent ?? '', text(c.website), text(c.description), iso(c.createdAt)];
      }
    },
  });

  add({
    key: 'categories',
    sheet: 'Categories',
    headers: ['Category ID', 'Name', 'Brand', 'Parent category', 'Active', 'Show on website', 'Hidden from customers', 'Customer discount %', 'Wholesaler discount %', 'Created at'],
    async* rows({ Category }, lookups) {
      for await (const c of cursorOf(Category.find({}).sort({ order: 1, name: 1 }))) {
        yield [idOf(c._id), text(c.name), lookups.companies.get(String(c.company)) || '', c.parent ? ((lookups.categories.get(String(c.parent)) || {}).name || '') : '',
          yesNo(c.isActive), yesNo(c.showOnWebsite), yesNo(c.hideFromCustomers),
          c.customerDiscountPercent ?? '', c.wholesalerDiscountPercent ?? '', iso(c.createdAt)];
      }
    },
  });

  add({
    key: 'customers',
    sheet: 'Customers',
    headers: [
      'User ID', 'Name', 'Role', 'Phone', 'Email', 'Username', 'Active', 'Preferred language',
      'Business name', 'GST number', 'Contact person', 'Business status', 'Verified', 'Verified at',
      'Address', 'Business address', 'Shop location label', 'Shop latitude', 'Shop longitude',
      'Hidden brands', 'Marketing consent', 'Terms accepted at', 'Last login at', 'Created at',
    ],
    async* rows({ User }, lookups) {
      // Explicit allow-list: nothing outside these fields is ever read from the database.
      const fields = [
        'name', 'role', 'phone', 'email', 'username', 'isActive', 'preferredLanguage', 'address',
        'businessInfo.businessName', 'businessInfo.gstNumber', 'businessInfo.contactPerson', 'businessInfo.businessAddress',
        'businessInfo.status', 'businessInfo.verified', 'businessInfo.verifiedAt', 'businessInfo.shopLocation',
        'hiddenBrands', 'marketingConsent', 'termsAcceptedAt', 'lastLoginAt', 'createdAt',
      ].join(' ');
      for await (const u of cursorOf(User.find({}).select(fields).sort({ createdAt: 1 }))) {
        const b = u.businessInfo || {};
        const loc = b.shopLocation || {};
        yield [
          idOf(u._id), text(u.name), text(u.role), text(u.phone), text(u.email), text(u.username), yesNo(u.isActive), text(u.preferredLanguage),
          text(b.businessName), text(b.gstNumber), text(b.contactPerson), text(b.status), yesNo(b.verified), iso(b.verifiedAt),
          text(u.address), text(b.businessAddress), text(loc.placeLabel), loc.lat ?? '', loc.lng ?? '',
          (u.hiddenBrands || []).map((id) => lookups.companies.get(String(id)) || String(id)).join('; '),
          yesNo(u.marketingConsent), iso(u.termsAcceptedAt), iso(u.lastLoginAt), iso(u.createdAt),
        ];
      }
    },
  });

  // Latest payment status per order (shared by the orders dataset).
  const paymentStatusByOrder = async ({ Payment }) => {
    const out = new Map();
    for await (const p of cursorOf(Payment.find({}).select('orderId status createdAt').sort({ createdAt: 1 }))) {
      out.set(String(p.orderId), p.status); // later payments overwrite earlier ones
    }
    return out;
  };

  add({
    key: 'orders',
    sheet: 'Orders',
    headers: [
      'Order number', 'Order ID', 'Created at', 'Customer', 'Customer email', 'Customer phone', 'Business', 'Order type',
      'Status', 'Payment status', 'Acceptance', 'Items', 'Subtotal', 'Delivery fee', 'Discount', 'Total',
      'Ship to: name', 'Ship to: phone', 'Ship to: address 1', 'Ship to: address 2', 'Ship to: city', 'Ship to: state', 'Ship to: pincode',
      'Courier', 'Tracking number', 'Shipped at', 'Delivered at', 'Customer note', 'Admin note', 'Rejection reason', 'Requirement numbers',
    ],
    async* rows(models, lookups) {
      const payments = await paymentStatusByOrder(models);
      for await (const o of cursorOf(models.Order.find({}).sort({ createdAt: 1 }))) {
        const c = o.customerSnapshot || {};
        const s = o.shippingAddress || {};
        const negIds = (o.negotiationIds && o.negotiationIds.length ? o.negotiationIds : [o.negotiationId]).filter(Boolean);
        yield [
          text(o.orderNumber), idOf(o._id), iso(o.createdAt), text(c.name), text(c.email), text(c.phone), text(c.businessName), text(o.orderType),
          text(o.status), payments.get(String(o._id)) || 'none', text(o.acceptanceStatus), (o.items || []).length,
          o.subtotal, o.deliveryFee ?? 0, o.discount ?? 0, o.total,
          text(s.fullName), text(s.phone), text(s.addressLine1), text(s.addressLine2), text(s.city), text(s.state), text(s.pincode),
          text(o.courierName), text(o.trackingNumber), iso(o.shippedAt), iso(o.deliveredAt),
          text(o.customerNote), text(o.adminNote), text(o.rejectionReason), negIds.map((id) => idOf(id)).join('; '),
        ];
      }
    },
  });

  add({
    key: 'order_items',
    sheet: 'Order items',
    headers: ['Order number', 'Line', 'SKU', 'Product', 'Variant', 'Pack', 'Unit', 'Quantity', 'MRP per unit', 'Discount %', 'Price per unit', 'Line total'],
    async* rows({ Order }) {
      for await (const o of cursorOf(Order.find({}).select('orderNumber items createdAt').sort({ createdAt: 1 }))) {
        let line = 0;
        for (const item of o.items || []) {
          line += 1;
          const ps = item.productSnapshot || {};
          const vs = item.variantSnapshot || {};
          yield [text(o.orderNumber), line, text(ps.sku), text(ps.name), text(vs.displayName || vs.name), text(vs.packing), text(vs.priceUnit),
            item.quantity, item.mrpPerUnit ?? '', item.discountPercent ?? '', item.pricePerUnit, item.totalPrice];
        }
      }
    },
  });

  add({
    key: 'order_status_history',
    sheet: 'Order status history',
    headers: ['Order number', 'Status', 'Changed at', 'Changed by', 'Note'],
    async* rows({ Order }, lookups) {
      for await (const o of cursorOf(Order.find({}).select('orderNumber statusHistory createdAt').sort({ createdAt: 1 }))) {
        for (const h of o.statusHistory || []) {
          const by = h.updatedBy ? (lookups.users.get(String(h.updatedBy)) || {}).name || '' : '';
          yield [text(o.orderNumber), text(h.status), iso(h.timestamp), by, text(h.note)];
        }
      }
    },
  });

  add({
    key: 'payments',
    sheet: 'Payments',
    headers: ['Payment number', 'Order number', 'Customer', 'Amount', 'Method', 'Status', 'UPI id', 'Proof uploaded at', 'Verified at', 'Verified by', 'Rejection reason', 'Hold reason', 'Created at'],
    async* rows({ Payment }, lookups) {
      // Screenshot links are intentionally left out.
      for await (const p of cursorOf(Payment.find({}).select('-screenshotUrl -screenshotPublicId').sort({ createdAt: 1 }))) {
        yield [text(p.paymentNumber), lookups.orders.get(String(p.orderId)) || idOf(p.orderId), (lookups.users.get(String(p.userId)) || {}).name || '',
          p.amount, text(p.method), text(p.status), text(p.upiId), iso(p.uploadedAt), iso(p.verifiedAt),
          p.verifiedBy ? ((lookups.users.get(String(p.verifiedBy)) || {}).name || '') : '', text(p.rejectionReason), text(p.holdReason), iso(p.createdAt)];
      }
    },
  });

  add({
    key: 'negotiations',
    sheet: 'Negotiations',
    headers: [
      'Requirement number', 'Group number', 'Created at', 'Wholesaler', 'Business', 'Phone', 'SKU', 'Product', 'Variant',
      'Pack', 'Unit', 'List price', 'Quantity', 'Requested price/unit', 'Requested total', 'Current price/unit', 'Current offer by',
      'Final price/unit', 'Final total', 'Status', 'Order number', 'Expires at', 'Declined at', 'Message',
    ],
    async* rows({ Negotiation }, lookups) {
      for await (const n of cursorOf(Negotiation.find({}).sort({ createdAt: 1 }))) {
        const ws = lookups.users.get(String(n.wholesalerId)) || {};
        const ps = n.productSnapshot || {};
        yield [
          text(n.negotiationNumber), text(n.requestGroup && n.requestGroup.number), iso(n.createdAt), text(ws.name), text(ws.business), text(ws.phone),
          text(ps.sku), text(ps.name), text(ps.variantDisplayName || ps.variantName), text(ps.packing), text(ps.priceUnit), ps.price ?? '',
          n.requestedQuantity, n.requestedPricePerUnit, n.requestedTotalPrice, n.currentPricePerUnit ?? '', text(n.currentOfferBy),
          n.finalPricePerUnit ?? '', n.finalTotalPrice ?? '', text(n.status), n.orderId ? (lookups.orders.get(String(n.orderId)) || idOf(n.orderId)) : '',
          iso(n.expiresAt), iso(n.rejectedAt), text(n.message),
        ];
      }
    },
  });

  add({
    key: 'negotiation_history',
    sheet: 'Negotiation history',
    headers: ['Requirement number', 'Step', 'Time', 'Action', 'By', 'Actor', 'Price per unit', 'Total', 'Message'],
    async* rows({ Negotiation }, lookups) {
      for await (const n of cursorOf(Negotiation.find({}).select('negotiationNumber history createdAt').sort({ createdAt: 1 }))) {
        let step = 0;
        for (const h of n.history || []) {
          step += 1;
          const actor = h.actorId ? ((lookups.users.get(String(h.actorId)) || {}).name || '') : '';
          yield [text(n.negotiationNumber), step, iso(h.timestamp), text(h.action), text(h.by), actor, h.pricePerUnit ?? '', h.totalPrice ?? '', text(h.message)];
        }
      }
    },
  });

  add({
    key: 'price_history',
    sheet: 'Price history',
    headers: [
      'Recorded at', 'SKU', 'Product', 'Category', 'Changed by', 'Previous retail', 'New retail', 'Previous wholesale', 'New wholesale',
      'Schedule', 'Scheduled at', 'Effective at', 'Status', 'Applied at',
    ],
    async* rows({ PriceChangeAudit }) {
      for await (const a of cursorOf(PriceChangeAudit.find({}).sort({ createdAt: 1 }))) {
        yield [iso(a.createdAt), text(a.productSku), text(a.productName), text(a.category), text(a.performedByName),
          a.previousRetailPrice, a.newRetailPrice ?? '', a.previousWholesalePrice, a.newWholesalePrice ?? '',
          text(a.scheduleType), iso(a.scheduledAt), iso(a.effectiveAt), text(a.status), iso(a.appliedAt)];
      }
    },
  });

  add({
    key: 'stock_logs',
    sheet: 'Stock logs',
    headers: ['Time', 'SKU', 'Product', 'Action', 'Quantity change', 'Previous stock', 'New stock', 'Order number', 'Reason', 'Done by'],
    async* rows({ StockLog }, lookups) {
      for await (const l of cursorOf(StockLog.find({}).sort({ createdAt: 1 }))) {
        const p = lookups.products.get(String(l.productId)) || {};
        yield [iso(l.createdAt), text(p.sku), text(p.name), text(l.action), l.quantityChange, l.previousStock, l.newStock,
          l.orderId ? (lookups.orders.get(String(l.orderId)) || idOf(l.orderId)) : '', text(l.reason),
          l.performedBy ? ((lookups.users.get(String(l.performedBy)) || {}).name || '') : ''];
      }
    },
  });

  return datasets;
}

// ----------------------------------------------------------------------------
// Runner
// ----------------------------------------------------------------------------

async function exportAll({ outDir, formats = ['csv', 'xlsx'], models, log = () => {} }) {
  const ExcelJS = require('exceljs');
  fs.mkdirSync(outDir, { recursive: true });
  const lookups = await loadLookups(models);
  const datasets = buildDatasets();
  const counts = {};
  const files = [];

  let workbook = null;
  if (formats.includes('xlsx')) {
    workbook = new ExcelJS.stream.xlsx.WorkbookWriter({
      filename: path.join(outDir, 'export.xlsx'),
      useStyles: true,
      useSharedStrings: true,
    });
    workbook.creator = 'DemoMart client export';
    workbook.created = new Date();
  }

  for (const dataset of datasets) {
    const csv = formats.includes('csv') ? openCsv(path.join(outDir, `${dataset.key}.csv`), dataset.headers) : null;
    const sheet = workbook ? openSheet(workbook, dataset.sheet, dataset.headers) : null;
    let n = 0;
    for await (const row of dataset.rows(models, lookups)) {
      if (row.length !== dataset.headers.length) {
        throw new Error(`Dataset ${dataset.key}: row has ${row.length} cells, expected ${dataset.headers.length}`);
      }
      if (csv) csv.write(row);
      if (sheet) sheet.write(row);
      n += 1;
    }
    if (csv) await csv.close();
    if (sheet) await sheet.close();
    counts[dataset.key] = n;
    if (csv) files.push(`${dataset.key}.csv`);
    log(`  ${dataset.key}: ${n} rows`);
  }
  if (workbook) {
    await workbook.commit();
    files.push('export.xlsx');
  }
  fs.writeFileSync(path.join(outDir, 'counts.json'), `${JSON.stringify(counts, null, 2)}\n`);
  return { counts, files };
}

function parseArgs(argv) {
  const args = { formats: ['csv', 'xlsx'] };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = () => {
      i += 1;
      if (i >= argv.length) throw new Error(`${arg} needs a value`);
      return argv[i];
    };
    if (arg === '--out') args.out = next();
    else if (arg === '--slug') args.slug = next();
    else if (arg === '--db') args.db = next();
    else if (arg === '--clients-dir') args.clientsDir = next();
    else if (arg === '--formats') args.formats = next().split(',').map((f) => f.trim()).filter(Boolean);
    else if (arg === '--help' || arg === '-h') args.help = true;
    else throw new Error(`Unknown option: ${arg}`);
  }
  return args;
}

const USAGE = 'Usage: node scripts/export-client-data.js --out <dir> [--slug <slug>] [--db <name>] [--clients-dir <dir>] [--formats csv,xlsx]';

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(USAGE);
    return;
  }
  if (!args.out) throw new Error(`--out is required. ${USAGE}`);
  if (args.formats.some((f) => !['csv', 'xlsx'].includes(f))) throw new Error('--formats accepts csv and/or xlsx');
  if (args.slug && !/^[a-z0-9-]{2,30}$/.test(args.slug)) throw new Error('--slug must match ^[a-z0-9-]{2,30}$');

  const uri = stripQuotes(process.env.MONGODB_URI);
  if (!uri) throw new Error('MONGODB_URI is not set');
  await mongoose.connect(uri, { serverSelectionTimeoutMS: 15000, family: 4 });

  try {
    const connectedDb = mongoose.connection.name;
    const clientsDir = args.clientsDir || path.resolve(__dirname, '..', '..', 'deploy', 'clients');
    assertSafeTarget({
      connectedDb,
      explicitDb: args.db || null,
      slug: args.slug || null,
      declared: readDeclaredDatabases(clientsDir),
    });
    const models = require('../src/models');
    console.error(`Exporting database "${connectedDb}" to ${path.resolve(args.out)}`);
    const { counts } = await exportAll({
      outDir: args.out,
      formats: args.formats,
      models,
      log: (line) => console.error(line),
    });
    console.error(`Done: ${Object.values(counts).reduce((a, b) => a + b, 0)} rows in ${Object.keys(counts).length} datasets.`);
  } finally {
    await mongoose.disconnect();
  }
}

if (require.main === module) {
  main().then(() => process.exit(0)).catch((error) => {
    console.error(`export-client-data failed: ${error.message}`);
    process.exit(1);
  });
}

module.exports = { assertSafeTarget, readDeclaredDatabases, csvCell, buildDatasets, exportAll };
