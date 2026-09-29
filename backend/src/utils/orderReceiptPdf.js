const BRAND = require('../config/brand');
const PAGE_WIDTH = 595.28;
const PAGE_HEIGHT = 841.89;
const MARGIN = 42;
const CONTENT_WIDTH = PAGE_WIDTH - (MARGIN * 2);

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

const formatCurrency = (value) => {
  const amount = Number(value || 0);
  const formatted = new Intl.NumberFormat('en-IN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount);
  return `Rs. ${formatted}`;
};

const escapePdfText = (value = '') => String(value)
  .replace(/\\/g, '\\\\')
  .replace(/\(/g, '\\(')
  .replace(/\)/g, '\\)')
  .replace(/[^\x20-\x7E]/g, '?');

const wrapText = (text, maxChars) => {
  const words = String(text || '').trim().split(/\s+/).filter(Boolean);
  if (words.length === 0) return ['-'];

  const lines = [];
  let current = '';

  for (const word of words) {
    const candidate = current ? `${current} ${word}` : word;
    if (candidate.length <= maxChars) {
      current = candidate;
      continue;
    }

    if (current) {
      lines.push(current);
      current = word;
      continue;
    }

    let remaining = word;
    while (remaining.length > maxChars) {
      lines.push(remaining.slice(0, maxChars - 1));
      remaining = remaining.slice(maxChars - 1);
    }
    current = remaining;
  }

  if (current) lines.push(current);
  return lines;
};

const buildAddressLines = (shippingAddress = {}) => {
  const lines = [];
  if (shippingAddress.fullName) lines.push(shippingAddress.fullName);
  if (shippingAddress.phone) lines.push(`Phone: ${shippingAddress.phone}`);
  if (shippingAddress.addressLine1) lines.push(shippingAddress.addressLine1);
  if (shippingAddress.addressLine2) lines.push(shippingAddress.addressLine2);
  const cityState = [shippingAddress.city, shippingAddress.state].filter(Boolean).join(', ');
  const pincode = shippingAddress.pincode ? ` - ${shippingAddress.pincode}` : '';
  if (cityState || pincode) {
    lines.push(`${cityState}${pincode}`.trim());
  }
  return lines.filter(Boolean);
};

const buildVariantDetails = (variantSnapshot = {}) => {
  const parts = [];
  if (variantSnapshot.displayName || variantSnapshot.name) {
    parts.push(variantSnapshot.displayName || variantSnapshot.name);
  }
  if (Array.isArray(variantSnapshot.attributes) && variantSnapshot.attributes.length > 0) {
    parts.push(
      variantSnapshot.attributes
        .filter((attribute) => attribute?.key && attribute?.value)
        .map((attribute) => `${attribute.key}: ${attribute.value}`)
        .join(', ')
    );
  }
  if (variantSnapshot.packing) {
    parts.push(`Packing: ${variantSnapshot.packing}`);
  }
  if (variantSnapshot.priceUnit) {
    parts.push(`Unit: ${variantSnapshot.priceUnit}`);
  }
  return parts.join(' | ');
};

const createPdfBuffer = (pages) => {
  const objects = [];
  const pushObject = (content) => {
    objects.push(content);
    return objects.length;
  };

  const catalogId = pushObject('<< /Type /Catalog /Pages 2 0 R >>');
  const pagesId = pushObject('');
  const regularFontId = pushObject('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
  const boldFontId = pushObject('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>');

  const pageObjectIds = [];
  const contentObjectIds = [];

  for (const pageContent of pages) {
    const stream = Buffer.from(pageContent, 'utf8');
    const contentId = pushObject(`<< /Length ${stream.length} >>\nstream\n${pageContent}\nendstream`);
    const pageId = pushObject(
      `<< /Type /Page /Parent ${pagesId} 0 R /MediaBox [0 0 ${PAGE_WIDTH} ${PAGE_HEIGHT}] ` +
      `/Resources << /Font << /F1 ${regularFontId} 0 R /F2 ${boldFontId} 0 R >> >> ` +
      `/Contents ${contentId} 0 R >>`
    );
    contentObjectIds.push(contentId);
    pageObjectIds.push(pageId);
  }

  objects[pagesId - 1] = `<< /Type /Pages /Kids [${pageObjectIds.map((id) => `${id} 0 R`).join(' ')}] /Count ${pageObjectIds.length} >>`;

  let output = '%PDF-1.4\n';
  const offsets = [0];

  for (let index = 0; index < objects.length; index += 1) {
    offsets.push(Buffer.byteLength(output, 'utf8'));
    output += `${index + 1} 0 obj\n${objects[index]}\nendobj\n`;
  }

  const xrefOffset = Buffer.byteLength(output, 'utf8');
  output += `xref\n0 ${objects.length + 1}\n`;
  output += '0000000000 65535 f \n';
  for (let index = 1; index < offsets.length; index += 1) {
    output += `${String(offsets[index]).padStart(10, '0')} 00000 n \n`;
  }
  output += `trailer\n<< /Size ${objects.length + 1} /Root ${catalogId} 0 R >>\n`;
  output += `startxref\n${xrefOffset}\n%%EOF`;

  return Buffer.from(output, 'utf8');
};

const createOrderReceiptPdfBuffer = async ({ order, settings, whatsappNumber }) => {
  const pages = [];
  let commands = [];
  let cursorY = PAGE_HEIGHT - MARGIN;

  const pushPage = () => {
    pages.push(commands.join('\n'));
    commands = [];
    cursorY = PAGE_HEIGHT - MARGIN;
  };

  const ensureSpace = (height) => {
    if (cursorY - height < MARGIN) {
      pushPage();
      drawPageHeader(true);
    }
  };

  const drawText = (text, x, y, { size = 11, font = 'F1' } = {}) => {
    commands.push(`BT /${font} ${size} Tf 1 0 0 1 ${x.toFixed(2)} ${y.toFixed(2)} Tm (${escapePdfText(text)}) Tj ET`);
  };

  const drawLine = (x1, y1, x2, y2, width = 0.6) => {
    commands.push(`${width} w ${x1.toFixed(2)} ${y1.toFixed(2)} m ${x2.toFixed(2)} ${y2.toFixed(2)} l S`);
  };

  const drawPageHeader = (continuation = false) => {
    const businessName = settings?.businessName || BRAND.name;
    drawText(businessName, MARGIN, cursorY, { size: 20, font: 'F2' });
    cursorY -= 18;

    const businessLines = [
      settings?.businessAddress || '',
      [
        settings?.businessPhone ? `Phone: ${settings.businessPhone}` : null,
        settings?.businessEmail ? `Email: ${settings.businessEmail}` : null,
      ].filter(Boolean).join(' | '),
      whatsappNumber ? `WhatsApp Orders: ${whatsappNumber}` : '',
    ].filter(Boolean);

    businessLines.forEach((line) => {
      drawText(line, MARGIN, cursorY, { size: 10 });
      cursorY -= 12;
    });

    cursorY -= 6;
    drawText(continuation ? 'Order Receipt (continued)' : 'Order Receipt', MARGIN, cursorY, { size: 16, font: 'F2' });
    cursorY -= 10;
    drawLine(MARGIN, cursorY, PAGE_WIDTH - MARGIN, cursorY, 1);
    cursorY -= 18;
  };

  drawPageHeader(false);

  const metaPairs = [
    ['Order Number', order.orderNumber || '-'],
    ['Order Date', formatDateTime(order.createdAt)],
    ['Customer', order.customerSnapshot?.name || order.shippingAddress?.fullName || '-'],
    ['Phone', order.customerSnapshot?.phone || order.shippingAddress?.phone || '-'],
    ['Email', order.customerSnapshot?.email || '-'],
    ['Order Type', order.orderType === 'wholesale' ? 'Wholesale' : 'Retail'],
  ];

  metaPairs.forEach(([label, value]) => {
    ensureSpace(16);
    drawText(`${label}:`, MARGIN, cursorY, { size: 11, font: 'F2' });
    drawText(value, MARGIN + 95, cursorY, { size: 11 });
    cursorY -= 14;
  });

  cursorY -= 4;
  ensureSpace(28);
  drawText('Shipping Address', MARGIN, cursorY, { size: 12, font: 'F2' });
  cursorY -= 14;
  buildAddressLines(order.shippingAddress).forEach((line) => {
    ensureSpace(14);
    drawText(line, MARGIN, cursorY, { size: 10 });
    cursorY -= 12;
  });

  cursorY -= 6;
  ensureSpace(26);
  drawLine(MARGIN, cursorY, PAGE_WIDTH - MARGIN, cursorY, 0.8);
  cursorY -= 16;
  drawText('Product', MARGIN, cursorY, { size: 11, font: 'F2' });
  drawText('Qty', MARGIN + 315, cursorY, { size: 11, font: 'F2' });
  drawText('Rate', MARGIN + 380, cursorY, { size: 11, font: 'F2' });
  drawText('Total', MARGIN + 460, cursorY, { size: 11, font: 'F2' });
  cursorY -= 10;
  drawLine(MARGIN, cursorY, PAGE_WIDTH - MARGIN, cursorY, 0.8);
  cursorY -= 14;

  for (const [index, item] of order.items.entries()) {
    const productLabel = item.productSnapshot?.name || `Item ${index + 1}`;
    const variantDetails = buildVariantDetails(item.variantSnapshot);
    const productLines = [
      ...wrapText(productLabel, 42),
      ...(variantDetails ? wrapText(variantDetails, 50) : []),
    ];

    const rowHeight = Math.max(24, (productLines.length * 12) + 4);
    ensureSpace(rowHeight + 12);

    drawText(productLines[0], MARGIN, cursorY, {
      size: 10,
      font: 'F2',
    });
    drawText(String(item.quantity || 0), MARGIN + 315, cursorY, { size: 10 });
    drawText(formatCurrency(item.pricePerUnit), MARGIN + 380, cursorY, { size: 10 });
    drawText(formatCurrency(item.totalPrice), MARGIN + 460, cursorY, { size: 10 });

    let lineY = cursorY - 12;
    for (let lineIndex = 1; lineIndex < productLines.length; lineIndex += 1) {
      drawText(productLines[lineIndex], MARGIN, lineY, { size: 9 });
      lineY -= 11;
    }

    cursorY -= rowHeight;
    drawLine(MARGIN, cursorY + 6, PAGE_WIDTH - MARGIN, cursorY + 6, 0.35);
  }

  cursorY -= 8;
  const totals = [
    ['Subtotal', formatCurrency(order.subtotal)],
    ['Delivery Fee', formatCurrency(order.deliveryFee)],
  ];
  if (Number(order.discount || 0) > 0) {
    totals.push(['Discount', `- ${formatCurrency(order.discount)}`]);
  }
  totals.push(['Grand Total', formatCurrency(order.total)]);

  totals.forEach(([label, value], index) => {
    ensureSpace(16);
    drawText(label, MARGIN + 300, cursorY, {
      size: label === 'Grand Total' ? 12 : 10,
      font: label === 'Grand Total' ? 'F2' : 'F1',
    });
    drawText(value, MARGIN + 430, cursorY, {
      size: label === 'Grand Total' ? 12 : 10,
      font: label === 'Grand Total' ? 'F2' : 'F1',
    });
    cursorY -= index === totals.length - 1 ? 18 : 14;
  });

  if (order.customerNote) {
    ensureSpace(24);
    drawText('Customer Note', MARGIN, cursorY, { size: 11, font: 'F2' });
    cursorY -= 14;
    wrapText(order.customerNote, 78).forEach((line) => {
      ensureSpace(12);
      drawText(line, MARGIN, cursorY, { size: 10 });
      cursorY -= 12;
    });
  }

  if (commands.length > 0) {
    pushPage();
  }

  return createPdfBuffer(pages);
};

module.exports = {
  createOrderReceiptPdfBuffer,
};
