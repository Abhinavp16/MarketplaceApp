import 'package:flutter_test/flutter_test.dart';
import 'package:tradehub_demo/core/utils/order_pagination.dart';

void main() {
  test('prefers server total over page length', () {
    expect(
      resolveOrderTotal({
        'data': List.filled(20, <String, dynamic>{}),
        'pagination': {'total': 73, 'hasNext': true},
      }, 20),
      73,
    );
  });

  test('falls back to page length without pagination', () {
    expect(resolveOrderTotal({'data': []}, 0), 0);
    expect(
      resolveOrderTotal({'data': List.filled(5, <String, dynamic>{})}, 5),
      5,
    );
  });

  test('reads hasNext safely', () {
    expect(
      hasNextOrderPage({
        'pagination': {'hasNext': true},
      }),
      isTrue,
    );
    expect(
      hasNextOrderPage({
        'pagination': {'hasNext': false},
      }),
      isFalse,
    );
    expect(hasNextOrderPage({'data': []}), isFalse);
  });
}
