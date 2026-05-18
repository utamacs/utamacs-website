import 'package:flutter/material.dart';
import '../ds_tokens.dart' show DsModuleColor;
import 'skin_tokens.dart';

// =============================================================================
// Concourse — Premium transit-board · midnight + saffron
// Deep midnight bg, bone-cream boarding-pass surfaces, saffron accent.
// Fonts: Big Shoulders Display (display) + Sora (body) + JetBrains Mono
// Always dark — forcedBrightness: Brightness.dark
// =============================================================================

class ConcourseTokens implements SkinTokens {
  const ConcourseTokens();

  @override
  Brightness get brightness => Brightness.dark;
  @override bool get isDark => true;

  // Surfaces — dark dominant
  @override Color get background    => const Color(0xFF0E1218);
  @override Color get backgroundAlt => const Color(0xFF161B23);
  @override Color get surface       => const Color(0xFF1B2230);
  @override Color get surfaceAlt    => const Color(0xFF212835);
  @override Color get surfaceRaised => const Color(0xFF242C3A);

  // Text — light on dark
  @override Color get textPrimary   => const Color(0xFFF0EDE3);
  @override Color get textSecondary => const Color(0xFF9CA3B3);
  @override Color get textTertiary  => const Color(0xFF5A6072);

  // Brand — saffron
  @override Color get accent      => const Color(0xFFE89236);
  @override Color get accentSoft  => const Color(0xFF3A2A14);
  @override Color get accentText  => const Color(0xFF0A0C10);
  @override Color get warm        => const Color(0xFFF5A84B);
  @override Color get warmSoft    => const Color(0xFF2A1F0A);

  // Borders
  @override Color get border       => const Color(0xFF212835);
  @override Color get borderSoft   => const Color(0xFF191F2A);
  @override Color get borderStrong => const Color(0xFF2E3747);

  // Status
  @override Color get statusGood     => const Color(0xFF7DBD5C);
  @override Color get statusGoodSoft => const Color(0xFF1E3010);
  @override Color get statusWarn     => const Color(0xFFE89236);
  @override Color get statusWarnSoft => const Color(0xFF3A2A14);
  @override Color get statusBad      => const Color(0xFFE54B30);
  @override Color get statusBadSoft  => const Color(0xFF3D1812);

  // Typography
  @override String get fontDisplay    => 'Big Shoulders Display';
  @override String get fontBody       => 'Sora';
  @override String get fontMono       => 'JetBrains Mono';
  @override bool   get isSerifDisplay => false;

  // Shape — angular, tight
  @override double get radiusCard   => 12;
  @override double get radiusButton => 8;
  @override double get radiusInput  => 8;
  @override double get radiusChip   => 4;

  @override
  DsModuleColor moduleColor(String key) =>
      _concourseModuleColors[key] ??
      const DsModuleColor(bg: Color(0xFF212835), fg: Color(0xFF9CA3B3), border: Color(0xFF2E3747));
}

const Map<String, DsModuleColor> _concourseModuleColors = {
  'notices':         DsModuleColor(bg: Color(0xFF3A2A14), fg: Color(0xFFE89236), border: Color(0xFF4A3A20)),
  'visitors':        DsModuleColor(bg: Color(0xFF1E3010), fg: Color(0xFF7DBD5C), border: Color(0xFF2A4018)),
  'complaints':      DsModuleColor(bg: Color(0xFF3D1812), fg: Color(0xFFE54B30), border: Color(0xFF4D2820)),
  'finance':         DsModuleColor(bg: Color(0xFF3A2A14), fg: Color(0xFFF5A84B), border: Color(0xFF4A3A20)),
  'facilities':      DsModuleColor(bg: Color(0xFF152838), fg: Color(0xFF5BB8E5), border: Color(0xFF1F3848)),
  'community':       DsModuleColor(bg: Color(0xFF1E1B38), fg: Color(0xFF8B8DE5), border: Color(0xFF2E2B48)),
  'documents':       DsModuleColor(bg: Color(0xFF1E3010), fg: Color(0xFF7DBD5C), border: Color(0xFF2A4018)),
  'parking':         DsModuleColor(bg: Color(0xFF212835), fg: Color(0xFF9CA3B3), border: Color(0xFF2E3747)),
  'gallery':         DsModuleColor(bg: Color(0xFF3A2A14), fg: Color(0xFFE89236), border: Color(0xFF4A3A20)),
  'events':          DsModuleColor(bg: Color(0xFF3A2A14), fg: Color(0xFFF5A84B), border: Color(0xFF4A3A20)),
  'polls':           DsModuleColor(bg: Color(0xFF1E1B38), fg: Color(0xFF8B8DE5), border: Color(0xFF2E2B48)),
  'water_tankers':   DsModuleColor(bg: Color(0xFF152838), fg: Color(0xFF5BB8E5), border: Color(0xFF1F3848)),
  'vendors':         DsModuleColor(bg: Color(0xFF1E3010), fg: Color(0xFF7DBD5C), border: Color(0xFF2A4018)),
  'maids':           DsModuleColor(bg: Color(0xFF2A1F0A), fg: Color(0xFFE89236), border: Color(0xFF3A2F1A)),
  'security_patrol': DsModuleColor(bg: Color(0xFF3D1812), fg: Color(0xFFE54B30), border: Color(0xFF4D2820)),
  'members':         DsModuleColor(bg: Color(0xFF212835), fg: Color(0xFF9CA3B3), border: Color(0xFF2E3747)),
  'agm':             DsModuleColor(bg: Color(0xFF3A2A14), fg: Color(0xFFE89236), border: Color(0xFF4A3A20)),
  'policies':        DsModuleColor(bg: Color(0xFF212835), fg: Color(0xFF9CA3B3), border: Color(0xFF2E3747)),
  'register':        DsModuleColor(bg: Color(0xFF3A2A14), fg: Color(0xFFE89236), border: Color(0xFF4A3A20)),
  'tenant_kyc':      DsModuleColor(bg: Color(0xFF1E3010), fg: Color(0xFF7DBD5C), border: Color(0xFF2A4018)),
  'feedback':        DsModuleColor(bg: Color(0xFF2A1F0A), fg: Color(0xFFE89236), border: Color(0xFF3A2F1A)),
  'snags':           DsModuleColor(bg: Color(0xFF3D1812), fg: Color(0xFFE54B30), border: Color(0xFF4D2820)),
  'letters':         DsModuleColor(bg: Color(0xFF1E1B38), fg: Color(0xFF8B8DE5), border: Color(0xFF2E2B48)),
  'notifications':   DsModuleColor(bg: Color(0xFF3A2A14), fg: Color(0xFFE89236), border: Color(0xFF4A3A20)),
  'hoto':            DsModuleColor(bg: Color(0xFF1E3010), fg: Color(0xFF7DBD5C), border: Color(0xFF2A4018)),
  'staff':           DsModuleColor(bg: Color(0xFF212835), fg: Color(0xFF9CA3B3), border: Color(0xFF2E3747)),
  'analytics':       DsModuleColor(bg: Color(0xFF3A2A14), fg: Color(0xFFE89236), border: Color(0xFF4A3A20)),
};
