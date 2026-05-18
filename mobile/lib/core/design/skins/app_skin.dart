import 'package:flutter/material.dart';

/// The six available skins (Classic = original UTAMACS theme + 5 COS skins).
///
/// [forcedBrightness] — when non-null, the skin only makes sense in that
/// brightness. The dark-mode toggle is hidden from Profile when set.
enum AppSkin {
  classic(
    id: 'classic',
    label: 'Classic',
    description: 'Original UTAMACS design · indigo + white',
    previewBg: Color(0xFFEEF2FF),
    previewAccent: Color(0xFF1E3A8A),
    previewSurface: Colors.white,
    forcedBrightness: null,
  ),
  vellum(
    id: 'vellum',
    label: 'Vellum',
    description: 'Editorial precision × warm humanism',
    previewBg: Color(0xFFF8F2E7),
    previewAccent: Color(0xFF2B2E8C),
    previewSurface: Colors.white,
    forcedBrightness: null,
  ),
  concourse(
    id: 'concourse',
    label: 'Concourse',
    description: 'Premium transit-board · midnight + saffron',
    previewBg: Color(0xFF0E1218),
    previewAccent: Color(0xFFE89236),
    previewSurface: Color(0xFF1B2230),
    forcedBrightness: Brightness.dark,
  ),
  verdant(
    id: 'verdant',
    label: 'Verdant',
    description: 'Warm botanical · cream + forest green',
    previewBg: Color(0xFFF8F2E2),
    previewAccent: Color(0xFF1F4A36),
    previewSurface: Colors.white,
    forcedBrightness: Brightness.light,
  ),
  riso(
    id: 'riso',
    label: 'Riso',
    description: 'Risograph print zine · cobalt + tomato',
    previewBg: Color(0xFFF4EFE0),
    previewAccent: Color(0xFF1A37C8),
    previewSurface: Color(0xFFF4EFE0),
    forcedBrightness: Brightness.light,
  ),
  atrium(
    id: 'atrium',
    label: 'Atrium',
    description: 'Boutique hospitality · linen + brass',
    previewBg: Color(0xFF1A1714),
    previewAccent: Color(0xFFC49A4A),
    previewSurface: Color(0xFF262220),
    forcedBrightness: Brightness.dark,
  );

  const AppSkin({
    required this.id,
    required this.label,
    required this.description,
    required this.previewBg,
    required this.previewAccent,
    required this.previewSurface,
    required this.forcedBrightness,
  });

  final String id;
  final String label;
  final String description;
  final Color previewBg;
  final Color previewAccent;
  final Color previewSurface;

  /// When non-null, the skin forces this brightness — dark mode toggle is hidden.
  final Brightness? forcedBrightness;

  bool get hasDarkModeToggle => forcedBrightness == null;

  /// Resolve the effective brightness for this skin given the user preference.
  Brightness effectiveBrightness(bool userDarkPreference) {
    if (forcedBrightness != null) return forcedBrightness!;
    return userDarkPreference ? Brightness.dark : Brightness.light;
  }

  static AppSkin fromId(String id) =>
      AppSkin.values.firstWhere((s) => s.id == id, orElse: () => AppSkin.classic);
}
