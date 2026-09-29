class PhoneValidation {
  static final RegExp _indianMobilePattern = RegExp(r'^[6-9]\d{9}$');
  static final RegExp _repeatedDigitsPattern = RegExp(r'^(\d)\1{9}$');

  static bool isValidRegistrationPhone(String phone) {
    return _indianMobilePattern.hasMatch(phone) &&
        !_repeatedDigitsPattern.hasMatch(phone) &&
        !_hasSequentialDigits(phone);
  }

  static String? registrationError(String phone) {
    if (!_indianMobilePattern.hasMatch(phone)) {
      return 'Enter a valid 10-digit Indian mobile number starting with 6, 7, 8, or 9.';
    }

    if (_repeatedDigitsPattern.hasMatch(phone) || _hasSequentialDigits(phone)) {
      return 'Enter a real mobile number, not a repeated or sequential number.';
    }

    return null;
  }

  static bool _hasSequentialDigits(String phone) {
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) return false;

    final digits = phone.codeUnits.map((codeUnit) => codeUnit - 48).toList();
    final isAscending = List.generate(digits.length - 1, (index) => index).every(
      (index) => digits[index + 1] == (digits[index] + 1) % 10,
    );
    final isDescending = List.generate(digits.length - 1, (index) => index).every(
      (index) => digits[index + 1] == (digits[index] + 9) % 10,
    );

    return isAscending || isDescending;
  }
}
