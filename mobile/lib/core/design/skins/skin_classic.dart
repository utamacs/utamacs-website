import 'package:flutter/material.dart';
import '../ds_tokens.dart';
import 'skin_tokens.dart';

// =============================================================================
// Classic — Original UTAMACS "Residences" design language
// Indigo-tinted canvas, emerald secondary, amber accent. Inter + Poppins.
// Supports both light and dark.
// =============================================================================

class ClassicTokens implements SkinTokens {
  const ClassicTokens({this.brightness = Brightness.light});

  @override
  final Brightness brightness;

  bool get _d => brightness == Brightness.dark;
  @override bool get isDark => _d;

  // Surfaces
  @override Color get background    => _d ? dsDarkBackground      : dsBackground;
  @override Color get backgroundAlt => _d ? dsDarkSurfaceMuted    : dsSurfaceMuted;
  @override Color get surface       => _d ? dsDarkSurface         : dsSurface;
  @override Color get surfaceAlt    => _d ? dsDarkSurfaceMuted    : dsSurfaceMuted;
  @override Color get surfaceRaised => _d ? dsDarkSurfaceElevated : dsSurfaceElevated;

  // Text
  @override Color get textPrimary   => _d ? dsDarkTextPrimary   : dsTextPrimary;
  @override Color get textSecondary => _d ? dsDarkTextSecondary : dsTextSecondary;
  @override Color get textTertiary  => _d ? dsDarkTextTertiary  : dsTextTertiary;

  // Brand
  @override Color get accent      => _d ? dsColorIndigo300 : dsBrandPrimary;
  @override Color get accentSoft  => _d ? const Color(0xFF1A2A60) : dsBrandPrimaryLight;
  @override Color get accentText  => dsTextInverse;
  @override Color get warm        => dsBrandAccent;
  @override Color get warmSoft    => dsColorAmber50;

  // Borders
  @override Color get border       => _d ? dsDarkBorderLight  : dsBorderLight;
  @override Color get borderSoft   => _d ? dsDarkBorderSubtle : dsBorderSubtle;
  @override Color get borderStrong => _d ? const Color(0xFF2E3A60) : dsBorderDefault;

  // Status
  @override Color get statusGood     => dsStatusSuccess;
  @override Color get statusGoodSoft => _d ? const Color(0xFF0A2E1A) : dsStatusSuccessLight;
  @override Color get statusWarn     => dsStatusWarning;
  @override Color get statusWarnSoft => _d ? const Color(0xFF2E2010) : dsStatusWarningLight;
  @override Color get statusBad      => dsStatusError;
  @override Color get statusBadSoft  => _d ? const Color(0xFF2E0A0A) : dsStatusErrorLight;

  // Typography — original design language
  @override String get fontDisplay    => 'Poppins';
  @override String get fontBody       => 'Inter';
  @override String get fontMono       => 'JetBrains Mono';
  @override bool   get isSerifDisplay => false;

  // Shape — standard portal radii
  @override double get radiusCard   => 16;
  @override double get radiusButton => 12;
  @override double get radiusInput  => 10;
  @override double get radiusChip   => 100;

  @override
  DsModuleColor moduleColor(String key) {
    final colors = _classicModuleColors[key];
    if (colors != null) return colors;
    return DsModuleColor(
      bg: _d ? const Color(0xFF1A2240) : dsSurfaceMuted,
      fg: _d ? dsColorIndigo300 : dsBrandPrimary,
      border: _d ? dsDarkBorderLight : dsBorderLight,
    );
  }
}

// Classic module colors match the existing portal colour scheme
const Map<String, DsModuleColor> _classicModuleColors = {
  'notices':         DsModuleColor(bg: Color(0xFFEEF2FF), fg: Color(0xFF1E3A8A), border: Color(0xFFB3C1E8)),
  'visitors':        DsModuleColor(bg: Color(0xFFECFDF5), fg: Color(0xFF047857), border: Color(0xFFD1FAE5)),
  'complaints':      DsModuleColor(bg: Color(0xFFFEF2F2), fg: Color(0xFFB91C1C), border: Color(0xFFFEE2E2)),
  'finance':         DsModuleColor(bg: Color(0xFFFFFBEB), fg: Color(0xFFB45309), border: Color(0xFFFDE68A)),
  'facilities':      DsModuleColor(bg: Color(0xFFF0F9FF), fg: Color(0xFF0369A1), border: Color(0xFFE0F2FE)),
  'community':       DsModuleColor(bg: Color(0xFFF5F3FF), fg: Color(0xFF6D28D9), border: Color(0xFFEDE9FE)),
  'documents':       DsModuleColor(bg: Color(0xFFECFDF5), fg: Color(0xFF047857), border: Color(0xFFD1FAE5)),
  'parking':         DsModuleColor(bg: Color(0xFFF8FAFC), fg: Color(0xFF475569), border: Color(0xFFE2E8F0)),
  'gallery':         DsModuleColor(bg: Color(0xFFFFF7ED), fg: Color(0xFF9A3412), border: Color(0xFFFFEDD5)),
  'events':          DsModuleColor(bg: Color(0xFFEEF2FF), fg: Color(0xFF1A2F87), border: Color(0xFFB3C1E8)),
  'polls':           DsModuleColor(bg: Color(0xFFF5F3FF), fg: Color(0xFF4C1D95), border: Color(0xFFEDE9FE)),
  'water_tankers':   DsModuleColor(bg: Color(0xFFF0FDFA), fg: Color(0xFF0D9488), border: Color(0xFFCCFBF1)),
  'vendors':         DsModuleColor(bg: Color(0xFFECFDF5), fg: Color(0xFF059669), border: Color(0xFFD1FAE5)),
  'maids':           DsModuleColor(bg: Color(0xFFFFF7ED), fg: Color(0xFFC2410C), border: Color(0xFFFFEDD5)),
  'security_patrol': DsModuleColor(bg: Color(0xFFEEF2FF), fg: Color(0xFF1E3A8A), border: Color(0xFFB3C1E8)),
  'members':         DsModuleColor(bg: Color(0xFFF8FAFC), fg: Color(0xFF475569), border: Color(0xFFE2E8F0)),
  'agm':             DsModuleColor(bg: Color(0xFFECFDF5), fg: Color(0xFF047857), border: Color(0xFFD1FAE5)),
  'policies':        DsModuleColor(bg: Color(0xFFEEF2FF), fg: Color(0xFF1E3A8A), border: Color(0xFFB3C1E8)),
  'register':        DsModuleColor(bg: Color(0xFFFFF7ED), fg: Color(0xFF9A3412), border: Color(0xFFFFEDD5)),
  'tenant_kyc':      DsModuleColor(bg: Color(0xFFECFDF5), fg: Color(0xFF047857), border: Color(0xFFD1FAE5)),
  'feedback':        DsModuleColor(bg: Color(0xFFFFFBEB), fg: Color(0xFFB45309), border: Color(0xFFFDE68A)),
  'snags':           DsModuleColor(bg: Color(0xFFFEF2F2), fg: Color(0xFFB91C1C), border: Color(0xFFFEE2E2)),
  'letters':         DsModuleColor(bg: Color(0xFFF5F3FF), fg: Color(0xFF7C3AED), border: Color(0xFFEDE9FE)),
  'notifications':   DsModuleColor(bg: Color(0xFFEEF2FF), fg: Color(0xFF1E3A8A), border: Color(0xFFB3C1E8)),
  'hoto':            DsModuleColor(bg: Color(0xFFECFDF5), fg: Color(0xFF047857), border: Color(0xFFD1FAE5)),
  'staff':           DsModuleColor(bg: Color(0xFFF8FAFC), fg: Color(0xFF475569), border: Color(0xFFE2E8F0)),
  'analytics':       DsModuleColor(bg: Color(0xFFEEF2FF), fg: Color(0xFF1E3A8A), border: Color(0xFFB3C1E8)),
};
