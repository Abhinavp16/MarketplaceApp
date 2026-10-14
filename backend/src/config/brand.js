// Single source for the (fictional) business identity used by this demo API.
// Each value can be overridden per deployment through a BRAND_* environment
// variable (see deploy/); with no overrides the defaults below apply.
const fromEnv = (key, fallback) => {
  const value = process.env[key];
  return value !== undefined && String(value).trim() !== '' ? String(value).trim() : fallback;
};

const BRAND = Object.freeze({
  name: fromEnv('BRAND_NAME', 'DemoMart Distribution'),
  // Short name used inside notification text ("DemoMart accepted your requirement").
  shortName: fromEnv('BRAND_SHORT_NAME', 'DemoMart'),
  legalName: fromEnv('BRAND_LEGAL_NAME', 'DemoMart Distribution Pvt Ltd (Demo)'),
  tagline: 'Distribution made simple',
  email: fromEnv('BRAND_EMAIL', 'demo@demomart.example'),
  phone: fromEnv('BRAND_PHONE', '+91 00000 00000'),
  address: fromEnv('BRAND_ADDRESS', '100 Demo Street, Sample City, Demo State 000000'),
  website: fromEnv('BRAND_WEBSITE', 'https://demo.demomart.example'),
  whatsapp: '',
  // Placeholder app-store links (the demo apps are not published anywhere).
  storeUrls: Object.freeze({
    android: 'https://demo.demomart.example/get-app/android',
    ios: 'https://demo.demomart.example/get-app/ios',
  }),
});

module.exports = BRAND;
