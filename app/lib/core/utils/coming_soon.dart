import 'package:intl/intl.dart';

/// Coming Soon products (set by the admin): listed with a badge but not for
/// sale yet. The server decides; these read its flags from a product map.
bool isComingSoonProduct(Map<dynamic, dynamic>? product) =>
    product?['comingSoon'] == true;

/// The admin hid the price ("Price coming soon"); price fields are 0/null.
bool isPriceHidden(Map<dynamic, dynamic>? product) =>
    isComingSoonProduct(product) && product?['priceHidden'] == true;

DateTime? expectedLaunchDate(Map<dynamic, dynamic>? product) {
  final raw = product?['expectedDate'];
  if (raw == null || raw.toString().isEmpty) return null;
  return DateTime.tryParse(raw.toString())?.toLocal();
}

/// "15 Oct" (or "15 Oct 2027" when not this year), in the app's language.
String? expectedLaunchText(
  Map<dynamic, dynamic>? product,
  String languageCode, {
  DateTime? now,
}) {
  final date = expectedLaunchDate(product);
  if (date == null) return null;
  final sameYear = date.year == (now ?? DateTime.now()).year;
  return DateFormat(sameYear ? 'd MMM' : 'd MMM y', languageCode).format(date);
}
