import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppFonts {
  // Set by the language provider. When Hindi is shown, text falls back to a
  // Devanagari font and tight (negative) letter spacing is removed, because it
  // squeezes Hindi vowel signs together.
  static bool hindi = false;

  static final List<String> _fallback = [
    GoogleFonts.notoSansDevanagari().fontFamily!,
  ];

  // Plus Jakarta Sans family name per weight/style. google_fonts resolves
  // (and starts loading) each one once; after that a style is a plain
  // TextStyle copy, which matters at hundreds of styles per rebuild.
  static final Map<(FontWeight, FontStyle), String> _jakartaFamilies = {};

  /// Letter spacing actually used (negative spacing is removed for Hindi).
  static double? spacingFor(double? letterSpacing) {
    if (!hindi || letterSpacing == null) return letterSpacing;
    return letterSpacing < 0 ? 0 : letterSpacing;
  }

  /// Font size actually used: never below 10, so no label becomes unreadable.
  static double? sizeFor(double? fontSize) {
    if (fontSize == null) return fontSize;
    return fontSize < 10 ? 10 : fontSize;
  }

  // Plus Jakarta Sans - the app's main font. Drop-in for
  // GoogleFonts.plusJakartaSans(...) that also renders Hindi well.
  static TextStyle jakarta({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    Color? decorationColor,
    double? decorationThickness,
    List<Shadow>? shadows,
  }) {
    final base = textStyle ?? const TextStyle();
    final weight = fontWeight ?? base.fontWeight ?? FontWeight.w400;
    final style = fontStyle ?? base.fontStyle ?? FontStyle.normal;
    final family = _jakartaFamilies.putIfAbsent(
      (weight, style),
      () => GoogleFonts.plusJakartaSans(
        fontWeight: weight,
        fontStyle: style,
      ).fontFamily!,
    );
    return base.copyWith(
      color: color,
      fontSize: sizeFor(fontSize),
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: spacingFor(letterSpacing),
      height: height,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationThickness: decorationThickness,
      shadows: shadows,
      fontFamily: family,
      fontFamilyFallback: _fallback,
    );
  }

  // Headings used to be Montserrat. The app now uses one family, so this
  // renders Plus Jakarta Sans; the name is kept for existing call sites.
  static TextStyle montserrat({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return jakarta(
      decoration: decoration,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Body text used to be Outfit; now Plus Jakarta Sans (see [montserrat]).
  static TextStyle outfit({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return jakarta(
      decoration: decoration,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Heading Styles
  static TextStyle h1({Color? color}) => montserrat(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: color,
    letterSpacing: -0.5,
  );

  static TextStyle h2({Color? color}) => montserrat(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: color,
    letterSpacing: -0.3,
  );

  static TextStyle h3({Color? color}) => montserrat(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: color,
  );

  static TextStyle h4({Color? color}) => montserrat(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: color,
  );

  // Body Styles
  static TextStyle bodyLarge({Color? color, FontWeight? fontWeight}) => outfit(
    fontSize: 17,
    fontWeight: fontWeight ?? FontWeight.w400,
    color: color,
    height: 1.5,
  );

  static TextStyle bodyMedium({Color? color, FontWeight? fontWeight}) => outfit(
    fontSize: 15,
    fontWeight: fontWeight ?? FontWeight.w400,
    color: color,
    height: 1.4,
  );

  static TextStyle bodySmall({Color? color, FontWeight? fontWeight}) => outfit(
    fontSize: 13,
    fontWeight: fontWeight ?? FontWeight.w400,
    color: color,
    height: 1.4,
  );

  // Label Styles
  static TextStyle labelLarge({Color? color}) => outfit(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: color,
    letterSpacing: 0.1,
  );

  static TextStyle labelMedium({Color? color}) => outfit(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: color,
    letterSpacing: 0.5,
  );

  static TextStyle labelSmall({Color? color}) => outfit(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: color,
    letterSpacing: 0.5,
  );

  // Button Text
  static TextStyle button({Color? color}) => montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: color,
    letterSpacing: 0.2,
  );

  // Caption
  static TextStyle caption({Color? color}) => outfit(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.3,
  );
}
