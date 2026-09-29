const ExcelJS = require('exceljs');
const BRAND = require('../config/brand');

const currencyFormat = '"₹"#,##0.00';

const formatDateTime = (value) => {
  if (!value) return '';
  try {
    return new Intl.DateTimeFormat('en-IN', {
      dateStyle: 'medium',
      timeStyle: 'short',
      timeZone: 'Asia/Kolkata',
    }).format(new Date(value));
  } catch (error) {
    return new Date(value).toLocaleString('en-IN');
  }
};

const buildAddressLines = (shippingAddress = {}) => {
  const lines = [];
  if (shippingAddress.fullName) lines.push(shippingAddress.fullName);
  if (shippingAddress.phone) lines.push(`Phone: ${shippingAddress.phone}`);
  if (shippingAddress.addressLine1) lines.push(shippingAddress.addressLine1);
  if (shippingAddress.addressLine2) lines.push(shippingAddress.addressLine2);

  const cityStateLine = [shippingAddress.city, shippingAddress.state]
    .filter(Boolean)
    .join(', ');
  const pincode = shippingAddress.pincode ? ` - ${shippingAddress.pincode}` : '';
  if (cityStateLine || pincode) {
    lines.push(`${cityStateLine}${pincode}`.trim());
  }

  return lines.filter(Boolean);
};

const buildVariantDetails = (variantSnapshot = {}) => {
  const pieces = [];

  if (variantSnapshot.displayName || variantSnapshot.name) {
    pieces.push(variantSnapshot.displayName || variantSnapshot.name);
  }

  if (Array.isArray(variantSnapshot.attributes) && variantSnapshot.attributes.length > 0) {
    pieces.push(
      variantSnapshot.attributes
        .filter((attribute) => attribute?.key && attribute?.value)
        .map((attribute) => `${attribute.key}: ${attribute.value}`)
        .join(', ')
    );
  }

  if (variantSnapshot.packing) {
    pieces.push(`Packing: ${variantSnapshot.packing}`);
  }

  if (variantSnapshot.priceUnit) {
    pieces.push(`Unit: ${variantSnapshot.priceUnit}`);
  }

  return pieces.join('\n');
};

const buildBusinessLines = (settings = {}, whatsappNumber = '') => {
  const lines = [];

  if (settings.businessName) lines.push(settings.businessName);
  if (settings.businessAddress) lines.push(settings.businessAddress);

  const contactLine = [
    settings.businessPhone ? `Phone: ${settings.businessPhone}` : null,
    settings.businessEmail ? `Email: ${settings.businessEmail}` : null,
  ].filter(Boolean).join(' | ');

  if (contactLine) {
    lines.push(contactLine);
  }

  if (whatsappNumber) {
    lines.push(`WhatsApp Orders: ${whatsappNumber}`);
  }

  return lines;
};

const sanitizeFileNamePart = (value = '') => String(value)
  .replace(/[<>:"/\\|?*\x00-\x1F]/g, '-')
  .replace(/\s+/g, '-')
  .replace(/-+/g, '-')
  .replace(/^-|-$/g, '')
  .trim();

const createOrderWorkbookBuffer = async ({ order, settings, whatsappNumber }) => {
  const workbook = new ExcelJS.Workbook();
  workbook.creator = `${BRAND.name} Backend`;
  workbook.company = settings?.businessName || BRAND.name;
  workbook.created = new Date();
  workbook.modified = new Date();

  const sheet = workbook.addWorksheet('Order Invoice', {
    views: [{ state: 'frozen', ySplit: 7 }],
  });

  sheet.columns = [
    { key: 'sr', width: 8 },
    { key: 'product', width: 30 },
    { key: 'variant', width: 34 },
    { key: 'qty', width: 10 },
    { key: 'unitPrice', width: 16 },
    { key: 'lineTotal', width: 16 },
  ];

  sheet.mergeCells('A1:F1');
  const titleCell = sheet.getCell('A1');
  titleCell.value = 'Order Invoice';
  titleCell.font = { size: 18, bold: true, color: { argb: 'FFFFFFFF' } };
  titleCell.alignment = { horizontal: 'center', vertical: 'middle' };
  titleCell.fill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FF135BEC' },
  };
  sheet.getRow(1).height = 28;

  const businessLines = buildBusinessLines(settings, whatsappNumber);
  sheet.mergeCells('A2:F2');
  sheet.getCell('A2').value = businessLines.join('\n');
  sheet.getCell('A2').alignment = { wrapText: true, vertical: 'top' };
  sheet.getCell('A2').font = { size: 11, color: { argb: 'FF334155' } };
  sheet.getRow(2).height = Math.max(48, businessLines.length * 16);

  sheet.getCell('A4').value = 'Order Number';
  sheet.getCell('B4').value = order.orderNumber || '-';
  sheet.getCell('D4').value = 'Order Date';
  sheet.getCell('E4').value = formatDateTime(order.createdAt);

  sheet.getCell('A5').value = 'Customer';
  sheet.getCell('B5').value = order.customerSnapshot?.name || '-';
  sheet.getCell('D5').value = 'Phone';
  sheet.getCell('E5').value = order.customerSnapshot?.phone || order.shippingAddress?.phone || '-';

  sheet.getCell('A6').value = 'Email';
  sheet.getCell('B6').value = order.customerSnapshot?.email || '-';
  sheet.getCell('D6').value = 'Order Type';
  sheet.getCell('E6').value = order.orderType === 'wholesale' ? 'Wholesale' : 'Retail';

  const metaLabelCells = ['A4', 'D4', 'A5', 'D5', 'A6', 'D6'];
  metaLabelCells.forEach((address) => {
    const cell = sheet.getCell(address);
    cell.font = { bold: true, color: { argb: 'FF0F172A' } };
    cell.fill = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: 'FFE2E8F0' },
    };
  });

  ['B4', 'E4', 'B5', 'E5', 'B6', 'E6'].forEach((address) => {
    const cell = sheet.getCell(address);
    cell.fill = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: 'FFF8FAFC' },
    };
  });

  sheet.mergeCells('A8:C8');
  sheet.getCell('A8').value = 'Shipping Address';
  sheet.getCell('A8').font = { bold: true, color: { argb: 'FF0F172A' } };
  sheet.getCell('A8').fill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FFE2E8F0' },
  };

  sheet.mergeCells('A9:C11');
  sheet.getCell('A9').value = buildAddressLines(order.shippingAddress).join('\n') || '-';
  sheet.getCell('A9').alignment = { wrapText: true, vertical: 'top' };
  sheet.getCell('A9').fill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FFF8FAFC' },
  };

  const tableHeaderRow = 13;
  const headers = ['#', 'Product', 'Variant / Specs', 'Qty', 'Unit Price', 'Line Total'];
  headers.forEach((header, index) => {
    const cell = sheet.getRow(tableHeaderRow).getCell(index + 1);
    cell.value = header;
    cell.font = { bold: true, color: { argb: 'FFFFFFFF' } };
    cell.alignment = { horizontal: 'center', vertical: 'middle' };
    cell.fill = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: 'FF1E40AF' },
    };
    cell.border = {
      top: { style: 'thin', color: { argb: 'FFCBD5E1' } },
      left: { style: 'thin', color: { argb: 'FFCBD5E1' } },
      bottom: { style: 'thin', color: { argb: 'FFCBD5E1' } },
      right: { style: 'thin', color: { argb: 'FFCBD5E1' } },
    };
  });

  let currentRow = tableHeaderRow + 1;
  for (const [index, item] of order.items.entries()) {
    const row = sheet.getRow(currentRow);
    row.getCell(1).value = index + 1;
    row.getCell(2).value = item.productSnapshot?.name || '-';
    row.getCell(3).value = buildVariantDetails(item.variantSnapshot);
    row.getCell(4).value = item.quantity || 0;
    row.getCell(5).value = Number(item.pricePerUnit || 0);
    row.getCell(6).value = Number(item.totalPrice || 0);

    row.getCell(1).alignment = { horizontal: 'center', vertical: 'top' };
    row.getCell(3).alignment = { wrapText: true, vertical: 'top' };
    row.getCell(4).alignment = { horizontal: 'center', vertical: 'top' };
    row.getCell(5).numFmt = currencyFormat;
    row.getCell(6).numFmt = currencyFormat;

    for (let column = 1; column <= 6; column += 1) {
      row.getCell(column).border = {
        top: { style: 'thin', color: { argb: 'FFE2E8F0' } },
        left: { style: 'thin', color: { argb: 'FFE2E8F0' } },
        bottom: { style: 'thin', color: { argb: 'FFE2E8F0' } },
        right: { style: 'thin', color: { argb: 'FFE2E8F0' } },
      };
      row.getCell(column).fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: index % 2 === 0 ? 'FFFFFFFF' : 'FFF8FAFC' },
      };
    }

    row.height = 42;
    currentRow += 1;
  }

  const totalsStartRow = currentRow + 1;
  const totals = [
    ['Subtotal', Number(order.subtotal || 0)],
    ['Delivery Fee', Number(order.deliveryFee || 0)],
    ['Discount', Number(order.discount || 0) * -1],
    ['Grand Total', Number(order.total || 0)],
  ];

  totals.forEach(([label, value], index) => {
    const rowNumber = totalsStartRow + index;
    sheet.mergeCells(`A${rowNumber}:D${rowNumber}`);
    const labelCell = sheet.getCell(`A${rowNumber}`);
    const valueCell = sheet.getCell(`E${rowNumber}`);
    const valueTailCell = sheet.getCell(`F${rowNumber}`);

    labelCell.value = label;
    labelCell.font = {
      bold: label === 'Grand Total',
      size: label === 'Grand Total' ? 12 : 11,
      color: { argb: 'FF0F172A' },
    };
    labelCell.alignment = { horizontal: 'right' };

    valueCell.value = Number(value);
    valueCell.numFmt = currencyFormat;
    valueCell.font = {
      bold: label === 'Grand Total',
      size: label === 'Grand Total' ? 12 : 11,
      color: { argb: label === 'Grand Total' ? 'FF135BEC' : 'FF0F172A' },
    };
    valueTailCell.value = '';

    [labelCell, valueCell, valueTailCell].forEach((cell) => {
      cell.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: label === 'Grand Total' ? 'FFE0E7FF' : 'FFF8FAFC' },
      };
      cell.border = {
        top: { style: 'thin', color: { argb: 'FFE2E8F0' } },
        left: { style: 'thin', color: { argb: 'FFE2E8F0' } },
        bottom: { style: 'thin', color: { argb: 'FFE2E8F0' } },
        right: { style: 'thin', color: { argb: 'FFE2E8F0' } },
      };
    });
  });

  if (order.customerNote) {
    const noteRow = totalsStartRow + totals.length + 2;
    sheet.mergeCells(`A${noteRow}:F${noteRow}`);
    sheet.getCell(`A${noteRow}`).value = `Customer Note: ${order.customerNote}`;
    sheet.getCell(`A${noteRow}`).font = { italic: true, color: { argb: 'FF475569' } };
    sheet.getCell(`A${noteRow}`).alignment = { wrapText: true };
  }

  sheet.eachRow((row) => {
    row.eachCell((cell) => {
      if (!cell.alignment) {
        cell.alignment = { vertical: 'middle' };
      }
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
  createOrderWorkbookBuffer,
  sanitizeFileNamePart,
};
