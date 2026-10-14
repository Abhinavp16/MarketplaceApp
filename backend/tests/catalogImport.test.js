// Catalog import (Excel/CSV): parsing and validation run without a database.
// The write path (dry run, commit, refusal, rollback, idempotence) needs a
// local MongoDB replica set whose database name contains "test":
//   CATALOG_IMPORT_TEST_MONGODB_URI (or TEST_MONGODB_URI)=mongodb://127.0.0.1:27019/demomart_test?replicaSet=rs0
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-access-secret-0123456789-abcdefghij';
const assert = require('assert');
const ExcelJS = require('exceljs');
const mongoose = require('mongoose');
const {
  fieldForHeader,
  normalizeHeader,
  parseNumber,
  parseBoolean,
  parseCsvText,
  parseWorkbook,
  validateRows,
  importCatalog,
  importWorkbook,
  MAX_ROWS,
} = require('../src/services/catalogImportService');
const { createCatalogWorkbookBuffer, TEMPLATE_HEADERS } = require('../src/utils/catalogImportWorkbook');
const { isSafeTestDatabase, testDatabaseUri, assertSafeToWipe } = require('./helpers/testDb');

const csv = (text) => Buffer.from(text, 'utf8');
const rejects = async (promise, code, label) => {
  try {
    await promise;
  } catch (error) {
    assert.strictEqual(error.code, code, `${label}: expected ${code}, got ${error.code} (${error.message})`);
    return error;
  }
  throw new Error(`${label}: expected an error (${code})`);
};
const byRow = (report, row) => report.rows.find((entry) => entry.row === row);
const messages = (entry, key = 'errors') => entry[key].map((item) => item.message).join(' | ');

const catalog = () => ({
  brands: [
    { _id: 'b1', name: 'Kestrel Works', slug: 'kestrel-works' },
    { _id: 'b2', name: 'Anvilpoint', slug: 'anvilpoint' },
  ],
  categories: [
    { _id: 'c1', name: 'Power Tools', slug: 'power-tools', company: 'b1', parent: null },
    { _id: 'c2', name: 'Drills & Drivers', slug: 'drills-drivers', company: 'b1', parent: 'c1' },
    { _id: 'c3', name: 'Saws', slug: 'saws', company: 'b1', parent: 'c1' },
    { _id: 'c4', name: 'Fasteners', slug: 'fasteners', company: 'b2', parent: null },
    { _id: 'c5', name: 'Saws', slug: 'saws', company: 'b2', parent: 'c4' },
  ],
  products: [
    {
      _id: 'p1', sku: 'KW-DRL-18V', slug: 'drill-driver', name: 'Drill Driver', category: 'drills-drivers', categoryRef: 'c2', company: 'b1',
      mrp: 7499, retailPrice: 6499, wholesalePrice: 5200, minWholesaleQuantity: 5, minCustomerQuantity: 1,
      priceUnit: 'piece', packing: '1 kit', stock: 1200, lowStockThreshold: 20, status: 'active', negotiationEnabled: true,
      isFeatured: true, isHot: false, tags: ['drill'], description: 'A drill', shortDescription: '', nameHindi: '',
    },
    {
      _id: 'p2', sku: 'AP-WSH-M10', slug: 'washer-m10', name: 'Washer M10', category: 'fasteners', categoryRef: 'c4', company: 'b2',
      mrp: 8, retailPrice: 6.5, wholesalePrice: 4.8, minWholesaleQuantity: 5, minCustomerQuantity: 10,
      priceUnit: 'Packet', packing: '100 pcs', stock: 500, lowStockThreshold: 20, status: 'active',
    },
  ],
});

const row = (number, values) => ({ row: number, values });
const good = (extra = {}) => ({
  sku: 'NEW-1', name: 'New Product', brand: 'Kestrel Works', category: 'Power Tools > Saws',
  mrp: 100, retailPrice: 90, wholesalePrice: 70, description: 'ok', ...extra,
});

async function testHeaders() {
  assert.strictEqual(normalizeHeader('Retail Price (₹)'), 'retailprice');
  for (const [header, field] of [
    ['SKU', 'sku'], ['sku code', 'sku'], ['  Item_Code ', 'sku'], ['Product Name', 'name'], ['NAME', 'name'],
    ['retail_price', 'retailPrice'], ['Retail-Price (Rs.)', 'retailPrice'], ['Selling Price', 'retailPrice'],
    ['M.R.P.', 'mrp'], ['Wholesale Price', 'wholesalePrice'], ['Dealer Price', 'wholesalePrice'],
    ['Min Wholesale Qty', 'minWholesaleQuantity'], ['MOQ', 'minWholesaleQuantity'], ['Min Customer Qty', 'minCustomerQuantity'],
    ['Sub Category', 'subCategory'], ['UOM', 'priceUnit'], ['Packing', 'packing'], ['Pack Type', 'packType'], ['pack_size', 'packSize'],
    ['Stock Qty', 'stock'], ['Negotiation', 'negotiationEnabled'], ['Featured', 'isFeatured'], ['Hot', 'isHot'], ['Status', 'status'],
  ]) {
    assert.strictEqual(fieldForHeader(header), field, `${header} -> ${field}`);
  }
  assert.strictEqual(fieldForHeader('Internal Notes'), null);
  assert.strictEqual(TEMPLATE_HEADERS.length, new Set(TEMPLATE_HEADERS.map(normalizeHeader)).size);
}

function testNumbers() {
  assert.strictEqual(parseNumber(1250).value, 1250);
  assert.strictEqual(parseNumber('1,250').value, 1250);
  assert.strictEqual(parseNumber('1,00,000.50').value, 100000.5);
  assert.strictEqual(parseNumber('₹ 1250').value, 1250);
  assert.strictEqual(parseNumber('Rs. 99.5').value, 99.5);
  assert.strictEqual(parseNumber('1250/-').value, 1250);
  assert.strictEqual(parseNumber('-5').value, -5);
  assert.strictEqual(parseNumber('.5').value, 0.5);
  assert.ok(parseNumber('abc').error);
  assert.ok(parseNumber('12,5').error);
  assert.ok(parseNumber('1.2.3').error);
  assert.ok(parseNumber('12 pcs').error);
  assert.ok(parseNumber('').blank);
  assert.ok(parseNumber('   ').blank);
  assert.strictEqual(parseBoolean('Yes').value, true);
  assert.strictEqual(parseBoolean('n').value, false);
  assert.strictEqual(parseBoolean(1).value, true);
  assert.ok(parseBoolean('maybe').error);
  assert.ok(parseBoolean('').blank);
}

async function testCsv() {
  assert.deepStrictEqual(parseCsvText('\ufeffa,b\r\n"x, y","he said ""hi"""\r\n'), [['a', 'b'], ['x, y', 'he said "hi"']]);
  assert.deepStrictEqual(parseCsvText('a;b\n1;2\n'), [['a', 'b'], ['1', '2']]);
  assert.deepStrictEqual(parseCsvText('a,b\n"line1\nline2",2'), [['a', 'b'], ['line1\nline2', '2']]);

  const parsed = await parseWorkbook(csv(
    '\ufeffproduct_name,SKU Code,Retail Price (Rs.),MRP,Wholesale Price,Internal Notes\r\n'
    + '"Hex Bolt, M8",hb-8,"1,250",1500,900,keep\r\n'
    + ',,,,,\r\n'
    + 'Nut M8, hn-8 ,Rs. 40,50,30,\r\n',
  ), { filename: 'products.csv' });
  assert.strictEqual(parsed.rows.length, 2, 'blank row skipped');
  assert.deepStrictEqual(parsed.ignoredColumns, ['Internal Notes']);
  assert.strictEqual(parsed.rows[0].row, 2);
  assert.strictEqual(parsed.rows[1].row, 4, 'row numbers follow the file');
  assert.strictEqual(parsed.rows[0].values.name, 'Hex Bolt, M8');
  assert.strictEqual(parsed.rows[0].values.retailPrice, '1,250');
  assert.ok(parsed.columns.some((column) => column.field === 'sku' && column.header === 'SKU Code'));

  await rejects(parseWorkbook(csv('Name,MRP\nA,1\n'), { filename: 'x.csv' }), 'MISSING_COLUMNS', 'no SKU column');
  await rejects(parseWorkbook(csv('SKU,SKU Code,Name\nA,B,C\n'), { filename: 'x.csv' }), 'DUPLICATE_COLUMN', 'duplicate meaning');
  await rejects(parseWorkbook(csv(''), { filename: 'x.csv' }), 'EMPTY_FILE', 'empty');
  await rejects(parseWorkbook(csv('a'), { filename: 'x.xls' }), 'INVALID_FILE_TYPE', 'xls');
  await rejects(parseWorkbook(csv('a'), { filename: 'x.pdf' }), 'INVALID_FILE_TYPE', 'pdf');
  await rejects(parseWorkbook(csv('SKU,Name\nA,B'), { filename: 'x.xlsx' }), 'INVALID_FILE_TYPE', 'text renamed to xlsx');
  const workbook = new ExcelJS.Workbook();
  workbook.addWorksheet('Products').addRow(['SKU', 'Name']);
  const xlsxBuffer = Buffer.from(await workbook.xlsx.writeBuffer());
  await rejects(parseWorkbook(xlsxBuffer, { filename: 'x.csv' }), 'INVALID_FILE_TYPE', 'xlsx renamed to csv');
  assert.strictEqual((await parseWorkbook(xlsxBuffer, { filename: 'x.xlsx' })).rows.length, 0, 'header-only workbook has no rows');

  const big = ['SKU,Name'];
  for (let i = 0; i <= MAX_ROWS; i += 1) big.push(`S${i},Name ${i}`);
  await rejects(parseWorkbook(csv(big.join('\n')), { filename: 'big.csv' }), 'TOO_MANY_ROWS', 'too many rows');
  const maxRows = ['SKU,Name'];
  for (let i = 0; i < MAX_ROWS; i += 1) maxRows.push(`S${i},Name ${i}`);
  assert.strictEqual((await parseWorkbook(csv(maxRows.join('\n')), { filename: 'max.csv' })).rows.length, MAX_ROWS);
}

async function testXlsx() {
  const workbook = new ExcelJS.Workbook();
  workbook.addWorksheet('Cover').addRow(['Read me first']);
  const sheet = workbook.addWorksheet('Products');
  sheet.addRow(['Catalogue export 2026']); // a title row above the headers
  sheet.addRow([]);
  sheet.addRow(['SKU', 'Product Name', 'Brand', 'Category', 'Retail Price', 'MRP', 'Wholesale Price', 'Stock', 'Status']);
  sheet.addRow(['kw-1', { richText: [{ text: 'Rich ' }, { text: 'Text' }] }, 'Kestrel Works', 'Power Tools > Saws', 1250, 1500, { formula: 'B1*2', result: 900 }, 15, 'Active']);
  sheet.addRow([123456, 'Numeric SKU', 'Kestrel Works', 'Saws', '₹ 99', 120, 80, 0, '']);
  sheet.addRow([]);
  const buffer = Buffer.from(await workbook.xlsx.writeBuffer());

  const parsed = await parseWorkbook(buffer, { filename: 'catalog.xlsx' });
  assert.strictEqual(parsed.sheetName, 'Products', 'the Products sheet is preferred over the first sheet');
  assert.strictEqual(parsed.rows.length, 2);
  assert.strictEqual(parsed.rows[0].row, 4);
  assert.strictEqual(parsed.rows[0].values.name, 'Rich Text');
  assert.strictEqual(parsed.rows[0].values.wholesalePrice, 900, 'formula result');
  assert.strictEqual(parsed.rows[0].values.retailPrice, 1250);

  const report = validateRows(parsed, { catalog: catalog() });
  assert.strictEqual(report.summary.errors, 0, JSON.stringify(report.rows.map((entry) => entry.errors)));
  assert.strictEqual(byRow(report, 4).sku, 'KW-1');
  assert.strictEqual(byRow(report, 4).normalized.status, 'active');
  assert.strictEqual(byRow(report, 5).sku, '123456');
  assert.strictEqual(byRow(report, 5).normalized.retailPrice, 99);

  // The shipped template reads back and validates (examples use the demo brands).
  const template = await parseWorkbook(Buffer.from(await createCatalogWorkbookBuffer()), { filename: 'template.xlsx' });
  assert.strictEqual(template.rows.length, 3);
  assert.deepStrictEqual(template.ignoredColumns, []);
  assert.strictEqual(template.columns.length, TEMPLATE_HEADERS.length);
  const notes = new ExcelJS.Workbook();
  await notes.xlsx.load(await createCatalogWorkbookBuffer());
  assert.deepStrictEqual(notes.worksheets.map((entry) => entry.name), ['Products', 'Notes']);
  assert.ok(template.rows.some((entry) => entry.values.packType === 'Packet') && template.rows.some((entry) => entry.values.packType === 'Coil'));
}

function testValidation() {
  const run = (rows, options = {}) => validateRows(rows, { catalog: catalog(), ...options });

  // A clean new product.
  let report = run([row(2, good())]);
  assert.strictEqual(report.rows[0].action, 'create');
  assert.strictEqual(report.rows[0].status, 'ok');
  assert.strictEqual(report.rows[0].normalized.status, 'draft', 'new products default to draft');
  assert.strictEqual(report.rows[0].normalized.priceUnit, 'piece');
  assert.strictEqual(report.rows[0].normalized.category, 'Power Tools > Saws');
  assert.strictEqual(report.summary.created, 1);

  // Required fields on create.
  report = run([row(2, { sku: 'X-1' })]);
  assert.strictEqual(report.rows[0].status, 'error');
  for (const column of ['Name', 'Brand', 'Category', 'MRP', 'Retail Price', 'Wholesale Price']) {
    assert.ok(report.rows[0].errors.some((error) => error.column === column), `${column} required`);
  }
  assert.ok(messages(run([row(2, { name: 'No sku' })]).rows[0]).includes('SKU is required'));

  // Duplicate SKU in the file (case-insensitive), both rows flagged; SKU characters.
  report = run([row(2, good({ sku: 'dup-1' })), row(3, good({ sku: 'DUP-1', name: 'Other' }))]);
  assert.ok(messages(report.rows[0]).includes('Duplicate SKU in this file (also on row 3)'));
  assert.ok(messages(report.rows[1]).includes('also on row 2'));
  assert.ok(messages(run([row(2, good({ sku: 'BAD SKU!' }))]).rows[0]).includes('SKU may only contain'));

  // Prices: not numbers, negative; ordering is a warning (the app does not enforce it).
  report = run([
    row(2, good({ mrp: 'abc' })),
    row(3, good({ sku: 'N-2', name: 'N2', retailPrice: -1 })),
    row(4, good({ sku: 'N-3', name: 'N3', mrp: 100, retailPrice: 120, wholesalePrice: 130 })),
    row(5, good({ sku: 'N-4', name: 'N4', retailPrice: 10.456 })),
  ]);
  assert.ok(messages(report.rows[0]).includes('MRP "abc" is not a number'));
  assert.ok(messages(report.rows[1]).includes('Retail Price must be zero or more'));
  assert.strictEqual(report.rows[2].status, 'warning');
  assert.strictEqual(report.rows[2].errors.length, 0);
  assert.ok(messages(report.rows[2], 'warnings').includes('higher than MRP'));
  assert.ok(messages(report.rows[2], 'warnings').includes('higher than the retail price'));
  assert.strictEqual(report.rows[3].normalized.retailPrice, 10.46);
  assert.ok(messages(report.rows[3], 'warnings').includes('rounded'));
  assert.strictEqual(report.summary.errors, 2);
  assert.strictEqual(report.summary.warnings, 2);

  // Stock, quantities, status, flags, lengths.
  report = run([
    row(2, good({ stock: 12.5 })),
    row(3, good({ sku: 'N-2', name: 'N2', stock: -3 })),
    row(4, good({ sku: 'N-3', name: 'N3', minWholesaleQuantity: 0 })),
    row(5, good({ sku: 'N-4', name: 'N4', status: 'live' })),
    row(6, good({ sku: 'N-5', name: 'N5', negotiationEnabled: 'maybe' })),
    row(7, good({ sku: 'N-6', name: 'x'.repeat(201) })),
    row(8, good({ sku: 'N-7', name: 'N7', status: ' Active ', stock: '1,200', negotiationEnabled: 'no', isFeatured: 'Y' })),
  ]);
  assert.ok(messages(report.rows[0]).includes('Stock must be a whole number'));
  assert.ok(messages(report.rows[1]).includes('Stock must be zero or more'));
  assert.ok(messages(report.rows[2]).includes('Min Wholesale Qty must be at least 1'));
  assert.ok(messages(report.rows[3]).includes('Use active, draft or archived'));
  assert.ok(messages(report.rows[4]).includes('must be Yes or No'));
  assert.ok(messages(report.rows[5]).includes('Name is too long'));
  assert.strictEqual(report.rows[6].status, 'ok');
  assert.deepStrictEqual(
    [report.rows[6].normalized.status, report.rows[6].normalized.stock, report.rows[6].normalized.negotiationEnabled, report.rows[6].normalized.isFeatured],
    ['active', 1200, false, true],
  );

  // Unknown brand / category are errors; spelling and case are forgiven.
  report = run([
    row(2, good({ brand: 'Nope Tools' })),
    row(3, good({ sku: 'N-2', name: 'N2', category: 'Power Tools > Welding' })),
    row(4, good({ sku: 'N-3', name: 'N3', brand: 'kestrel  works', category: 'power tools > drills & drivers' })),
    row(5, good({ sku: 'N-4', name: 'N4', category: 'Power Tools', subCategory: 'Saws' })),
    row(6, good({ sku: 'N-5', name: 'N5', category: 'Drills & Drivers' })),
    row(7, good({ sku: 'N-6', name: 'N6', brand: 'Anvilpoint', category: 'Saws' })),
    row(8, good({ sku: 'N-7', name: 'N7', category: 'Power Tools', subCategory: 'Drills & Drivers', brand: 'Kestrel Works' })),
    row(9, good({ sku: 'N-8', name: 'N8', category: 'Power Tools > Saws', subCategory: 'Drills & Drivers' })),
  ]);
  assert.ok(messages(report.rows[0]).includes('Brand "Nope Tools" does not exist'));
  assert.ok(messages(report.rows[1]).includes('Category "Power Tools > Welding" does not exist under Kestrel Works'));
  assert.strictEqual(report.rows[2].status, 'ok');
  assert.strictEqual(report.rows[2].normalized.brand, 'Kestrel Works');
  assert.strictEqual(report.rows[2].normalized.category, 'Power Tools > Drills & Drivers');
  assert.strictEqual(report.rows[3].normalized.category, 'Power Tools > Saws');
  assert.strictEqual(report.rows[4].normalized.category, 'Power Tools > Drills & Drivers', 'unique subcategory name resolves to its path');
  assert.strictEqual(report.rows[5].normalized.category, 'Fasteners > Saws', 'the same name under another brand is a different category');
  assert.strictEqual(report.rows[6].status, 'ok');
  assert.ok(messages(report.rows[7]).includes('does not match the last part'));
  assert.deepStrictEqual(report.newBrands, []);

  // createMissing plans what it will create.
  report = run([
    row(2, good({ brand: 'Fresh Brand', category: 'Garden > Hoses' })),
    row(3, good({ sku: 'N-2', name: 'N2', brand: 'FRESH BRAND', category: 'Garden > Nozzles' })),
    row(4, good({ sku: 'N-3', name: 'N3', category: 'Power Tools > Planers' })),
    row(5, good({ sku: 'N-4', name: 'N4', category: 'Brand New Top' })),
    row(6, good({ sku: 'N-5', name: 'N5', brand: 'Bad', category: 'X' })),
  ], { createMissing: true });
  assert.strictEqual(report.summary.errors, 0, JSON.stringify(report.rows.map((entry) => entry.errors)));
  assert.deepStrictEqual(report.newBrands, ['Fresh Brand', 'Bad']);
  assert.deepStrictEqual(report.newCategories, [
    'Fresh Brand: Garden', 'Fresh Brand: Garden > Hoses', 'Fresh Brand: Garden > Nozzles',
    'Kestrel Works: Power Tools > Planers', 'Kestrel Works: Brand New Top', 'Bad: X',
  ]);
  assert.strictEqual(byRow(report, 4).normalized.category, 'Power Tools > Planers', 'existing parent keeps its stored spelling');
  // A brand name that only differs by punctuation would collide on its web address.
  report = run([row(2, good({ brand: 'Kestrel-Works!', category: 'X' }))], { createMissing: true });
  assert.ok(messages(report.rows[0]).includes('too similar'));

  // Pack products.
  report = run([
    row(2, good({ sku: 'P-1', name: 'Packet product', packType: 'Packet', packSize: 200 })),
    row(3, good({ sku: 'P-2', name: 'Coil product', packType: 'coil', packSize: '30' })),
    row(4, good({ sku: 'P-3', name: 'Bundle product', priceUnit: 'Bundle', packing: '100 m' })),
    row(5, good({ sku: 'P-4', name: 'Packet no size', packType: 'Packet' })),
    row(6, good({ sku: 'P-5', name: 'Bad type', packType: 'Roll', packSize: 5 })),
    row(7, good({ sku: 'P-6', name: 'Size one', packType: 'Packet', packSize: 1 })),
    row(8, good({ sku: 'P-7', name: 'Size no type', packSize: 10 })),
    row(9, good({ sku: 'P-8', name: 'Unit clash', packType: 'Coil', priceUnit: 'Packet', packSize: 10 })),
    row(10, good({ sku: 'P-9', name: 'Packing clash', packType: 'Packet', packSize: 50, packing: '100 pcs' })),
    row(11, good({ sku: 'P-10', name: 'Pack of text', priceUnit: 'pack', packing: 'Pack of 50' })),
    row(12, good({ sku: 'P-11', name: 'Packet wrong packing', priceUnit: 'Packet', packing: '50 m' })),
    row(13, good({ sku: 'P-12', name: 'Box', priceUnit: 'box', packing: 'Box of 100' })),
    row(14, good({ sku: 'P-13', name: 'Packet with matching packing', packType: 'Packet', packSize: 15, packing: '15 pieces' })),
  ]);
  const norm = (index) => report.rows[index].normalized;
  assert.strictEqual(report.rows[0].status, 'ok');
  assert.deepStrictEqual([norm(0).priceUnit, norm(0).packing], ['Packet', '200 pcs']);
  assert.deepStrictEqual([norm(1).priceUnit, norm(1).packing], ['Coil', '30 m']);
  assert.deepStrictEqual([norm(2).priceUnit, norm(2).packing], ['Bundle', '100 m']);
  assert.ok(messages(report.rows[3]).includes('need a pack size'));
  assert.ok(messages(report.rows[4]).includes('Pack Type "Roll" is not valid'));
  assert.ok(messages(report.rows[5]).includes('Pack Size must be a whole number of 2 or more'));
  assert.ok(messages(report.rows[6]).includes('Pack Size needs a Pack Type'));
  assert.ok(messages(report.rows[7]).includes('does not match Pack Type'));
  assert.ok(messages(report.rows[8]).includes('does not match Pack Size'));
  assert.strictEqual(report.rows[9].status, 'warning', 'a "pack" of free text is a normal product');
  assert.ok(messages(report.rows[9], 'warnings').includes('normal product priced per pack'));
  assert.strictEqual(report.rows[10].status, 'warning', 'Unit Packet with a length is only a normal product');
  assert.strictEqual(report.rows[11].status, 'ok');
  assert.strictEqual(report.rows[12].status, 'ok');

  // Web address (slug) clashes: with a stored product and inside the file.
  report = run([
    row(2, good({ name: 'Drill Driver' })),
    row(3, good({ sku: 'N-2', name: 'Fresh Name' })),
    row(4, good({ sku: 'N-3', name: 'fresh  name!' })),
    row(5, good({ sku: 'N-4', name: '!!!' })),
  ]);
  assert.ok(messages(report.rows[0]).includes('Another product (KW-DRL-18V) already has this name'));
  assert.strictEqual(report.rows[1].status, 'ok');
  assert.ok(messages(report.rows[2]).includes('Another row (SKU N-2)'));
  assert.ok(messages(report.rows[3]).includes('at least one letter or number'));

  // Updates: only provided columns, unchanged rows are skipped, diffs are listed.
  const one = (values) => run([row(2, values)]).rows[0];
  let entry = one({ sku: 'kw-drl-18v', stock: 1000, retailPrice: 6399 });
  assert.strictEqual(entry.action, 'update');
  assert.deepStrictEqual(entry.changes.map((change) => change.field), ['retailPrice', 'stock']);
  assert.deepStrictEqual(entry.changes.find((change) => change.field === 'stock'), { field: 'stock', column: 'Stock', from: 1200, to: 1000 });
  assert.strictEqual(entry.normalized.name, undefined, 'columns without a value are untouched');
  assert.strictEqual(one({ sku: 'KW-DRL-18V' }).action, 'skip');
  entry = one({ sku: 'AP-WSH-M10', retailPrice: '6.50', packType: 'Packet', packSize: 100, stock: 500, status: 'active' });
  assert.strictEqual(entry.action, 'skip', JSON.stringify(entry));
  assert.strictEqual(entry.note, 'No changes: the product already matches this row.');
  assert.strictEqual(
    one({ sku: 'KW-DRL-18V', name: 'Drill Driver', brand: 'Kestrel Works', category: 'Power Tools > Drills & Drivers', tags: 'drill' }).action,
    'skip',
    'same name/brand/category/tags is no change',
  );
  entry = one({ sku: 'KW-DRL-18V', category: 'Power Tools > Saws' });
  assert.strictEqual(entry.action, 'update');
  assert.deepStrictEqual(entry.changes.map((change) => change.field), ['category']);
  assert.ok(messages(one({ sku: 'KW-DRL-18V', brand: 'Anvilpoint' })).includes('To move a product to another brand'));
  entry = one({ sku: 'KW-DRL-18V', brand: 'Anvilpoint', category: 'Fasteners' });
  assert.deepStrictEqual(entry.changes.map((change) => change.field), ['brand', 'category']);
  entry = one({ sku: 'AP-WSH-M10', packSize: 50 });
  assert.strictEqual(entry.status, 'ok');
  assert.deepStrictEqual(entry.changes.map((change) => change.field), ['packing'], 'pack size updates the packing text');
  assert.ok(messages(one({ sku: 'KW-DRL-18V', name: 'Washer M10' })).includes('Another product (AP-WSH-M10)'));
  assert.strictEqual(one({ sku: 'KW-DRL-18V', retailPrice: 7600 }).status, 'warning', 'retail above MRP');
  assert.ok(messages(one({ sku: 'KW-DRL-18V', stock: 'many' })).includes('Stock "many" is not a number'));
  assert.ok(messages(one({ sku: 'KW-DRL-18V', subCategory: 'Saws' })).includes('Subcategory needs a Category'));

  report = run([
    row(2, { sku: 'KW-DRL-18V', stock: 1000 }),
    row(3, { sku: 'AP-WSH-M10' }),
    row(4, good()),
    row(5, good({ sku: 'N-2', name: '' })),
  ]);
  assert.deepStrictEqual(
    [report.summary.created, report.summary.updated, report.summary.skipped, report.summary.errors],
    [1, 1, 1, 1],
  );

  // Row/summary shape the admin UI renders.
  report = run([row(2, good()), row(3, { sku: 'KW-DRL-18V' }), row(4, good({ sku: 'E', name: '' }))]);
  assert.deepStrictEqual(Object.keys(report.summary).sort(), [
    'created', 'errorCount', 'errors', 'newBrands', 'newCategories', 'skipped', 'totalRows', 'updated', 'warningCount', 'warnings',
  ]);
  assert.deepStrictEqual(Object.keys(report.rows[0]).sort(), ['action', 'changes', 'errors', 'normalized', 'row', 'sku', 'status', 'target', 'warnings'].sort());
  assert.strictEqual(report.dryRun, true);
  assert.strictEqual(report.committed, false);
  assert.deepStrictEqual(Object.keys(report.rows[2].errors[0]).sort(), ['column', 'field', 'message']);
}

// ---------------------------------------------------------------------------
// Database part

const SKU_PREFIX = 'CIT-';
async function cleanupDb() {
  const { Product, Company, Category, StockLog, PriceChangeAudit, AuditLog, PriceChangeNotificationBatch } = require('../src/models');
  const products = await Product.find({ sku: new RegExp(`^${SKU_PREFIX}`) }).select('_id').lean();
  const ids = products.map((product) => product._id);
  await StockLog.deleteMany({ productId: { $in: ids } });
  await PriceChangeAudit.deleteMany({ product: { $in: ids } });
  await Product.deleteMany({ _id: { $in: ids } });
  const brands = await Company.find({ name: /^CIT / }).select('_id').lean();
  await Category.deleteMany({ company: { $in: brands.map((brand) => brand._id) } });
  await Company.deleteMany({ _id: { $in: brands.map((brand) => brand._id) } });
  await AuditLog.deleteMany({ entityType: 'CatalogImport' });
  await PriceChangeNotificationBatch.deleteMany({ productId: { $in: ids } }).catch(() => {});
}

const sheet = (rows) => rows.map((entry, index) => ({ row: index + 2, values: entry }));

async function runDatabaseTests() {
  const { Product, Company, Category, StockLog, PriceChangeAudit, AuditLog, User } = require('../src/models');
  await cleanupDb();
  const admin = await User.create({
    name: 'Catalog Import Test Admin',
    email: `catalog-import-${Date.now()}@test.example`,
    phone: `9${Date.now().toString().slice(-9)}`,
    passwordHash: 'not-a-real-hash',
    role: 'admin',
    isActive: true,
  });
  const count = (model, filter) => model.countDocuments(filter);
  const opts = { awaitFollowUps: true, actorId: admin._id };

  try {
    const rows = sheet([
      { sku: 'CIT-DRL-1', name: 'CIT Drill One', brand: 'CIT Brand', category: 'CIT Tools > CIT Drills', description: 'Drill', mrp: 1000, retailPrice: 900, wholesalePrice: 700, stock: 20, status: 'active', priceUnit: 'piece' },
      { sku: 'CIT-WSH-1', name: 'CIT Washer Packet', brand: 'CIT Brand', category: 'CIT Tools > CIT Fasteners', description: 'Washers', mrp: 5, retailPrice: 4, wholesalePrice: 3, stock: 1000, packType: 'Packet', packSize: 100, minWholesaleQuantity: 2, status: 'active' },
      { sku: 'CIT-CRD-1', name: 'CIT Cord Coil', brand: 'CIT Brand', category: 'CIT Tools > CIT Fasteners', description: 'Cord', mrp: 20, retailPrice: 15, wholesalePrice: 11, stock: 0, packType: 'Coil', packSize: 50 },
    ]);

    // 1. Dry run reports and writes nothing (not even the brand/categories).
    let report = await importCatalog(rows, { ...opts, dryRun: true, createMissing: true });
    assert.strictEqual(report.committed, false);
    assert.strictEqual(report.dryRun, true);
    assert.deepStrictEqual([report.summary.created, report.summary.updated, report.summary.errors], [3, 0, 0]);
    assert.deepStrictEqual(report.newBrands, ['CIT Brand']);
    assert.strictEqual(await count(Product, { sku: /^CIT-/ }), 0);
    assert.strictEqual(await count(Company, { name: /^CIT / }), 0);

    // 1b. Without createMissing the unknown brand is an error, even on commit.
    report = await importCatalog(rows, { ...opts, dryRun: false });
    assert.strictEqual(report.committed, false);
    assert.strictEqual(report.summary.errors, 3);
    assert.strictEqual(await count(Company, { name: /^CIT / }), 0);

    // 2. Commit creates brand, categories (with parent links) and products.
    report = await importCatalog(rows, { ...opts, dryRun: false, createMissing: true, fileName: 'cit.xlsx' });
    assert.strictEqual(report.committed, true, JSON.stringify(report.rows.map((entry) => entry.errors)));
    assert.deepStrictEqual([report.summary.created, report.summary.updated, report.summary.skipped], [3, 0, 0]);
    assert.ok(report.rows.every((entry) => entry.productId));
    const brand = await Company.findOne({ name: 'CIT Brand' }).lean();
    assert.ok(brand && brand.slug === 'cit-brand');
    const top = await Category.findOne({ company: brand._id, name: 'CIT Tools' }).lean();
    const drills = await Category.findOne({ company: brand._id, name: 'CIT Drills' }).lean();
    const fasteners = await Category.findOne({ company: brand._id, name: 'CIT Fasteners' }).lean();
    assert.ok(top && !top.parent);
    assert.strictEqual(String(drills.parent), String(top._id));
    assert.strictEqual(String(fasteners.parent), String(top._id));
    assert.strictEqual(await count(Category, { company: brand._id }), 3);
    const drill = await Product.findOne({ sku: 'CIT-DRL-1' }).lean();
    assert.strictEqual(drill.slug, 'cit-drill-one');
    assert.strictEqual(String(drill.company), String(brand._id));
    assert.strictEqual(String(drill.categoryRef), String(drills._id));
    assert.strictEqual(drill.category, drills.slug);
    assert.strictEqual(drill.brand, 'CIT Brand');
    assert.strictEqual(drill.subCategory, 'CIT Drills');
    assert.strictEqual(drill.status, 'active');
    assert.strictEqual(drill.stock, 20);
    const washer = await Product.findOne({ sku: 'CIT-WSH-1' }).lean();
    assert.deepStrictEqual([washer.priceUnit, washer.packing, washer.minWholesaleQuantity], ['Packet', '100 pcs', 2]);
    assert.strictEqual((await Product.findOne({ sku: 'CIT-CRD-1' }).lean()).status, 'draft', 'status defaults to draft');
    const { getPackInfo } = require('../src/utils/packSize');
    assert.strictEqual(getPackInfo(washer).size, 100);
    assert.deepStrictEqual(
      [(await Product.findOne({ sku: 'CIT-CRD-1' }).lean()).packing, getPackInfo(await Product.findOne({ sku: 'CIT-CRD-1' }).lean()).packUnit],
      ['50 m', 'coil'],
    );
    assert.strictEqual((await Category.findById(drills._id).lean()).productCount, 1, 'category counts refreshed');
    assert.strictEqual((await Category.findById(fasteners._id).lean()).productCount, 2);
    assert.strictEqual(await count(StockLog, { productId: drill._id }), 1, 'initial stock is logged');
    assert.strictEqual(await count(StockLog, { productId: (await Product.findOne({ sku: 'CIT-CRD-1' }).lean())._id }), 0, 'no log for zero stock');
    assert.strictEqual(await count(AuditLog, { entityType: 'CatalogImport', actorId: admin._id }), 1);

    // 3. Idempotent: the same file again creates and updates nothing.
    report = await importCatalog(rows, { ...opts, dryRun: false, createMissing: true });
    assert.strictEqual(report.committed, true);
    assert.deepStrictEqual([report.summary.created, report.summary.updated, report.summary.skipped, report.summary.errors], [0, 0, 3, 0]);
    assert.ok(report.rows.every((entry) => entry.action === 'skip'));
    assert.strictEqual(await count(Product, { sku: /^CIT-/ }), 3);
    assert.strictEqual(await count(Company, { name: /^CIT / }), 1);
    assert.strictEqual(await count(StockLog, { productId: drill._id }), 1);

    // 4. Update: only the columns present change; stock is logged; price change is audited.
    const updates = sheet([
      { sku: 'cit-drl-1', stock: 35, retailPrice: 950, shortDescription: 'Updated' },
      { sku: 'CIT-WSH-1' },
    ]);
    report = await importCatalog(updates, { ...opts, dryRun: false });
    assert.strictEqual(report.committed, true);
    assert.deepStrictEqual([report.summary.created, report.summary.updated, report.summary.skipped], [0, 1, 1]);
    const updated = await Product.findOne({ sku: 'CIT-DRL-1' }).lean();
    assert.deepStrictEqual([updated.stock, updated.retailPrice, updated.wholesalePrice, updated.mrp, updated.name], [35, 950, 700, 1000, 'CIT Drill One']);
    assert.strictEqual(updated.shortDescription, 'Updated');
    assert.strictEqual(updated.status, 'active');
    const logs = await StockLog.find({ productId: drill._id }).sort({ createdAt: 1 }).lean();
    assert.strictEqual(logs.length, 2);
    assert.deepStrictEqual([logs[1].previousStock, logs[1].newStock, logs[1].quantityChange, logs[1].action], [20, 35, 15, 'manual_set']);
    const audit = await PriceChangeAudit.findOne({ product: drill._id }).lean();
    assert.deepStrictEqual([audit.previousRetailPrice, audit.newRetailPrice, audit.status, audit.scheduleType], [900, 950, 'applied', 'immediate']);
    assert.strictEqual(String(audit.performedBy), String(admin._id));

    // 4b. Scheduled mode keeps the live price and records a pending change.
    report = await importCatalog(sheet([{ sku: 'CIT-DRL-1', retailPrice: 975 }]), { ...opts, dryRun: false, priceChangeMode: 'schedule_24h' });
    assert.strictEqual(report.committed, true);
    const pending = await Product.findOne({ sku: 'CIT-DRL-1' }).lean();
    assert.deepStrictEqual([pending.retailPrice, pending.pendingRetailPrice], [950, 975]);
    await PriceChangeAudit.deleteMany({ product: drill._id });

    // 5. Any row with an error refuses the whole file: the good row is not written either.
    const mixed = sheet([
      { sku: 'CIT-NEW-OK', name: 'CIT Valid Row', brand: 'CIT Brand', category: 'CIT Tools > CIT Drills', mrp: 10, retailPrice: 9, wholesalePrice: 8 },
      { sku: 'CIT-NEW-BAD', name: 'CIT Bad Row', brand: 'CIT Brand', category: 'CIT Tools > CIT Drills', mrp: 'x', retailPrice: 9, wholesalePrice: 8 },
      { sku: 'CIT-DRL-1', stock: 1 },
    ]);
    report = await importCatalog(mixed, { ...opts, dryRun: false, createMissing: true });
    assert.strictEqual(report.committed, false);
    assert.strictEqual(report.summary.errors, 1);
    assert.deepStrictEqual([report.summary.created, report.summary.updated], [1, 1], 'counts show what valid rows would do');
    assert.strictEqual(await count(Product, { sku: 'CIT-NEW-OK' }), 0);
    assert.strictEqual((await Product.findOne({ sku: 'CIT-DRL-1' }).lean()).stock, 35);

    // 6. A failure in the middle of the write rolls everything back.
    const models = require('../src/models');
    const originalInsertMany = models.StockLog.insertMany;
    models.StockLog.insertMany = async () => { throw new Error('simulated failure after the products were written'); };
    try {
      const beforeCategories = await count(Category, { company: brand._id });
      await assert.rejects(
        importCatalog(sheet([
          { sku: 'CIT-ROLL-1', name: 'CIT Rollback One', brand: 'CIT Rollback Brand', category: 'CIT Rollback Cat', mrp: 10, retailPrice: 9, wholesalePrice: 8, stock: 5 },
          { sku: 'CIT-DRL-1', stock: 99, name: 'CIT Drill Renamed' },
        ]), { ...opts, dryRun: false, createMissing: true }),
        /simulated failure/,
      );
      assert.strictEqual(await count(Product, { sku: 'CIT-ROLL-1' }), 0, 'new product rolled back');
      assert.strictEqual(await count(Company, { name: 'CIT Rollback Brand' }), 0, 'new brand rolled back');
      assert.strictEqual(await count(Category, { company: brand._id }), beforeCategories);
      const untouched = await Product.findOne({ sku: 'CIT-DRL-1' }).lean();
      assert.deepStrictEqual([untouched.stock, untouched.name], [35, 'CIT Drill One'], 'updates rolled back');
    } finally {
      models.StockLog.insertMany = originalInsertMany;
    }

    // 7. End to end from files: CSV and XLSX bytes in, products out.
    const csvText = [
      'SKU Code,Product Name,Brand,Category,MRP,Retail Price (Rs.),Wholesale Price,Stock,Status',
      'CIT-CSV-1,CIT Csv Product,CIT Brand,CIT Tools > CIT Drills,"1,200","1,000",800,12,active',
    ].join('\r\n');
    report = await importWorkbook(csv(csvText), { ...opts, filename: 'upload.csv', dryRun: false });
    assert.strictEqual(report.committed, true);
    assert.strictEqual(report.fileName, 'upload.csv');
    assert.strictEqual((await Product.findOne({ sku: 'CIT-CSV-1' }).lean()).retailPrice, 1000);
    const workbook = new ExcelJS.Workbook();
    const productsSheet = workbook.addWorksheet('Products');
    productsSheet.addRow(['SKU', 'Name', 'Brand', 'Category', 'MRP', 'Retail Price', 'Wholesale Price']);
    productsSheet.addRow(['CIT-XLS-1', 'CIT Xlsx Product', 'CIT Brand', 'CIT Tools > CIT Drills', 50, 40, 30]);
    report = await importWorkbook(Buffer.from(await workbook.xlsx.writeBuffer()), { ...opts, filename: 'upload.xlsx', dryRun: false });
    assert.strictEqual(report.committed, true);
    assert.ok(await Product.findOne({ sku: 'CIT-XLS-1' }).lean());
  } finally {
    await cleanupDb();
    await User.deleteOne({ _id: admin._id });
  }
}

async function main() {
  await testHeaders();
  testNumbers();
  await testCsv();
  await testXlsx();
  testValidation();
  console.log('Catalog import unit tests passed');

  const uri = testDatabaseUri('CATALOG_IMPORT_TEST_MONGODB_URI');
  if (!isSafeTestDatabase(uri)) {
    console.log('Catalog import database tests skipped (set CATALOG_IMPORT_TEST_MONGODB_URI or TEST_MONGODB_URI to a local "test" database with a replica set)');
    return;
  }
  await mongoose.connect(uri);
  try {
    assertSafeToWipe(mongoose);
    await runDatabaseTests();
    console.log('Catalog import database tests passed');
  } finally {
    await mongoose.disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
