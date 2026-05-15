import 'package:flutter/material.dart';

// UTAMACS design tokens — mirrors tailwind.config.cjs
const kPrimary600 = Color(0xFF1E3A8A);
const kPrimary100 = Color(0xFFDBEAFE);
const kPrimary50  = Color(0xFFEFF6FF);
const kSecondary500 = Color(0xFF10B981);
const kAccent500    = Color(0xFFF59E0B);
const kTextPrimary  = Color(0xFF111827);
const kTextSecondary = Color(0xFF4B5563);
const kBorderLight  = Color(0xFFE5E7EB);
const kSectionAlt   = Color(0xFFF8FAFC);
const kRed600       = Color(0xFFDC2626);

final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kPrimary600,
    primary: kPrimary600,
    secondary: kSecondary500,
    tertiary: kAccent500,
    error: kRed600,
    surface: Colors.white,
  ),
  fontFamily: 'Inter',
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: kPrimary600),
    displayMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: kPrimary600),
    headlineLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: kPrimary600, fontSize: 22),
    headlineMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: kTextPrimary, fontSize: 18),
    titleLarge: TextStyle(fontWeight: FontWeight.w600, color: kTextPrimary, fontSize: 16),
    titleMedium: TextStyle(fontWeight: FontWeight.w500, color: kTextPrimary, fontSize: 14),
    bodyLarge: TextStyle(color: kTextPrimary, fontSize: 16),
    bodyMedium: TextStyle(color: kTextPrimary, fontSize: 14),
    bodySmall: TextStyle(color: kTextSecondary, fontSize: 12),
    labelLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: kPrimary600,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontFamily: 'Poppins',
      fontWeight: FontWeight.w600,
      fontSize: 18,
      color: Colors.white,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimary600,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: kPrimary600,
      minimumSize: const Size(double.infinity, 52),
      side: const BorderSide(color: kPrimary600, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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
    labelStyle: const TextStyle(color: kTextSecondary, fontSize: 14),
    hintStyle: const TextStyle(color: kTextSecondary, fontSize: 14),
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
  dividerTheme: const DividerThemeData(color: kBorderLight, thickness: 1),
  scaffoldBackgroundColor: kSectionAlt,
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
);
