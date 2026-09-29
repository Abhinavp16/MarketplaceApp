import 'package:flutter_test/flutter_test.dart';
import 'package:tradehub_demo/core/utils/phone_validation.dart';

void main() {
  group('PhoneValidation', () {
    test('accepts a valid Indian registration number', () {
      expect(PhoneValidation.isValidRegistrationPhone('9135724680'), isTrue);
      expect(PhoneValidation.registrationError('9135724680'), isNull);
    });

    test('rejects malformed Indian mobile numbers', () {
      for (final phone in [
        '5135724680',
        '913572468',
        '91357246801',
        '91357a4680',
        '91357 24680',
        '+919135724680',
      ]) {
        expect(PhoneValidation.isValidRegistrationPhone(phone), isFalse);
        expect(PhoneValidation.registrationError(phone), isNotNull);
      }
    });

    test('rejects repeated and sequential placeholder numbers', () {
      for (final phone in [
        '9999999999',
        '6666666666',
        '1234567890',
        '9876543210',
        '6789012345',
      ]) {
        expect(PhoneValidation.isValidRegistrationPhone(phone), isFalse);
        expect(PhoneValidation.registrationError(phone), isNotNull);
      }
    });
  });
}
