import 'package:flutter/material.dart';
import '../ds_tokens.dart' show DsModuleColor;
import 'skin_tokens.dart';

// =============================================================================
// Riso — Risograph print zine · cobalt + tomato
// Cream paper, cobalt dominant, tomato signal, sun yellow accent.
// Fonts: Bricolage Grotesque (single font family) + Space Mono
// Always light — forcedBrightness: Brightness.light
// =============================================================================

class RisoTokens implements SkinTokens {
  const RisoTokens();

  @override
  Brightness get brightness => Brightness.light;
  @override bool get isDark => false;

  // Surfaces — cream paper
  @override Color get background    => const Color(0xFFF4EFE0);
  @override Color get backgroundAlt => const Color(0xFFEBE4CF);
  @override Color get surface       => const Color(0xFFF4EFE0);
  @override Color get surfaceAlt    => const Color(0xFFEBE4CF);
  @override Color get surfaceRaised => const Color(0xFFE2DAC0);

  // Text — warm ink
  @override Color get textPrimary   => const Color(0xFF1A1614);
  @override Color get textSecondary => const Color(0xFF3F3630);
  @override Color get textTertiary  => const Color(0xFF6E6358);

  // Brand — cobalt
  @override Color get accent      => const Color(0xFF1A37C8);
  @override Color get accentSoft  => const Color(0xFFD5DCF8);
  @override Color get accentText  => const Color(0xFFFFFFFF);
  @override Color get warm        => const Color(0xFFE54A3E);  // tomato as warm signal
  @override Color get warmSoft    => const Color(0xFFFBD9D4);

  // Borders
  @override Color get border       => const Color(0xFFD6CDB4);
  @override Color get borderSoft   => const Color(0xFFE2DBC5);
  @override Color get borderStrong => const Color(0xFFBFB498);

  // Status
  @override Color get statusGood     => const Color(0xFF2E9A65);
  @override Color get statusGoodSoft => const Color(0xFFCFE9DB);
  @override Color get statusWarn     => const Color(0xFFA57F0F);
  @override Color get statusWarnSoft => const Color(0xFFF9EAB0);
  @override Color get statusBad      => const Color(0xFF9F2A20);
  @override Color get statusBadSoft  => const Color(0xFFFBD9D4);

  // Typography — single expressive font
  @override String get fontDisplay    => 'Bricolage Grotesque';
  @override String get fontBody       => 'Bricolage Grotesque';
  @override String get fontMono       => 'Space Mono';
  @override bool   get isSerifDisplay => false;

  // Shape — punchy, square-ish
  @override double get radiusCard   => 8;
  @override double get radiusButton => 6;
  @override double get radiusInput  => 6;
  @override double get radiusChip   => 4;

  @override
  DsModuleColor moduleColor(String key) =>
      _risoModuleColors[key] ??
      const DsModuleColor(bg: Color(0xFFEBE4CF), fg: Color(0xFF6E6358), border: Color(0xFFD6CDB4));
}

const Map<String, DsModuleColor> _risoModuleColors = {
  'notices':         DsModuleColor(bg: Color(0xFFD5DCF8), fg: Color(0xFF1A37C8), border: Color(0xFFB8C3F0)),
  'visitors':        DsModuleColor(bg: Color(0xFFCFE9DB), fg: Color(0xFF2E9A65), border: Color(0xFFB0D8C5)),
  'complaints':      DsModuleColor(bg: Color(0xFFFBD9D4), fg: Color(0xFF9F2A20), border: Color(0xFFF5BFB8)),
  'finance':         DsModuleColor(bg: Color(0xFFF9EAB0), fg: Color(0xFFA57F0F), border: Color(0xFFF0D880)),
  'facilities':      DsModuleColor(bg: Color(0xFFD5DCF8), fg: Color(0xFF0F1F8E), border: Color(0xFFB8C3F0)),
  'community':       DsModuleColor(bg: Color(0xFFFBD9D4), fg: Color(0xFFE54A3E), border: Color(0xFFF5BFB8)),
  'documents':       DsModuleColor(bg: Color(0xFFCFE9DB), fg: Color(0xFF2E9A65), border: Color(0xFFB0D8C5)),
  'parking':         DsModuleColor(bg: Color(0xFFEBE4CF), fg: Color(0xFF3F3630), border: Color(0xFFD6CDB4)),
  'gallery':         DsModuleColor(bg: Color(0xFFF9EAB0), fg: Color(0xFFA57F0F), border: Color(0xFFF0D880)),
  'events':          DsModuleColor(bg: Color(0xFFD5DCF8), fg: Color(0xFF1A37C8), border: Color(0xFFB8C3F0)),
  'polls':           DsModuleColor(bg: Color(0xFFFBD9D4), fg: Color(0xFFE54A3E), border: Color(0xFFF5BFB8)),
  'water_tankers':   DsModuleColor(bg: Color(0xFFCFE9DB), fg: Color(0xFF2E9A65), border: Color(0xFFB0D8C5)),
  'vendors':         DsModuleColor(bg: Color(0xFFCFE9DB), fg: Color(0xFF2E9A65), border: Color(0xFFB0D8C5)),
  'maids':           DsModuleColor(bg: Color(0xFFF9EAB0), fg: Color(0xFFA57F0F), border: Color(0xFFF0D880)),
  'security_patrol': DsModuleColor(bg: Color(0xFFD5DCF8), fg: Color(0xFF1A37C8), border: Color(0xFFB8C3F0)),
  'members':         DsModuleColor(bg: Color(0xFFEBE4CF), fg: Color(0xFF3F3630), border: Color(0xFFD6CDB4)),
  'agm':             DsModuleColor(bg: Color(0xFFCFE9DB), fg: Color(0xFF2E9A65), border: Color(0xFFB0D8C5)),
  'policies':        DsModuleColor(bg: Color(0xFFD5DCF8), fg: Color(0xFF1A37C8), border: Color(0xFFB8C3F0)),
  'register':        DsModuleColor(bg: Color(0xFFF9EAB0), fg: Color(0xFFA57F0F), border: Color(0xFFF0D880)),
  'tenant_kyc':      DsModuleColor(bg: Color(0xFFCFE9DB), fg: Color(0xFF2E9A65), border: Color(0xFFB0D8C5)),
  'feedback':        DsModuleColor(bg: Color(0xFFF9EAB0), fg: Color(0xFFA57F0F), border: Color(0xFFF0D880)),
  'snags':           DsModuleColor(bg: Color(0xFFFBD9D4), fg: Color(0xFF9F2A20), border: Color(0xFFF5BFB8)),
  'letters':         DsModuleColor(bg: Color(0xFFD5DCF8), fg: Color(0xFF1A37C8), border: Color(0xFFB8C3F0)),
  'notifications':   DsModuleColor(bg: Color(0xFFD5DCF8), fg: Color(0xFF1A37C8), border: Color(0xFFB8C3F0)),
  'hoto':            DsModuleColor(bg: Color(0xFFCFE9DB), fg: Color(0xFF2E9A65), border: Color(0xFFB0D8C5)),
  'staff':           DsModuleColor(bg: Color(0xFFEBE4CF), fg: Color(0xFF3F3630), border: Color(0xFFD6CDB4)),
  'analytics':       DsModuleColor(bg: Color(0xFFD5DCF8), fg: Color(0xFF1A37C8), border: Color(0xFFB8C3F0)),
};
