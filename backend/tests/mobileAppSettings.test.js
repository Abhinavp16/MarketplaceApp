const assert = require('assert');
const BRAND = require('../src/config/brand');
const Settings = require('../src/models/Settings');
const { adminValidation } = require('../src/validations');
const adminSettingsController = require('../src/controllers/admin/settingsController');
const settingsController = require('../src/controllers/settingsController');

const validEnabledPlatform = {
  enabled: true,
  latestVersion: '1.2.3',
  latestBuildNumber: 123,
  storeUrl: BRAND.storeUrls.android,
  title: 'Update Required',
  message: 'Please update to continue.',
};

const response = () => ({
  headers: {},
  set(name, value) { this.headers[name] = value; return this; },
  json(payload) { this.payload = payload; return this; },
});

async function run() {
  const defaults = new Settings({
    upiId: 'test@ybl',
    upiDisplayName: 'Test',
  });
  assert.strictEqual(defaults.mobileApp.android.enabled, false);
  assert.strictEqual(defaults.mobileApp.android.latestVersion, '');
  assert.strictEqual(defaults.mobileApp.android.latestBuildNumber, 0);
  assert.strictEqual(defaults.mobileApp.android.storeUrl, BRAND.storeUrls.android);
  assert.strictEqual(defaults.mobileApp.ios.storeUrl, BRAND.storeUrls.ios);

  assert.ifError(adminValidation.updateSettings.validate({
    mobileApp: { android: validEnabledPlatform },
  }).error);
  assert.ok(adminValidation.updateSettings.validate({
    mobileApp: { android: { enabled: true } },
  }).error, 'enabled platforms must include all mandatory values');
  assert.ok(adminValidation.updateSettings.validate({
    mobileApp: { android: { ...validEnabledPlatform, latestBuildNumber: 0 } },
  }).error, 'enabled platforms must use a positive build number');
  assert.ok(adminValidation.updateSettings.validate({
    mobileApp: { android: { ...validEnabledPlatform, storeUrl: 'not a url' } },
  }).error, 'store URLs must be valid http(s) URLs');
  assert.ok(adminValidation.updateSettings.validate({
    mobileApp: { android: { unexpected: true } },
  }).error, 'unknown platform fields must be rejected');

  const originalFindById = Settings.findById;
  const originalGetSettings = Settings.getSettings;
  try {
    const document = {
      mobileApp: {
        android: { ...validEnabledPlatform },
        ios: {
          enabled: false,
          latestVersion: '',
          latestBuildNumber: 0,
          storeUrl: BRAND.storeUrls.ios,
          title: 'Update Required',
          message: 'Original iOS message',
        },
      },
      checkout: {},
      async save() {},
    };
    Settings.findById = async () => document;

    const adminResponse = response();
    await adminSettingsController.updateSettings({
      body: { mobileApp: { android: { message: 'New Android message' } } },
    }, adminResponse, (error) => { throw error; });
    assert.strictEqual(document.mobileApp.android.message, 'New Android message');
    assert.strictEqual(document.mobileApp.android.latestVersion, '1.2.3');
    assert.strictEqual(document.mobileApp.ios.message, 'Original iOS message');

    let mergeValidationError;
    await adminSettingsController.updateSettings({
      body: { mobileApp: { android: { message: '' } } },
    }, response(), (error) => { mergeValidationError = error; });
    assert.ok(mergeValidationError, 'merged enabled platform state must remain valid');

    document.updatedAt = new Date('2026-09-19T00:00:00.000Z');
    document.secret = 'not public';
    document.mobileApp.android.secret = 'not public';
    Settings.getSettings = async () => document;
    const publicResponse = response();
    await settingsController.getMobileAppSettings({}, publicResponse, (error) => { throw error; });
    assert.strictEqual(publicResponse.headers['Cache-Control'], 'no-store');
    assert.deepStrictEqual(Object.keys(publicResponse.payload.data).sort(), ['android', 'ios']);
    assert.deepStrictEqual(Object.keys(publicResponse.payload.data.android).sort(), [
      'enabled',
      'latestBuildNumber',
      'latestVersion',
      'message',
      'storeUrl',
      'title',
    ]);
    assert.strictEqual(publicResponse.payload.data.secret, undefined);

    const getAdminResponse = response();
    await adminSettingsController.getSettings({}, getAdminResponse, (error) => { throw error; });
    assert.strictEqual(getAdminResponse.headers['Cache-Control'], 'no-store');
  } finally {
    Settings.findById = originalFindById;
    Settings.getSettings = originalGetSettings;
  }

  console.log('Mobile app settings tests passed');
}

run().catch((error) => {
  console.error('Mobile app settings tests failed');
  throw error;
});
