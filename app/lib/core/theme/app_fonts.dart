import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppFonts {
  // Set by the language provider. When Hindi is shown, text falls back to a
  // Devanagari font and tight (negative) letter spacing is removed, because it
  // squeezes Hindi vowel signs together.
  static bool hindi = false;

  static List<String> get _fallback => [
    GoogleFonts.notoSansDevanagari().fontFamily!,
  ];

  /// Letter spacing actually used (negative spacing is removed for Hindi).
  static double? spacingFor(double? letterSpacing) {
    if (!hindi || letterSpacing == null) return letterSpacing;
    return letterSpacing < 0 ? 0 : letterSpacing;
  }

  /// Font size actually used (at least 10 for Hindi).
  static double? sizeFor(double? fontSize) {
    if (!hindi || fontSize == null) return fontSize;
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
    return GoogleFonts.plusJakartaSans(
      textStyle: textStyle,
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
    ).copyWith(fontFamilyFallback: _fallback);
  }

  // Montserrat - Primary headings and titles
  static TextStyle montserrat({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.montserrat(
      decoration: decoration,
      fontSize: sizeFor(fontSize),
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: spacingFor(letterSpacing),
    ).copyWith(fontFamilyFallback: _fallback);
  }

  // Outfit - Body text and subtitles
  static TextStyle outfit({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.outfit(
      decoration: decoration,
      fontSize: sizeFor(fontSize),
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: spacingFor(letterSpacing),
    ).copyWith(fontFamilyFallback: _fallback);
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
