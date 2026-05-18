import 'package:flutter/material.dart';
import '../ds_tokens.dart' show DsModuleColor;

/// Abstract contract every skin must satisfy.
/// Consumed by SkinContext.of(context) throughout the widget tree.
abstract class SkinTokens {
  // ── Surfaces ───────────────────────────────────────────────────────────────
  Color get background;
  Color get backgroundAlt;
  Color get surface;
  Color get surfaceAlt;
  Color get surfaceRaised;

  // ── Text ───────────────────────────────────────────────────────────────────
  Color get textPrimary;
  Color get textSecondary;
  Color get textTertiary;

  // ── Brand ──────────────────────────────────────────────────────────────────
  Color get accent;
  Color get accentSoft;
  Color get accentText;    // text placed ON accent-bg
  Color get warm;          // secondary signal (terracotta / saffron / ochre / brass)
  Color get warmSoft;

  // ── Borders ────────────────────────────────────────────────────────────────
  Color get border;
  Color get borderSoft;
  Color get borderStrong;

  // ── Status ─────────────────────────────────────────────────────────────────
  Color get statusGood;
  Color get statusGoodSoft;
  Color get statusWarn;
  Color get statusWarnSoft;
  Color get statusBad;
  Color get statusBadSoft;

  // ── Typography ─────────────────────────────────────────────────────────────
  /// Primary display / heading font family name (passed to GoogleFonts)
  String get fontDisplay;
  /// Body / UI sans-serif font family name
  String get fontBody;
  /// Monospace / data font family name
  String get fontMono;
  /// Whether display uses a serif face (affects heading style)
  bool get isSerifDisplay;

  // ── Shape ──────────────────────────────────────────────────────────────────
  double get radiusCard;
  double get radiusButton;
  double get radiusInput;
  double get radiusChip;

  // ── Module tile palette ─────────────────────────────────────────────────────
  DsModuleColor moduleColor(String key);

  // ── Brightness ─────────────────────────────────────────────────────────────
  Brightness get brightness;
  bool get isDark => brightness == Brightness.dark;
}
