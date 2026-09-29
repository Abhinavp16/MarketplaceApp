const ExcelJS = require('exceljs');
const BRAND = require('../config/brand');

const CURRENCY_FORMAT = '"₹"#,##0.00';
const BORDER_COLOR = 'FFE2E8F0';
const TABLE_HEADER_ROW = 5;
const LAST_COLUMN = 'K';

const formatIstDateTime = (value) => {
  if (!value) return '';

  try {
    return new Intl.DateTimeFormat('en-IN', {
      dateStyle: 'medium',
      timeStyle: 'short',
      timeZone: 'Asia/Kolkata',
    }).format(new Date(value));
  } catch {
    return '';
  }
};

const formatScheduleType = (value) => ({
  immediate: 'Immediately',
  schedule_24h: 'After 24 hours',
  schedule_48h: 'After 48 hours',
  custom: 'Custom',
}[value] || (value ? String(value) : ''));

const tableBorder = {
  top: { style: 'thin', color: { argb: BORDER_COLOR } },
  left: { style: 'thin', color: { argb: BORDER_COLOR } },
  bottom: { style: 'thin', color: { argb: BORDER_COLOR } },
  right: { style: 'thin', color: { argb: BORDER_COLOR } },
};

const setRowBorders = (row, fillColor) => {
  row.eachCell({ includeEmpty: true }, (cell) => {
    cell.border = tableBorder;
    cell.alignment = { vertical: 'middle', wrapText: true };
    if (fillColor) {
      cell.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: fillColor },
      };
    }
  });
};

const createPriceSnapshotWorkbookBuffer = async ({
  companyName = BRAND.name,
  exportedAt = new Date(),
  products = [],
}) => {
  const workbook = new ExcelJS.Workbook();
  workbook.creator = `${BRAND.name} Backend`;
  workbook.company = companyName;
  workbook.created = new Date(exportedAt);
  workbook.modified = new Date(exportedAt);

  const sheet = workbook.addWorksheet('Product Price Snapshot', {
    views: [{ state: 'frozen', ySplit: TABLE_HEADER_ROW }],
  });

  sheet.columns = [
    { key: 'serialNumber', width: 9 },
    { key: 'category', width: 24 },
    { key: 'productName', width: 32 },
    { key: 'sku', width: 18 },
    { key: 'currentRetailPrice', width: 22 },
    { key: 'currentWholesalePrice', width: 23 },
    { key: 'pendingRetailPrice', width: 23 },
    { key: 'pendingWholesalePrice', width: 24 },
    { key: 'scheduleType', width: 19 },
    { key: 'effectiveAt', width: 25 },
    { key: 'pendingStatus', width: 18 },
  ];

  sheet.mergeCells(`A1:${LAST_COLUMN}1`);
  const titleCell = sheet.getCell('A1');
  titleCell.value = 'Product Price Snapshot';
  titleCell.font = { name: 'Calibri', size: 18, bold: true, color: { argb: 'FFFFFFFF' } };
  titleCell.alignment = { horizontal: 'center', vertical: 'middle' };
  titleCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF166534' } };
  sheet.getRow(1).height = 30;

  sheet.mergeCells(`A2:${LAST_COLUMN}2`);
  const companyCell = sheet.getCell('A2');
  companyCell.value = companyName;
  companyCell.font = { name: 'Calibri', size: 13, bold: true, color: { argb: 'FF0F172A' } };
  companyCell.alignment = { horizontal: 'center', vertical: 'middle' };
  companyCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFDCFCE7' } };

  sheet.mergeCells(`A3:${LAST_COLUMN}3`);
  const exportedCell = sheet.getCell('A3');
  exportedCell.value = `Exported on (IST): ${formatIstDateTime(exportedAt)}`;
  exportedCell.font = { name: 'Calibri', size: 10, italic: true, color: { argb: 'FF475569' } };
  exportedCell.alignment = { horizontal: 'center', vertical: 'middle' };

  const headers = [
    'S.No.',
    'Category',
    'Product Name',
    'SKU',
    'Current Customer Price',
    'Current Wholesaler Price',
    'Changing Customer Price',
    'Changing Wholesaler Price',
    'Schedule Type',
    'Effective Date/Time (IST)',
    'Pending Status',
  ];
  const headerRow = sheet.getRow(TABLE_HEADER_ROW);
  headers.forEach((header, index) => {
    const cell = headerRow.getCell(index + 1);
    cell.value = header;
    cell.font = { name: 'Calibri', size: 10, bold: true, color: { argb: 'FFFFFFFF' } };
    cell.alignment = { horizontal: 'center', vertical: 'middle', wrapText: true };
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1E3A8A' } };
    cell.border = tableBorder;
  });
  headerRow.height = 32;

  const productsByCategory = new Map();
  for (const product of products) {
    const categoryName = String(product.category || 'Uncategorized').trim() || 'Uncategorized';
    const categoryProducts = productsByCategory.get(categoryName) || [];
    categoryProducts.push(product);
    productsByCategory.set(categoryName, categoryProducts);
  }

  let rowNumber = TABLE_HEADER_ROW + 1;
  let serialNumber = 1;
  for (const [categoryName, categoryProducts] of productsByCategory) {
    sheet.mergeCells(`A${rowNumber}:${LAST_COLUMN}${rowNumber}`);
    const categoryCell = sheet.getCell(`A${rowNumber}`);
    categoryCell.value = categoryName;
    categoryCell.font = { name: 'Calibri', size: 12, bold: true, color: { argb: 'FF14532D' } };
    categoryCell.alignment = { vertical: 'middle' };
    categoryCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFDCFCE7' } };
    categoryCell.border = tableBorder;
    sheet.getRow(rowNumber).height = 24;
    rowNumber += 1;

    for (const product of categoryProducts) {
      const hasPendingChange = product.pendingRetailPrice !== null
        && product.pendingRetailPrice !== undefined
        || product.pendingWholesalePrice !== null
        && product.pendingWholesalePrice !== undefined;
      const row = sheet.getRow(rowNumber);
      row.values = [
        serialNumber,
        categoryName,
        product.name || '',
        product.sku || '',
        Number(product.retailPrice ?? 0),
        Number(product.wholesalePrice ?? 0),
        product.pendingRetailPrice ?? null,
        product.pendingWholesalePrice ?? null,
        hasPendingChange ? formatScheduleType(product.scheduleType) : '',
        hasPendingChange ? formatIstDateTime(product.effectiveAt) : '',
        hasPendingChange ? product.changeStatus || 'Pending' : 'No pending change',
      ];

      setRowBorders(row, serialNumber % 2 === 0 ? 'FFF8FAFC' : 'FFFFFFFF');
      row.getCell(1).alignment = { horizontal: 'center', vertical: 'middle' };
      row.getCell(5).numFmt = CURRENCY_FORMAT;
      row.getCell(6).numFmt = CURRENCY_FORMAT;
      row.getCell(7).numFmt = CURRENCY_FORMAT;
      row.getCell(8).numFmt = CURRENCY_FORMAT;
      row.getCell(11).alignment = { horizontal: 'center', vertical: 'middle', wrapText: true };
      row.height = 28;
      serialNumber += 1;
      rowNumber += 1;
    }
  }

  if (products.length === 0) {
    sheet.mergeCells(`A${rowNumber}:${LAST_COLUMN}${rowNumber}`);
    const emptyCell = sheet.getCell(`A${rowNumber}`);
    emptyCell.value = 'No non-archived products were available at the time of export.';
    emptyCell.font = { name: 'Calibri', size: 11, italic: true, color: { argb: 'FF64748B' } };
    emptyCell.alignment = { horizontal: 'center', vertical: 'middle' };
    emptyCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF8FAFC' } };
    emptyCell.border = tableBorder;
  }

  sheet.autoFilter = `A${TABLE_HEADER_ROW}:${LAST_COLUMN}${Math.max(rowNumber - 1, TABLE_HEADER_ROW)}`;
  sheet.eachRow((row) => {
    row.eachCell({ includeEmpty: true }, (cell) => {
      cell.font = {
        name: 'Calibri',
        size: cell.font?.size || 11,
        bold: cell.font?.bold || false,
        italic: cell.font?.italic || false,
        color: cell.font?.color,
      };
    });
  });

  return workbook.xlsx.writeBuffer();
};

module.exports = {
  CURRENCY_FORMAT,
  createPriceSnapshotWorkbookBuffer,
  formatIstDateTime,
};
