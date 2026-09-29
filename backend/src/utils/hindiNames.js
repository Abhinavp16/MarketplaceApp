// Rules for generated Hindi product/category names.
//
// Only plain words are converted to Hindi. Numbers, sizes, units and codes
// ("2 HP", "16L", "V-4", "PVC", "25 sqmm") are kept exactly as written, and
// digits are always Latin (1, 2, 3), never Devanagari (१, २, ३).

const HINDI_NAME_SWEEP_MINUTES = 30;
const HINDI_NAME_SWEEP_BATCH = 100;

const HINDI_NAME_SOURCES = Object.freeze({ AUTO: 'auto', MANUAL: 'manual' });

// Units written as separate words that must not be converted.
const PROTECTED_UNITS = new Set([
  'hp', 'kw', 'kva', 'kv', 'v', 'w', 'a', 'amp', 'amps', 'rpm', 'bar', 'psi',
  'l', 'ltr', 'ltrs', 'litre', 'liter', 'ml', 'mm', 'cm', 'm', 'mtr', 'sqmm', 'sq',
  'kg', 'g', 'gm', 'ft', 'nb', 'od', 'id',
]);

// Upper-case codes/abbreviations that must stay as written. Other all-caps
// words (PANEL, STAGE, PIPE...) are ordinary words and are converted.
const PROTECTED_CODES = new Set([
  'HP', 'SS', 'MS', 'GI', 'CI', 'PP', 'PE', 'MCB', 'BCH', 'TP', 'DOL', 'SP',
  'PVC', 'HDPE', 'UPVC', 'CPVC', 'LDPE', 'ISI', 'BIS', 'ABS', 'NB', 'OD', 'ID',
  'AC', 'DC', 'LED', 'RPM', 'KVA', 'KW', 'MM', 'CM', 'FT', 'KG', 'LTR',
  'SQMM', 'COD', 'GST', 'ELCB', 'RCCB', 'MPCB', 'SPN', 'TPN',
]);

// Measurement units are written in Hindi after a number, the way Google
// Translate does ("10 m" -> "10 मी", "12mm" -> "12 मिमी"). Electrical codes
// (HP, KW, V) stay as written.
const HINDI_UNITS = {
  sqmm: 'वर्ग मिमी',
  mm: 'मिमी',
  cm: 'सेमी',
  m: 'मी',
  mtr: 'मी',
  mtrs: 'मी',
  meter: 'मी',
  meters: 'मी',
  metre: 'मी',
  metres: 'मी',
  kg: 'किग्रा',
  kgs: 'किग्रा',
  g: 'ग्राम',
  gm: 'ग्राम',
  gms: 'ग्राम',
  l: 'लीटर',
  ltr: 'लीटर',
  ltrs: 'लीटर',
  litre: 'लीटर',
  litres: 'लीटर',
  liter: 'लीटर',
  liters: 'लीटर',
  ml: 'मिली',
  ft: 'फीट',
  feet: 'फीट',
  inch: 'इंच',
  inches: 'इंच',
};

// "12mm", "10 m", "2.5 sq mm", "50ft" -> number + Hindi unit.
const UNIT_AFTER_NUMBER = new RegExp(
  `(\\d(?:[\\d.,/]*\\d)?)\\s*(sq\\.?\\s?mm|${Object.keys(HINDI_UNITS).filter((unit) => unit !== 'sqmm').sort((a, b) => b.length - a.length).join('|')})(?![A-Za-z])`,
  'gi',
);

const localizeUnits = (text) => String(text ?? '').replace(UNIT_AFTER_NUMBER, (match, number, unit) => {
  const key = unit.toLowerCase().replace(/[.\s]/g, '');
  const hindi = HINDI_UNITS[key];
  return hindi ? `${number} ${hindi}` : match;
});

// Short all-caps words that are ordinary words, not codes.
const COMMON_SHORT_WORDS = new Set(['OIL', 'TEE', 'CAP', 'NUT', 'END', 'BOX', 'FAN', 'CUP', 'SET', 'KIT', 'TAP', 'BIG', 'NEW']);

const DEVANAGARI_DIGITS = '०१२३४५६७८९';

const normalizeDigits = (value) => String(value ?? '')
  .replace(/[०-९]/g, (digit) => String(DEVANAGARI_DIGITS.indexOf(digit)));

// A stored Hindi name that an older converter broke (placeholder text, Hindi
// digits or leftover underscores) needs to be regenerated.
const isBrokenHindiName = (value) => {
  const text = String(value ?? '');
  if (!text.trim()) return false;
  return /_/.test(text) || /नुम|प्लेसहोल्डर/.test(text) || /[०-९]/.test(text);
};

const isProtectedWord = (word) => {
  if (!word) return true;
  if (/\d/.test(word)) return true; // 2, 1.5, 2-3, 16L, 2HP, V-4, 4"
  if (!/[A-Za-z]/.test(word)) return true; // punctuation, symbols
  const bare = word.replace(/[^A-Za-z]/g, '');
  if (!/[a-z]/.test(word)) {
    // All-caps: keep known codes, very short ones (HP, GI) and letter groups
    // without vowels (BCH, MCB); convert real words (PANEL, STAGE).
    const upper = bare.toUpperCase();
    if (COMMON_SHORT_WORDS.has(upper)) return false;
    if (PROTECTED_CODES.has(upper) || upper.length <= 3 || !/[AEIOU]/.test(upper)) return true;
    return false;
  }
  if (/^[xX×]$/.test(word)) return true; // "2 x 1" size separator
  return PROTECTED_UNITS.has(bare.toLowerCase());
};

// Splits a name into runs of convertible words and protected tokens,
// keeping the original spacing.
const splitForConversion = (text) => {
  const parts = String(text ?? '').split(/(\s+)/);
  const segments = [];
  for (const part of parts) {
    if (!part) continue;
    const isSpace = /^\s+$/.test(part);
    const protect = isSpace ? null : isProtectedWord(part);
    const last = segments[segments.length - 1];
    if (isSpace) {
      if (last) last.text += part;
      else segments.push({ text: part, protect: true });
      continue;
    }
    if (last && last.protect === protect) {
      last.text += part;
    } else {
      segments.push({ text: part, protect });
    }
  }
  return segments;
};

// `convertWords(text)` converts one run of plain words (may throw / return
// null). Returns the Hindi name, or null when nothing could be converted.
async function buildHindiName(englishName, convertWords) {
  const input = String(englishName ?? '').trim();
  if (!input) return null;

  const segments = splitForConversion(input);
  let converted = false;
  const output = [];
  for (const segment of segments) {
    if (segment.protect) {
      output.push(localizeUnits(segment.text));
      continue;
    }
    const trailing = segment.text.match(/\s*$/)[0];
    const words = segment.text.slice(0, segment.text.length - trailing.length);
    const result = normalizeDigits(await convertWords(words) || '').trim();
    if (result && result !== words && !isBrokenHindiName(result)) {
      output.push(result + trailing);
      converted = true;
    } else {
      output.push(segment.text);
    }
  }

  if (!converted) {
    // Only numbers/codes/units: still write the units in Hindi.
    const withUnits = normalizeDigits(output.join('')).replace(/\s+/g, ' ').trim();
    return withUnits !== input ? withUnits : null;
  }
  return normalizeDigits(output.join('')).replace(/\s+/g, ' ').trim();
}

// Decides what to do with the Hindi name when an admin saves a product or
// category. Returns the fields to set and whether to generate one afterwards.
//   incomingHindi: value sent by the form (undefined = not sent)
//   stored*: current values (empty for a new item)
function resolveHindiNameOnSave({ incomingHindi, storedHindi = '', storedSource = null, nameChanged = false }) {
  const stored = String(storedHindi ?? '').trim();
  if (incomingHindi !== undefined) {
    const typed = String(incomingHindi ?? '').trim();
    if (!typed) {
      return { set: { nameHindi: '', nameHindiSource: null }, generate: true };
    }
    if (typed !== stored) {
      return { set: { nameHindi: typed, nameHindiSource: HINDI_NAME_SOURCES.MANUAL }, generate: false };
    }
  }
  if (nameChanged && storedSource === HINDI_NAME_SOURCES.AUTO) {
    return { set: { nameHindi: '', nameHindiSource: null }, generate: true };
  }
  return { set: {}, generate: !stored || isBrokenHindiName(stored) };
}

module.exports = {
  resolveHindiNameOnSave,
  HINDI_UNITS,
  localizeUnits,
  HINDI_NAME_SWEEP_MINUTES,
  HINDI_NAME_SWEEP_BATCH,
  HINDI_NAME_SOURCES,
  normalizeDigits,
  isBrokenHindiName,
  isProtectedWord,
  splitForConversion,
  buildHindiName,
};
