import 'package:flutter/material.dart';

/// Centralized palette + theme for a minimal, premium look.
///
/// Design intent: a neutral graphite/paper base, a single restrained brass
/// accent used sparingly (progress, primary action, active states), flat
/// bordered surfaces instead of drop shadows, and tight, deliberate
/// typography with tracked-out labels for a "precision instrument" feel.
class AppColors {
  const AppColors._();

  // Brass accent — the only saturated color in the app.
  static const accent = Color(0xFFC8A464);
  static const accentOn = Color(0xFF20180C); // text/icon drawn on accent

  // A muted terracotta used only for step markers on the chart — distinct
  // from the accent without turning the UI busy.
  static const marker = Color(0xFFB8593F);

  // --- Dark theme ---
  static const darkBg = Color(0xFF0C0C0E);
  static const darkSurface = Color(0xFF15151A);
  static const darkSurfaceAlt = Color(0xFF1B1B21);
  static const darkBorder = Color(0xFF27272E);
  static const darkText = Color(0xFFF3F2EF);
  static const darkTextMuted = Color(0xFF8C8C94);

  // --- Light theme ---
  static const lightBg = Color(0xFFF7F6F3);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFF1EFEA);
  static const lightBorder = Color(0xFFE6E4DE);
  static const lightText = Color(0xFF17171B);
  static const lightTextMuted = Color(0xFF6C6C74);
}

class AppTheme {
  const AppTheme._();

  static const _fontFamilyFallback = <String>[
    '-apple-system',
    'San Francisco',
    'Roboto',
  ];

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final textMuted =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.accent,
      onPrimary: AppColors.accentOn,
      secondary: AppColors.accent,
      onSecondary: AppColors.accentOn,
      error: const Color(0xFFCF6679),
      onError: isDark ? Colors.black : Colors.white,
      surface: surface,
      onSurface: text,
      outline: border,
      outlineVariant: border,
      surfaceContainerHighest:
          isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
      inverseSurface: text,
      onInverseSurface: surface,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: border,
      splashFactory: NoSplash.splashFactory,
      fontFamilyFallback: _fontFamilyFallback,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(
          color: text,
          fontWeight: FontWeight.w600,
          fontSize: 64,
          height: 1.0,
          letterSpacing: -1.5,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          color: textMuted,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 3,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          color: text,
          fontWeight: FontWeight.w600,
          fontSize: 17,
          letterSpacing: 0.2,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: text,
          fontSize: 14,
          height: 1.4,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          color: textMuted,
          fontSize: 12.5,
          height: 1.45,
        ),
        labelSmall: base.textTheme.labelSmall?.copyWith(
          color: textMuted,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontWeight: FontWeight.w600,
          fontSize: 15,
          letterSpacing: 2.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.accentOn,
          disabledBackgroundColor: border,
          disabledForegroundColor: textMuted,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: border, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: border,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: 0.12),
        trackHeight: 2.5,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 7,
          elevation: 0,
          pressedElevation: 0,
        ),
        valueIndicatorColor: text,
        valueIndicatorTextStyle: TextStyle(
          color: surface,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      iconTheme: IconThemeData(color: textMuted, size: 18),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    );
  }
}