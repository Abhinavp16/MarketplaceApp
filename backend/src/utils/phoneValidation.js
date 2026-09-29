const INDIAN_MOBILE_PATTERN = /^[6-9]\d{9}$/;

function hasRepeatedDigits(phone) {
  return /^(\d)\1{9}$/.test(phone);
}

function hasSequentialDigits(phone) {
  if (!/^\d{10}$/.test(phone)) return false;

  const digits = [...phone].map(Number);
  const isAscending = digits.every((digit, index) => (
    index === 0 || digit === (digits[index - 1] + 1) % 10
  ));
  const isDescending = digits.every((digit, index) => (
    index === 0 || digit === (digits[index - 1] + 9) % 10
  ));

  return isAscending || isDescending;
}

function isRegistrationPhoneValid(phone) {
  return typeof phone === 'string'
    && INDIAN_MOBILE_PATTERN.test(phone)
    && !hasRepeatedDigits(phone)
    && !hasSequentialDigits(phone);
}

module.exports = {
  INDIAN_MOBILE_PATTERN,
  hasRepeatedDigits,
  hasSequentialDigits,
  isRegistrationPhoneValid,
};
