import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

extension L10nContext on BuildContext {
  /// App text in the current language: `context.l10n.cartTitle`.
  AppLocalizations get l10n => AppLocalizations.of(this);

  bool get isHindi => Localizations.localeOf(this).languageCode == 'hi';
}

const _devanagariDigits = '०१२३४५६७८९';

/// Numbers are always shown as 1, 2, 3. Some stored Hindi names contain
/// Hindi digits (१, २, ३) from an older converter; show them as Latin digits.
String latinDigits(String text) => text.replaceAllMapped(
  RegExp('[०-९]'),
  (match) => '${_devanagariDigits.indexOf(match.group(0)!)}',
);

/// Product/category name for the current language: the Hindi name when Hindi
/// is selected and one exists, otherwise the English name.
String localizedName(
  BuildContext context,
  Map<dynamic, dynamic>? item, {
  String englishKey = 'name',
  String hindiKey = 'nameHindi',
  String fallback = '',
}) {
  if (item == null) return fallback;
  final english = (item[englishKey] ?? '').toString().trim();
  if (context.isHindi) {
    final hindi = (item[hindiKey] ?? '').toString().trim();
    if (hindi.isNotEmpty) return latinDigits(hindi);
  }
  return english.isNotEmpty ? english : fallback;
}

/// Same as [localizedName] for two plain strings.
String pickLocalizedName(BuildContext context, String? english, String? hindi) {
  final hindiText = (hindi ?? '').trim();
  if (context.isHindi && hindiText.isNotEmpty) return latinDigits(hindiText);
  return (english ?? '').trim();
}
