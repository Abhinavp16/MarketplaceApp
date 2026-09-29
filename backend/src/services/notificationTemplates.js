// Customer-facing push / in-app notification texts in English and Hindi.
// Placeholders: {orderNumber} {productName} {price} {reason} {message} {when} {brand}.
// Numbers and prices always stay in Latin digits (1, 2, 3).
const BRAND = require('../config/brand');
const SUPPORTED_LANGUAGES = ['en', 'hi'];

const TEMPLATES = {
  orderConfirmed: {
    en: { title: 'Order Confirmed!', body: 'Your order has been confirmed and is being processed.' },
    hi: { title: 'ऑर्डर कन्फर्म हो गया!', body: 'आपका ऑर्डर कन्फर्म हो गया है और तैयार किया जा रहा है।' },
  },
  orderShipped: {
    en: { title: 'Order Shipped!', body: 'Your order is on its way!' },
    hi: { title: 'ऑर्डर भेज दिया गया!', body: 'आपका ऑर्डर रास्ते में है!' },
  },
  orderDelivered: {
    en: { title: 'Order Delivered!', body: 'Your order has been delivered. Enjoy!' },
    hi: { title: 'ऑर्डर डिलीवर हो गया!', body: 'आपका ऑर्डर डिलीवर हो गया है। धन्यवाद!' },
  },
  orderCancelled: {
    en: { title: 'Order Cancelled', body: 'Your order has been cancelled.' },
    hi: { title: 'ऑर्डर रद्द किया गया', body: 'आपका ऑर्डर रद्द कर दिया गया है।' },
  },
  orderUpdated: {
    en: { title: 'Order Update', body: 'Your order status has been updated.' },
    hi: { title: 'ऑर्डर अपडेट', body: 'आपके ऑर्डर की स्थिति अपडेट की गई है।' },
  },
  orderAccepted: {
    en: { title: 'Order Accepted', body: 'Your order {orderNumber} has been accepted. You can now complete payment.' },
    hi: { title: 'ऑर्डर स्वीकार किया गया', body: 'आपका ऑर्डर {orderNumber} स्वीकार कर लिया गया है। अब आप भुगतान कर सकते हैं।' },
  },
  orderRejected: {
    en: { title: 'Order Rejected', body: 'Your order {orderNumber} was rejected: {reason}' },
    hi: { title: 'ऑर्डर अस्वीकार किया गया', body: 'आपका ऑर्डर {orderNumber} अस्वीकार कर दिया गया: {reason}' },
  },
  paymentVerified: {
    en: { title: 'Payment Verified!', body: "Your payment for order {orderNumber} has been verified. We're processing your order now." },
    hi: { title: 'भुगतान की पुष्टि हो गई!', body: 'ऑर्डर {orderNumber} के लिए आपके भुगतान की पुष्टि हो गई है। अब हम आपका ऑर्डर तैयार कर रहे हैं।' },
  },
  paymentRejectedWithReason: {
    en: { title: 'Payment Declined', body: 'Your payment for order {orderNumber} was declined: {reason}' },
    hi: { title: 'भुगतान अस्वीकार हुआ', body: 'ऑर्डर {orderNumber} के लिए आपका भुगतान अस्वीकार हुआ: {reason}' },
  },
  paymentRejected: {
    en: { title: 'Payment Declined', body: 'Your payment for order {orderNumber} was declined. Please re-upload.' },
    hi: { title: 'भुगतान अस्वीकार हुआ', body: 'ऑर्डर {orderNumber} के लिए आपका भुगतान अस्वीकार हुआ। कृपया दोबारा अपलोड करें।' },
  },
  requirementDeclinedWithReason: {
    en: { title: 'Requirement Declined', body: '{brand} could not confirm requirement for {productName}: {reason}' },
    hi: { title: 'रिक्वायरमेंट अस्वीकार हुई', body: '{brand} {productName} की रिक्वायरमेंट कन्फर्म नहीं कर सका: {reason}' },
  },
  requirementDeclined: {
    en: { title: 'Requirement Declined', body: '{brand} could not confirm requirement for {productName}. Open it to view the reason.' },
    hi: { title: 'रिक्वायरमेंट अस्वीकार हुई', body: '{brand} {productName} की रिक्वायरमेंट कन्फर्म नहीं कर सका। कारण देखने के लिए खोलें।' },
  },
  requirementNewPrice: {
    en: { title: 'New Price from {brand}', body: '{brand} shared a new price ₹{price}/unit for {productName}. Review and respond.' },
    hi: { title: '{brand} से नई कीमत', body: '{brand} ने {productName} के लिए नई कीमत ₹{price}/यूनिट भेजी है। देखें और जवाब दें।' },
  },
  requirementMessage: {
    en: { title: 'New message on your requirement', body: '{brand}: {message}' },
    hi: { title: 'आपकी रिक्वायरमेंट पर नया मैसेज', body: '{brand}: {message}' },
  },
  requirementAccepted: {
    en: { title: 'Order Created! ✅', body: '{brand} accepted your requirement for {productName} at ₹{price}/unit. Order {orderNumber} is ready to view.' },
    hi: { title: 'ऑर्डर बन गया! ✅', body: '{brand} ने {productName} की आपकी रिक्वायरमेंट ₹{price}/यूनिट पर स्वीकार कर ली है। ऑर्डर {orderNumber} देखें।' },
  },
  negotiationUpdate: {
    en: { title: 'Negotiation Update', body: '{message}' },
    hi: { title: 'मोलभाव अपडेट', body: '{message}' },
  },
  wholesalerApproved: {
    en: { title: 'Account Upgraded! 🎉', body: 'Your wholesaler account has been approved. Enjoy exclusive bulk access!' },
    hi: { title: 'खाता अपग्रेड हो गया! 🎉', body: 'आपका होलसेलर खाता स्वीकृत हो गया है। अब थोक कीमतों का लाभ उठाएं!' },
  },
  wholesalerRejected: {
    en: { title: 'Application Update', body: 'Your wholesaler application was not approved. Please review your details and re-apply from your profile.' },
    hi: { title: 'आवेदन अपडेट', body: 'आपका होलसेलर आवेदन स्वीकृत नहीं हुआ। कृपया अपनी जानकारी जांचें और प्रोफ़ाइल से दोबारा आवेदन करें।' },
  },
  priceCampaignStarted: {
    en: { title: 'Price update scheduled', body: 'New prices will apply on {when} IST.' },
    hi: { title: 'कीमतों में बदलाव तय हुआ', body: 'नई कीमतें {when} (IST) से लागू होंगी।' },
  },
  priceCampaign12h: {
    en: { title: 'Price update reminder', body: 'Most product prices will update in 12 hours.' },
    hi: { title: 'कीमत बदलाव रिमाइंडर', body: 'ज़्यादातर उत्पादों की कीमतें 12 घंटे में बदल जाएंगी।' },
  },
  priceCampaign6h: {
    en: { title: 'Price update reminder', body: 'Most product prices will update in 6 hours.' },
    hi: { title: 'कीमत बदलाव रिमाइंडर', body: 'ज़्यादातर उत्पादों की कीमतें 6 घंटे में बदल जाएंगी।' },
  },
  priceCampaign20m: {
    en: { title: 'Price update reminder', body: 'Prices on many products will update in 20 minutes.' },
    hi: { title: 'कीमत बदलाव रिमाइंडर', body: 'कई उत्पादों की कीमतें 20 मिनट में बदल जाएंगी।' },
  },
  priceCampaignApplied: {
    en: { title: 'Prices updated', body: 'New prices are now applied.' },
    hi: { title: 'कीमतें बदल गईं', body: 'नई कीमतें अब लागू हो गई हैं।' },
  },
};

const normalizeLanguage = (value) => (SUPPORTED_LANGUAGES.includes(value) ? value : 'en');

const fill = (text, params) => text.replace(/\{(\w+)\}/g, (match, key) => (
  params[key] === undefined || params[key] === null ? '' : String(params[key])
)).replace(/\s+([:.])/g, '$1').trim();

// params.productName / params.productNameHindi: the Hindi name is used for
// Hindi messages when available.
function renderNotification(key, language, params = {}) {
  const template = TEMPLATES[key];
  if (!template) throw new Error(`Unknown notification template: ${key}`);
  const lang = normalizeLanguage(language);
  const values = {
    brand: BRAND.name,
    ...params,
    productName: lang === 'hi' && params.productNameHindi ? params.productNameHindi : params.productName,
  };
  const text = template[lang] || template.en;
  return { title: fill(text.title, values), body: fill(text.body, values) };
}

module.exports = { TEMPLATES, SUPPORTED_LANGUAGES, normalizeLanguage, renderNotification };
