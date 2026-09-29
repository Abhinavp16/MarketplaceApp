const assert = require('assert');
const User = require('../src/models/User');
const { authValidation } = require('../src/validations');
const { TERMS_VERSION, PRIVACY_POLICY_VERSION } = require('../src/config/legalAcceptance');
const {
  hasRepeatedDigits,
  hasSequentialDigits,
  isRegistrationPhoneValid,
} = require('../src/utils/phoneValidation');

const registrationSchemas = [
  {
    name: 'email customer registration',
    schema: authValidation.register,
    payload: (phone) => ({
      name: 'Test Customer',
      email: 'customer@example.com',
      password: 'password123',
      phone,
      termsAccepted: true,
      privacyPolicyAccepted: true,
      termsVersion: TERMS_VERSION,
      privacyPolicyVersion: PRIVACY_POLICY_VERSION,
    }),
  },
  {
    name: 'email wholesaler registration',
    schema: authValidation.registerWholesaler,
    payload: (phone) => ({
      name: 'Test Wholesaler',
      email: 'wholesaler@example.com',
      password: 'password123',
      phone,
      businessName: 'Test Traders',
      termsAccepted: true,
      privacyPolicyAccepted: true,
      termsVersion: TERMS_VERSION,
      privacyPolicyVersion: PRIVACY_POLICY_VERSION,
    }),
  },
  {
    name: 'phone customer registration',
    schema: authValidation.registerPhone,
    payload: (phone) => ({
      name: 'Test Customer',
      password: 'password123',
      phone,
      termsAccepted: true,
      privacyPolicyAccepted: true,
      termsVersion: TERMS_VERSION,
      privacyPolicyVersion: PRIVACY_POLICY_VERSION,
    }),
  },
  {
    name: 'phone wholesaler registration',
    schema: authValidation.registerPhoneWholesaler,
    payload: (phone) => ({
      name: 'Test Wholesaler',
      password: 'password123',
      phone,
      businessName: 'Test Traders',
      termsAccepted: true,
      privacyPolicyAccepted: true,
      termsVersion: TERMS_VERSION,
      privacyPolicyVersion: PRIVACY_POLICY_VERSION,
    }),
  },
];

function validate(schema, payload) {
  return schema.validate(payload, { abortEarly: false, stripUnknown: true });
}

function run() {
  const validPhone = '9135724680';
  assert.strictEqual(isRegistrationPhoneValid(validPhone), true);

  for (const { name, schema, payload } of registrationSchemas) {
    const result = validate(schema, payload(validPhone));
    assert.ifError(result.error, `${name} should accept a valid Indian mobile number`);
    assert.strictEqual(result.value.phone, validPhone);
    assert.strictEqual(result.value.termsAccepted, true);
    assert.strictEqual(result.value.privacyPolicyAccepted, true);
  }

  for (const { name, schema, payload } of registrationSchemas.slice(2)) {
    const missingConsent = payload(validPhone);
    delete missingConsent.termsAccepted;
    assert.ok(validate(schema, missingConsent).error, `${name} must require terms acceptance`);

    const refusedPrivacy = payload(validPhone);
    refusedPrivacy.privacyPolicyAccepted = false;
    assert.ok(validate(schema, refusedPrivacy).error, `${name} must require privacy acceptance`);
  }

  const invalidPhones = [
    '5135724680',
    '913572468',
    '91357246801',
    '91357a4680',
    '91357 24680',
    '+919135724680',
    '9999999999',
    '6666666666',
    '1234567890',
    '9876543210',
    '6789012345',
  ];

  for (const phone of invalidPhones) {
    assert.strictEqual(isRegistrationPhoneValid(phone), false, `${phone} must be rejected`);
    for (const { name, schema, payload } of registrationSchemas) {
      const result = validate(schema, payload(phone));
      assert.ok(result.error, `${name} must reject ${phone}`);
      assert.ok(
        result.error.details.some((detail) => detail.path[0] === 'phone'),
        `${name} should report phone validation for ${phone}`
      );
    }
  }

  assert.strictEqual(hasRepeatedDigits('9999999999'), true);
  assert.strictEqual(hasSequentialDigits('1234567890'), true);
  assert.strictEqual(hasSequentialDigits('9876543210'), true);
  assert.strictEqual(hasSequentialDigits('9135724680'), false);

  const phonePath = User.schema.path('phone');
  assert.strictEqual(phonePath.options.unique, true, 'phone must use the shared unique index across user roles');

  console.log('✅ Registration phone validation tests passed');
}

try {
  run();
} catch (error) {
  console.error('❌ Registration phone validation tests failed');
  throw error;
}
