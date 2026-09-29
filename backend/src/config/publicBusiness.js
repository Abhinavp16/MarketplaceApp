// WhatsApp checkout is disabled in the demo: no number is configured unless
// PUBLIC_ORDER_WHATSAPP_NUMBER is set explicitly.
const digitsOnly = (value = '') => String(value).replace(/\D/g, '');

const normalizeIndianWhatsAppNumber = (value = '') => {
  const digits = digitsOnly(value);
  if (!digits) return '';
  if (digits.length === 10) return `91${digits}`;
  return digits;
};

const orderWhatsAppNumber = normalizeIndianWhatsAppNumber(
  process.env.PUBLIC_ORDER_WHATSAPP_NUMBER || ''
);

module.exports = {
  orderWhatsAppNumber,
};
