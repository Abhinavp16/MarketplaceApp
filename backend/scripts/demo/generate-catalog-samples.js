#!/usr/bin/env node
/**
 * Writes the catalog import sample files to ../docs:
 *   docs/catalog-import-sample.xlsx   12 products that import cleanly into the seeded demo catalog
 *   docs/catalog-import-sample.csv    the same rows as CSV
 *   docs/catalog-import-errors.csv    deliberate mistakes, to show the validation report
 *
 *   npm run catalog:samples
 *
 * The sample uses the seeded brands (Kestrel Works, Anvilpoint, Brightguard Safety), two pack
 * products (a Packet and a Coil) and one row that updates an existing seeded product
 * (AP-TPE-5M: price and stock). Re-running `npm run demo:reset` restores the seed.
 */
const fs = require('fs');
const path = require('path');
const { TEMPLATE_HEADERS, createCatalogWorkbookBuffer } = require('../../src/utils/catalogImportWorkbook');

const DOCS_DIR = path.join(__dirname, '..', '..', '..', 'docs');

const SAMPLE_ROWS = [
  {
    SKU: 'KW-DRL-12V',
    Name: '12V Compact Cordless Drill Driver, 10 mm Chuck (1 x 2.0 Ah)',
    Brand: 'Kestrel Works',
    Category: 'Power Tools > Drills & Drivers',
    Description: 'Light 12V drill driver for cabinet work, assembly and light drilling. 10 mm keyless chuck, 16 torque settings and an LED work light. Supplied with one 2.0 Ah battery and a charger.',
    'Short Description': 'Compact 12V drill driver with 10 mm keyless chuck and battery.',
    MRP: 4999, 'Retail Price': 4299, 'Wholesale Price': 3450, 'Min Wholesale Qty': 5,
    Unit: 'piece', Packing: '1 kit (drill, battery, charger)', Stock: 340, Status: 'active',
    Negotiation: 'Yes', Featured: 'No', Hot: 'No', Tags: 'drill, cordless, 12v',
  },
  {
    SKU: 'KW-GRD-125',
    Name: '1000 W Angle Grinder 125 mm, 11,000 rpm (Side Handle, Guard)',
    Brand: 'Kestrel Works',
    Category: 'Power Tools > Grinders & Sanders',
    Description: 'Mid-size angle grinder for cutting, grinding and deburring metal and masonry. Spindle lock, adjustable guard and anti-vibration side handle included.',
    'Short Description': '1000 W angle grinder for 125 mm discs.',
    MRP: 4199, 'Retail Price': 3599, 'Wholesale Price': 2950, 'Min Wholesale Qty': 5,
    Unit: 'piece', Packing: '1 piece (grinder, side handle, guard, spanner)', Stock: 220, Status: 'active',
    Negotiation: 'Yes', Featured: 'Yes', Hot: 'No', Tags: 'grinder, 125mm, angle grinder',
  },
  {
    SKU: 'KW-RSW-900',
    Name: '900 W Reciprocating Saw, 28 mm Stroke, Tool-Free Blade Change',
    Brand: 'Kestrel Works',
    Category: 'Power Tools',
    Subcategory: 'Saws',
    Description: 'Reciprocating saw for demolition, pipe and timber cutting with variable speed trigger and tool-free blade change. Supplied with one wood and one metal blade.',
    'Short Description': '900 W reciprocating saw with tool-free blade change.',
    MRP: 5499, 'Retail Price': 4699, 'Wholesale Price': 3850, 'Min Wholesale Qty': 3,
    Unit: 'piece', Packing: '1 piece + 2 blades', Stock: 150, Status: 'draft',
    Negotiation: 'Yes', Featured: 'No', Hot: 'No', Tags: 'saw, reciprocating',
  },
  {
    SKU: 'AP-SQR-300',
    Name: 'Steel Try Square 300 mm, Rosewood Handle',
    Brand: 'Anvilpoint',
    Category: 'Hand Tools > Measuring & Marking',
    Description: 'Hardened steel blade with etched metric scale on a polished rosewood stock. Used for marking and checking right angles in joinery and metalwork.',
    'Short Description': '300 mm steel try square with rosewood handle.',
    MRP: 749, 'Retail Price': 629, 'Wholesale Price': 470, 'Min Wholesale Qty': 10,
    Unit: 'piece', Packing: '1 piece', Stock: 420, Status: 'active',
    Negotiation: 'Yes', Featured: 'No', Hot: 'No', Tags: 'square, marking',
  },
  {
    SKU: 'AP-SCR-SS-M6',
    Name: 'Stainless Socket Head Cap Screw M6 x 25 mm, A2 (Box of 100)',
    Brand: 'Anvilpoint',
    Category: 'Fasteners & Fittings > Bolts & Nuts',
    Description: 'A2 stainless steel socket head cap screw with hex drive, metric coarse thread. Corrosion resistant for indoor and outdoor assemblies. Packed 100 per box.',
    'Short Description': 'M6 x 25 mm stainless cap screws, box of 100.',
    MRP: 999, 'Retail Price': 829, 'Wholesale Price': 610, 'Min Wholesale Qty': 10,
    Unit: 'box', Packing: 'Box of 100', Stock: 380, Status: 'active',
    Negotiation: 'Yes', Featured: 'No', Hot: 'Yes', Tags: 'screw, stainless, m6',
  },
  {
    SKU: 'AP-NUT-NYL-M8',
    Name: 'Nylon Insert Lock Nut M8, Zinc Plated (Packet of 100)',
    Brand: 'Anvilpoint',
    Category: 'Fasteners & Fittings > Bolts & Nuts',
    Description: 'Self-locking nut with nylon insert that resists loosening under vibration. Zinc plated. Priced per piece; a packet holds 100 pieces.',
    'Short Description': 'M8 nylon lock nuts, sold by the piece in packets of 100.',
    MRP: 5, 'Retail Price': 3.8, 'Wholesale Price': 2.6, 'Min Wholesale Qty': 5, 'Min Customer Qty': 10,
    'Pack Type': 'Packet', 'Pack Size': 100, Stock: 8000, Status: 'active',
    Negotiation: 'Yes', Featured: 'No', Hot: 'No', Tags: 'nut, nylock, m8',
  },
  {
    SKU: 'AP-CRD-NYL-6',
    Name: 'Braided Nylon Cord 6 mm, High Strength (Coil of 100 m)',
    Brand: 'Anvilpoint',
    Category: 'Fasteners & Fittings > Cables & Rope',
    Description: 'Braided nylon cord for tying down, hoisting light loads and general site use. Priced per metre; a coil is 100 m and customers can buy cut lengths.',
    'Short Description': '6 mm braided nylon cord, per metre, coil of 100 m.',
    MRP: 18, 'Retail Price': 14, 'Wholesale Price': 10.5, 'Min Wholesale Qty': 2, 'Min Customer Qty': 5,
    'Pack Type': 'Coil', 'Pack Size': 100, Stock: 2500, Status: 'active',
    Negotiation: 'Yes', Featured: 'No', Hot: 'No', Tags: 'cord, nylon, rope',
  },
  {
    SKU: 'AP-TEE-34',
    Name: 'Brass Equal Tee 3/4 inch BSP, Female Threaded',
    Brand: 'Anvilpoint',
    Category: 'Fasteners & Fittings > Pipe Fittings',
    Description: 'Forged brass equal tee with three female BSP threads for water and air lines. Pressure rated for general plumbing use.',
    'Short Description': '3/4 inch BSP female brass tee.',
    MRP: 299, 'Retail Price': 249, 'Wholesale Price': 185, 'Min Wholesale Qty': 20,
    Unit: 'piece', Packing: '1 piece', Stock: 600, Status: 'active',
    Negotiation: 'Yes', Featured: 'No', Hot: 'No', Tags: 'brass, fitting, tee',
  },
  {
    SKU: 'BG-EAR-29',
    Name: 'Over-Ear Safety Ear Muffs, 29 dB SNR, Adjustable Headband',
    Brand: 'Brightguard Safety',
    Category: 'Safety Gear > Head & Eye Protection',
    Description: 'Comfortable ear defenders with padded cushions and an adjustable steel headband. Reduces noise by up to 29 dB for workshops, grinding and site work.',
    'Short Description': 'Ear muffs, 29 dB noise reduction.',
    MRP: 549, 'Retail Price': 449, 'Wholesale Price': 330, 'Min Wholesale Qty': 20,
    Unit: 'piece', Packing: '1 piece', Stock: 300, Status: 'active',
    Negotiation: 'Yes', Featured: 'No', Hot: 'No', Tags: 'ear muff, hearing protection',
  },
  {
    SKU: 'BG-FPL-N95',
    Name: 'Disposable Dust Mask FFP2, Cup Style, Valved (Box of 20)',
    Brand: 'Brightguard Safety',
    Category: 'Safety Gear > Head & Eye Protection',
    Description: 'FFP2 cup-style dust mask with exhalation valve and adjustable nose clip for sanding, grinding and dusty work. Box of 20.',
    'Short Description': 'FFP2 valved dust masks, box of 20.',
    MRP: 899, 'Retail Price': 749, 'Wholesale Price': 560, 'Min Wholesale Qty': 10,
    Unit: 'box', Packing: 'Box of 20', Stock: 260, Status: 'active',
    Negotiation: 'Yes', Featured: 'No', Hot: 'No', Tags: 'mask, dust, ffp2',
  },
  {
    SKU: 'BG-GLV-NT',
    Name: 'Nitrile Coated Work Gloves, Seamless Knit Liner (Pair)',
    Brand: 'Brightguard Safety',
    Category: 'Safety Gear > Hand & Foot Protection',
    Description: 'Seamless knit gloves with nitrile palm coating for grip in oily and dry conditions. Breathable back for all-day wear.',
    'Short Description': 'Nitrile palm-coated work gloves.',
    MRP: 199, 'Retail Price': 159, 'Wholesale Price': 115, 'Min Wholesale Qty': 50,
    Unit: 'pair', Packing: '1 pair', Stock: 700, Status: 'active',
    Negotiation: 'Yes', Featured: 'No', Hot: 'No', Tags: 'gloves, nitrile',
  },
  {
    // Updates the seeded Steel Measuring Tape: only these columns change.
    SKU: 'AP-TPE-5M',
    'Retail Price': 209, 'Wholesale Price': 150, Stock: 800,
  },
];

// Mistakes on purpose: every kind of problem the report can show.
const ERROR_ROWS = [
  { SKU: 'DM-OK-001', Name: 'Cobalt Drill Bit Set 19 pc, HSS (Case)', Brand: 'Kestrel Works', Category: 'Power Tools > Drills & Drivers', Description: 'A correct row for comparison.', MRP: 1899, 'Retail Price': 1549, 'Wholesale Price': 1190, Unit: 'set', Stock: 90, Status: 'active' },
  { SKU: '', Name: 'Row without a SKU', Brand: 'Anvilpoint', Category: 'Hand Tools > Wrenches & Pliers', MRP: 100, 'Retail Price': 90, 'Wholesale Price': 70 },
  { SKU: 'DM-DUP-001', Name: 'Pipe Wrench 14 inch', Brand: 'Anvilpoint', Category: 'Hand Tools > Wrenches & Pliers', Description: 'First use of this SKU.', MRP: 1299, 'Retail Price': 1099, 'Wholesale Price': 850, Stock: 40 },
  { SKU: 'DM-DUP-001', Name: 'Pipe Wrench 18 inch', Brand: 'Anvilpoint', Category: 'Hand Tools > Wrenches & Pliers', Description: 'Second use of the same SKU.', MRP: 1599, 'Retail Price': 1349, 'Wholesale Price': 1050, Stock: 25 },
  { SKU: 'DM-BRD-001', Name: 'Spirit Level 600 mm', Brand: 'Zenith Tools', Category: 'Hand Tools > Measuring & Marking', Description: 'Brand does not exist.', MRP: 499, 'Retail Price': 429, 'Wholesale Price': 320 },
  { SKU: 'DM-CAT-001', Name: 'Welding Rod E6013 (Pack)', Brand: 'Kestrel Works', Category: 'Power Tools > Welding', Description: 'Category does not exist under the brand.', MRP: 349, 'Retail Price': 299, 'Wholesale Price': 230 },
  { SKU: 'DM-PRC-001', Name: 'Cutting Disc 100 mm', Brand: 'Kestrel Works', Category: 'Power Tools > Grinders & Sanders', Description: 'Prices that are not valid.', MRP: 'abc', 'Retail Price': -5, 'Wholesale Price': 12 },
  { SKU: 'DM-PRC-002', Name: 'Flap Disc 100 mm, 60 Grit', Brand: 'Kestrel Works', Category: 'Power Tools > Grinders & Sanders', Description: 'Only warnings: retail above MRP, wholesale above retail.', MRP: 99, 'Retail Price': 120, 'Wholesale Price': 130, Stock: 500 },
  { SKU: 'DM-STK-001', Name: 'Tile Cutter 600 mm', Brand: 'Kestrel Works', Category: 'Power Tools > Saws', Description: 'Stock must be a whole number; status must be active, draft or archived.', MRP: 3999, 'Retail Price': 3499, 'Wholesale Price': 2900, Stock: 12.5, Status: 'live' },
  { SKU: 'DM-PCK-001', Name: 'Plastic Wall Plug 8 mm', Brand: 'Anvilpoint', Category: 'Fasteners & Fittings > Screws & Anchors', Description: 'Pack Size must be 2 or more and Pack Type must be Packet, Coil or Bundle.', MRP: 2, 'Retail Price': 1.5, 'Wholesale Price': 1, 'Pack Type': 'Roll', 'Pack Size': 1 },
  { SKU: 'DM-PCK-002', Name: 'Cable Tie 200 mm (Packet)', Brand: 'Anvilpoint', Category: 'Fasteners & Fittings > Cables & Rope', Description: 'Packet without a pack size.', MRP: 2, 'Retail Price': 1.5, 'Wholesale Price': 1, 'Pack Type': 'Packet' },
  { SKU: 'DM-NAM-001', Name: '18V Brushless Cordless Drill Driver, 13 mm Chuck (2 x 2.0 Ah)', Brand: 'Kestrel Works', Category: 'Power Tools > Drills & Drivers', Description: 'Same name as an existing product (KW-DRL-18V).', MRP: 7499, 'Retail Price': 6499, 'Wholesale Price': 5200 },
  { SKU: 'DM-NAM-002', Name: '', Brand: 'Anvilpoint', Category: 'Hand Tools > Wrenches & Pliers', Description: 'Name is missing.', MRP: 100, 'Retail Price': 90, 'Wholesale Price': 70 },
  { SKU: 'BAD SKU!', Name: 'Hacksaw Frame 300 mm', Brand: 'Anvilpoint', Category: 'Hand Tools > Wrenches & Pliers', Description: 'SKU with spaces and symbols.', MRP: 349, 'Retail Price': 299, 'Wholesale Price': 230, Negotiation: 'maybe' },
];

const csvCell = (value) => {
  if (value === undefined || value === null) return '';
  const text = String(value);
  return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
};

function toCsv(rows, headers) {
  const lines = [headers.map(csvCell).join(',')];
  for (const row of rows) lines.push(headers.map((header) => csvCell(row[header])).join(','));
  return `${lines.join('\n')}\n`;
}

async function main() {
  fs.mkdirSync(DOCS_DIR, { recursive: true });
  const xlsx = Buffer.from(await createCatalogWorkbookBuffer({ rows: SAMPLE_ROWS }));
  fs.writeFileSync(path.join(DOCS_DIR, 'catalog-import-sample.xlsx'), xlsx);
  fs.writeFileSync(path.join(DOCS_DIR, 'catalog-import-sample.csv'), toCsv(SAMPLE_ROWS, TEMPLATE_HEADERS));
  // The errors file also carries a column the importer does not know, to show "ignored columns".
  const errorHeaders = [...TEMPLATE_HEADERS, 'Internal Notes'];
  const errorRows = ERROR_ROWS.map((row) => ({ ...row, 'Internal Notes': 'ignored by the import' }));
  fs.writeFileSync(path.join(DOCS_DIR, 'catalog-import-errors.csv'), toCsv(errorRows, errorHeaders));
  console.log(`Wrote catalog-import-sample.xlsx, catalog-import-sample.csv and catalog-import-errors.csv to ${DOCS_DIR}`);
}

main().catch((error) => { console.error(error); process.exit(1); });
