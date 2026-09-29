const assert = require('assert');
const BRAND = require('../src/config/brand');

const { TEMPLATES, renderNotification, normalizeLanguage } = require('../src/services/notificationTemplates');

const placeholders = (text) => (text.match(/\{\w+\}/g) || []).sort();

// Every template has English and Hindi with the same placeholders.
for (const [key, template] of Object.entries(TEMPLATES)) {
  for (const lang of ['en', 'hi']) {
    assert.ok(template[lang]?.title && template[lang]?.body, `${key}.${lang} must have title and body`);
  }
  for (const part of ['title', 'body']) {
    assert.deepStrictEqual(placeholders(template.hi[part]), placeholders(template.en[part]), `${key}.${part} placeholders differ`);
  }
  // Hindi text is in Devanagari and never uses Hindi digits.
  assert.ok(/[ऀ-ॿ]/.test(template.hi.title + template.hi.body), `${key}.hi must be Hindi`);
  assert.ok(!/[०-९]/.test(template.hi.title + template.hi.body), `${key}.hi must use Latin digits`);
}

// Rendering
assert.deepStrictEqual(
  renderNotification('requirementNewPrice', 'hi', { productName: 'Submersible Pump', productNameHindi: 'सबमर्सिबल पंप', price: 850 }),
  { title: `${BRAND.name} से नई कीमत`, body: `${BRAND.name} ने सबमर्सिबल पंप के लिए नई कीमत ₹850/यूनिट भेजी है। देखें और जवाब दें।` },
);
assert.strictEqual(
  renderNotification('requirementNewPrice', 'en', { productName: 'Submersible Pump', productNameHindi: 'सबमर्सिबल पंप', price: 850 }).body,
  `${BRAND.name} shared a new price ₹850/unit for Submersible Pump. Review and respond.`,
);
// Hindi falls back to the English product name when no Hindi name exists.
assert.ok(renderNotification('requirementDeclined', 'hi', { productName: 'Sprayer 16L' }).body.includes('Sprayer 16L'));
assert.strictEqual(renderNotification('orderShipped', 'fr').title, 'Order Shipped!');
assert.strictEqual(normalizeLanguage(undefined), 'en');
assert.throws(() => renderNotification('nope', 'en'), /Unknown notification template/);

console.log('notificationTemplates tests passed');
