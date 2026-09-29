const assert = require('assert');

const { buildSearchTerms, groupPattern, normalizeSearchText } = require('../src/utils/searchQuery');

const n = normalizeSearchText;

// Spelling variants compare equal.
assert.strictEqual(n('पम्प'), n('पंप'));
assert.strictEqual(n('फ़ेज़'), n('फेज'));
assert.strictEqual(n('ठण्डा'), n('ठंडा'));
assert.strictEqual(n('सँग'), n('संग'));
assert.strictEqual(n('पं‍प'), n('पंप')); // zero-width joiner
assert.strictEqual(n('१० मिमी'), '10 मिमी');
assert.strictEqual(n('10मिमी'), '10 मिमी');
assert.strictEqual(n('  SUBMERSIBLE   Pump '), 'submersible pump');

const flat = (query) => buildSearchTerms(query).map((group) => group.slice().sort());

// Hindi, Hinglish and English words map to the same catalog words.
assert.ok(buildSearchTerms('बोल्ट')[0].includes('bolt'));
assert.ok(buildSearchTerms('दस्ताने')[0].includes('gloves'));
assert.ok(buildSearchTerms('चश्मा')[0].includes('goggles'));
assert.ok(buildSearchTerms('तार')[0].includes('cable'));
assert.ok(buildSearchTerms('नली')[0].includes('pipe'));
assert.ok(buildSearchTerms('ड्रिल')[0].includes('drill'));

// Filler words are dropped.
assert.deepStrictEqual(flat('motor wala'), flat('motor'));
assert.deepStrictEqual(flat('drill ka rate'), flat('drill'));
assert.deepStrictEqual(buildSearchTerms('wala'), []);

// Units and numbers.
assert.deepStrictEqual(buildSearchTerms('10 मिमी')[0], ['10']);
assert.ok(buildSearchTerms('10 मिमी')[1].includes('mm'));
assert.ok(buildSearchTerms('2.5 वर्ग मिमी')[1].includes('sqmm'), 'multi-word unit');
assert.strictEqual(buildSearchTerms('2.5 वर्ग मिमी').length, 2);
assert.ok(buildSearchTerms('2 इंच')[1].includes('inch'));

// Unknown words still search as typed; very short Latin variants are not added.
assert.deepStrictEqual(buildSearchTerms('xyz123'), [['xyz123']]);
assert.ok(!buildSearchTerms('मीटर')[0].includes('m'));

// Pattern escapes regex characters.
assert.ok(new RegExp(groupPattern(['1/2"', 'a.b']), 'i').test('pipe 1/2" x'));
assert.ok(!new RegExp(groupPattern(['a.b']), 'i').test('axb'));

console.log('searchQuery tests passed');
