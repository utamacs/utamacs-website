import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ds_tokens.dart';
import 'app_skin.dart';
import 'skin_tokens.dart';
import 'skin_classic.dart';
import 'skin_vellum.dart';
import 'skin_concourse.dart';
import 'skin_verdant.dart';
import 'skin_riso.dart';
import 'skin_atrium.dart';

/// Builds a (ThemeData, SkinTokens) pair from an [AppSkin] and brightness.
abstract final class SkinFactory {
  /// Resolves [SkinTokens] for the given skin and effective brightness.
  static SkinTokens tokens(AppSkin skin, Brightness brightness) {
    switch (skin) {
      case AppSkin.classic:
        return ClassicTokens(brightness: brightness);
      case AppSkin.vellum:
        return VellumTokens(brightness: brightness);
      case AppSkin.concourse:
        return const ConcourseTokens();
      case AppSkin.verdant:
        return const VerdantTokens();
      case AppSkin.riso:
        return const RisoTokens();
      case AppSkin.atrium:
        return const AtriumTokens();
    }
  }

  /// Builds a complete [ThemeData] from [SkinTokens].
  static ThemeData theme(SkinTokens t) {
    final displayFont = GoogleFonts.getFont(t.fontDisplay);
    final bodyFont    = GoogleFonts.getFont(t.fontBody);

    final cs = ColorScheme(
      brightness:              t.brightness,
      primary:                 t.accent,
      onPrimary:               t.accentText,
      primaryContainer:        t.accentSoft,
      onPrimaryContainer:      t.accent,
      secondary:               t.warm,
      onSecondary:             t.accentText,
      secondaryContainer:      t.warmSoft,
      onSecondaryContainer:    t.warm,
      tertiary:                t.statusGood,
      onTertiary:              t.accentText,
      tertiaryContainer:       t.statusGoodSoft,
      onTertiaryContainer:     t.statusGood,
      error:                   t.statusBad,
      onError:                 t.accentText,
      errorContainer:          t.statusBadSoft,
      onErrorContainer:        t.statusBad,
      surface:                 t.surface,
      onSurface:               t.textPrimary,
      surfaceContainerHighest: t.surfaceAlt,
      outline:                 t.border,
      outlineVariant:          t.borderSoft,
      shadow:                  Colors.black,
      scrim:                   Colors.black,
      inverseSurface:          t.isDark ? t.surfaceRaised : const Color(0xFF1E293B),
      onInverseSurface:        t.isDark ? t.textPrimary   : Colors.white,
      inversePrimary:          t.accent,
    );

    final displayStyle = displayFont.copyWith(color: t.textPrimary, height: 1.15, letterSpacing: -0.5);
    final bodyStyle    = bodyFont.copyWith(color: t.textPrimary);

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: t.background,
      fontFamily: bodyFont.fontFamily,

      textTheme: TextTheme(
        displayLarge:  displayStyle.copyWith(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        displayMedium: displayStyle.copyWith(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        displaySmall:  displayStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
        headlineLarge:  displayStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
        headlineMedium: displayStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3),
        headlineSmall:  displayStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35),
        titleLarge:   bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
        titleMedium:  bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: 0.1),
        titleSmall:   bodyStyle.copyWith(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: 0.1),
        bodyLarge:    bodyStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.55),
        bodyMedium:   bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.55),
        bodySmall:    bodyStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5, color: t.textSecondary),
        labelLarge:   bodyStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        labelMedium:  bodyStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.3, color: t.textSecondary),
        labelSmall:   bodyStyle.copyWith(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: t.textSecondary),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: t.surface,
        foregroundColor: t.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: t.border,
        centerTitle: false,
        systemOverlayStyle: t.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: displayFont.copyWith(
          fontWeight: FontWeight.w600, fontSize: 17, color: t.textPrimary, height: 1.2,
        ),
        iconTheme: IconThemeData(color: t.textPrimary, size: dsIconLg),
        actionsIconTheme: IconThemeData(color: t.textPrimary, size: dsIconLg),
        toolbarHeight: 56,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.accentText,
          disabledBackgroundColor: t.borderStrong,
          disabledForegroundColor: t.textTertiary,
          minimumSize: const Size(double.infinity, 52),
          maximumSize: const Size(double.infinity, 52),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusButton)),
          textStyle: bodyFont.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: dsSpace5),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          animationDuration: dsDurationFast,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.accent,
          minimumSize: const Size(double.infinity, 52),
          maximumSize: const Size(double.infinity, 52),
          side: BorderSide(color: t.accent, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusButton)),
          textStyle: bodyFont.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          animationDuration: dsDurationFast,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.accent,
          minimumSize: const Size(0, 40),
          textStyle: bodyFont.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: dsSpace2, vertical: dsSpace1),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: dsSpace4, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.radiusInput),
          borderSide: BorderSide(color: t.border, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.radiusInput),
          borderSide: BorderSide(color: t.border, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.radiusInput),
          borderSide: BorderSide(color: t.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.radiusInput),
          borderSide: BorderSide(color: t.statusBad, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.radiusInput),
          borderSide: BorderSide(color: t.statusBad, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.radiusInput),
          borderSide: BorderSide(color: t.borderSoft, width: 1.0),
        ),
        labelStyle: bodyFont.copyWith(color: t.textSecondary, fontSize: 14),
        hintStyle: bodyFont.copyWith(color: t.textTertiary, fontSize: 14),
        errorStyle: bodyFont.copyWith(color: t.statusBad, fontSize: 12),
        prefixIconColor: t.textSecondary,
        suffixIconColor: t.textSecondary,
      ),

      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(t.radiusCard)),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: t.surfaceAlt,
        selectedColor: t.accentSoft,
        disabledColor: t.surfaceAlt,
        labelStyle: bodyFont.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: t.textPrimary),
        secondaryLabelStyle: bodyFont.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: t.accent),
        side: BorderSide(color: t.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: dsSpace3, vertical: dsSpace1),
        elevation: 0,
        pressElevation: 0,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(dsRadiusXxl)),
        titleTextStyle: displayFont.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: t.textPrimary),
        contentTextStyle: bodyFont.copyWith(fontSize: 14, color: t.textSecondary, height: 1.55),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(dsRadiusXxl)),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        indicatorColor: t.accentSoft,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: t.accent, size: dsIconLg);
          }
          return IconThemeData(color: t.textTertiary, size: dsIconLg);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return bodyFont.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: t.accent);
          }
          return bodyFont.copyWith(fontSize: 11, fontWeight: FontWeight.w500, color: t.textTertiary);
        }),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
      ),

      dividerTheme: DividerThemeData(
        color: t.border,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        tileColor: t.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: dsSpace4),
        iconColor: t.textSecondary,
        textColor: t.textPrimary,
        subtitleTextStyle: bodyFont.copyWith(fontSize: 13, color: t.textSecondary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusCard)),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? t.accentText : t.textTertiary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? t.accent : t.borderStrong),
        trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: t.accentSoft,
        circularTrackColor: t.accentSoft,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.isDark ? t.surfaceRaised : const Color(0xFF1E293B),
        contentTextStyle: bodyFont.copyWith(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(dsRadiusMd)),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
    );
  }
}
