import 'package:flutter_test/flutter_test.dart';
import 'package:tradehub_demo/core/utils/product_search.dart';

void main() {
  test('ID filters are active and serialize without display names', () {
    const criteria = ProductSearchCriteria(
      query: '  pump  ',
      categoryId: 'category-id',
      brandId: 'brand-id',
    );

    expect(criteria.isActive, isTrue);
    expect(criteria.toQueryParameters(page: 2, limit: 20), {
      'page': 2,
      'limit': 20,
      'q': 'pump',
      'categoryId': 'category-id',
      'brandId': 'brand-id',
    });
  });

  test('Hindi query keeps Devanagari words and sends Latin digits', () {
    expect(normalizeSearchQuery('  १० मिमी   केबल '), '10 मिमी केबल');
    expect(
      const ProductSearchCriteria(query: '२ इंच पाइप')
          .toQueryParameters(page: 1, limit: 20)['q'],
      '2 इंच पाइप',
    );
    expect(
      const ProductSearchCriteria(query: '१० मिमी'),
      const ProductSearchCriteria(query: '10 मिमी'),
    );
  });

  test('filter-only criteria stays active', () {
    expect(
      const ProductSearchCriteria(categoryId: 'category-id').isActive,
      isTrue,
    );
    expect(const ProductSearchCriteria().isActive, isFalse);
  });

  test('search page parses pagination safely', () {
    final page = ProductSearchPage.fromJson({
      'data': [
        {'id': 'one'},
      ],
      'pagination': {'page': 3, 'hasNext': true},
    });
    expect(page.page, 3);
    expect(page.hasNext, isTrue);
    expect(page.items.length, 1);
  });

  test('additional pages replace duplicate product IDs', () {
    final merged = mergeSearchItems(
      [
        {'id': 'one', 'name': 'Old'},
      ],
      [
        {'id': 'one', 'name': 'Updated'},
        {'id': 'two', 'name': 'Second'},
      ],
    );
    expect(merged.length, 2);
    expect(merged.first['name'], 'Updated');
  });
}
