import 'package:flutter/material.dart';
import '../ds_tokens.dart' show DsModuleColor;
import 'skin_tokens.dart';

// =============================================================================
// Vellum — Editorial precision × warm humanism
// Warm vellum canvas, deep cobalt-indigo accent, terracotta warm signal.
// Fonts: Instrument Serif (display) + Plus Jakarta Sans (body) + JetBrains Mono
// Supports both light and dark.
// =============================================================================

class VellumTokens implements SkinTokens {
  const VellumTokens({this.brightness = Brightness.light});

  @override
  final Brightness brightness;

  bool get _d => brightness == Brightness.dark;
  @override bool get isDark => _d;

  // Surfaces
  @override Color get background    => _d ? const Color(0xFF0B0C0F) : const Color(0xFFF8F2E7);
  @override Color get backgroundAlt => _d ? const Color(0xFF121418) : const Color(0xFFF2EAD9);
  @override Color get surface       => _d ? const Color(0xFF15171C) : const Color(0xFFFFFFFF);
  @override Color get surfaceAlt    => _d ? const Color(0xFF1B1E25) : const Color(0xFFF8F5EE);
  @override Color get surfaceRaised => _d ? const Color(0xFF1E2129) : const Color(0xFFFDFAF5);

  // Text
  @override Color get textPrimary   => _d ? const Color(0xFFEFECE5) : const Color(0xFF1A1B2E);
  @override Color get textSecondary => _d ? const Color(0xFF8C8F99) : const Color(0xFF6B6C8A);
  @override Color get textTertiary  => _d ? const Color(0xFF5A5E69) : const Color(0xFFA8A9C0);

  // Brand
  @override Color get accent      => _d ? const Color(0xFFA0AEFF) : const Color(0xFF2B2E8C);
  @override Color get accentSoft  => _d ? const Color(0xFF2A2F70) : const Color(0xFFE8E9F8);
  @override Color get accentText  => _d ? const Color(0xFF0B0C0F) : const Color(0xFFFFFFFF);
  @override Color get warm        => _d ? const Color(0xFFE5A858) : const Color(0xFFC07830);
  @override Color get warmSoft    => _d ? const Color(0xFF3A2510) : const Color(0xFFF8EDD8);

  // Borders
  @override Color get border       => _d ? const Color(0xFF23262E) : const Color(0xFFEBE5D9);
  @override Color get borderSoft   => _d ? const Color(0xFF1B1E25) : const Color(0xFFF2EDE5);
  @override Color get borderStrong => _d ? const Color(0xFF333740) : const Color(0xFFDDD7C8);

  // Status
  @override Color get statusGood     => const Color(0xFF2F7A55);
  @override Color get statusGoodSoft => _d ? const Color(0xFF1A3D2B) : const Color(0xFFE5F5EC);
  @override Color get statusWarn     => const Color(0xFFA07820);
  @override Color get statusWarnSoft => _d ? const Color(0xFF3A2D10) : const Color(0xFFF8F0D5);
  @override Color get statusBad      => const Color(0xFFB83A2A);
  @override Color get statusBadSoft  => _d ? const Color(0xFF3D1812) : const Color(0xFFFBE8E5);

  // Typography
  @override String get fontDisplay      => 'Instrument Serif';
  @override String get fontBody         => 'Plus Jakarta Sans';
  @override String get fontMono         => 'JetBrains Mono';
  @override bool   get isSerifDisplay   => true;

  // Shape
  @override double get radiusCard   => 20;
  @override double get radiusButton => 16;
  @override double get radiusInput  => 12;
  @override double get radiusChip   => 100;

  // Module colors — cobalt-indigo family adapted to vellum palette
  @override
  DsModuleColor moduleColor(String key) =>
      _vellumModuleColors[key] ??
      const DsModuleColor(bg: Color(0xFFF8F5EE), fg: Color(0xFF6B6C8A), border: Color(0xFFEBE5D9));
}

const Map<String, DsModuleColor> _vellumModuleColors = {
  'notices':         DsModuleColor(bg: Color(0xFFE8E9F8), fg: Color(0xFF2B2E8C), border: Color(0xFFD0D2F0)),
  'visitors':        DsModuleColor(bg: Color(0xFFE5F5EC), fg: Color(0xFF2F7A55), border: Color(0xFFCAEDD8)),
  'complaints':      DsModuleColor(bg: Color(0xFFFBE8E5), fg: Color(0xFFB83A2A), border: Color(0xFFF5CFC8)),
  'finance':         DsModuleColor(bg: Color(0xFFF8EDD8), fg: Color(0xFFC07830), border: Color(0xFFF0D8B4)),
  'facilities':      DsModuleColor(bg: Color(0xFFE0F2FE), fg: Color(0xFF0369A1), border: Color(0xFFBAE0FB)),
  'community':       DsModuleColor(bg: Color(0xFFEDE9FE), fg: Color(0xFF5B21B6), border: Color(0xFFD8D0FC)),
  'documents':       DsModuleColor(bg: Color(0xFFE5F5EC), fg: Color(0xFF166534), border: Color(0xFFCAEDD8)),
  'parking':         DsModuleColor(bg: Color(0xFFF8F5EE), fg: Color(0xFF4A4B60), border: Color(0xFFEBE5D9)),
  'gallery':         DsModuleColor(bg: Color(0xFFF8EDD8), fg: Color(0xFF9E5B22), border: Color(0xFFF0D8B4)),
  'events':          DsModuleColor(bg: Color(0xFFE8E9F8), fg: Color(0xFF1A2F87), border: Color(0xFFD0D2F0)),
  'polls':           DsModuleColor(bg: Color(0xFFEDE9FE), fg: Color(0xFF4C1D95), border: Color(0xFFD8D0FC)),
  'water_tankers':   DsModuleColor(bg: Color(0xFFCCFBF1), fg: Color(0xFF0D9488), border: Color(0xFFA8F0E4)),
  'vendors':         DsModuleColor(bg: Color(0xFFE5F5EC), fg: Color(0xFF2F7A55), border: Color(0xFFCAEDD8)),
  'maids':           DsModuleColor(bg: Color(0xFFFFF3E0), fg: Color(0xFFC07830), border: Color(0xFFFFDDB4)),
  'security_patrol': DsModuleColor(bg: Color(0xFFE8E9F8), fg: Color(0xFF2B2E8C), border: Color(0xFFD0D2F0)),
  'members':         DsModuleColor(bg: Color(0xFFF8F5EE), fg: Color(0xFF4A4B60), border: Color(0xFFEBE5D9)),
  'agm':             DsModuleColor(bg: Color(0xFFE5F5EC), fg: Color(0xFF166534), border: Color(0xFFCAEDD8)),
  'policies':        DsModuleColor(bg: Color(0xFFE8E9F8), fg: Color(0xFF2B2E8C), border: Color(0xFFD0D2F0)),
  'register':        DsModuleColor(bg: Color(0xFFF8EDD8), fg: Color(0xFF9E5B22), border: Color(0xFFF0D8B4)),
  'tenant_kyc':      DsModuleColor(bg: Color(0xFFE5F5EC), fg: Color(0xFF166534), border: Color(0xFFCAEDD8)),
  'feedback':        DsModuleColor(bg: Color(0xFFF8EDD8), fg: Color(0xFFC07830), border: Color(0xFFF0D8B4)),
  'snags':           DsModuleColor(bg: Color(0xFFFBE8E5), fg: Color(0xFFB83A2A), border: Color(0xFFF5CFC8)),
  'letters':         DsModuleColor(bg: Color(0xFFEDE9FE), fg: Color(0xFF5B21B6), border: Color(0xFFD8D0FC)),
  'notifications':   DsModuleColor(bg: Color(0xFFE8E9F8), fg: Color(0xFF2B2E8C), border: Color(0xFFD0D2F0)),
  'hoto':            DsModuleColor(bg: Color(0xFFE5F5EC), fg: Color(0xFF166534), border: Color(0xFFCAEDD8)),
  'staff':           DsModuleColor(bg: Color(0xFFF8F5EE), fg: Color(0xFF4A4B60), border: Color(0xFFEBE5D9)),
  'analytics':       DsModuleColor(bg: Color(0xFFE8E9F8), fg: Color(0xFF2B2E8C), border: Color(0xFFD0D2F0)),
};
