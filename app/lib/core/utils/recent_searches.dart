import 'package:shared_preferences/shared_preferences.dart';

/// Adds [query] to the front of the recent-search list: case-insensitive
/// de-duplication, drops shorter entries the new query extends ("pum" when
/// "pump" is searched), and keeps at most [max] items.
List<String> addRecentSearch(List<String> current, String query, {int max = 5}) {
  final value = query.trim();
  if (value.isEmpty) return List<String>.from(current);
  final lower = value.toLowerCase();
  final next = current.where((item) {
    final existing = item.toLowerCase();
    return existing != lower && !lower.startsWith(existing);
  }).toList();
  next.insert(0, value);
  return next.length > max ? next.sublist(0, max) : next;
}

/// Recent searches saved on the device so they survive an app restart.
class RecentSearchStore {
  static const _key = 'recent_searches';

  static Future<List<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(List<String> searches) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, searches);
    } catch (_) {}
  }
}
