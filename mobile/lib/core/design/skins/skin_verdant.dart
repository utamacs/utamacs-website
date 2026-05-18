import 'package:flutter/material.dart';
import '../ds_tokens.dart' show DsModuleColor;
import 'skin_tokens.dart';

// =============================================================================
// Verdant — Warm botanical · cream + forest green
// Cream canvas, forest green accent, ochre warm signal.
// Fonts: DM Serif Display (display) + Outfit (body) + Space Mono
// Always light — forcedBrightness: Brightness.light
// =============================================================================

class VerdantTokens implements SkinTokens {
  const VerdantTokens();

  @override
  Brightness get brightness => Brightness.light;
  @override bool get isDark => false;

  // Surfaces — warm cream
  @override Color get background    => const Color(0xFFF8F2E2);
  @override Color get backgroundAlt => const Color(0xFFF3ECD7);
  @override Color get surface       => const Color(0xFFFFFFFF);
  @override Color get surfaceAlt    => const Color(0xFFFCF6E7);
  @override Color get surfaceRaised => const Color(0xFFF4ECD4);

  // Text — forest ink
  @override Color get textPrimary   => const Color(0xFF1F2C25);
  @override Color get textSecondary => const Color(0xFF3F4F45);
  @override Color get textTertiary  => const Color(0xFF697569);

  // Brand — forest green
  @override Color get accent      => const Color(0xFF1F4A36);
  @override Color get accentSoft  => const Color(0xFFE6EEE7);
  @override Color get accentText  => const Color(0xFFFFFFFF);
  @override Color get warm        => const Color(0xFFC97B37);
  @override Color get warmSoft    => const Color(0xFFF4E0C0);

  // Borders
  @override Color get border       => const Color(0xFFE3DCC4);
  @override Color get borderSoft   => const Color(0xFFEEE6CC);
  @override Color get borderStrong => const Color(0xFFD3CBAA);

  // Status
  @override Color get statusGood     => const Color(0xFF5A8F66);
  @override Color get statusGoodSoft => const Color(0xFFD8EDDA);
  @override Color get statusWarn     => const Color(0xFFC97B37);
  @override Color get statusWarnSoft => const Color(0xFFF4E0C0);
  @override Color get statusBad      => const Color(0xFFB0463A);
  @override Color get statusBadSoft  => const Color(0xFFF6DDD4);

  // Typography
  @override String get fontDisplay    => 'DM Serif Display';
  @override String get fontBody       => 'Outfit';
  @override String get fontMono       => 'Space Mono';
  @override bool   get isSerifDisplay => true;

  // Shape — organic, generous
  @override double get radiusCard   => 24;
  @override double get radiusButton => 20;
  @override double get radiusInput  => 14;
  @override double get radiusChip   => 100;

  @override
  DsModuleColor moduleColor(String key) =>
      _verdantModuleColors[key] ??
      const DsModuleColor(bg: Color(0xFFF4ECD4), fg: Color(0xFF697569), border: Color(0xFFE3DCC4));
}

const Map<String, DsModuleColor> _verdantModuleColors = {
  'notices':         DsModuleColor(bg: Color(0xFFE6EEE7), fg: Color(0xFF1F4A36), border: Color(0xFFCCDCCE)),
  'visitors':        DsModuleColor(bg: Color(0xFFD8EDDA), fg: Color(0xFF5A8F66), border: Color(0xFFBBD9BE)),
  'complaints':      DsModuleColor(bg: Color(0xFFF6DDD4), fg: Color(0xFFB0463A), border: Color(0xFFECC9BE)),
  'finance':         DsModuleColor(bg: Color(0xFFF4E0C0), fg: Color(0xFFC97B37), border: Color(0xFFEAD0A0)),
  'facilities':      DsModuleColor(bg: Color(0xFFE6EEE7), fg: Color(0xFF163322), border: Color(0xFFCCDCCE)),
  'community':       DsModuleColor(bg: Color(0xFFEDE7D8), fg: Color(0xFF5A8F66), border: Color(0xFFDDD5C0)),
  'documents':       DsModuleColor(bg: Color(0xFFE6EEE7), fg: Color(0xFF1F4A36), border: Color(0xFFCCDCCE)),
  'parking':         DsModuleColor(bg: Color(0xFFF4ECD4), fg: Color(0xFF3F4F45), border: Color(0xFFE3DCC4)),
  'gallery':         DsModuleColor(bg: Color(0xFFF4E0C0), fg: Color(0xFF9E5B22), border: Color(0xFFEAD0A0)),
  'events':          DsModuleColor(bg: Color(0xFFEDE7D8), fg: Color(0xFF163322), border: Color(0xFFDDD5C0)),
  'polls':           DsModuleColor(bg: Color(0xFFE6EEE7), fg: Color(0xFF1F4A36), border: Color(0xFFCCDCCE)),
  'water_tankers':   DsModuleColor(bg: Color(0xFFD8EDDA), fg: Color(0xFF2D6B3A), border: Color(0xFFBBD9BE)),
  'vendors':         DsModuleColor(bg: Color(0xFFE6EEE7), fg: Color(0xFF5A8F66), border: Color(0xFFCCDCCE)),
  'maids':           DsModuleColor(bg: Color(0xFFF4E0C0), fg: Color(0xFFC97B37), border: Color(0xFFEAD0A0)),
  'security_patrol': DsModuleColor(bg: Color(0xFFF6DDD4), fg: Color(0xFFB0463A), border: Color(0xFFECC9BE)),
  'members':         DsModuleColor(bg: Color(0xFFF4ECD4), fg: Color(0xFF3F4F45), border: Color(0xFFE3DCC4)),
  'agm':             DsModuleColor(bg: Color(0xFFE6EEE7), fg: Color(0xFF1F4A36), border: Color(0xFFCCDCCE)),
  'policies':        DsModuleColor(bg: Color(0xFFE6EEE7), fg: Color(0xFF163322), border: Color(0xFFCCDCCE)),
  'register':        DsModuleColor(bg: Color(0xFFF4E0C0), fg: Color(0xFF9E5B22), border: Color(0xFFEAD0A0)),
  'tenant_kyc':      DsModuleColor(bg: Color(0xFFD8EDDA), fg: Color(0xFF5A8F66), border: Color(0xFFBBD9BE)),
  'feedback':        DsModuleColor(bg: Color(0xFFF4E0C0), fg: Color(0xFFC97B37), border: Color(0xFFEAD0A0)),
  'snags':           DsModuleColor(bg: Color(0xFFF6DDD4), fg: Color(0xFFB0463A), border: Color(0xFFECC9BE)),
  'letters':         DsModuleColor(bg: Color(0xFFEDE7D8), fg: Color(0xFF1F4A36), border: Color(0xFFDDD5C0)),
  'notifications':   DsModuleColor(bg: Color(0xFFE6EEE7), fg: Color(0xFF1F4A36), border: Color(0xFFCCDCCE)),
  'hoto':            DsModuleColor(bg: Color(0xFFE6EEE7), fg: Color(0xFF163322), border: Color(0xFFCCDCCE)),
  'staff':           DsModuleColor(bg: Color(0xFFF4ECD4), fg: Color(0xFF3F4F45), border: Color(0xFFE3DCC4)),
  'analytics':       DsModuleColor(bg: Color(0xFFE6EEE7), fg: Color(0xFF1F4A36), border: Color(0xFFCCDCCE)),
};
