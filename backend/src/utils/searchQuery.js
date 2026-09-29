// Product search in English, Hindi and Hinglish.
//
// - normalizeSearchText makes spelling variants equal (पम्प = पंप, फ़ = फ,
//   १० = 10) so the query and stored names compare the same way.
// - Filler words ("wala", "ka", "के") are ignored.
// - SEARCH_GLOSSARY maps Hindi/Hinglish industrial-supply words to their English
//   catalog words and back, so "ड्रिल" also finds products named "DRILL".
const { normalizeDigits } = require('./hindiNames');

// Nukta letters (क़ ख़ ग़ ज़ ड़ ढ़ फ़ य़) -> base letter.
const NUKTA_LETTERS = {
  'क़': 'क', 'ख़': 'ख', 'ग़': 'ग', 'ज़': 'ज',
  'ड़': 'ड', 'ढ़': 'ढ', 'फ़': 'फ', 'य़': 'य',
};

function normalizeSearchText(text) {
  let value = String(text ?? '').normalize('NFC');
  value = value.replace(/[\u200B-\u200D\uFEFF]/g, ''); // zero-width characters
  value = value.replace(/[\u0958-\u095F]/g, (letter) => NUKTA_LETTERS[letter] || letter);
  value = value.replace(/\u093C/g, ''); // standalone nukta
  value = value.replace(/\u0901/g, '\u0902'); // chandrabindu -> anusvara
  // Half nasal before a consonant of the same group -> anusvara (पम्प = पंप).
  value = value
    .replace(/\u092E\u094D(?=[\u092A\u092B\u092C\u092D])/g, '\u0902') // म् + प फ ब भ
    .replace(/\u0928\u094D(?=[\u0924\u0925\u0926\u0927\u091F\u0920\u0921\u0922])/g, '\u0902') // न् + त थ द ध ट ठ ड ढ
    .replace(/\u0923\u094D(?=[\u091F\u0920\u0921\u0922])/g, '\u0902') // ण् + ट ठ ड ढ
    .replace(/\u0919\u094D(?=[\u0915\u0916\u0917\u0918])/g, '\u0902') // ङ् + क ख ग घ
    .replace(/\u091E\u094D(?=[\u091A\u091B\u091C\u091D])/g, '\u0902'); // ञ् + च छ ज झ
  value = normalizeDigits(value);
  // "10मिमी" -> "10 मिमी"
  value = value
    .replace(/(\d)([\u0900-\u097F])/g, '$1 $2')
    .replace(/([\u0900-\u097F])(\d)/g, '$1 $2');
  return value.toLowerCase().replace(/\s+/g, ' ').trim();
}

const STOP_WORDS = new Set([
  'wala', 'wali', 'wale', 'vala', 'vali', 'vale', 'ka', 'ki', 'ke', 'ko', 'se', 'aur', 'and',
  'the', 'for', 'of', 'a', 'an', 'with', 'chahiye', 'chaiye', 'dikhao', 'price', 'rate',
  'वाला', 'वाली', 'वाले', 'का', 'की', 'के', 'को', 'से', 'और', 'चाहिए', 'दिखाओ', 'दाम', 'रेट', 'कीमत',
].map(normalizeSearchText));

// Each group lists words that mean the same thing for this catalog.
const SEARCH_GLOSSARY_GROUPS = [
  // Tools
  ['drill', 'ड्रिल', 'ड्रील', 'drilling'],
  ['cordless', 'कॉर्डलेस', 'बैटरी', 'battery', 'बैटरी वाला'],
  ['grinder', 'ग्राइंडर', 'ग्राइन्डर'],
  ['hammer', 'हथौड़ा', 'हैमर', 'hathoda'],
  ['wrench', 'spanner', 'रिंच', 'पाना', 'पाने', 'pana'],
  ['plier', 'pliers', 'प्लायर', 'प्लास', 'plaas'],
  ['screwdriver', 'स्क्रूड्राइवर', 'पेचकस', 'pechkas'],
  ['saw', 'आरी', 'aari', 'सॉ'],
  ['cutter', 'कटर'],
  ['tape', 'टेप', 'फीता', 'measuring'],
  ['tool', 'tools', 'औज़ार', 'औजार', 'ऑज़ार', 'ozaar', 'टूल', 'टूल्स'],
  ['power', 'पावर', 'बिजली', 'electric', 'इलेक्ट्रिक'],
  ['hand', 'हैंड', 'हाथ'],
  ['kit', 'किट', 'set', 'सेट'],
  // Fasteners and fittings
  ['bolt', 'बोल्ट', 'bolts'],
  ['nut', 'नट', 'nuts'],
  ['screw', 'स्क्रू', 'पेच', 'pech', 'screws'],
  ['washer', 'वॉशर', 'वाशर', 'washers'],
  ['anchor', 'एंकर', 'ऐंकर'],
  ['rivet', 'रिवेट', 'rivets'],
  ['clamp', 'क्लैंप', 'क्लैम्प', 'clip', 'क्लिप'],
  ['hinge', 'हिंज', 'कब्ज़ा', 'kabja', 'कब्जा'],
  ['fastener', 'fasteners', 'फास्टनर', 'fittings', 'fitting', 'फिटिंग'],
  ['elbow', 'एल्बो', 'कोहनी'],
  ['tee', 'टी'],
  ['socket', 'सॉकेट', 'सोकेट'],
  ['coupler', 'कपलर', 'coupling', 'कपलिंग'],
  ['nipple', 'निप्पल', 'निपल'],
  ['valve', 'वाल्व', 'वॉल्व'],
  ['pipe', 'पाइप', 'पाईप', 'नली', 'nali', 'paip'],
  ['cap', 'कैप', 'ढक्कन'],
  ['adaptor', 'adapter', 'adopter', 'एडॉप्टर', 'अडैप्टर', 'एडाप्टर'],
  ['brass', 'ब्रास', 'पीतल'],
  ['steel', 'स्टील', 'iron', 'लोहा', 'loha'],
  ['plastic', 'प्लास्टिक'],
  ['copper', 'कॉपर', 'तांबा'],
  ['black', 'ब्लैक', 'काला'],
  ['premium', 'प्रीमियम'],
  ['cable', 'wire', 'केबल', 'वायर', 'तार', 'taar'],
  ['tank', 'टैंक', 'टंकी', 'tanki'],
  ['oil', 'आयल', 'ऑयल', 'तेल'],
  ['machine', 'मशीन'],
  // Safety gear
  ['helmet', 'हेलमेट', 'टोपी', 'hard hat', 'हार्ड हैट'],
  ['gloves', 'glove', 'दस्ताने', 'दस्ताना', 'ग्लव्स', 'dastane'],
  ['goggles', 'goggle', 'चश्मा', 'चश्मे', 'गॉगल', 'gogal', 'chashma'],
  ['safety', 'सेफ्टी', 'सुरक्षा', 'suraksha'],
  ['shoes', 'shoe', 'boots', 'जूते', 'जूता', 'joote', 'बूट'],
  ['vest', 'जैकेट', 'jacket', 'वेस्ट'],
  ['mask', 'मास्क', 'respirator', 'रेस्पिरेटर'],
  ['earplug', 'earplugs', 'ear plug', 'ear plugs', 'ear muff', 'ear muffs', 'इयरप्लग'],
  // Units and codes
  ['mm', 'मिमी', 'मि.मी.', 'मिलीमीटर', 'millimeter'],
  ['sqmm', 'sq mm', 'वर्ग मिमी', 'स्क्वायर मिमी'],
  ['inch', 'इंच', 'inches'],
  ['ft', 'feet', 'फीट', 'फुट'],
  ['mtr', 'meter', 'metre', 'मीटर', 'मी'],
  ['ltr', 'litre', 'liter', 'लीटर', 'लिटर'],
  ['kg', 'किग्रा', 'किलो', 'kilo'],
  ['hp', 'एचपी', 'हॉर्स पावर', 'horse power'],
  ['volt', 'volts', 'वोल्ट'],
  ['phase', 'फेज़', 'फेज', 'फ़ेज़'],
  ['single', 'सिंगल'],
];

// normalized word -> Set of normalized equivalents (including itself)
const GLOSSARY = new Map();
for (const group of SEARCH_GLOSSARY_GROUPS) {
  const normalized = [...new Set(group.map(normalizeSearchText))];
  for (const word of normalized) {
    const set = GLOSSARY.get(word) || new Set();
    normalized.forEach((equivalent) => set.add(equivalent));
    GLOSSARY.set(word, set);
  }
}
const MULTI_WORD_ENTRIES = [...GLOSSARY.keys()].filter((key) => key.includes(' '))
  .sort((a, b) => b.split(' ').length - a.split(' ').length);

// Latin variants this short would match almost everything; skip them.
const isUsableVariant = (variant) => /[\u0900-\u097F]/.test(variant) || variant.length >= 2 || /^\d/.test(variant);

// Returns one group of equivalent search variants per meaningful query word,
// e.g. "सबमर्सिबल पंप wala" -> [[सबमर्सिबल, submersible, ...], [पंप, pump, motor, ...]].
function buildSearchTerms(query) {
  const words = normalizeSearchText(query).split(' ').filter(Boolean);
  const groups = [];
  for (let i = 0; i < words.length; i += 1) {
    // Longest multi-word glossary phrase first ("वर्ग मिमी", "control panel").
    const phrase = MULTI_WORD_ENTRIES.find((entry) => {
      const parts = entry.split(' ');
      return parts.every((part, offset) => words[i + offset] === part);
    });
    const word = phrase || words[i];
    if (phrase) i += phrase.split(' ').length - 1;
    if (STOP_WORDS.has(word)) continue;
    const variants = [...(GLOSSARY.get(word) || new Set([word]))].filter(isUsableVariant);
    if (!variants.includes(word)) variants.unshift(word);
    groups.push([...new Set(variants)]);
  }
  return groups;
}

const escapeRegex = (value) => String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

// One case-insensitive pattern that matches any variant of a word group.
const groupPattern = (variants) => variants.map(escapeRegex).join('|');

module.exports = {
  normalizeSearchText,
  buildSearchTerms,
  groupPattern,
  escapeRegex,
  STOP_WORDS,
  SEARCH_GLOSSARY_GROUPS,
};
