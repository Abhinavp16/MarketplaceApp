import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:demomart_demo/core/providers/cart_provider.dart';
import 'package:demomart_demo/core/utils/packing.dart';
import 'package:demomart_demo/l10n/l10n.dart';
import 'package:demomart_demo/l10n/pack_text.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final hi = lookupAppLocalizations(const Locale('hi'));

  test('reads pieces per packet and meters per coil/bundle', () {
    expect(packingPieceCount('15'), 15);
    expect(packingPieceCount(' 15 pcs '), 15);
    expect(packingPieceCount('10 Pieces'), 10);
    expect(packingPieceCount('12 nos.'), 12);
    expect(packingPieceCount('Box of 10'), isNull);
    expect(packingPieceCount(null), isNull);
    expect(packingMeterLength('500 m'), 500);
    expect(packingMeterLength('500mtr'), 500);
    expect(packingMeterLength('300 Meters'), 300);
    expect(packingMeterLength('500'), isNull);
    expect(packingMeterLength('500 mors'), isNull);
  });

  test('recognises packet and meter units', () {
    expect(isPacketUnit('Packet'), isTrue);
    expect(isPacketUnit('pack'), isTrue);
    expect(isPacketUnit('Meter'), isFalse);
    expect(isMeterUnit('Mtr'), isTrue);
    expect(isMeterUnit('meters'), isTrue);
    expect(isMeterUnit('Piece'), isFalse);
  });

  // Same cases as backend/tests/packSize.test.js.
  test('pack info: packets per piece, coils and bundles per meter', () {
    PackInfo info(String unit, String packing) => packInfoFor(unit, packing);
    expect(info('Packet', '15').size, 15);
    expect(info('Packet', '15').contentUnit, ContentUnit.piece);
    expect(info('packet', '15 pcs').size, 15);
    expect(info('Coil', '500 m').packUnit, PackUnit.coil);
    expect(info('Coil', '500 m').contentUnit, ContentUnit.meter);
    expect(info('Coil', '500').size, 500);
    expect(info('Bundle', '300 m').size, 300);
    expect(info('Bundle', '300 m').packUnit, PackUnit.bundle);
    expect(info('Bundle', '500mtr').size, 500);
    // Not packs (priced per unit as before).
    expect(info('Bundle', '5').isPack, isFalse);
    expect(info('Bundle', '3 bundles').isPack, isFalse);
    expect(info('Packet', '25 pcs/bag; 150 pcs/box').isPack, isFalse);
    expect(info('Packet', '1').isPack, isFalse);
    expect(info('Piece', '20').isPack, isFalse);
    expect(info('Mtr', '500').isPack, isFalse);
  });

  test('pack size and minimums from API product maps', () {
    final pipe = {
      'priceUnit': 'Packet',
      'packing': '15',
      'minWholesaleQuantity': 1,
    };
    final cable = {
      'priceUnit': 'Bundle',
      'packing': '500 m',
      'minWholesaleQuantity': 2,
      'minCustomerQuantity': 10,
    };
    expect(packSizeOf(pipe), 15);
    expect(packSizeOf({...pipe, 'packSize': 12}), 12);
    expect(packSizeOf(null), 1);
    expect(wholesaleMinimumOf(pipe), 15);
    expect(wholesaleMinimumOf(cable), 1000);
    expect(
      wholesaleMinimumOf({'priceUnit': 'Piece', 'minWholesaleQuantity': 8}),
      8,
    );
    expect(customerMinimumOf(cable), 10);
    expect(customerMinimumOf(pipe), 1);
    expect(isMeterProduct(cable), isTrue);
    expect(isMeterProduct({'priceUnit': 'Mtr'}), isTrue);
    expect(isMeterProduct(pipe), isFalse);
  });

  test('cart item: packs for wholesalers, pieces/meters for customers', () {
    final pipe = CartItem(
      productId: 'p',
      cartItemKey: 'p:default',
      name: 'Column Pipe',
      price: 720,
      quantity: 30,
      priceUnit: 'Packet',
      packing: '15',
    );
    expect(pipe.total, 21600);
    expect(pipe.displayQuantity(true), 2);
    expect(pipe.quantityStep(true), 15);
    expect(pipe.minimumQuantity(true), 15);
    expect(pipe.badgeCount(true), 2);
    expect(pipe.displayQuantity(false), 30);
    expect(pipe.quantityStep(false), 1);
    expect(pipe.badgeCount(false), 30);

    final cable = CartItem(
      productId: 'c',
      cartItemKey: 'c:default',
      name: 'Service wire',
      price: 75,
      quantity: 1000,
      minCustomerQuantity: 10,
      priceUnit: 'Coil',
      packing: '500 m',
    );
    expect(cable.total, 75000);
    expect(cable.displayQuantity(true), 2);
    expect(cable.minimumQuantity(true), 500);
    expect(cable.minimumQuantity(false), 10);
    expect(cable.isMeter, isTrue);
    expect(cable.badgeCount(true), 2);
    expect(cable.badgeCount(false), 1); // a cut length counts once
    expect(cable.copyWith(quantity: 1500).packSize, 500);
  });

  test('pack texts in English and Hindi', () {
    const coil = PackInfo(500, PackUnit.coil, ContentUnit.meter);
    const bundle = PackInfo(300, PackUnit.bundle, ContentUnit.meter);
    const packet = PackInfo(15, PackUnit.packet, ContentUnit.piece);
    expect(packPriceText(en, coil, 75), '1 Coil (500 m) = ₹37,500');
    expect(packPriceText(hi, coil, 75), '1 कॉइल (500 मी) = ₹37,500');
    expect(packPriceText(en, packet, 720), '1 Packet (15 pieces) = ₹10,800');
    expect(packPriceText(hi, packet, 720), '1 पैकेट (15 पीस) = ₹10,800');
    expect(packQuantityText(en, bundle, 900), '3 Bundles (900 m)');
    expect(packQuantityText(hi, bundle, 900), '3 बंडल (900 मी)');
    expect(packQuantityText(en, coil, 1000), '2 Coils (1,000 m)');
    expect(contentsText(en, ContentUnit.meter, 50), '50 m');
    expect(contentsText(en, ContentUnit.piece, 1), '1 piece');
    expect(contentUnitLabel(hi, ContentUnit.meter), 'मीटर');
    expect(packUnitLabel(en, PackUnit.bundle), 'Bundle');
    expect(en.productMinOrderQuantity('10 m'), 'Minimum order: 10 m');
    expect(hi.productMinOrderQuantity('10 मी'), 'न्यूनतम ऑर्डर: 10 मी');
    expect(en.productPacketContainsPieces(15), '1 Packet contains 15 pieces');
    expect(
      en.apiErrorPackQuantity,
      'This product is sold in whole packets, coils or bundles only.',
    );
  });
}
