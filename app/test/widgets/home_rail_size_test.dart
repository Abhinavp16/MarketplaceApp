import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demomart_demo/l10n/l10n.dart';
import 'package:demomart_demo/screens/home/home_parts.dart';
import 'package:demomart_demo/widgets/ui/product_card.dart';
import 'package:demomart_demo/widgets/ui/quantity_stepper.dart';

// Home rails give every card a fixed height. These pump real cards at a
// 360 x 800 phone size, in English and Hindi and at a larger text size, and
// fail when anything overflows the card's height. (Widths depend on the real
// fonts, which tests don't load, so sideways overflow is checked on a device.)

const _cardWidth = 158.0;
const _tileWidth = 84.0;

/// Pumps [child] and returns every overflow along the card's height
/// ("... on the bottom"); all layout errors are collected, not just the first.
Future<List<String>> _pump(
  WidgetTester tester, {
  required Locale locale,
  required double textScale,
  required Widget child,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pump();
  FlutterError.onError = previous;
  return errors
      .where((e) => e.contains('overflowed') && e.contains('bottom'))
      .toList();
}

Widget _productCard(bool hindi, {bool pack = true}) => ProductCard(
  name: hindi ? '1.25 इंच रेनगन हरित प्रीमियम' : '1.25 INCH RAINGUN PREMIUM',
  brand: 'SAMPLE',
  price: 1970,
  mrp: 2170,
  unit: hindi ? '/पीस' : '/pc',
  packNote: pack ? (hindi ? 'पैकेट 8 पीस' : 'Packet 8 pcs') : null,
  packPrice: pack ? '₹15,760' : null,
  rating: 4.5,
  offLabel: (percent) => hindi ? '$percent% छूट' : '$percent% OFF',
  onTap: () {},
  action: QuantityStepper(
    quantity: 0,
    compact: true,
    expand: true,
    addLabel: hindi ? 'जोड़ें' : 'Add',
    onChanged: (_) {},
  ),
);

void main() {
  for (final hindi in [false, true]) {
    for (final textScale in [1.0, 1.3]) {
      final name = '${hindi ? 'Hindi' : 'English'} at ${textScale}x';

      testWidgets('product rail card with a pack line fits ($name)', (
        tester,
      ) async {
        final overflows = await _pump(
          tester,
          locale: Locale(hindi ? 'hi' : 'en'),
          textScale: textScale,
          child: SizedBox(
            width: _cardWidth,
            height: homeProductRailHeight(
              _cardWidth,
              textScale: textScale,
              hasPackNote: true,
            ),
            child: _productCard(hindi),
          ),
        );
        expect(overflows, isEmpty);
      });

      testWidgets('product rail card without a pack line fits ($name)', (
        tester,
      ) async {
        final overflows = await _pump(
          tester,
          locale: Locale(hindi ? 'hi' : 'en'),
          textScale: textScale,
          child: SizedBox(
            width: _cardWidth,
            height: homeProductRailHeight(
              _cardWidth,
              textScale: textScale,
              hasPackNote: false,
            ),
            child: _productCard(hindi, pack: false),
          ),
        );
        expect(overflows, isEmpty);
      });

      testWidgets('category tile with a two-line name fits ($name)', (
        tester,
      ) async {
        final overflows = await _pump(
          tester,
          locale: Locale(hindi ? 'hi' : 'en'),
          textScale: textScale,
          child: SizedBox(
            width: _tileWidth,
            height: homeCategoryRailHeight(
              _tileWidth,
              textScale: textScale,
              hindi: hindi,
            ),
            child: HomeCategoryTile(
              label: hindi ? 'इसकॉन GI पाइप 6 मीटर' : 'Iskcon GI Pipe 6 MTR',
              onTap: () {},
            ),
          ),
        );
        expect(overflows, isEmpty);
      });
    }
  }
}
