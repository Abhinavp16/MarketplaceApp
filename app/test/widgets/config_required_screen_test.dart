import 'package:flutter_test/flutter_test.dart';
import 'package:tradehub_demo/core/config/api_config.dart';
import 'package:tradehub_demo/core/config/brand_config.dart';
import 'package:tradehub_demo/widgets/config_required_screen.dart';

void main() {
  test('API base URL has no built-in fallback', () {
    // Tests run without --dart-define=API_BASE_URL.
    expect(ApiConfig.isConfigured, isFalse);
    expect(ApiConfig.baseUrl, isEmpty);
  });

  testWidgets('config required screen explains how to configure the app', (
    tester,
  ) async {
    await tester.pumpWidget(const ConfigRequiredApp());
    expect(find.textContaining('Configuration required'), findsOneWidget);
    expect(find.textContaining('API_BASE_URL'), findsWidgets);
  });

  test('brand constants are the generic demo values', () {
    expect(BrandConfig.name, 'TradeHub Demo');
    expect(BrandConfig.supportEmail, 'demo@tradehub.example');
    expect(BrandConfig.packageName, 'com.demo.tradehub');
  });
}
