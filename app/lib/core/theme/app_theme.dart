import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;
import 'package:google_fonts/google_fonts.dart';
import 'app_fonts.dart';

/// Brand palette: teal for actions, blue only for information, marigold only
/// for savings and offers. Neutrals lean slightly teal so white cards sit
/// calmly on the page ground.
class AppColors {
  // Brand
  static const Color primary = Color(0xFF0F766E); // teal
  static const Color primaryDark = Color(0xFF115E59); // pressed / emphasis
  static const Color primaryDeep = Color(0xFF134E4A); // text on soft teal
  static const Color primarySoft = Color(0xFFDDF3EF); // tinted fills
  static const Color primaryTint = Color(0xFFF0FAF8); // faint washes
  static const Color primaryGlow = Color(0xFF5EEAD4); // light teal on dark teal
  static const Color secondary = Color(0xFF1560A8); // water: links, info
  static const Color secondarySoft = Color(0xFFE6EEF8);
  static const Color accent = Color(0xFFD9730D); // marigold: savings, offers
  static const Color accentSoft = Color(0xFFFCEFDF);

  // Backgrounds
  static const Color backgroundLight = Color(0xFFF3F8F7); // page ground
  static const Color backgroundDark = Color(0xFF0B1514);
  static const Color surfaceMuted = Color(0xFFEBF3F1); // inset panels

  // Surface colors
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF12211F);

  // Text colors
  static const Color textPrimary = Color(0xFF0F2422);
  static const Color textSecondary = Color(0xFF44595A);
  static const Color textTertiary = Color(0xFF68797A);
  static const Color textDisabled = Color(0xFFA0B0AF);

  // Status colors (separate from the brand accent)
  static const Color success = Color(0xFF1F8A3B);
  static const Color successSoft = Color(0xFFE5F2E7);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSoft = Color(0xFFFDF1DE);
  static const Color error = Color(0xFFC62828);
  static const Color errorSoft = Color(0xFFFDECEA);
  static const Color info = Color(0xFF1560A8);
  static const Color infoSoft = Color(0xFFE6EEF8);

  // Border colors
  static const Color border = Color(0xFFDAE6E3);
  static const Color borderStrong = Color(0xFFC0D1CD);
  static const Color borderDark = Color(0xFF24393A);

  // Gray scale (teal-biased)
  static const Color gray50 = Color(0xFFF6FAF9);
  static const Color gray100 = Color(0xFFEBF3F1);
  static const Color gray200 = Color(0xFFDAE6E3);
  static const Color gray300 = Color(0xFFC0D1CD);
  static const Color gray400 = Color(0xFF97ABAA);
  static const Color gray500 = Color(0xFF68797A);
  static const Color gray600 = Color(0xFF44595A);
  static const Color gray700 = Color(0xFF304445);
  static const Color gray800 = Color(0xFF1F3132);
  static const Color gray900 = Color(0xFF0F2422);

  // Rating stars.
  static const Color star = Color(0xFFE8A317);
}

/// Corner radii. Use these instead of literal values.
class AppRadius {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
}

/// Spacing on a 4/8 grid.
class AppSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  /// Side gutter for page content.
  static const double gutter = 16;
}

/// Squircle (continuous-corner) shapes for buttons and button-like controls.
/// Cards, fields, sheets and dialogs keep plain rounded corners.
class AppShapes {
  static RoundedSuperellipseBorder squircle(
    double radius, {
    BorderSide side = BorderSide.none,
  }) => RoundedSuperellipseBorder(
    borderRadius: BorderRadius.circular(radius),
    side: side,
  );
}

/// Soft, low shadows. Cards mostly rely on a hairline border instead.
class AppShadows {
  static List<BoxShadow> get card => [
    BoxShadow(
      color: const Color(0xFF0F2422).withValues(alpha: 0.05),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get raised => [
    BoxShadow(
      color: const Color(0xFF0F2422).withValues(alpha: 0.10),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// Shadow for bars that float above content (bottom nav, cart bar).
  static List<BoxShadow> get bar => [
    BoxShadow(
      color: const Color(0xFF0F2422).withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, -4),
    ),
  ];
}

/// Motion tokens. Keep animation short and quiet; honour "reduce motion".
/// A curve that follows an underdamped spring starting at rest, so motion
/// eases off the mark, overshoots slightly and settles. The spring's first
/// [settle] seconds are mapped onto the curve.
class SpringCurve extends Curve {
  const SpringCurve({
    this.stiffness = 180,
    this.dampingRatio = 0.6,
    this.settle = 0.6,
  });

  final double stiffness;
  final double dampingRatio;
  final double settle;

  @override
  double transformInternal(double t) => SpringSimulation(
    SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: stiffness,
      ratio: dampingRatio,
    ),
    0,
    1,
    0,
  ).x(t * settle);
}

class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration page = Duration(milliseconds: 300);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutQuart;
  static const Curve exit = Curves.easeInCubic;

  /// A light spring from rest: eases off the mark, overshoots a little and
  /// settles. Pair it with [springDuration].
  static const Curve spring = SpringCurve();
  static const Duration springDuration = Duration(milliseconds: 600);

  /// True when the user asked the OS to reduce motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], or zero when motion is reduced.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}

/// Text helpers that the theme's text styles don't cover.
class AppText {
  /// Prices and other aligned numbers: tabular figures.
  static TextStyle price({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w800,
    Color color = AppColors.textPrimary,
  }) => AppFonts.jakarta(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: -0.2,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Struck-through MRP next to a price.
  static TextStyle mrp({double fontSize = 12}) => AppFonts.jakarta(
    fontSize: fontSize,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
    decoration: TextDecoration.lineThrough,
    decorationColor: AppColors.textTertiary,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  /// Small uppercase eyebrow / section label.
  static TextStyle eyebrow({Color color = AppColors.textTertiary}) =>
      AppFonts.jakarta(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.8,
      );
}

/// Fade with a short upward drift, used for pushed pages on Android and web.
/// iOS keeps its native slide so swipe-back still works.
class _FadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.standard,
      reverseCurve: AppMotion.exit,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class AppTheme {
  static ThemeData get lightTheme {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primaryDeep,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondarySoft,
      onSecondaryContainer: Color(0xFF0B3A66),
      tertiary: AppColors.accent,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.accentSoft,
      onTertiaryContainer: Color(0xFF6B3606),
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorSoft,
      onErrorContainer: Color(0xFF7A1414),
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.surfaceLight,
      surfaceContainerLow: AppColors.gray50,
      surfaceContainer: AppColors.backgroundLight,
      surfaceContainerHigh: AppColors.gray100,
      surfaceContainerHighest: AppColors.gray200,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
      shadow: Color(0xFF0F2422),
      inverseSurface: AppColors.textPrimary,
      onInverseSurface: Colors.white,
      inversePrimary: Color(0xFF5EEAD4),
      surfaceTint: Colors.transparent,
    );

    final buttonShape = AppShapes.squircle(AppRadius.md);
    final buttonText = AppFonts.jakarta(
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      canvasColor: AppColors.backgroundLight,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeThroughPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _FadeThroughPageTransitionsBuilder(),
          TargetPlatform.windows: _FadeThroughPageTransitionsBuilder(),
          TargetPlatform.linux: _FadeThroughPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
        displayLarge: AppFonts.jakarta(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.6,
        ),
        displayMedium: AppFonts.jakarta(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        displaySmall: AppFonts.jakarta(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.4,
        ),
        headlineLarge: AppFonts.jakarta(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
        headlineMedium: AppFonts.jakarta(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
        headlineSmall: AppFonts.jakarta(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleLarge: AppFonts.jakarta(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleMedium: AppFonts.jakarta(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleSmall: AppFonts.jakarta(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: AppFonts.jakarta(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          height: 1.45,
        ),
        bodyMedium: AppFonts.jakarta(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.45,
        ),
        bodySmall: AppFonts.jakarta(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
        labelLarge: AppFonts.jakarta(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        labelMedium: AppFonts.jakarta(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        labelSmall: AppFonts.jakarta(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        titleTextStyle: AppFonts.jakarta(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.gray200,
          disabledForegroundColor: AppColors.textDisabled,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.gray200,
          disabledForegroundColor: AppColors.textDisabled,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderStrong),
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, 44),
          shape: buttonShape,
          textStyle: AppFonts.jakarta(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(44, 44),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
        hintStyle: AppFonts.jakarta(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textTertiary,
        ),
        labelStyle: AppFonts.jakarta(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        floatingLabelStyle: AppFonts.jakarta(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        prefixIconColor: AppColors.textTertiary,
        suffixIconColor: AppColors.textTertiary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedColor: AppColors.primarySoft,
        disabledColor: AppColors.gray100,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelStyle: AppFonts.jakarta(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        secondaryLabelStyle: AppFonts.jakarta(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDeep,
        ),
        checkmarkColor: AppColors.primaryDeep,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surfaceLight,
        showDragHandle: false,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: AppFonts.jakarta(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: AppFonts.jakarta(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.45,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        contentTextStyle: AppFonts.jakarta(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        actionTextColor: AppColors.primaryGlow,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primarySoft,
        circularTrackColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        titleTextStyle: AppFonts.jakarta(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        subtitleTextStyle: AppFonts.jakarta(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        dividerColor: AppColors.border,
        labelStyle: AppFonts.jakarta(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: AppFonts.jakarta(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
        side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.borderStrong,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.gray400,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.gray100,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
        textStyle: AppFonts.jakarta(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: AppFonts.jakarta(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: AppFonts.jakarta(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: AppFonts.jakarta(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
