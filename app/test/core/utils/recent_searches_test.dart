import 'package:flutter_test/flutter_test.dart';
import 'package:tradehub_demo/core/utils/recent_searches.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('adds to the front, de-duplicates and caps at five', () {
    var list = <String>[];
    for (final query in ['pump', 'केबल', 'pipe', 'PUMP', 'motor', 'tank', 'valve']) {
      list = addRecentSearch(list, query);
    }
    expect(list, ['valve', 'tank', 'motor', 'PUMP', 'pipe']);
  });

  test('a longer search replaces the partial one it extends', () {
    var list = addRecentSearch([], 'pum');
    list = addRecentSearch(list, 'pump');
    list = addRecentSearch(list, 'पंप');
    expect(list, ['पंप', 'pump']);
    expect(addRecentSearch(list, '   '), list);
  });

  test('saved searches survive a restart', () async {
    SharedPreferences.setMockInitialValues({});
    await RecentSearchStore.save(['पंप', 'pipe']);
    expect(await RecentSearchStore.load(), ['पंप', 'pipe']);
  });
}
