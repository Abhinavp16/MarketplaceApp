const assert = require('assert');

const { displayActivityText, withDisplayNotes } = require('../src/utils/roleLabels');

assert.strictEqual(
  displayActivityText('Negotiation NEG-1 accepted by Staff Ravi — order confirmed'),
  'Negotiation NEG-1 accepted by Member Ravi — order confirmed',
);
assert.strictEqual(displayActivityText('verified by staff'), 'verified by member');
assert.strictEqual(displayActivityText('STAFF NOTE'), 'MEMBER NOTE');
// Only whole words change.
assert.strictEqual(displayActivityText('Staffordshire staffing'), 'Staffordshire staffing');
assert.strictEqual(displayActivityText(''), '');
assert.strictEqual(displayActivityText(null), null);

assert.deepStrictEqual(
  withDisplayNotes([{ status: 'pending_payment', note: 'accepted by Staff A' }, { status: 'shipped' }]),
  [{ status: 'pending_payment', note: 'accepted by Member A' }, { status: 'shipped', note: undefined }],
);
assert.strictEqual(withDisplayNotes(undefined), undefined);

console.log('roleLabels tests passed');
