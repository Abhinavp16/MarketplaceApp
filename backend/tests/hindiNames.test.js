const assert = require('assert');

const {
  buildHindiName,
  isBrokenHindiName,
  localizeUnits,
  normalizeDigits,
  resolveHindiNameOnSave,
  splitForConversion,
} = require('../src/utils/hindiNames');
const { generateHindiName } = require('../src/services/hindiNameService');

// Stand-in for Google (no network): marks what would be converted.
const fakeHindi = { PANEL: 'पैनल', STAGE: 'स्टेज', TURBOMAX: 'टर्बोमैक्स', 'Knapsack Sprayer': 'नैपसैक स्प्रेयर', Sprayer: 'स्प्रेयर', Column: 'कॉलम', inch: 'इंच', Pipe: 'पाइप', Cable: 'केबल', 'Submersible Pump': 'सबमर्सिबल पंप', 'Control Panel': 'कंट्रोल पैनल' };
const converter = async (words) => fakeHindi[words] || null;

(async () => {
  // Numbers, sizes, units and codes are never sent for conversion.
  assert.strictEqual(await generateHindiName('Sprayer 16L', { converter }), 'स्प्रेयर 16 लीटर');
  assert.strictEqual(await generateHindiName('V-4 2 HP', { converter }), 'V-4 2 HP');
  assert.strictEqual(await generateHindiName('Column 2 inch', { converter }), 'कॉलम 2 इंच');
  assert.strictEqual(await generateHindiName('PVC Pipe 1.5 inch', { converter }), 'PVC पाइप 1.5 इंच');
  assert.strictEqual(await generateHindiName('25 sqmm Cable', { converter }), '25 वर्ग मिमी केबल');
  assert.strictEqual(await generateHindiName('MCB Control Panel', { converter }), 'MCB कंट्रोल पैनल');
  assert.strictEqual(await generateHindiName('Submersible Pump', { converter }), 'सबमर्सिबल पंप');
  // Live catalog names are ALL CAPS: codes stay, real words are converted.
  assert.strictEqual(await generateHindiName('1.0HP BCH PANEL', { converter }), '1.0HP BCH पैनल');
  assert.strictEqual(await generateHindiName('7.5 HP 10 STAGE V-6 50ft TURBOMAX', { converter }), '7.5 HP 10 स्टेज V-6 50 फीट टर्बोमैक्स');
  assert.strictEqual(await generateHindiName('HDPE PIPE', { converter: async (w) => (w === 'PIPE' ? 'पाइप' : null) }), 'HDPE पाइप');
  assert.deepStrictEqual(['FTA', 'MTA', 'SDR', 'x', 'X'].map((w) => require('../src/utils/hindiNames').isProtectedWord(w)), [true, true, true, true, true]);
  // Units are written in Hindi after a number (like Google Translate).
  assert.strictEqual(await generateHindiName('4 core Premium 12mm', { converter: async (w) => ({ 'core Premium': 'कोर प्रीमियम' })[w] || null }), '4 कोर प्रीमियम 12 मिमी');
  assert.strictEqual(await generateHindiName('10 m', { converter }), '10 मी');
  assert.strictEqual(localizeUnits('2.5 sqmm 10MM 16L 500 gm 25 kg 50ft 10 Mtr'), '2.5 वर्ग मिमी 10 मिमी 16 लीटर 500 ग्राम 25 किग्रा 50 फीट 10 मी');
  assert.strictEqual(localizeUnits('2HP V-6 1.0HP 2.5X2.5 3-Way'), '2HP V-6 1.0HP 2.5X2.5 3-Way');
  assert.strictEqual(require('../src/utils/hindiNames').isProtectedWord('OIL'), false);
  const sent = [];
  await generateHindiName('Openwell Pump 0.5 HP', { converter: async (w) => { sent.push(w); return 'x'; } });
  assert.deepStrictEqual(sent, ['Openwell Pump']);

  // Hindi digits from the converter always become Latin digits.
  assert.strictEqual(await buildHindiName('Motor', async () => 'मोटर २'), 'मोटर 2');
  assert.strictEqual(normalizeDigits('२ HP, १६L'), '2 HP, 16L');

  // Conversion failure -> null (retry later); junk output is rejected.
  assert.strictEqual(await generateHindiName('Sprayer 16L', { converter: async () => { throw new Error('down'); } }), null);
  assert.strictEqual(await generateHindiName('Sprayer', { converter: async () => '__नुम_प्लेसहोल्डर_०__' }), null);

  // Broken names from the old converter are detected; clean Hindi is not.
  assert.strictEqual(isBrokenHindiName('स्प्रेयर __नुम_प्लेसहोल्डर_०__ल'), true);
  assert.strictEqual(isBrokenHindiName('व्-२ हप'), true);
  assert.strictEqual(isBrokenHindiName('सबमर्सिबल पंप'), false);
  assert.strictEqual(isBrokenHindiName('स्प्रेयर 16L'), false);
  assert.strictEqual(isBrokenHindiName(''), false);

  assert.deepStrictEqual(splitForConversion('Pump 2 HP').map((s) => s.protect), [false, true]);

  // Save rules: typed Hindi is manual and kept; auto Hindi follows the English name.
  assert.deepStrictEqual(resolveHindiNameOnSave({ incomingHindi: undefined }), { set: {}, generate: true });
  assert.deepStrictEqual(resolveHindiNameOnSave({ incomingHindi: ' पंप ' }), { set: { nameHindi: 'पंप', nameHindiSource: 'manual' }, generate: false });
  assert.deepStrictEqual(resolveHindiNameOnSave({ incomingHindi: '', storedHindi: 'पंप', storedSource: 'manual' }), { set: { nameHindi: '', nameHindiSource: null }, generate: true });
  assert.deepStrictEqual(resolveHindiNameOnSave({ incomingHindi: 'पंप', storedHindi: 'पंप', storedSource: 'auto', nameChanged: true }), { set: { nameHindi: '', nameHindiSource: null }, generate: true });
  assert.deepStrictEqual(resolveHindiNameOnSave({ incomingHindi: 'पंप', storedHindi: 'पंप', storedSource: 'manual', nameChanged: true }), { set: {}, generate: false });
  assert.deepStrictEqual(resolveHindiNameOnSave({ incomingHindi: undefined, storedHindi: 'स्प्रेयर __नुम_०__' }), { set: {}, generate: true });

  console.log('hindiNames tests passed');
})().catch((error) => { console.error(error); process.exit(1); });
