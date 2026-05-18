import 'package:flutter/material.dart';
import '../ds_tokens.dart' show DsModuleColor;
import 'skin_tokens.dart';

// =============================================================================
// Atrium — Boutique hospitality · linen + brass
// Deep ink bg, warm linen surfaces, brass accent, sage secondary.
// Fonts: Cormorant Garamond (serif display) + Manrope (body) + DM Mono
// Always dark — forcedBrightness: Brightness.dark
// =============================================================================

class AtriumTokens implements SkinTokens {
  const AtriumTokens();

  @override
  Brightness get brightness => Brightness.dark;
  @override bool get isDark => true;

  // Surfaces — deep ink
  @override Color get background    => const Color(0xFF1A1714);
  @override Color get backgroundAlt => const Color(0xFF211D19);
  @override Color get surface       => const Color(0xFF262220);
  @override Color get surfaceAlt    => const Color(0xFF2C2822);
  @override Color get surfaceRaised => const Color(0xFF312D28);

  // Text — linen on dark
  @override Color get textPrimary   => const Color(0xFFF2EBDC);
  @override Color get textSecondary => const Color(0xFFA89E8E);
  @override Color get textTertiary  => const Color(0xFF665E54);

  // Brand — brass
  @override Color get accent      => const Color(0xFFC49A4A);
  @override Color get accentSoft  => const Color(0xFF33280E);
  @override Color get accentText  => const Color(0xFF0F0B08);
  @override Color get warm        => const Color(0xFF7C8868);  // sage as warm complement
  @override Color get warmSoft    => const Color(0xFF252C1E);

  // Borders
  @override Color get border       => const Color(0xFF33291F);
  @override Color get borderSoft   => const Color(0xFF28201A);
  @override Color get borderStrong => const Color(0xFF3F342A);

  // Status
  @override Color get statusGood     => const Color(0xFF7C8868);
  @override Color get statusGoodSoft => const Color(0xFF252C1E);
  @override Color get statusWarn     => const Color(0xFFC49A4A);
  @override Color get statusWarnSoft => const Color(0xFF33280E);
  @override Color get statusBad      => const Color(0xFF9A3A3A);
  @override Color get statusBadSoft  => const Color(0xFF2E1212);

  // Typography
  @override String get fontDisplay    => 'Cormorant Garamond';
  @override String get fontBody       => 'Manrope';
  @override String get fontMono       => 'DM Mono';
  @override bool   get isSerifDisplay => true;

  // Shape — refined, classic
  @override double get radiusCard   => 16;
  @override double get radiusButton => 12;
  @override double get radiusInput  => 10;
  @override double get radiusChip   => 100;

  @override
  DsModuleColor moduleColor(String key) =>
      _atriumModuleColors[key] ??
      const DsModuleColor(bg: Color(0xFF2C2822), fg: Color(0xFFA89E8E), border: Color(0xFF33291F));
}

const Map<String, DsModuleColor> _atriumModuleColors = {
  'notices':         DsModuleColor(bg: Color(0xFF33280E), fg: Color(0xFFC49A4A), border: Color(0xFF40351A)),
  'visitors':        DsModuleColor(bg: Color(0xFF252C1E), fg: Color(0xFF7C8868), border: Color(0xFF323D28)),
  'complaints':      DsModuleColor(bg: Color(0xFF2E1212), fg: Color(0xFF9A3A3A), border: Color(0xFF3E2020)),
  'finance':         DsModuleColor(bg: Color(0xFF33280E), fg: Color(0xFFC49A4A), border: Color(0xFF40351A)),
  'facilities':      DsModuleColor(bg: Color(0xFF252C1E), fg: Color(0xFF7C8868), border: Color(0xFF323D28)),
  'community':       DsModuleColor(bg: Color(0xFF2C2822), fg: Color(0xFFA89E8E), border: Color(0xFF33291F)),
  'documents':       DsModuleColor(bg: Color(0xFF252C1E), fg: Color(0xFF7C8868), border: Color(0xFF323D28)),
  'parking':         DsModuleColor(bg: Color(0xFF2C2822), fg: Color(0xFFA89E8E), border: Color(0xFF33291F)),
  'gallery':         DsModuleColor(bg: Color(0xFF33280E), fg: Color(0xFFC49A4A), border: Color(0xFF40351A)),
  'events':          DsModuleColor(bg: Color(0xFF33280E), fg: Color(0xFFC49A4A), border: Color(0xFF40351A)),
  'polls':           DsModuleColor(bg: Color(0xFF2C2822), fg: Color(0xFFA89E8E), border: Color(0xFF33291F)),
  'water_tankers':   DsModuleColor(bg: Color(0xFF252C1E), fg: Color(0xFF7C8868), border: Color(0xFF323D28)),
  'vendors':         DsModuleColor(bg: Color(0xFF252C1E), fg: Color(0xFF7C8868), border: Color(0xFF323D28)),
  'maids':           DsModuleColor(bg: Color(0xFF33280E), fg: Color(0xFFC49A4A), border: Color(0xFF40351A)),
  'security_patrol': DsModuleColor(bg: Color(0xFF2E1212), fg: Color(0xFF9A3A3A), border: Color(0xFF3E2020)),
  'members':         DsModuleColor(bg: Color(0xFF2C2822), fg: Color(0xFFA89E8E), border: Color(0xFF33291F)),
  'agm':             DsModuleColor(bg: Color(0xFF33280E), fg: Color(0xFFC49A4A), border: Color(0xFF40351A)),
  'policies':        DsModuleColor(bg: Color(0xFF252C1E), fg: Color(0xFF7C8868), border: Color(0xFF323D28)),
  'register':        DsModuleColor(bg: Color(0xFF33280E), fg: Color(0xFFC49A4A), border: Color(0xFF40351A)),
  'tenant_kyc':      DsModuleColor(bg: Color(0xFF252C1E), fg: Color(0xFF7C8868), border: Color(0xFF323D28)),
  'feedback':        DsModuleColor(bg: Color(0xFF33280E), fg: Color(0xFFC49A4A), border: Color(0xFF40351A)),
  'snags':           DsModuleColor(bg: Color(0xFF2E1212), fg: Color(0xFF9A3A3A), border: Color(0xFF3E2020)),
  'letters':         DsModuleColor(bg: Color(0xFF252C1E), fg: Color(0xFF7C8868), border: Color(0xFF323D28)),
  'notifications':   DsModuleColor(bg: Color(0xFF33280E), fg: Color(0xFFC49A4A), border: Color(0xFF40351A)),
  'hoto':            DsModuleColor(bg: Color(0xFF252C1E), fg: Color(0xFF7C8868), border: Color(0xFF323D28)),
  'staff':           DsModuleColor(bg: Color(0xFF2C2822), fg: Color(0xFFA89E8E), border: Color(0xFF33291F)),
  'analytics':       DsModuleColor(bg: Color(0xFF33280E), fg: Color(0xFFC49A4A), border: Color(0xFF40351A)),
};
