import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradehub_demo/core/config/legal_acceptance_config.dart';
import 'package:tradehub_demo/screens/profile/legal_policy_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registration legal policy assets are bundled and non-empty', () async {
    for (final policyId in ['terms-conditions', 'privacy-policy']) {
      final policy = LegalPolicyCatalog.byId(policyId);
      expect(policy, isNotNull);
      final content = await rootBundle.loadString(policy!.assetPath);
      expect(content.trim(), isNotEmpty);
    }
  });

  test('privacy policy content matches the recorded policy version', () async {
    expect(LegalAcceptanceConfig.privacyPolicyVersion, '2026-08-17');
    final policy = LegalPolicyCatalog.byId('privacy-policy')!;
    final content = await rootBundle.loadString(policy.assetPath);
    expect(content, contains('Effective date: 17 August 2026'));
  });
}
