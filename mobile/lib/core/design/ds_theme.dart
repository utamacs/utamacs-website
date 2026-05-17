import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ds_tokens.dart';

// ============================================================================
// UTAMACS Design System — ThemeData builder
// Builds both light and dark themes from design tokens.
// ============================================================================

ThemeData buildLightTheme() {
  final ColorScheme cs = const ColorScheme(
    brightness: Brightness.light,
    primary:           dsColorIndigo600,
    onPrimary:         Color(0xFFFFFFFF),
    primaryContainer:  dsColorIndigo50,
    onPrimaryContainer: dsColorIndigo900,
    secondary:         dsColorEmerald500,
    onSecondary:       Color(0xFFFFFFFF),
    secondaryContainer: dsColorEmerald50,
    onSecondaryContainer: dsColorEmerald700,
    tertiary:          dsColorAmber500,
    onTertiary:        Color(0xFFFFFFFF),
    tertiaryContainer: dsColorAmber50,
    onTertiaryContainer: dsColorAmber700,
    error:             dsColorRed600,
    onError:           Color(0xFFFFFFFF),
    errorContainer:    dsColorRed50,
    onErrorContainer:  dsColorRed700,
    surface:           dsSurface,
    onSurface:         dsTextPrimary,
    surfaceContainerHighest: dsSurfaceMuted,
    outline:           dsBorderLight,
    outlineVariant:    dsBorderSubtle,
    shadow:            Color(0xFF000000),
    scrim:             Color(0xFF000000),
    inverseSurface:    dsColorSlate900,
    onInverseSurface:  Color(0xFFEEF2FF),
    inversePrimary:    dsColorIndigo300,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: dsBackground,
    fontFamily: GoogleFonts.inter().fontFamily,

    // ── Text theme ───────────────────────────────────────────────────────────
    textTheme: GoogleFonts.interTextTheme().copyWith(
      // Display — Poppins, used for large section headings
      displayLarge: GoogleFonts.poppins(
        fontWeight: FontWeight.w700, fontSize: 36,
        color: dsTextPrimary, height: 1.15, letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.poppins(
        fontWeight: FontWeight.w700, fontSize: 28,
        color: dsTextPrimary, height: 1.2, letterSpacing: -0.3,
      ),
      displaySmall: GoogleFonts.poppins(
        fontWeight: FontWeight.w700, fontSize: 22,
        color: dsTextPrimary, height: 1.25,
      ),
      // Headline — Poppins, page titles
      headlineLarge: GoogleFonts.poppins(
        fontWeight: FontWeight.w700, fontSize: 20,
        color: dsTextPrimary, height: 1.3,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontWeight: FontWeight.w600, fontSize: 18,
        color: dsTextPrimary, height: 1.3,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontWeight: FontWeight.w600, fontSize: 16,
        color: dsTextPrimary, height: 1.35,
      ),
      // Title — Inter, card titles / section headers
      titleLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w600, fontSize: 16,
        color: dsTextPrimary, height: 1.4,
      ),
      titleMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w600, fontSize: 14,
        color: dsTextPrimary, height: 1.4, letterSpacing: 0.1,
      ),
      titleSmall: GoogleFonts.inter(
        fontWeight: FontWeight.w600, fontSize: 13,
        color: dsTextPrimary, height: 1.4, letterSpacing: 0.1,
      ),
      // Body — Inter, content
      bodyLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w400, fontSize: 16,
        color: dsTextPrimary, height: 1.55,
      ),
      bodyMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w400, fontSize: 14,
        color: dsTextPrimary, height: 1.55,
      ),
      bodySmall: GoogleFonts.inter(
        fontWeight: FontWeight.w400, fontSize: 12,
        color: dsTextSecondary, height: 1.5,
      ),
      // Label — Inter, UI chrome (buttons, chips, badges)
      labelLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w600, fontSize: 14,
        color: dsTextPrimary, letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w500, fontSize: 12,
        color: dsTextSecondary, letterSpacing: 0.3,
      ),
      labelSmall: GoogleFonts.inter(
        fontWeight: FontWeight.w600, fontSize: 10,
        color: dsTextSecondary, letterSpacing: 0.8,
      ),
    ),

    // ── AppBar ───────────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: dsSurface,
      foregroundColor: dsTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: dsBorderLight,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 17,
        color: dsTextPrimary,
        height: 1.2,
      ),
      iconTheme: const IconThemeData(color: dsTextPrimary, size: dsIconLg),
      actionsIconTheme: const IconThemeData(color: dsTextPrimary, size: dsIconLg),
      toolbarHeight: 56,
    ),

    // ── Buttons ──────────────────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: dsColorIndigo600,
        foregroundColor: Colors.white,
        disabledBackgroundColor: dsColorSlate200,
        disabledForegroundColor: dsColorSlate400,
        minimumSize: const Size(double.infinity, 52),
        maximumSize: const Size(double.infinity, 52),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dsRadiusButton),
        ),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        padding: const EdgeInsets.symmetric(horizontal: dsSpace5, vertical: 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        animationDuration: dsDurationFast,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: dsColorIndigo600,
        disabledForegroundColor: dsColorSlate400,
        minimumSize: const Size(double.infinity, 52),
        maximumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: dsColorIndigo600, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dsRadiusButton),
        ),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        animationDuration: dsDurationFast,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: dsColorIndigo600,
        minimumSize: const Size(0, 40),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        padding: const EdgeInsets.symmetric(horizontal: dsSpace2, vertical: dsSpace1),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        animationDuration: dsDurationFast,
      ),
    ),

    // ── Inputs ───────────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dsSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: dsSpace4, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(dsRadiusInput),
        borderSide: const BorderSide(color: dsBorderLight, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(dsRadiusInput),
        borderSide: const BorderSide(color: dsBorderLight, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(dsRadiusInput),
        borderSide: const BorderSide(color: dsColorIndigo600, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(dsRadiusInput),
        borderSide: const BorderSide(color: dsColorRed600, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(dsRadiusInput),
        borderSide: const BorderSide(color: dsColorRed600, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(dsRadiusInput),
        borderSide: const BorderSide(color: dsBorderSubtle, width: 1.0),
      ),
      labelStyle: GoogleFonts.inter(
        color: dsTextSecondary, fontSize: 14, fontWeight: FontWeight.w400,
      ),
      hintStyle: GoogleFonts.inter(
        color: dsTextTertiary, fontSize: 14, fontWeight: FontWeight.w400,
      ),
      errorStyle: GoogleFonts.inter(
        color: dsColorRed600, fontSize: 12, fontWeight: FontWeight.w400,
      ),
      prefixIconColor: dsTextSecondary,
      suffixIconColor: dsTextSecondary,
    ),

    // ── Cards ────────────────────────────────────────────────────────────────
    cardTheme: const CardThemeData(
      color: dsSurface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(dsRadiusCard)),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),

    // ── Chips ────────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: dsSurfaceMuted,
      selectedColor: dsColorIndigo50,
      disabledColor: dsSurfaceMuted,
      labelStyle: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w500, color: dsTextPrimary,
      ),
      secondaryLabelStyle: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w600, color: dsColorIndigo600,
      ),
      side: const BorderSide(color: dsBorderLight),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: dsSpace3, vertical: dsSpace1),
      elevation: 0,
      pressElevation: 0,
    ),

    // ── Dialogs ──────────────────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: dsSurface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(dsRadiusXxl)),
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 18, fontWeight: FontWeight.w700, color: dsTextPrimary,
      ),
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14, color: dsTextSecondary, height: 1.55,
      ),
    ),

    // ── Bottom Sheet ─────────────────────────────────────────────────────────
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: dsSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(dsRadiusXxl),
        ),
      ),
      showDragHandle: true,
      dragHandleColor: dsBorderDefault,
      dragHandleSize: Size(36, 4),
      constraints: BoxConstraints(maxWidth: double.infinity),
    ),

    // ── Snackbar ─────────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dsColorSlate900,
      contentTextStyle: GoogleFonts.inter(
        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500,
      ),
      actionTextColor: dsColorIndigo300,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(dsRadiusMd)),
      elevation: 8,
      insetPadding: const EdgeInsets.all(dsSpace4),
    ),

    // ── Tabs ─────────────────────────────────────────────────────────────────
    tabBarTheme: TabBarThemeData(
      labelColor: dsColorIndigo600,
      unselectedLabelColor: dsTextSecondary,
      indicatorColor: dsColorIndigo600,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: dsBorderLight,
      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
      unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 13),
      overlayColor: WidgetStatePropertyAll(dsColorIndigo600.withValues(alpha: 0.06)),
    ),

    // ── Navigation bar ───────────────────────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dsSurface,
      indicatorColor: dsColorIndigo50,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w600, color: dsColorIndigo600,
          );
        }
        return GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w400, color: dsTextSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: dsColorIndigo600, size: 22);
        }
        return const IconThemeData(color: dsTextSecondary, size: 22);
      }),
    ),

    // ── Divider ──────────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: dsBorderSubtle,
      thickness: 1,
      space: 1,
    ),

    // ── List Tile ────────────────────────────────────────────────────────────
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: dsSpace4, vertical: dsSpace2),
      minVerticalPadding: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(dsRadiusMd)),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w500, color: dsTextPrimary,
      ),
      subtitleTextStyle: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w400, color: dsTextSecondary,
      ),
    ),

    // ── Floating Action Button ────────────────────────────────────────────────
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: dsColorIndigo600,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(dsRadiusXl)),
      sizeConstraints: const BoxConstraints.tightFor(height: 52),
      extendedTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      extendedPadding: const EdgeInsets.symmetric(horizontal: dsSpace5),
    ),

    // ── Progress Indicator ───────────────────────────────────────────────────
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: dsColorIndigo600,
      linearTrackColor: dsColorIndigo50,
      circularTrackColor: dsColorIndigo50,
      strokeWidth: 2.5,
    ),

    // ── Switch ───────────────────────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? dsColorIndigo600 : dsBorderLight),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
    ),

    // ── Checkbox ─────────────────────────────────────────────────────────────
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? dsColorIndigo600 : Colors.transparent),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      side: const BorderSide(color: dsBorderDefault, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(dsRadiusXs)),
    ),

    // ── Radio ────────────────────────────────────────────────────────────────
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? dsColorIndigo600 : dsBorderDefault),
    ),

    // ── Popup Menu ───────────────────────────────────────────────────────────
    popupMenuTheme: PopupMenuThemeData(
      color: dsSurface,
      elevation: 8,
      shadowColor: const Color(0xFF000000).withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(dsRadiusLg)),
      textStyle: GoogleFonts.inter(fontSize: 14, color: dsTextPrimary),
      surfaceTintColor: Colors.transparent,
      position: PopupMenuPosition.under,
    ),

    // ── Tooltip ──────────────────────────────────────────────────────────────
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: dsColorSlate900,
        borderRadius: BorderRadius.circular(dsRadiusSm),
      ),
      textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 12),
    ),
  );
}

// Dark theme — built on the same token system with dark surface overrides
ThemeData buildDarkTheme() {
  final lightTheme = buildLightTheme();
  const ColorScheme darkCs = ColorScheme(
    brightness: Brightness.dark,
    primary:           dsColorIndigo400,
    onPrimary:         Color(0xFF0F1F5C),
    primaryContainer:  dsColorIndigo800,
    onPrimaryContainer: dsColorIndigo100,
    secondary:         dsColorEmerald400,
    onSecondary:       Color(0xFF065F46),
    secondaryContainer: dsColorEmerald700,
    onSecondaryContainer: dsColorEmerald100,
    tertiary:          dsColorAmber300,
    onTertiary:        Color(0xFF7C3209),
    tertiaryContainer: dsColorAmber700,
    onTertiaryContainer: dsColorAmber100,
    error:             dsColorRed500,
    onError:           Color(0xFF7F1D1D),
    errorContainer:    dsColorRed700,
    onErrorContainer:  dsColorRed100,
    surface:           dsDarkSurface,
    onSurface:         dsDarkTextPrimary,
    surfaceContainerHighest: dsDarkSurfaceMuted,
    outline:           dsDarkBorderLight,
    outlineVariant:    dsDarkBorderSubtle,
    shadow:            Color(0xFF000000),
    scrim:             Color(0xFF000000),
    inverseSurface:    dsColorSlate100,
    onInverseSurface:  dsColorSlate900,
    inversePrimary:    dsColorIndigo600,
  );
  return lightTheme.copyWith(
    colorScheme: darkCs,
    scaffoldBackgroundColor: dsDarkBackground,
    appBarTheme: lightTheme.appBarTheme.copyWith(
      backgroundColor: dsDarkSurface,
      foregroundColor: dsDarkTextPrimary,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: const IconThemeData(color: Color(0xFFEEF2FF), size: dsIconLg),
    ),
    cardTheme: const CardThemeData(
      color: dsDarkSurface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(dsRadiusCard)),
      ),
      margin: EdgeInsets.zero,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: dsDarkSurface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: Color(0xFF334155),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(dsRadiusXxl)),
      ),
      showDragHandle: true,
    ),
    dividerTheme: const DividerThemeData(
      color: dsDarkBorderSubtle,
      thickness: 1,
    ),
  );
}

// Export convenience
final dsLightTheme = buildLightTheme();
final dsDarkTheme  = buildDarkTheme();
