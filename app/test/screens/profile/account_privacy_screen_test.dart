import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demomart_demo/core/providers/auth_provider.dart';
import 'package:demomart_demo/core/services/api_client.dart';
import 'package:demomart_demo/l10n/l10n.dart';
import 'package:demomart_demo/screens/profile/account_privacy_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Returns a fixed deletion request instead of calling the API.
class _FakeAuth extends AuthNotifier {
  _FakeAuth(this.request) : super(ApiClient());

  final Map<String, dynamic>? request;

  @override
  Future<Map<String, dynamic>?> getAccountDeletionRequest() async => request;
}

Future<void> _pump(
  WidgetTester tester,
  Map<String, dynamic>? request, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authProvider.overrideWith((ref) => _FakeAuth(request))],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AccountPrivacyScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets(
    'a declined request shows the reason and lets the user ask again',
    (tester) async {
      await _pump(tester, {
        'status': 'rejected',
        'staffNote': 'An order is still being delivered',
        'dueAt': '2026-11-10T00:00:00.000Z',
      });

      expect(
        find.text('Your last deletion request was declined'),
        findsOneWidget,
      );
      expect(
        find.text('Reason from DemoMart: An order is still being delivered'),
        findsOneWidget,
      );
      expect(find.text('Request account deletion'), findsWidgets);
      expect(find.text('Cancel pending request'), findsNothing);
    },
  );

  testWidgets('a declined request without a note still explains what to do', (
    tester,
  ) async {
    await _pump(tester, {'status': 'rejected', 'staffNote': null});

    expect(
      find.text('Your last deletion request was declined'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Contact us if you have any questions. You can send a new request below.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('declined notice in Hindi', (tester) async {
    await _pump(tester, {
      'status': 'rejected',
      'staffNote': 'ऑर्डर अभी डिलीवर हो रहा है',
    }, locale: const Locale('hi'));

    expect(
      find.text('आपका पिछला खाता हटाने का अनुरोध अस्वीकार कर दिया गया'),
      findsOneWidget,
    );
    expect(
      find.text('डेमोमार्ट की ओर से कारण: ऑर्डर अभी डिलीवर हो रहा है'),
      findsOneWidget,
    );
  });

  testWidgets('a pending request is unchanged', (tester) async {
    await _pump(tester, {
      'status': 'pending',
      'dueAt': '2026-11-10T00:00:00.000Z',
    });
    expect(find.text('Request received'), findsOneWidget);
    expect(find.text('Cancel pending request'), findsOneWidget);
    expect(find.text('Your last deletion request was declined'), findsNothing);
  });

  testWidgets('a cancelled request just offers a new one', (tester) async {
    await _pump(tester, {'status': 'cancelled'});
    expect(find.text('Your last deletion request was declined'), findsNothing);
    expect(find.text('Request account deletion'), findsWidgets);
  });
}
