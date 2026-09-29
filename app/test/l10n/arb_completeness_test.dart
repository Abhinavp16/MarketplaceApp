import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Every English text must have a Hindi version with the same placeholders,
// and Hindi text must use Latin digits (1, 2, 3), never Hindi digits.
Map<String, dynamic> _load(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync()) as Map<String, dynamic>;

Set<String> _placeholders(String text) {
  const icuWords = {'plural', 'select', 'other', 'zero', 'one', 'two', 'few', 'many'};
  return RegExp(r'\{([A-Za-z_]\w*)\s*[},]')
      .allMatches(text)
      .map((match) => match.group(1)!)
      .where((word) => !icuWords.contains(word) && int.tryParse(word) == null)
      .toSet();
}

void main() {
  final english = _load('app_en.arb');
  final hindi = _load('app_hi.arb');
  final keys = english.keys.where((key) => !key.startsWith('@')).toList();

  test('every English key has a Hindi translation', () {
    final missing = keys.where((key) => (hindi[key] ?? '').toString().trim().isEmpty).toList();
    expect(missing, isEmpty, reason: 'Missing Hindi for: ${missing.join(', ')}');
  });

  test('no Hindi keys without English', () {
    final extra = hindi.keys.where((key) => !key.startsWith('@') && !english.containsKey(key)).toList();
    expect(extra, isEmpty, reason: 'Hindi-only keys: ${extra.join(', ')}');
  });

  test('placeholders match between English and Hindi', () {
    final mismatched = keys
        .where((key) => hindi[key] != null)
        .where((key) => !_setEquals(_placeholders('${english[key]}'), _placeholders('${hindi[key]}')))
        .toList();
    expect(mismatched, isEmpty, reason: 'Placeholder mismatch: ${mismatched.join(', ')}');
  });

  test('Hindi text uses Latin digits only', () {
    final withHindiDigits = keys.where((key) => RegExp('[०-९]').hasMatch('${hindi[key] ?? ''}')).toList();
    expect(withHindiDigits, isEmpty, reason: 'Hindi digits in: ${withHindiDigits.join(', ')}');
  });

  test('Hindi file is mostly Devanagari (not untranslated English)', () {
    final untranslated = keys.where((key) {
      final en = '${english[key]}';
      final hi = '${hindi[key] ?? ''}';
      return en == hi && RegExp(r'[A-Za-z]{4,}').hasMatch(en) && !RegExp(r'^[A-Z0-9 .,:/₹%+\-{}()]+$').hasMatch(en);
    }).toList();
    // A few may legitimately stay identical (brand names, "OK"-like codes).
    expect(untranslated.length, lessThan(keys.length ~/ 20 + 5), reason: 'Possibly untranslated: ${untranslated.join(', ')}');
  });
}

bool _setEquals(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);
