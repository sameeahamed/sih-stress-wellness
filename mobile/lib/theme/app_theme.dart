/// Single source of truth for the app's visual language.
///
/// One Material 3 theme, one spacing/radius scale, and one LOW / MEDIUM /
/// HIGH risk colour system. Every screen reads its colours and type from
/// here so the UI stays consistent and professional.
///
/// Purely presentational: nothing in this file touches the API, the
/// authentication flow, or the ML pipeline.
library;

import 'package:flutter/material.dart';

import '../core/models.dart';

/// Product identity. Deliberately neutral — this is a prototype and must not
/// imply official government ownership, so no crest or official insignia is
/// used anywhere.
abstract final class AppIdentity {
  static const String productName = 'Personnel Stress & Welfare';
  static const String organisation = 'Smart India Hackathon 2026';
  static const String tagline = 'Prototype · synthetic demo data';
}

/// Spacing scale. Use these instead of ad-hoc numbers so rhythm is uniform.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double huge = 32;

  /// Horizontal page gutter.
  static const double gutter = 16;
}

/// Corner-radius scale.
abstract final class AppRadii {
  static const BorderRadius chip = BorderRadius.all(Radius.circular(8));
  static const BorderRadius field = BorderRadius.all(Radius.circular(12));
  static const BorderRadius card = BorderRadius.all(Radius.circular(16));
  static const BorderRadius hero = BorderRadius.all(Radius.circular(20));
}

/// Neutral / brand tokens.
abstract final class AppColors {
  /// Brand accent. Matches the officer dashboard accent so the two clients
  /// read as one product.
  static const Color brand = Color(0xFF1D4ED8);
  static const Color brandDark = Color(0xFF1E40AF);
  static const Color brandSoft = Color(0xFFEEF2FF);

  static const Color canvas = Color(0xFFF5F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF8F9FC);
  static const Color border = Color(0xFFE2E5EC);
  static const Color borderStrong = Color(0xFFCBD3E1);

  static const Color textPrimary = Color(0xFF1C2130);
  static const Color textMuted = Color(0xFF5B6478);

  /// Non-risk status colours (success, warning, danger, info). Risk levels use
  /// [AppRisk] instead, so a risk colour always means a risk level.
  static const Color success = Color(0xFF15803D);
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color successBorder = Color(0xFF86EFAC);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color warningBorder = Color(0xFFFDE68A);
  static const Color danger = Color(0xFFB91C1C);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color dangerBorder = Color(0xFFFCA5A5);
  static const Color info = Color(0xFF1E40AF);
  static const Color infoSoft = Color(0xFFDBEAFE);
  static const Color infoBorder = Color(0xFFBFDBFE);
}

/// The complete colour treatment for one risk level.
class RiskTone {
  const RiskTone({
    required this.strong,
    required this.soft,
    required this.border,
    required this.icon,
    required this.onSoft,
  });

  /// Saturated colour used for text, bars and fills.
  final Color strong;

  /// Tinted background for chips and panels.
  final Color soft;

  /// Hairline border for chips and panels.
  final Color border;

  /// Icon paired with the colour so risk is never encoded by colour alone.
  final IconData icon;

  /// Text colour that is readable on [soft].
  final Color onSoft;
}

/// The LOW / MEDIUM / HIGH risk colour system.
abstract final class AppRisk {
  static const RiskTone low = RiskTone(
    strong: Color(0xFF15803D),
    soft: Color(0xFFDCFCE7),
    border: Color(0xFF86EFAC),
    icon: Icons.check_circle_outline,
    onSoft: Color(0xFF14532D),
  );

  static const RiskTone medium = RiskTone(
    strong: Color(0xFFD97706),
    soft: Color(0xFFFEF3C7),
    border: Color(0xFFFDE68A),
    icon: Icons.error_outline,
    onSoft: Color(0xFF78350F),
  );

  static const RiskTone high = RiskTone(
    strong: Color(0xFFDC2626),
    soft: Color(0xFFFEE2E2),
    border: Color(0xFFFCA5A5),
    icon: Icons.warning_amber_rounded,
    onSoft: Color(0xFF7F1D1D),
  );

  static RiskTone of(RiskLevel level) => switch (level) {
    RiskLevel.low => low,
    RiskLevel.medium => medium,
    RiskLevel.high => high,
  };

  /// The model's own confidence for [level], in 0..1.
  static double probabilityOf(Prediction prediction, RiskLevel level) =>
      switch (level) {
        RiskLevel.low => prediction.probabilityLow,
        RiskLevel.medium => prediction.probabilityMedium,
        RiskLevel.high => prediction.probabilityHigh,
      };

  static const List<RiskLevel> scale = <RiskLevel>[
    RiskLevel.low,
    RiskLevel.medium,
    RiskLevel.high,
  ];
}

/// The app theme.
abstract final class AppTheme {
  static ThemeData get light => _build();

  static ThemeData _build() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      primary: AppColors.brand,
      surface: AppColors.surface,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = base.textTheme;
    final outline = OutlineInputBorder(
      borderRadius: AppRadii.field,
      borderSide: const BorderSide(color: AppColors.border),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleSmall: text.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyMedium: text.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
          height: 1.4,
        ),
        bodySmall: text.bodySmall?.copyWith(
          color: AppColors.textMuted,
          height: 1.4,
        ),
        labelLarge: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        labelMedium: text.labelMedium?.copyWith(
          color: AppColors.textMuted,
          height: 1.3,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.card,
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.field),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          side: const BorderSide(color: AppColors.borderStrong),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.field),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: outline,
        enabledBorder: outline,
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.field,
          borderSide: const BorderSide(color: AppColors.brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.field,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.field,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        helperStyle: const TextStyle(color: AppColors.textMuted),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll<TextStyle>(
            const TextStyle(fontWeight: FontWeight.w600),
          ),
          side: const WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: AppColors.borderStrong),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.surfaceMuted,
        side: BorderSide(color: AppColors.border),
        labelStyle: TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
      ),
      iconTheme: const IconThemeData(color: AppColors.textMuted),
    );
  }
}
