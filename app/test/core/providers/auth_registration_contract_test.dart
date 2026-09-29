import 'package:flutter_test/flutter_test.dart';
import 'package:tradehub_demo/core/providers/auth_provider.dart';

void main() {
  test(
    'customer phone registration preserves the legal acceptance contract',
    () {
      expect(phoneRegistrationEndpoint(false), '/auth/register-phone');
      expect(
        buildPhoneRegistrationPayload(
          name: 'Test Customer',
          phone: '9135724680',
          password: 'password123',
          isWholesaler: false,
          termsAccepted: true,
          privacyPolicyAccepted: true,
          termsVersion: '2026-08-17',
          privacyPolicyVersion: '2026-08-17',
        ),
        {
          'name': 'Test Customer',
          'phone': '9135724680',
          'password': 'password123',
          'termsAccepted': true,
          'privacyPolicyAccepted': true,
          'termsVersion': '2026-08-17',
          'privacyPolicyVersion': '2026-08-17',
        },
      );
    },
  );

  test(
    'wholesaler phone registration keeps its endpoint and business name',
    () {
      expect(
        phoneRegistrationEndpoint(true),
        '/auth/register-phone/wholesaler',
      );
      expect(
        buildPhoneRegistrationPayload(
          name: 'Test Wholesaler',
          phone: '8135724680',
          password: 'password123',
          isWholesaler: true,
          termsAccepted: true,
          privacyPolicyAccepted: true,
          termsVersion: '2026-08-17',
          privacyPolicyVersion: '2026-08-17',
          businessName: 'Test Traders',
        )['businessName'],
        'Test Traders',
      );
    },
  );
}
