import 'package:flutter/material.dart';

// ============================================================================
// UTAMACS Design System — "Residences" Design Language v2.0
// Token hierarchy: Primitive → Semantic → Component
// ============================================================================

// ─── PRIMITIVE COLOR TOKENS ─────────────────────────────────────────────────

// Indigo family (brand primary)
const Color dsColorIndigo950 = Color(0xFF080F2E);
const Color dsColorIndigo900 = Color(0xFF0F1F5C);
const Color dsColorIndigo800 = Color(0xFF162462);
const Color dsColorIndigo700 = Color(0xFF1A2F87);
const Color dsColorIndigo600 = Color(0xFF1E3A8A); // ← matches kPrimary600
const Color dsColorIndigo500 = Color(0xFF3352A8);
const Color dsColorIndigo400 = Color(0xFF4B6FCA);
const Color dsColorIndigo300 = Color(0xFF7F96D4);
const Color dsColorIndigo200 = Color(0xFFB3C1E8);
const Color dsColorIndigo100 = Color(0xFFD6DEFA);
const Color dsColorIndigo50  = Color(0xFFEEF2FF);
const Color dsColorIndigo25  = Color(0xFFF7F9FF);

// Emerald family (success / secondary actions)
const Color dsColorEmerald700 = Color(0xFF047857);
const Color dsColorEmerald600 = Color(0xFF059669);
const Color dsColorEmerald500 = Color(0xFF10B981); // ← matches kSecondary500
const Color dsColorEmerald400 = Color(0xFF34D399);
const Color dsColorEmerald100 = Color(0xFFD1FAE5);
const Color dsColorEmerald50  = Color(0xFFECFDF5);

// Amber family (warnings / attention)
const Color dsColorAmber700 = Color(0xFFB45309);
const Color dsColorAmber600 = Color(0xFFD97706);
const Color dsColorAmber500 = Color(0xFFF59E0B); // ← matches kAccent500
const Color dsColorAmber300 = Color(0xFFFCD34D);
const Color dsColorAmber100 = Color(0xFFFDE68A);
const Color dsColorAmber50  = Color(0xFFFFFBEB);

// Terracotta family (warm secondary accent — unique to Residences language)
const Color dsColorTerra700 = Color(0xFF9A3412);
const Color dsColorTerra600 = Color(0xFFC2410C);
const Color dsColorTerra500 = Color(0xFFEA580C);
const Color dsColorTerra400 = Color(0xFFFB923C);
const Color dsColorTerra100 = Color(0xFFFFEDD5);
const Color dsColorTerra50  = Color(0xFFFFF7ED);

// Red family (error / destructive)
const Color dsColorRed700 = Color(0xFFB91C1C);
const Color dsColorRed600 = Color(0xFFDC2626); // ← matches kRed600
const Color dsColorRed500 = Color(0xFFEF4444);
const Color dsColorRed100 = Color(0xFFFEE2E2);
const Color dsColorRed50  = Color(0xFFFEF2F2);

// Sky family (informational)
const Color dsColorSky700 = Color(0xFF0369A1);
const Color dsColorSky600 = Color(0xFF0284C7);
const Color dsColorSky500 = Color(0xFF0EA5E9);
const Color dsColorSky100 = Color(0xFFE0F2FE);
const Color dsColorSky50  = Color(0xFFF0F9FF);

// Violet family (special / creative features)
const Color dsColorViolet700 = Color(0xFF6D28D9);
const Color dsColorViolet600 = Color(0xFF7C3AED);
const Color dsColorViolet500 = Color(0xFF8B5CF6);
const Color dsColorViolet100 = Color(0xFFEDE9FE);
const Color dsColorViolet50  = Color(0xFFF5F3FF);

// Teal family (community/social)
const Color dsColorTeal700 = Color(0xFF0F766E);
const Color dsColorTeal600 = Color(0xFF0D9488);
const Color dsColorTeal500 = Color(0xFF14B8A6);
const Color dsColorTeal100 = Color(0xFFCCFBF1);
const Color dsColorTeal50  = Color(0xFFF0FDFA);

// Slate neutral family
const Color dsColorSlate950 = Color(0xFF020617);
const Color dsColorSlate900 = Color(0xFF0F172A);
const Color dsColorSlate800 = Color(0xFF1E293B);
const Color dsColorSlate700 = Color(0xFF334155);
const Color dsColorSlate600 = Color(0xFF475569);
const Color dsColorSlate500 = Color(0xFF64748B);
const Color dsColorSlate400 = Color(0xFF94A3B8);
const Color dsColorSlate300 = Color(0xFFCBD5E1);
const Color dsColorSlate200 = Color(0xFFE2E8F0);
const Color dsColorSlate100 = Color(0xFFF1F5F9);
const Color dsColorSlate50  = Color(0xFFF8FAFC);

// ─── SEMANTIC COLOR TOKENS (Light Mode) ─────────────────────────────────────

// Brand
const Color dsBrandPrimary      = dsColorIndigo600;
const Color dsBrandPrimaryLight = dsColorIndigo50;
const Color dsBrandPrimaryDark  = dsColorIndigo800;
const Color dsBrandAccent       = dsColorAmber500;

// Status
const Color dsStatusSuccess      = dsColorEmerald500;
const Color dsStatusSuccessLight = dsColorEmerald50;
const Color dsStatusSuccessDark  = dsColorEmerald700;
const Color dsStatusWarning      = dsColorAmber500;
const Color dsStatusWarningLight = dsColorAmber50;
const Color dsStatusWarningDark  = dsColorAmber700;
const Color dsStatusError        = dsColorRed600;
const Color dsStatusErrorLight   = dsColorRed50;
const Color dsStatusErrorDark    = dsColorRed700;
const Color dsStatusInfo         = dsColorSky500;
const Color dsStatusInfoLight    = dsColorSky50;
const Color dsStatusInfoDark     = dsColorSky700;

// Surface (light mode)
const Color dsBackground      = Color(0xFFEEF2FF); // soft indigo-tinted canvas
const Color dsSurface         = Color(0xFFFFFFFF); // card / sheet surface
const Color dsSurfaceElevated = Color(0xFFFFFFFF); // raised surfaces
const Color dsSurfaceMuted    = Color(0xFFF8FAFC); // subtle alternating bg
const Color dsSurfaceOverlay  = Color(0x0A1E3A8A); // 4% indigo tint overlay

// Text (light mode)
const Color dsTextPrimary   = dsColorSlate900;   // main body text
const Color dsTextSecondary = dsColorSlate500;   // supporting text
const Color dsTextTertiary  = dsColorSlate400;   // placeholders / muted
const Color dsTextInverse   = Color(0xFFFFFFFF); // on dark surfaces
const Color dsTextBrand     = dsColorIndigo600;  // brand-colored text
const Color dsTextLink      = dsColorIndigo600;  // links

// Border (light mode)
const Color dsBorderSubtle  = dsColorSlate100; // very faint dividers
const Color dsBorderLight   = dsColorSlate200; // standard borders
const Color dsBorderDefault = dsColorSlate300; // stronger borders
const Color dsBorderFocus   = dsColorIndigo600; // focus ring
const Color dsBorderBrand   = dsColorIndigo200; // brand-tinted borders

// Dark mode surfaces
const Color dsDarkBackground      = Color(0xFF070B17);
const Color dsDarkSurface         = Color(0xFF0E1424);
const Color dsDarkSurfaceElevated = Color(0xFF151D33);
const Color dsDarkSurfaceMuted    = Color(0xFF1A2240);
const Color dsDarkBorderSubtle    = Color(0xFF1E2846);
const Color dsDarkBorderLight     = Color(0xFF252F4D);
const Color dsDarkTextPrimary     = Color(0xFFEEF2FF);
const Color dsDarkTextSecondary   = Color(0xFF8A99C5);
const Color dsDarkTextTertiary    = Color(0xFF5A6A9B);

// ─── SPACING TOKENS (4pt grid) ───────────────────────────────────────────────

const double dsSpace1  = 4.0;
const double dsSpace2  = 8.0;
const double dsSpace3  = 12.0;
const double dsSpace4  = 16.0;
const double dsSpace5  = 20.0;
const double dsSpace6  = 24.0;
const double dsSpace8  = 32.0;
const double dsSpace10 = 40.0;
const double dsSpace12 = 48.0;
const double dsSpace16 = 64.0;
const double dsSpace20 = 80.0;

// Semantic spacing aliases
const double dsSpacePagePadding   = dsSpace4; // 16 — standard page horizontal padding
const double dsSpaceCardPadding   = dsSpace4; // 16 — card internal padding
const double dsSpaceCardPaddingLg = dsSpace5; // 20 — large card padding
const double dsSpaceItemGap       = dsSpace2; // 8  — gap between list items
const double dsSpaceSectionGap    = dsSpace6; // 24 — gap between sections
const double dsSpaceIconGap       = dsSpace2; // 8  — icon-to-label gap

// ─── BORDER RADIUS TOKENS ────────────────────────────────────────────────────

const double dsRadiusXs   = 4.0;
const double dsRadiusSm   = 8.0;
const double dsRadiusMd   = 12.0;
const double dsRadiusLg   = 16.0;
const double dsRadiusXl   = 20.0;
const double dsRadiusXxl  = 24.0;
const double dsRadiusFull = 999.0;

// Semantic aliases
const double dsRadiusButton  = dsRadiusMd; // 12 — all buttons
const double dsRadiusCard    = dsRadiusLg; // 16 — standard cards
const double dsRadiusCardLg  = dsRadiusXl; // 20 — featured/hero cards
const double dsRadiusChip    = dsRadiusFull; // pill chips
const double dsRadiusInput   = dsRadiusMd; // 12 — text inputs
const double dsRadiusBadge   = dsRadiusSm; // 8  — status badges
const double dsRadiusAvatar  = dsRadiusFull;
const double dsRadiusIcon    = dsRadiusSm; // 8  — icon containers (sm)
const double dsRadiusIconMd  = dsRadiusMd; // 12 — icon containers (md)

// ─── ELEVATION / SHADOW TOKENS ───────────────────────────────────────────────

List<BoxShadow> dsShadowNone = [];

List<BoxShadow> dsShadowXs = [
  BoxShadow(
    color: const Color(0xFF000000).withValues(alpha: 0.04),
    blurRadius: 4,
    offset: const Offset(0, 1),
  ),
];

List<BoxShadow> dsShadowSm = [
  BoxShadow(
    color: const Color(0xFF000000).withValues(alpha: 0.05),
    blurRadius: 8,
    offset: const Offset(0, 2),
  ),
  BoxShadow(
    color: const Color(0xFF000000).withValues(alpha: 0.03),
    blurRadius: 3,
    offset: const Offset(0, 1),
  ),
];

List<BoxShadow> dsShadowMd = [
  BoxShadow(
    color: const Color(0xFF000000).withValues(alpha: 0.07),
    blurRadius: 16,
    offset: const Offset(0, 4),
  ),
  BoxShadow(
    color: const Color(0xFF000000).withValues(alpha: 0.04),
    blurRadius: 6,
    offset: const Offset(0, 2),
  ),
];

List<BoxShadow> dsShadowLg = [
  BoxShadow(
    color: const Color(0xFF000000).withValues(alpha: 0.09),
    blurRadius: 32,
    offset: const Offset(0, 8),
  ),
  BoxShadow(
    color: const Color(0xFF000000).withValues(alpha: 0.05),
    blurRadius: 12,
    offset: const Offset(0, 3),
  ),
];

List<BoxShadow> dsShadowXl = [
  BoxShadow(
    color: const Color(0xFF000000).withValues(alpha: 0.12),
    blurRadius: 48,
    offset: const Offset(0, 16),
  ),
  BoxShadow(
    color: const Color(0xFF000000).withValues(alpha: 0.06),
    blurRadius: 16,
    offset: const Offset(0, 4),
  ),
];

// Brand-colored CTA shadow
List<BoxShadow> dsShadowBrand = [
  BoxShadow(
    color: dsColorIndigo600.withValues(alpha: 0.28),
    blurRadius: 20,
    spreadRadius: 0,
    offset: const Offset(0, 6),
  ),
];

// Success-colored shadow
List<BoxShadow> dsShadowSuccess = [
  BoxShadow(
    color: dsColorEmerald500.withValues(alpha: 0.25),
    blurRadius: 16,
    spreadRadius: 0,
    offset: const Offset(0, 4),
  ),
];

// ─── GRADIENT TOKENS ─────────────────────────────────────────────────────────

// Hero header gradient (used on dashboard)
const LinearGradient dsGradientHero = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF162462), // indigo-800
    Color(0xFF1E3A8A), // indigo-600
    Color(0xFF1A3370), // slightly different midpoint for depth
  ],
  stops: [0.0, 0.65, 1.0],
);

// Subtle page background gradient
const LinearGradient dsGradientPageBg = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFFEEF2FF), // indigo-50
    Color(0xFFF8FAFC), // slate-50
  ],
);

// Guard mode header gradient
const LinearGradient dsGradientGuard = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0F766E), Color(0xFF059669)],
);

// ─── DURATION TOKENS ─────────────────────────────────────────────────────────

const Duration dsDurationInstant   = Duration(milliseconds: 80);
const Duration dsDurationFast      = Duration(milliseconds: 150);
const Duration dsDurationNormal    = Duration(milliseconds: 250);
const Duration dsDurationSlow      = Duration(milliseconds: 380);
const Duration dsDurationVerySlow  = Duration(milliseconds: 500);
const Duration dsDurationPageTrans = Duration(milliseconds: 320);

// ─── ICON SIZE TOKENS ────────────────────────────────────────────────────────

const double dsIconXs  = 14.0;
const double dsIconSm  = 16.0;
const double dsIconMd  = 20.0;
const double dsIconLg  = 24.0;
const double dsIconXl  = 28.0;
const double dsIconXxl = 32.0;
const double dsIconHero = 40.0;

// ─── ELEVATION LEVELS ────────────────────────────────────────────────────────

// Maps conceptual levels to shadow lists
List<BoxShadow> dsElevation(int level) => switch (level) {
  0 => dsShadowNone,
  1 => dsShadowXs,
  2 => dsShadowSm,
  3 => dsShadowMd,
  4 => dsShadowLg,
  5 => dsShadowXl,
  _ => dsShadowMd,
};

// ─── SERVICE / MODULE COLOR PALETTE ──────────────────────────────────────────
// Consistent semantic color assignments for all 27 modules

class DsModuleColor {
  final Color bg;     // tile background
  final Color fg;     // icon color
  final Color border; // optional subtle border
  const DsModuleColor({required this.bg, required this.fg, required this.border});
}

const Map<String, DsModuleColor> dsModuleColors = {
  'notices':         DsModuleColor(bg: Color(0xFFEEF2FF), fg: Color(0xFF1E3A8A), border: Color(0xFFD6DEFA)),
  'visitors':        DsModuleColor(bg: Color(0xFFECFDF5), fg: Color(0xFF059669), border: Color(0xFFD1FAE5)),
  'complaints':      DsModuleColor(bg: Color(0xFFFEF2F2), fg: Color(0xFFDC2626), border: Color(0xFFFEE2E2)),
  'finance':         DsModuleColor(bg: Color(0xFFFFFBEB), fg: Color(0xFFD97706), border: Color(0xFFFDE68A)),
  'facilities':      DsModuleColor(bg: Color(0xFFF0F9FF), fg: Color(0xFF0284C7), border: Color(0xFFE0F2FE)),
  'community':       DsModuleColor(bg: Color(0xFFF5F3FF), fg: Color(0xFF7C3AED), border: Color(0xFFEDE9FE)),
  'documents':       DsModuleColor(bg: Color(0xFFECFDF5), fg: Color(0xFF047857), border: Color(0xFFD1FAE5)),
  'parking':         DsModuleColor(bg: Color(0xFFF8FAFC), fg: Color(0xFF334155), border: Color(0xFFE2E8F0)),
  'gallery':         DsModuleColor(bg: Color(0xFFFFFBEB), fg: Color(0xFFB45309), border: Color(0xFFFDE68A)),
  'events':          DsModuleColor(bg: Color(0xFFF0F9FF), fg: Color(0xFF0369A1), border: Color(0xFFE0F2FE)),
  'polls':           DsModuleColor(bg: Color(0xFFF5F3FF), fg: Color(0xFF6D28D9), border: Color(0xFFEDE9FE)),
  'water_tankers':   DsModuleColor(bg: Color(0xFFF0FDFA), fg: Color(0xFF0D9488), border: Color(0xFFCCFBF1)),
  'vendors':         DsModuleColor(bg: Color(0xFFECFDF5), fg: Color(0xFF059669), border: Color(0xFFD1FAE5)),
  'maids':           DsModuleColor(bg: Color(0xFFFFF7ED), fg: Color(0xFFEA580C), border: Color(0xFFFFEDD5)),
  'security_patrol': DsModuleColor(bg: Color(0xFFEEF2FF), fg: Color(0xFF1A2F87), border: Color(0xFFD6DEFA)),
  'members':         DsModuleColor(bg: Color(0xFFF8FAFC), fg: Color(0xFF475569), border: Color(0xFFE2E8F0)),
  'agm':             DsModuleColor(bg: Color(0xFFECFDF5), fg: Color(0xFF166534), border: Color(0xFFD1FAE5)),
  'policies':        DsModuleColor(bg: Color(0xFFEEF2FF), fg: Color(0xFF1E3A8A), border: Color(0xFFD6DEFA)),
  'register':        DsModuleColor(bg: Color(0xFFFFFBEB), fg: Color(0xFF92400E), border: Color(0xFFFDE68A)),
  'tenant_kyc':      DsModuleColor(bg: Color(0xFFECFDF5), fg: Color(0xFF065F46), border: Color(0xFFD1FAE5)),
  'feedback':        DsModuleColor(bg: Color(0xFFFFFBEB), fg: Color(0xFFD97706), border: Color(0xFFFDE68A)),
  'snags':           DsModuleColor(bg: Color(0xFFFEF2F2), fg: Color(0xFFDC2626), border: Color(0xFFFEE2E2)),
  'letters':         DsModuleColor(bg: Color(0xFFF5F3FF), fg: Color(0xFF6D28D9), border: Color(0xFFEDE9FE)),
  'notifications':   DsModuleColor(bg: Color(0xFFF0F9FF), fg: Color(0xFF0369A1), border: Color(0xFFE0F2FE)),
  'hoto':            DsModuleColor(bg: Color(0xFFECFDF5), fg: Color(0xFF15803D), border: Color(0xFFD1FAE5)),
  'staff':           DsModuleColor(bg: Color(0xFFF8FAFC), fg: Color(0xFF374151), border: Color(0xFFE2E8F0)),
  'analytics':       DsModuleColor(bg: Color(0xFFEEF2FF), fg: Color(0xFF1E3A8A), border: Color(0xFFD6DEFA)),
};

DsModuleColor dsGetModuleColor(String key) =>
    dsModuleColors[key] ??
    const DsModuleColor(bg: Color(0xFFF8FAFC), fg: Color(0xFF64748B), border: Color(0xFFE2E8F0));
