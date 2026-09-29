import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradehub_demo/core/providers/locale_provider.dart';
import 'package:tradehub_demo/core/theme/app_fonts.dart';
import 'package:tradehub_demo/core/utils/number_formatter.dart';
import 'package:tradehub_demo/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('language defaults to English and is remembered after a restart', () async {
    expect(await LocaleNotifier.hasSavedChoice(), isFalse);
    expect(await LocaleNotifier.loadSaved(), const Locale('en'));

    final notifier = LocaleNotifier();
    await notifier.setLocale(LocaleNotifier.hindi);
    expect(notifier.isHindi, isTrue);
    expect(AppFonts.hindi, isTrue);

    // "Restart": a new notifier reads the saved choice.
    expect(await LocaleNotifier.hasSavedChoice(), isTrue);
    final restored = LocaleNotifier(await LocaleNotifier.loadSaved());
    expect(restored.state, const Locale('hi'));

    await restored.toggle();
    expect(restored.state, const Locale('en'));
    expect(AppFonts.hindi, isFalse);
  });

  test('Hindi text keeps Latin digits for prices and counts', () {
    final hindi = lookupAppLocalizations(const Locale('hi'));
    final price = hindi.commonPricePerUnit(NumberFormatter.formatPrice(125000));
    expect(price, contains('1,25,000'));
    expect(RegExp('[०-९]').hasMatch(price), isFalse);
    expect(hindi.commonItemsCount(3), '3 आइटम');
    expect(lookupAppLocalizations(const Locale('en')).commonItemsCount(1), '1 item');
  });

  test('Hindi removes negative letter spacing and tiny text sizes', () {
    AppFonts.hindi = true;
    expect(AppFonts.spacingFor(-0.7), 0);
    expect(AppFonts.spacingFor(0.5), 0.5);
    expect(AppFonts.sizeFor(8), 10);
    expect(AppFonts.sizeFor(14), 14);
    AppFonts.hindi = false;
    expect(AppFonts.spacingFor(-0.7), -0.7);
    expect(AppFonts.sizeFor(8), 8);
  });

  test('stored Hindi names are shown with Latin digits', () {
    expect(latinDigits('४ कोर प्रीमियम १२mm'), '4 कोर प्रीमियम 12mm');
    expect(latinDigits('सबमर्सिबल पंप'), 'सबमर्सिबल पंप');
  });
}
