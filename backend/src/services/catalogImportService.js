// Catalog import from Excel (.xlsx) or CSV.
//
//   parseWorkbook(bufferOrPath, { filename })  -> { rows, columns, ignoredColumns, sheetName }
//   validateRows(rows, { createMissing, catalog }) -> report            (pure, no database)
//   loadCatalogSnapshot({ session })           -> catalog               (reads brands, categories, products)
//   importCatalog(rows, { dryRun, createMissing, actorId }) -> report   (validates, then writes in ONE transaction)
//   importWorkbook(bufferOrPath, options)      -> report                (parse + import, used by the API and the CLI)
//
// One row = one product, matched on SKU. A new SKU creates a product; an existing
// SKU updates only the columns that have a value in the file (blank cells leave
// the stored value alone). The whole file is all-or-nothing: if any row has an
// error nothing is written. Products are created and updated through the same
// functions the admin product form uses (controllers/admin/productController:
// createProductRecord / updateProductRecord), so slugs, pricing history, Hindi
// names and the price-update notices behave exactly the same.
//
// Images are not part of the workbook (a product without images shows the
// app's normal placeholder; add pictures afterwards in the admin panel). An
// "Image URL" column is deliberately not supported: images need a storage key
// and are processed (WebP + blur hash) on upload.

const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const ExcelJS = require('exceljs');
const slugify = require('slugify');
const { BadRequestError } = require('../utils/errors');
const { PRODUCT_STATUS } = require('../utils/constants');
const {
  getPackInfo,
  isPacketUnit,
  isCoilUnit,
  isBundleUnit,
} = require('../utils/packSize');

const MAX_ROWS = 5000;
const MAX_FILE_BYTES = 5 * 1024 * 1024;
const HEADER_SCAN_ROWS = 20;
const DEFAULT_STATUS = PRODUCT_STATUS.DRAFT;
const DEFAULT_UNIT = 'piece';
const PRICE_CHANGE_MODES = ['immediate', 'schedule_24h'];

// Canonical column titles (used in messages and in the template) and the other
// spellings accepted for them. Matching ignores case, spaces, underscores,
// punctuation and anything in brackets: "Retail Price (Rs.)" == "retail_price".
const COLUMNS = [
  { field: 'sku', label: 'SKU', aliases: ['sku', 'product sku', 'item code', 'product code', 'code', 'sku code', 'item sku'] },
  { field: 'name', label: 'Name', aliases: ['name', 'product name', 'title', 'product title', 'item name', 'product', 'item'] },
  { field: 'nameHindi', label: 'Hindi Name', aliases: ['hindi name', 'name hindi', 'name in hindi', 'product name hindi'] },
  { field: 'brand', label: 'Brand', aliases: ['brand', 'brand name', 'company', 'manufacturer', 'make'] },
  { field: 'category', label: 'Category', aliases: ['category', 'category name', 'main category', 'parent category', 'category path', 'category tree'] },
  { field: 'subCategory', label: 'Subcategory', aliases: ['subcategory', 'sub category', 'sub category name', 'subcat', 'child category'] },
  { field: 'description', label: 'Description', aliases: ['description', 'long description', 'details', 'product description'] },
  { field: 'shortDescription', label: 'Short Description', aliases: ['short description', 'short desc', 'summary', 'short details'] },
  { field: 'mrp', label: 'MRP', aliases: ['mrp', 'list price', 'maximum retail price', 'mrp price'] },
  { field: 'retailPrice', label: 'Retail Price', aliases: ['retail price', 'customer price', 'selling price', 'sale price', 'price', 'retail'] },
  { field: 'wholesalePrice', label: 'Wholesale Price', aliases: ['wholesale price', 'wholesaler price', 'dealer price', 'trade price', 'bulk price', 'wholesale'] },
  { field: 'minWholesaleQuantity', label: 'Min Wholesale Qty', aliases: ['min wholesale qty', 'min wholesale quantity', 'minimum wholesale quantity', 'wholesale min qty', 'min wholesale order', 'moq', 'min order qty'] },
  { field: 'minCustomerQuantity', label: 'Min Customer Qty', aliases: ['min customer qty', 'min customer quantity', 'minimum customer quantity', 'min retail qty', 'min retail quantity', 'min buyer qty'] },
  { field: 'priceUnit', label: 'Unit', aliases: ['unit', 'price unit', 'uom', 'unit of measure', 'sell unit', 'selling unit'] },
  { field: 'packing', label: 'Packing', aliases: ['packing', 'packing details', 'packaging', 'pack details'] },
  { field: 'packType', label: 'Pack Type', aliases: ['pack type', 'package type', 'pack unit'] },
  { field: 'packSize', label: 'Pack Size', aliases: ['pack size', 'pieces per pack', 'units per pack', 'pack qty', 'pack quantity', 'length per pack'] },
  { field: 'stock', label: 'Stock', aliases: ['stock', 'stock qty', 'stock quantity', 'quantity', 'qty', 'inventory', 'on hand', 'opening stock'] },
  { field: 'lowStockThreshold', label: 'Low Stock Alert', aliases: ['low stock alert', 'low stock', 'low stock threshold', 'reorder level', 'reorder point'] },
  { field: 'status', label: 'Status', aliases: ['status', 'product status'] },
  { field: 'negotiationEnabled', label: 'Negotiation', aliases: ['negotiation', 'negotiation enabled', 'allow negotiation', 'negotiable'] },
  { field: 'isFeatured', label: 'Featured', aliases: ['featured', 'is featured'] },
  { field: 'isHot', label: 'Hot', aliases: ['hot', 'is hot', 'hot product'] },
  { field: 'tags', label: 'Tags', aliases: ['tags', 'tag', 'keywords'] },
];

const LABELS = Object.fromEntries(COLUMNS.map((column) => [column.field, column.label]));

const normalizeHeader = (value) => String(value ?? '')
  .toLowerCase()
  .replace(/\(.*?\)/g, '')
  .replace(/[^a-z0-9]/g, '');

const HEADER_LOOKUP = new Map();
for (const column of COLUMNS) {
  HEADER_LOOKUP.set(normalizeHeader(column.label), column.field);
  for (const alias of column.aliases) HEADER_LOOKUP.set(normalizeHeader(alias), column.field);
}

const fieldForHeader = (header) => HEADER_LOOKUP.get(normalizeHeader(header)) || null;

// ---------------------------------------------------------------------------
// Cell helpers

const isBlank = (value) => (
  value === undefined || value === null || (typeof value === 'string' && value.trim() === '')
);

// Plain text of a cell (numbers keep their digits; whitespace is tidied).
function cellText(value) {
  if (isBlank(value)) return '';
  if (value instanceof Date) return value.toISOString().slice(0, 10);
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  return String(value).replace(/[\u00a0\u200b]/g, ' ').replace(/\r\n?/g, '\n').trim();
}

// Money and quantity cells: 1250, "1,250", "1,00,000.50", "Rs. 1250", "₹ 1250/-".
function parseNumber(raw) {
  if (isBlank(raw)) return { blank: true };
  if (typeof raw === 'number') {
    return Number.isFinite(raw) ? { value: raw } : { error: 'is not a number' };
  }
  let text = String(raw).replace(/[\s\u00a0]/g, '');
  text = text.replace(/^(?:₹|rs\.?|inr)/i, '').replace(/(?:\/-|-\/)$/, '');
  if (text.includes(',')) {
    if (!/^-?\d{1,3}(,\d{2,3})*(\.\d+)?$/.test(text)) return { error: 'is not a number' };
    text = text.replace(/,/g, '');
  }
  if (!/^-?(\d+\.?\d*|\.\d+)$/.test(text)) return { error: 'is not a number' };
  const value = Number(text);
  return Number.isFinite(value) ? { value } : { error: 'is not a number' };
}

const TRUE_WORDS = new Set(['yes', 'y', 'true', '1', 'on', 'enabled']);
const FALSE_WORDS = new Set(['no', 'n', 'false', '0', 'off', 'disabled']);

function parseBoolean(raw) {
  if (isBlank(raw)) return { blank: true };
  if (typeof raw === 'boolean') return { value: raw };
  const word = String(raw).trim().toLowerCase();
  if (TRUE_WORDS.has(word)) return { value: true };
  if (FALSE_WORDS.has(word)) return { value: false };
  return { error: 'must be Yes or No' };
}

const round2 = (value) => Math.round((value + Number.EPSILON) * 100) / 100;
const normName = (value) => String(value ?? '').normalize('NFKC').replace(/\s+/g, ' ').trim().toLowerCase();
const slugOf = (value) => slugify(String(value), { lower: true, strict: true });
const cleanName = (value) => String(value ?? '').replace(/\s+/g, ' ').trim();

// ---------------------------------------------------------------------------
// Reading files

function extractCellValue(value) {
  if (value === null || value === undefined) return null;
  if (typeof value !== 'object' || value instanceof Date) return value;
  if (Array.isArray(value.richText)) return value.richText.map((part) => part.text).join('');
  if (value.formula !== undefined || value.sharedFormula !== undefined) {
    return extractCellValue(value.result ?? null);
  }
  if (value.hyperlink !== undefined) return value.text ?? value.hyperlink;
  if (value.error !== undefined) return String(value.error);
  if (value.text !== undefined) return value.text;
  return String(value);
}

// RFC 4180-style CSV: quotes, doubled quotes, newlines inside quotes, CRLF,
// BOM; the delimiter (comma, semicolon or tab) is taken from the first line.
function parseCsvText(input) {
  let text = String(input ?? '');
  if (text.charCodeAt(0) === 0xfeff) text = text.slice(1);
  const firstLine = text.split(/\r?\n/, 1)[0] || '';
  const delimiter = [',', ';', '\t']
    .map((candidate) => ({ candidate, count: firstLine.split(candidate).length - 1 }))
    .sort((a, b) => b.count - a.count)[0];
  const separator = delimiter.count > 0 ? delimiter.candidate : ',';

  const rows = [];
  let row = [];
  let cell = '';
  let quoted = false;
  let sawAny = false;
  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];
    if (quoted) {
      if (char === '"') {
        if (text[i + 1] === '"') { cell += '"'; i += 1; } else quoted = false;
      } else {
        cell += char;
      }
    } else if (char === '"' && cell === '') {
      quoted = true;
      sawAny = true;
    } else if (char === separator) {
      row.push(cell); cell = ''; sawAny = true;
    } else if (char === '\n' || char === '\r') {
      if (char === '\r' && text[i + 1] === '\n') i += 1;
      row.push(cell); rows.push(row); row = []; cell = ''; sawAny = false;
    } else {
      cell += char; sawAny = true;
    }
  }
  if (sawAny || cell !== '' || row.length > 0) { row.push(cell); rows.push(row); }
  return rows;
}

const looksLikeZip = (buffer) => buffer.length > 3 && buffer[0] === 0x50 && buffer[1] === 0x4b;

async function readXlsxMatrix(buffer) {
  const workbook = new ExcelJS.Workbook();
  try {
    await workbook.xlsx.load(buffer);
  } catch (error) {
    throw new BadRequestError('This file could not be read as an Excel (.xlsx) workbook. Save it as .xlsx or .csv and try again.', 'INVALID_WORKBOOK');
  }
  const sheet = workbook.worksheets.find((candidate) => normalizeHeader(candidate.name) === 'products')
    || workbook.worksheets[0];
  if (!sheet) throw new BadRequestError('The workbook has no sheets.', 'INVALID_WORKBOOK');
  const matrix = [];
  sheet.eachRow({ includeEmpty: false }, (row, rowNumber) => {
    const cells = [];
    row.eachCell({ includeEmpty: false }, (cell, columnNumber) => {
      cells[columnNumber - 1] = extractCellValue(cell.value);
    });
    matrix[rowNumber - 1] = cells;
  });
  return { matrix, sheetName: sheet.name };
}

function matrixToRows(matrix, sheetName) {
  const isEmptyRow = (cells) => !cells || cells.every(isBlank);

  let headerIndex = -1;
  for (let i = 0; i < Math.min(matrix.length, HEADER_SCAN_ROWS); i += 1) {
    const cells = matrix[i];
    if (isEmptyRow(cells)) continue;
    const fields = new Set(cells.map((cell) => fieldForHeader(cellText(cell))).filter(Boolean));
    if (fields.has('sku') && fields.size >= 2) { headerIndex = i; break; }
  }
  if (headerIndex === -1) {
    throw new BadRequestError(
      'Could not find the header row. The first row must hold the column names and include at least SKU and Name (see the template).',
      'MISSING_COLUMNS',
    );
  }

  const headerCells = matrix[headerIndex];
  const columns = [];
  const ignoredColumns = [];
  const seen = new Map();
  headerCells.forEach((cell, index) => {
    const header = cellText(cell);
    if (!header) return;
    const field = fieldForHeader(header);
    if (!field) { ignoredColumns.push(header); return; }
    if (seen.has(field)) {
      throw new BadRequestError(
        `Columns "${seen.get(field)}" and "${header}" both mean ${LABELS[field]}. Keep only one of them.`,
        'DUPLICATE_COLUMN',
      );
    }
    seen.set(field, header);
    columns.push({ index, header, field });
  });

  const rows = [];
  for (let i = headerIndex + 1; i < matrix.length; i += 1) {
    const cells = matrix[i];
    if (isEmptyRow(cells)) continue;
    const values = {};
    for (const column of columns) values[column.field] = cells[column.index] ?? null;
    if (Object.values(values).every(isBlank)) continue;
    rows.push({ row: i + 1, values });
    if (rows.length > MAX_ROWS) {
      throw new BadRequestError(`The file has more than ${MAX_ROWS} product rows. Split it into smaller files.`, 'TOO_MANY_ROWS');
    }
  }
  return {
    rows,
    columns: columns.map(({ header, field }) => ({ header, field, label: LABELS[field] })),
    ignoredColumns,
    sheetName: sheetName || null,
  };
}

async function parseWorkbook(input, { filename } = {}) {
  let buffer;
  let name = filename || '';
  if (typeof input === 'string') {
    if (!name) name = path.basename(input);
    const stat = fs.statSync(input);
    if (stat.size > MAX_FILE_BYTES) throw new BadRequestError('The file is larger than 5 MB.', 'FILE_TOO_LARGE');
    buffer = fs.readFileSync(input);
  } else if (Buffer.isBuffer(input) || input instanceof Uint8Array) {
    buffer = Buffer.from(input);
  } else {
    throw new BadRequestError('No file given.', 'FILE_REQUIRED');
  }
  if (buffer.length > MAX_FILE_BYTES) throw new BadRequestError('The file is larger than 5 MB.', 'FILE_TOO_LARGE');
  if (buffer.length === 0) throw new BadRequestError('The file is empty.', 'EMPTY_FILE');

  const extension = path.extname(name).toLowerCase();
  let kind = null;
  if (extension === '.xlsx') kind = 'xlsx';
  else if (extension === '.csv') kind = 'csv';
  else if (!extension) kind = looksLikeZip(buffer) ? 'xlsx' : 'csv';
  else {
    throw new BadRequestError(
      `Unsupported file type "${extension}". Upload an Excel .xlsx file or a .csv file.`,
      'INVALID_FILE_TYPE',
    );
  }
  if (kind === 'csv' && looksLikeZip(buffer)) {
    throw new BadRequestError('This looks like an Excel file, not a CSV. Rename it to .xlsx.', 'INVALID_FILE_TYPE');
  }
  if (kind === 'xlsx' && !looksLikeZip(buffer)) {
    throw new BadRequestError('This file is not a valid .xlsx workbook (older .xls files are not supported; save as .xlsx or .csv).', 'INVALID_FILE_TYPE');
  }

  if (kind === 'csv') {
    return matrixToRows(parseCsvText(buffer.toString('utf8')), null);
  }
  const { matrix, sheetName } = await readXlsxMatrix(buffer);
  return matrixToRows(matrix, sheetName);
}

// ---------------------------------------------------------------------------
// Catalog lookups (brand / category matching)

function buildIndexes(catalog = {}) {
  const brands = catalog.brands || [];
  const categories = catalog.categories || [];
  const products = catalog.products || [];

  const brandByName = new Map();
  const brandSlugs = new Map();
  for (const brand of brands) {
    brandByName.set(normName(brand.name), brand);
    brandSlugs.set(String(brand.slug || slugOf(brand.name)), brand);
  }

  const categoriesByBrand = new Map();
  const categoryById = new Map();
  for (const category of categories) {
    const key = String(category.company);
    if (!categoriesByBrand.has(key)) categoriesByBrand.set(key, []);
    categoriesByBrand.get(key).push(category);
    categoryById.set(String(category._id), category);
  }

  const productBySku = new Map();
  const productBySlug = new Map();
  for (const product of products) {
    productBySku.set(String(product.sku).toUpperCase(), product);
    if (product.slug) productBySlug.set(String(product.slug), product);
  }
  return { brands, brandByName, brandSlugs, categoriesByBrand, categoryById, productBySku, productBySlug };
}

const brandById = (indexes, id) => indexes.brands.find((brand) => String(brand._id) === String(id)) || null;

// Splits "Power Tools > Drills & Drivers" (and a separate Subcategory cell) into names.
function categoryPathFromCells(categoryCell, subCategoryCell) {
  const parts = cleanName(categoryCell).split(/\s*[>›»]\s*/).map(cleanName).filter(Boolean);
  const sub = cleanName(subCategoryCell);
  if (sub) {
    if (parts.length >= 2 && normName(parts[parts.length - 1]) !== normName(sub)) {
      return { error: `Subcategory "${sub}" does not match the last part of the category path "${parts.join(' > ')}".` };
    }
    if (parts.length < 2) parts.push(sub);
  }
  if (parts.length > 4) return { error: 'Category paths can be at most 4 levels deep.' };
  return { parts };
}

// Finds the category for a path inside one brand. A single name may be a
// subcategory when it is unambiguous ("Drills & Drivers"); otherwise walk
// Parent > Child from the top level.
function findCategory(indexes, brandId, parts) {
  const list = indexes.categoriesByBrand.get(String(brandId)) || [];
  const childrenOf = (parentId) => list.filter((category) => (
    (parentId ? String(category.parent) === String(parentId) : !category.parent)
  ));
  const named = (candidates, name) => candidates.filter((category) => normName(category.name) === normName(name));

  let parent = null;
  let walked = 0;
  for (let i = 0; i < parts.length; i += 1) {
    const matches = named(childrenOf(parent && parent._id), parts[i]);
    if (matches.length === 1) { parent = matches[0]; walked += 1; continue; }
    if (matches.length > 1) return { ambiguous: true };
    break;
  }
  if (walked === parts.length) return { category: parent };

  if (parts.length === 1 && walked === 0) {
    const anywhere = named(list, parts[0]);
    if (anywhere.length === 1) return { category: anywhere[0] };
    if (anywhere.length > 1) return { ambiguous: true };
  }
  return { missingFrom: walked, parent };
}

// ---------------------------------------------------------------------------
// Validation

const PACK_TYPES = { packet: 'Packet', coil: 'Coil', bundle: 'Bundle' };

function packTypeOfUnit(unit) {
  if (isPacketUnit(unit)) return 'packet';
  if (isCoilUnit(unit)) return 'coil';
  if (isBundleUnit(unit)) return 'bundle';
  return null;
}

function packTypeFromCell(text) {
  const word = normName(text);
  if (/^packets?$/.test(word) || word === 'pack' || word === 'packs') return 'packet';
  if (/^coils?$/.test(word)) return 'coil';
  if (/^bundles?$/.test(word)) return 'bundle';
  return null;
}

const sameValue = (a, b) => {
  if (Array.isArray(a) || Array.isArray(b)) {
    return JSON.stringify([...(a || [])].map(String).sort()) === JSON.stringify([...(b || [])].map(String).sort());
  }
  if (typeof a === 'number' || typeof b === 'number') return Number(a) === Number(b);
  return (a ?? '') === (b ?? '');
};

const FIELD_ORDER = [
  'sku', 'name', 'nameHindi', 'brand', 'category', 'description', 'shortDescription', 'mrp', 'retailPrice',
  'wholesalePrice', 'minWholesaleQuantity', 'minCustomerQuantity', 'priceUnit', 'packing', 'stock',
  'lowStockThreshold', 'status', 'negotiationEnabled', 'isFeatured', 'isHot', 'tags',
];

function validateRow(raw, context) {
  const { indexes, createMissing, duplicates } = context;
  const values = raw.values || {};
  const errors = [];
  const warnings = [];
  const addError = (field, message) => errors.push({ field, column: LABELS[field] || field, message });
  const addWarning = (field, message) => warnings.push({ field, column: LABELS[field] || field, message });
  const has = (field) => !isBlank(values[field]);

  const result = {
    row: raw.row,
    sku: '',
    action: 'skip',
    status: 'ok',
    errors,
    warnings,
    changes: [],
    normalized: {},
  };
  const out = {}; // normalized values for the fields given in the file

  // SKU -------------------------------------------------------------------
  const skuText = cellText(values.sku).toUpperCase();
  result.sku = skuText;
  let existing = null;
  if (!skuText) {
    addError('sku', 'SKU is required.');
  } else if (skuText.length > 64 || !/^[A-Z0-9][A-Z0-9._/-]*$/.test(skuText)) {
    addError('sku', 'SKU may only contain letters, numbers and - _ . / (no spaces), up to 64 characters.');
  } else {
    existing = indexes.productBySku.get(skuText) || null;
    if (duplicates.get(skuText)?.length > 1) {
      const others = duplicates.get(skuText).filter((row) => row !== raw.row);
      addError('sku', `Duplicate SKU in this file (also on row ${others.join(', ')}).`);
    }
  }
  const creating = !existing;
  if (skuText && errors.every((error) => error.field !== 'sku' || error.message.startsWith('Duplicate'))) {
    result.action = creating ? 'create' : 'update';
  }
  out.sku = skuText;

  // Text fields -----------------------------------------------------------
  const textField = (field, { max, requiredOnCreate = false } = {}) => {
    if (!has(field)) {
      if (creating && requiredOnCreate) addError(field, `${LABELS[field]} is required for a new product.`);
      return undefined;
    }
    const value = cellText(values[field]);
    if (max && value.length > max) {
      addError(field, `${LABELS[field]} is too long (${value.length} characters; the limit is ${max}).`);
      return undefined;
    }
    out[field] = value;
    return value;
  };
  const name = textField('name', { max: 200, requiredOnCreate: true });
  if (name !== undefined) out.name = cleanName(name);
  textField('nameHindi', { max: 200 });
  textField('description');
  textField('shortDescription', { max: 300 });
  if (creating && !has('description')) {
    addWarning('description', 'No description; the product page will show none. You can add one later.');
  }

  // Tags -----------------------------------------------------------------
  if (has('tags')) {
    const tags = [...new Set(cellText(values.tags).split(/[,;|\n]/).map((tag) => tag.trim()).filter(Boolean))];
    if (tags.some((tag) => tag.length > 50) || tags.length > 20) {
      addError('tags', 'Tags: at most 20 tags of 50 characters each.');
    } else {
      out.tags = tags;
    }
  }

  // Numbers ----------------------------------------------------------------
  const numberField = (field, { integer = false, min = 0, requiredOnCreate = false } = {}) => {
    if (!has(field)) {
      if (creating && requiredOnCreate) addError(field, `${LABELS[field]} is required for a new product.`);
      return undefined;
    }
    const parsed = parseNumber(values[field]);
    if (parsed.error) {
      addError(field, `${LABELS[field]} "${cellText(values[field])}" ${parsed.error}.`);
      return undefined;
    }
    let { value } = parsed;
    if (value < min) {
      addError(field, `${LABELS[field]} must be ${min === 0 ? 'zero or more' : `at least ${min}`} (found ${value}).`);
      return undefined;
    }
    if (integer && !Number.isInteger(value)) {
      addError(field, `${LABELS[field]} must be a whole number (found ${value}).`);
      return undefined;
    }
    if (!integer && round2(value) !== value) {
      addWarning(field, `${LABELS[field]} ${value} was rounded to ${round2(value)}.`);
      value = round2(value);
    }
    out[field] = value;
    return value;
  };
  numberField('mrp', { requiredOnCreate: true });
  numberField('retailPrice', { requiredOnCreate: true });
  numberField('wholesalePrice', { requiredOnCreate: true });
  numberField('minWholesaleQuantity', { integer: true, min: 1 });
  numberField('minCustomerQuantity', { integer: true, min: 1 });
  numberField('stock', { integer: true });
  numberField('lowStockThreshold', { integer: true });

  const mrp = out.mrp ?? existing?.mrp;
  const retail = out.retailPrice ?? existing?.retailPrice;
  const wholesale = out.wholesalePrice ?? existing?.wholesalePrice;
  const touchesPrice = ['mrp', 'retailPrice', 'wholesalePrice'].some((field) => out[field] !== undefined);
  if (touchesPrice) {
    if (retail !== undefined && mrp !== undefined && retail > mrp) {
      addWarning('retailPrice', `Retail price ${retail} is higher than MRP ${mrp}.`);
    }
    if (wholesale !== undefined && retail !== undefined && wholesale > retail) {
      addWarning('wholesalePrice', `Wholesale price ${wholesale} is higher than the retail price ${retail}.`);
    }
  }

  // Yes/No flags ---------------------------------------------------------------
  for (const field of ['negotiationEnabled', 'isFeatured', 'isHot']) {
    if (!has(field)) continue;
    const parsed = parseBoolean(values[field]);
    if (parsed.error) addError(field, `${LABELS[field]} "${cellText(values[field])}" ${parsed.error}.`);
    else out[field] = parsed.value;
  }

  // Status ----------------------------------------------------------------------
  if (has('status')) {
    const status = normName(values.status);
    if (!Object.values(PRODUCT_STATUS).includes(status)) {
      addError('status', `Status "${cellText(values.status)}" is not valid. Use active, draft or archived.`);
    } else {
      out.status = status;
    }
  } else if (creating) {
    out.status = DEFAULT_STATUS;
  }

  // Unit, packing, pack type / size -----------------------------------------------
  const unitCell = has('priceUnit') ? cellText(values.priceUnit) : '';
  const packingCell = has('packing') ? cellText(values.packing) : '';
  const packTypeCell = has('packType') ? cellText(values.packType) : '';
  const packSizeGiven = has('packSize');
  let packType = null;
  let packSize = null;
  if (packTypeCell) {
    packType = packTypeFromCell(packTypeCell);
    if (!packType) addError('packType', `Pack Type "${packTypeCell}" is not valid. Use Packet, Coil or Bundle (or leave it empty).`);
  }
  if (packSizeGiven) {
    const parsed = parseNumber(values.packSize);
    if (parsed.error) addError('packSize', `Pack Size "${cellText(values.packSize)}" ${parsed.error}.`);
    else if (!Number.isInteger(parsed.value) || parsed.value < 2) addError('packSize', 'Pack Size must be a whole number of 2 or more (pieces per packet, or metres per coil/bundle).');
    else packSize = parsed.value;
  }

  const touchesPack = Boolean(unitCell || packingCell || packTypeCell || packSizeGiven);
  if (touchesPack || (creating && !has('priceUnit'))) {
    let unit = unitCell;
    let packing = packingCell;
    const typeOfUnit = unit ? packTypeOfUnit(unit) : null;
    if (packType) {
      if (unit && typeOfUnit !== packType) {
        addError('packType', `Unit "${unit}" does not match Pack Type "${packTypeCell}".`);
      } else {
        unit = unit || PACK_TYPES[packType];
      }
    }
    const effectiveType = packType || (unit ? typeOfUnit : packTypeOfUnit(existing?.priceUnit));
    if (packSizeGiven && packSize !== null && !effectiveType) {
      addError('packSize', 'Pack Size needs a Pack Type (Packet, Coil or Bundle), or a Unit that is one of them.');
    }
    if (packSize !== null && effectiveType) {
      const derived = effectiveType === 'packet' ? `${packSize} pcs` : `${packSize} m`;
      const finalUnit = unit || existing?.priceUnit || PACK_TYPES[effectiveType];
      if (packing) {
        const given = getPackInfo({ priceUnit: finalUnit, packing }).size;
        if (given !== packSize) {
          addError('packSize', `Packing "${packing}" does not match Pack Size ${packSize}. Leave Packing empty to use "${derived}".`);
        }
      } else {
        packing = derived;
      }
      if (!unit && !existing?.priceUnit) unit = PACK_TYPES[effectiveType];
    }
    if (creating && !unit) unit = DEFAULT_UNIT;

    const finalUnit = unit || existing?.priceUnit || '';
    const finalPacking = packing || (touchesPack ? existing?.packing : '') || '';
    if (unit) out.priceUnit = unit;
    if (packing) out.packing = packing;

    if (!errors.some((error) => error.field === 'packType' || error.field === 'packSize')) {
      const info = getPackInfo({ priceUnit: finalUnit, packing: finalPacking });
      const packish = packTypeOfUnit(finalUnit);
      if ((packTypeCell || packSizeGiven) && !info.packUnit) {
        addError(packTypeCell ? 'packType' : 'packSize',
          `${PACK_TYPES[effectiveType] || 'Pack'} products need a pack size: give Pack Size, or Packing like ${effectiveType === 'packet' ? '"15 pcs"' : '"50 m"'}.`);
      } else if (packish && !info.packUnit && touchesPack) {
        addWarning('packing',
          `Unit "${finalUnit}" with Packing "${finalPacking || '(empty)'}" is sold as a normal product priced per ${finalUnit}, not per piece or metre. `
          + `For packs of N pieces or metres use Pack Type and Pack Size.`);
      }
    }
  }

  // Brand / category --------------------------------------------------------------
  const brandCell = has('brand') ? cleanName(cellText(values.brand)) : '';
  const categoryCell = has('category') ? cellText(values.category) : '';
  const subCategoryCell = has('subCategory') ? cellText(values.subCategory) : '';
  if (creating) {
    if (!brandCell) addError('brand', 'Brand is required for a new product.');
    if (!categoryCell && !subCategoryCell) addError('category', 'Category is required for a new product.');
  } else if (subCategoryCell && !categoryCell) {
    addError('subCategory', 'Subcategory needs a Category as well (the parent category).');
  }
  if (brandCell && brandCell.length > 100) addError('brand', 'Brand name is too long (100 characters at most).');
  if (!creating && brandCell && !categoryCell && !subCategoryCell) {
    const current = brandById(indexes, existing.company);
    if (!current || normName(current.name) !== normName(brandCell)) {
      addError('brand', 'To move a product to another brand, also give its Category.');
    }
  }

  if ((categoryCell || subCategoryCell) && !errors.some((error) => ['brand', 'category', 'subCategory'].includes(error.field))) {
    const parsedPath = categoryPathFromCells(categoryCell, subCategoryCell);
    if (parsedPath.error) {
      addError('category', parsedPath.error);
    } else {
      const parts = parsedPath.parts;
      let brand = null;
      let brandIsNew = false;
      if (brandCell) {
        brand = indexes.brandByName.get(normName(brandCell)) || null;
        if (!brand) {
          if (!createMissing) {
            addError('brand', `Brand "${brandCell}" does not exist. Create it first or import with "create missing brands and categories".`);
          } else if (indexes.brandSlugs.has(slugOf(brandCell))) {
            addError('brand', `Brand "${brandCell}" is too similar to the existing brand "${indexes.brandSlugs.get(slugOf(brandCell)).name}".`);
          } else {
            brandIsNew = true;
          }
        }
      } else if (existing) {
        brand = brandById(indexes, existing.company);
        if (!brand) addError('brand', 'This product has no brand yet; add a Brand column value.');
      }
      if (!errors.some((error) => error.field === 'brand' || error.field === 'category')) {
        let categoryId = null;
        let canonicalParts = parts;
        let categoryIsNew = brandIsNew;
        let existingDepth = 0;
        if (!brandIsNew && brand) {
          const found = findCategory(indexes, brand._id, parts);
          if (found.ambiguous) {
            addError('category', `"${parts.join(' > ')}" matches more than one category under ${brand.name}. Write the full path as "Parent > Child".`);
          } else if (found.category) {
            categoryId = String(found.category._id);
            // Canonical spelling: the names as stored, walked up the tree.
            const chain = [];
            let node = found.category;
            while (node) {
              chain.unshift(node.name);
              node = node.parent ? indexes.categoryById.get(String(node.parent)) : null;
            }
            canonicalParts = chain;
          } else if (!createMissing) {
            addError('category', `Category "${parts.join(' > ')}" does not exist under ${brand.name}. Create it first or import with "create missing brands and categories".`);
          } else {
            categoryIsNew = true;
            // Reuse the stored spelling of the part of the path that already exists.
            const existingChain = [];
            let node = found.parent;
            while (node) {
              existingChain.unshift(node.name);
              node = node.parent ? indexes.categoryById.get(String(node.parent)) : null;
            }
            canonicalParts = [...existingChain, ...parts.slice(found.missingFrom)];
            existingDepth = found.missingFrom;
            const siblings = (indexes.categoriesByBrand.get(String(brand._id)) || [])
              .filter((category) => String(category.parent || '') === String(found.parent?._id || ''));
            const wanted = slugOf(parts[found.missingFrom]);
            const clash = siblings.find((category) => (category.slug || slugOf(category.name)) === wanted);
            if (clash) addError('category', `Category "${parts[found.missingFrom]}" is too similar to the existing category "${clash.name}".`);
          }
        }
        if (!errors.some((error) => error.field === 'category')) {
          out.brand = brand ? brand.name : brandCell;
          out.category = canonicalParts.join(' > ');
          result.target = { brandIsNew, categoryIsNew, categoryId, existingDepth };
          if (existing && !categoryIsNew && categoryId && String(existing.categoryRef) === categoryId) {
            // Same category as today: not a change.
            delete result.target;
            delete out.brand;
            delete out.category;
          }
        }
      }
    }
  }

  // Result -----------------------------------------------------------------------
  if (result.action === 'update' && errors.length === 0) {
    const changes = [];
    for (const field of FIELD_ORDER) {
      if (field === 'sku' || out[field] === undefined) continue;
      if (field === 'brand') {
        const from = brandById(indexes, existing.company)?.name || '';
        if (result.target && normName(from) !== normName(out.brand)) changes.push({ field, column: LABELS.brand, from, to: out.brand });
        continue;
      }
      if (field === 'category') {
        if (!result.target) continue;
        changes.push({ field, column: LABELS.category, from: existing.category || '', to: out.category });
        continue;
      }
      const before = existing[field];
      const beforeValue = field === 'tags' ? (before || []) : before;
      if (!sameValue(beforeValue, out[field])) {
        changes.push({ field, column: LABELS[field], from: beforeValue ?? null, to: out[field] });
      }
    }
    result.changes = changes;
    if (changes.length === 0) result.action = 'skip';
  }

  result.normalized = Object.fromEntries(FIELD_ORDER.filter((field) => out[field] !== undefined).map((field) => [field, out[field]]));
  if (result.action === 'skip' && errors.length === 0) {
    result.warnings = warnings;
    result.note = 'No changes: the product already matches this row.';
  }
  result.status = errors.length > 0 ? 'error' : (warnings.length > 0 ? 'warning' : 'ok');
  return result;
}

// Pure: checks every row against a snapshot of the catalog and says what an
// import would do. `catalog` = { brands, categories, products } as returned by
// loadCatalogSnapshot (an empty catalog treats every brand/category as unknown).
function validateRows(rows, { createMissing = false, catalog = {}, ignoredColumns = [], columns = null } = {}) {
  const list = Array.isArray(rows) ? rows : (rows?.rows || []);
  const indexes = buildIndexes(catalog);

  const duplicates = new Map();
  for (const row of list) {
    const sku = cellText(row.values?.sku).toUpperCase();
    if (!sku) continue;
    if (!duplicates.has(sku)) duplicates.set(sku, []);
    duplicates.get(sku).push(row.row);
  }

  const reportRows = list.map((row) => validateRow(row, { indexes, createMissing, duplicates }));

  // Two products cannot share a web address (slug), neither with each other nor with a stored product.
  const slugOwner = new Map();
  for (const row of reportRows) {
    if (row.errors.length > 0 || row.normalized.name === undefined) continue;
    const slug = slugOf(row.normalized.name);
    if (!slug) {
      row.errors.push({ field: 'name', column: LABELS.name, message: 'Name needs at least one letter or number.' });
      continue;
    }
    const stored = indexes.productBySlug.get(slug);
    const storedSame = stored && stored.sku === row.sku;
    const sameFile = slugOwner.get(slug);
    if (stored && !storedSame && row.action !== 'skip') {
      row.errors.push({
        field: 'name',
        column: LABELS.name,
        message: `Another product (${stored.sku}) already has this name, so the web address would clash. Make the name unique.`,
      });
    } else if (sameFile && sameFile !== row.sku) {
      row.errors.push({
        field: 'name',
        column: LABELS.name,
        message: `Another row (SKU ${sameFile}) in this file has the same name, so the web address would clash. Make the name unique.`,
      });
    } else {
      slugOwner.set(slug, row.sku);
    }
  }
  for (const row of reportRows) {
    row.status = row.errors.length > 0 ? 'error' : (row.warnings.length > 0 ? 'warning' : 'ok');
  }

  // Rows that name the same new brand in different spellings use the first one.
  const firstSpelling = new Map();
  for (const row of reportRows) {
    if (row.errors.length > 0 || !row.target?.brandIsNew) continue;
    const key = normName(row.normalized.brand);
    if (!firstSpelling.has(key)) firstSpelling.set(key, row.normalized.brand);
    row.normalized.brand = firstSpelling.get(key);
  }

  // Brands and categories the import would create (error-free rows only).
  const newBrands = new Map();
  const newCategories = new Map();
  for (const row of reportRows) {
    if (row.errors.length > 0 || !row.target) continue;
    const brandKey = normName(row.normalized.brand);
    if (row.target.brandIsNew && !newBrands.has(brandKey)) newBrands.set(brandKey, row.normalized.brand);
    if (row.target.categoryIsNew) {
      const parts = row.normalized.category.split(' > ');
      for (let depth = row.target.existingDepth + 1; depth <= parts.length; depth += 1) {
        const key = `${brandKey}|${parts.slice(0, depth).map(normName).join('>')}`;
        if (!newCategories.has(key)) {
          newCategories.set(key, { brand: row.normalized.brand, path: parts.slice(0, depth).join(' > ') });
        }
      }
    }
  }

  const counted = reportRows.filter((row) => row.errors.length === 0);
  const summary = {
    totalRows: reportRows.length,
    created: counted.filter((row) => row.action === 'create').length,
    updated: counted.filter((row) => row.action === 'update').length,
    skipped: counted.filter((row) => row.action === 'skip').length,
    errors: reportRows.filter((row) => row.errors.length > 0).length,
    warnings: reportRows.filter((row) => row.warnings.length > 0).length,
    errorCount: reportRows.reduce((sum, row) => sum + row.errors.length, 0),
    warningCount: reportRows.reduce((sum, row) => sum + row.warnings.length, 0),
    newBrands: newBrands.size,
    newCategories: newCategories.size,
  };

  return {
    dryRun: true,
    committed: false,
    createMissing: Boolean(createMissing),
    summary,
    newBrands: [...newBrands.values()],
    newCategories: [...newCategories.values()].map((entry) => `${entry.brand}: ${entry.path}`),
    columns: columns || undefined,
    ignoredColumns,
    rows: reportRows,
  };
}

// ---------------------------------------------------------------------------
// Database

async function loadCatalogSnapshot({ session = null } = {}) {
  const { Company, Category, Product } = require('../models');
  const withSession = (query) => (session ? query.session(session) : query);
  const [brands, categories, products] = await Promise.all([
    withSession(Company.find({}).select('_id name slug').lean()),
    withSession(Category.find({}).select('_id name slug company parent').lean()),
    withSession(Product.find({}).select(
      'sku slug name nameHindi description shortDescription category categoryRef company mrp retailPrice wholesalePrice '
      + 'minWholesaleQuantity minCustomerQuantity priceUnit packing stock lowStockThreshold status '
      + 'negotiationEnabled isFeatured isHot tags',
    ).lean()),
  ]);
  return { brands, categories, products };
}

const ensureModelsReady = async () => {
  const { Company, Category, Product, StockLog, PriceChangeAudit, AuditLog } = require('../models');
  await Promise.all([Company, Category, Product, StockLog, PriceChangeAudit, AuditLog].map((model) => model.init()));
};

function mergeParse(rows, options) {
  if (Array.isArray(rows)) return { rows, columns: options.columns, ignoredColumns: options.ignoredColumns || [] };
  return { rows: rows?.rows || [], columns: rows?.columns, ignoredColumns: rows?.ignoredColumns || [] };
}

// Builds the body the admin product functions expect from a validated row.
function productBodyFor(row, { creating, categoryId, categoryLeaf, brandName, priceChangeMode }) {
  const n = row.normalized;
  const body = {};
  for (const field of [
    'name', 'nameHindi', 'description', 'shortDescription', 'mrp', 'retailPrice', 'wholesalePrice',
    'minWholesaleQuantity', 'minCustomerQuantity', 'priceUnit', 'packing', 'stock', 'lowStockThreshold',
    'status', 'negotiationEnabled', 'isFeatured', 'isHot', 'tags',
  ]) {
    if (n[field] !== undefined) body[field] = n[field];
  }
  if (creating) {
    body.sku = n.sku;
    body.description = n.description ?? '';
  }
  if (categoryId) {
    body.categoryId = String(categoryId);
    body.brand = brandName;
    body.subCategory = categoryLeaf;
  }
  if (!creating) {
    // Only the columns that differ are sent; the product function compares prices itself.
    const changed = new Set(row.changes.map((change) => change.field));
    for (const field of Object.keys(body)) {
      if (['categoryId', 'brand', 'subCategory'].includes(field)) continue;
      if (!changed.has(field)) delete body[field];
    }
    body.priceChangeMode = priceChangeMode;
  }
  return body;
}

// Validates and (unless dryRun) writes. All writes happen in one transaction.
async function importCatalog(rows, options = {}) {
  const {
    dryRun = true,
    createMissing = false,
    actorId = null,
    priceChangeMode = 'immediate',
    fileName = null,
    awaitFollowUps = false,
  } = options;
  if (!PRICE_CHANGE_MODES.includes(priceChangeMode)) {
    throw new BadRequestError(`priceChangeMode must be one of: ${PRICE_CHANGE_MODES.join(', ')}`, 'INVALID_PRICE_CHANGE_MODE');
  }
  const parsed = mergeParse(rows, options);
  if (parsed.rows.length > MAX_ROWS) {
    throw new BadRequestError(`The file has more than ${MAX_ROWS} product rows. Split it into smaller files.`, 'TOO_MANY_ROWS');
  }
  if (parsed.rows.length === 0) {
    throw new BadRequestError('The file has a header row but no product rows.', 'NO_ROWS');
  }

  const validateAgainst = async (session) => {
    const catalog = await loadCatalogSnapshot({ session });
    const report = validateRows(parsed.rows, {
      createMissing,
      catalog,
      ignoredColumns: parsed.ignoredColumns,
      columns: parsed.columns,
    });
    return { report, catalog };
  };
  const finish = (report) => {
    report.fileName = fileName;
    report.priceChangeMode = priceChangeMode;
    return report;
  };

  if (dryRun) {
    const { report } = await validateAgainst(null);
    report.dryRun = true;
    report.committed = false;
    return finish(report);
  }

  await ensureModelsReady();
  const followUps = { categoryPairs: new Map(), hindiProductIds: [], hindiCategoryIds: [], priceNotices: [], scheduled: false };
  let report;
  await mongoose.connection.transaction(async (session) => {
    // The whole attempt (also on a retry) starts from a fresh read.
    followUps.categoryPairs.clear();
    followUps.hindiProductIds.length = 0;
    followUps.hindiCategoryIds.length = 0;
    followUps.priceNotices.length = 0;
    followUps.scheduled = false;

    const attempt = await validateAgainst(session);
    report = attempt.report;
    report.dryRun = false;
    report.committed = false;
    if (report.summary.errors > 0) return;
    await applyReport(report, attempt.catalog, { session, actorId, priceChangeMode, followUps, fileName });
    report.committed = true;
  });
  finish(report);
  if (report.committed) await runFollowUps(followUps, { awaitFollowUps });
  return report;
}

async function applyReport(report, catalog, { session, actorId, priceChangeMode, followUps, fileName }) {
  const { Company, Category, Product, StockLog } = require('../models');
  const { createProductRecord, updateProductRecord } = require('../controllers/admin/productController');
  const { recordAudit } = require('./auditService');
  const { clearHiddenCatalogCache } = require('../utils/customerVisibility');
  const { resolveHindiNameOnSave } = require('../utils/hindiNames');

  const indexes = buildIndexes(catalog);
  const rowsToWrite = report.rows.filter((row) => row.errors.length === 0 && row.action !== 'skip');

  // Brands and categories first (only those some written row needs).
  const brandIds = new Map(catalog.brands.map((brand) => [normName(brand.name), brand._id]));
  const needBrands = new Map();
  for (const row of rowsToWrite) {
    if (row.target?.brandIsNew) needBrands.set(normName(row.normalized.brand), row.normalized.brand);
  }
  if (needBrands.size > 0) {
    const last = await Company.findOne().sort({ order: -1 }).select('order').session(session).lean();
    let order = (last?.order || 0) + 1;
    for (const [key, name] of needBrands) {
      const [company] = await Company.create([{ name, order, hideFromCustomers: false }], { session });
      order += 1;
      brandIds.set(key, company._id);
      indexes.brandByName.set(key, company);
    }
  }

  const categoryByKey = new Map();
  for (const category of catalog.categories) {
    categoryByKey.set(`${category.company}|${category.parent || ''}|${normName(category.name)}`, category._id);
  }
  const resolveCategoryId = async (brandId, parts) => {
    let parent = null;
    for (const part of parts) {
      const key = `${brandId}|${parent || ''}|${normName(part)}`;
      if (!categoryByKey.has(key)) {
        const [category] = await Category.create([{
          name: part,
          company: brandId,
          nameHindi: '',
          nameHindiSource: null,
          parent,
          order: 0,
          isActive: true,
          hideFromCustomers: false,
        }], { session });
        categoryByKey.set(key, category._id);
        if (resolveHindiNameOnSave({ incomingHindi: undefined, nameChanged: true }).generate) {
          followUps.hindiCategoryIds.push(category._id);
        }
      }
      parent = categoryByKey.get(key);
    }
    return parent;
  };

  const stockLogs = [];
  const performedBy = actorId ? { _id: actorId } : null;
  for (const row of rowsToWrite) {
    const creating = row.action === 'create';
    let categoryId = null;
    let categoryLeaf = null;
    let brandName = null;
    if (row.normalized.category) {
      const brandId = brandIds.get(normName(row.normalized.brand));
      const parts = row.normalized.category.split(' > ');
      categoryId = await resolveCategoryId(brandId, parts);
      categoryLeaf = parts.length > 1 ? parts[parts.length - 1] : null;
      brandName = row.normalized.brand;
    }
    const body = productBodyFor(row, { creating, categoryId, categoryLeaf, brandName, priceChangeMode });

    if (creating) {
      const { product, hindiDecision } = await createProductRecord(body, { session });
      row.productId = String(product._id);
      if (hindiDecision.generate) followUps.hindiProductIds.push(product._id);
      followUps.categoryPairs.set(`${product.category}|${product.company}`, [product.category, product.company]);
      if (product.stock > 0) {
        stockLogs.push({
          productId: product._id,
          action: 'manual_set',
          quantityChange: product.stock,
          previousStock: 0,
          newStock: product.stock,
          reason: `Catalog import${fileName ? ` (${fileName})` : ''}: new product`,
          performedBy: actorId,
        });
      }
    } else {
      const product = await Product.findOne({ sku: row.sku }).session(session);
      if (!product) throw new BadRequestError(`Product ${row.sku} disappeared during the import; please try again.`, 'CONFLICT');
      const previousStock = product.stock;
      const updated = await updateProductRecord(product, body, { performedBy, session });
      row.productId = String(product._id);
      if (updated.hindiDecision.generate) followUps.hindiProductIds.push(product._id);
      if (updated.priceChangeResult?.isScheduled) followUps.scheduled = true;
      else if (updated.priceChangeResult) followUps.priceNotices.push(updated.priceChangeResult);
      for (const [slug, company] of [[updated.previousCategory, updated.previousCompany], [product.category, product.company]]) {
        if (slug) followUps.categoryPairs.set(`${slug}|${company}`, [slug, company]);
      }
      if (product.stock !== previousStock) {
        stockLogs.push({
          productId: product._id,
          action: 'manual_set',
          quantityChange: product.stock - previousStock,
          previousStock,
          newStock: product.stock,
          reason: `Catalog import${fileName ? ` (${fileName})` : ''}`,
          performedBy: actorId,
        });
      }
    }
  }
  if (stockLogs.length > 0) await StockLog.insertMany(stockLogs, { session });

  report.createdBrands = [...needBrands.values()];
  clearHiddenCatalogCache();

  if (actorId) {
    await recordAudit({
      actorId,
      action: 'catalog.import',
      entityType: 'CatalogImport',
      entityId: new mongoose.Types.ObjectId(),
      metadata: {
        fileName,
        created: report.summary.created,
        updated: report.summary.updated,
        skipped: report.summary.skipped,
        newBrands: report.newBrands,
        newCategories: report.newCategories,
      },
      session,
    });
  }
}

// After the commit: category counts, Hindi names, price-update notices.
async function runFollowUps(followUps, { awaitFollowUps = false } = {}) {
  const logger = require('../utils/logger');
  const run = async () => {
    try {
      const { updateProductCount } = require('../controllers/categoryController');
      for (const [slug, company] of followUps.categoryPairs.values()) {
        await updateProductCount(slug, company);
      }
      const { queuePriceUpdateNotice } = require('../controllers/admin/productController');
      for (const result of followUps.priceNotices) await queuePriceUpdateNotice(result);
      if (followUps.scheduled) {
        const { registerPriceChangeCampaign } = require('./productPriceSchedulerService');
        await registerPriceChangeCampaign();
      }
      const { Product, Category } = require('../models');
      const { fillHindiNames } = require('./hindiNameService');
      if (followUps.hindiCategoryIds.length > 0) {
        await fillHindiNames(Category, { mode: 'repair', ids: followUps.hindiCategoryIds });
      }
      if (followUps.hindiProductIds.length > 0) {
        await fillHindiNames(Product, { mode: 'repair', ids: followUps.hindiProductIds });
      }
    } catch (error) {
      logger.warn(`[CatalogImport] follow-up after commit failed: ${error.message}`);
    }
  };
  if (awaitFollowUps) await run();
  else setImmediate(() => { run(); });
}

async function importWorkbook(input, options = {}) {
  const parsed = await parseWorkbook(input, { filename: options.filename });
  return importCatalog(parsed, { ...options, fileName: options.fileName || options.filename || null });
}

module.exports = {
  MAX_ROWS,
  MAX_FILE_BYTES,
  DEFAULT_STATUS,
  PRICE_CHANGE_MODES,
  COLUMNS,
  normalizeHeader,
  fieldForHeader,
  parseNumber,
  parseBoolean,
  parseCsvText,
  parseWorkbook,
  validateRows,
  loadCatalogSnapshot,
  importCatalog,
  importWorkbook,
};
