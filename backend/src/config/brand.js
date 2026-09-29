// Single source for the (fictional) business identity used by this demo API.
const BRAND = Object.freeze({
  name: 'TradeHub Demo',
  legalName: 'TradeHub Distribution Pvt Ltd (Demo)',
  tagline: 'Distribution made simple',
  email: 'demo@tradehub.example',
  phone: '+91 00000 00000',
  address: '100 Demo Street, Sample City, Demo State 000000',
  website: 'https://demo.tradehub.example',
  whatsapp: '',
  // Placeholder app-store links (the demo apps are not published anywhere).
  storeUrls: Object.freeze({
    android: 'https://demo.tradehub.example/get-app/android',
    ios: 'https://demo.tradehub.example/get-app/ios',
  }),
});

module.exports = BRAND;
