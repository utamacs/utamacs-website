import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// UTAMACS design tokens — mirrors tailwind.config.cjs
const kPrimary600    = Color(0xFF1E3A8A);
const kPrimary100    = Color(0xFFDBEAFE);
const kPrimary50     = Color(0xFFEFF6FF);
const kSecondary500  = Color(0xFF10B981);
const kAccent500     = Color(0xFFF59E0B);
const kTextPrimary   = Color(0xFF111827);
const kTextSecondary = Color(0xFF4B5563);
const kBorderLight   = Color(0xFFE5E7EB);
const kSectionAlt    = Color(0xFFF8FAFC);
const kRed600        = Color(0xFFDC2626);
const kBgWarm        = Color(0xFFF5F0EB);

ThemeData _buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimary600,
      primary: kPrimary600,
      secondary: kSecondary500,
      tertiary: kAccent500,
      error: kRed600,
      surface: Colors.white,
    ),
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
    displayLarge:  GoogleFonts.poppins(fontWeight: FontWeight.w700, color: kPrimary600),
    displayMedium: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: kPrimary600),
    headlineLarge: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: kPrimary600, fontSize: 22),
    headlineMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: kTextPrimary, fontSize: 18),
    titleLarge:  GoogleFonts.inter(fontWeight: FontWeight.w600, color: kTextPrimary, fontSize: 16),
    titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w500, color: kTextPrimary, fontSize: 14),
    bodyLarge:   GoogleFonts.inter(color: kTextPrimary, fontSize: 16),
    bodyMedium:  GoogleFonts.inter(color: kTextPrimary, fontSize: 14),
    bodySmall:   GoogleFonts.inter(color: kTextSecondary, fontSize: 12),
    labelLarge:  GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: kTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: kBorderLight,
      centerTitle: false,
      titleTextStyle: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        fontSize: 18,
        color: kTextPrimary,
      ),
      iconTheme: const IconThemeData(color: kTextPrimary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary600,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimary600,
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: kPrimary600, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimary600, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kRed600),
      ),
      labelStyle: GoogleFonts.inter(color: kTextSecondary, fontSize: 14),
      hintStyle: GoogleFonts.inter(color: kTextSecondary, fontSize: 14),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorderLight),
      ),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Colors.transparent,
      surfaceTintColor: Colors.white,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: kPrimary600);
        }
        return GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: kTextSecondary);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: kPrimary600, size: 24);
        }
        return const IconThemeData(color: kTextSecondary, size: 24);
      }),
    ),
    dividerTheme: const DividerThemeData(color: kBorderLight, thickness: 1),
    scaffoldBackgroundColor: kBgWarm,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

final appTheme = _buildTheme();
