import 'package:flutter/material.dart';
import 'ds_tokens.dart';

// ============================================================================
// UTAMACS Design System — Typography & Icon Scale System
// Three accessibility tiers: A (Small) · A+ (Medium/Default) · A++ (Large)
// Applied globally via MediaQuery.textScaler override at the app root.
// ============================================================================

// ─── Scale Enum ──────────────────────────────────────────────────────────────

enum DsTextScale {
  small,   // A    — compact,  0.88×
  medium,  // A+   — default,  1.00×
  large,   // A++  — large,    1.20×
}

extension DsTextScaleX on DsTextScale {
  // Human-readable labels
  String get label => switch (this) {
    DsTextScale.small  => 'A',
    DsTextScale.medium => 'A+',
    DsTextScale.large  => 'A++',
  };

  String get description => switch (this) {
    DsTextScale.small  => 'Compact — fits more on screen',
    DsTextScale.medium => 'Default — balanced for all users',
    DsTextScale.large  => 'Accessible — larger text & icons',
  };

  // Text scale factor applied to MediaQuery.textScaler
  double get textFactor => switch (this) {
    DsTextScale.small  => 0.88,
    DsTextScale.medium => 1.00,
    DsTextScale.large  => 1.20,
  };

  // Icon size multiplier (applied via context.si())
  double get iconFactor => switch (this) {
    DsTextScale.small  => 0.88,
    DsTextScale.medium => 1.00,
    DsTextScale.large  => 1.15,
  };

  // Spacing multiplier (applied via context.ss())
  double get spaceFactor => switch (this) {
    DsTextScale.small  => 0.92,
    DsTextScale.medium => 1.00,
    DsTextScale.large  => 1.10,
  };

  // Persisted integer key
  int get storageIndex => index;
  static DsTextScale fromIndex(int i) =>
      DsTextScale.values.elementAtOrNull(i) ?? DsTextScale.medium;
}

// ─── InheritedWidget ─────────────────────────────────────────────────────────
// Placed at the root so every widget can read the current scale without
// digging through BuildContext ancestors manually.

class DsScaleScope extends InheritedWidget {
  final DsTextScale scale;

  const DsScaleScope({
    super.key,
    required this.scale,
    required super.child,
  });

  static DsTextScale of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<DsScaleScope>()
            ?.scale ??
        DsTextScale.medium;
  }

  @override
  bool updateShouldNotify(DsScaleScope old) => scale != old.scale;
}

// ─── BuildContext Extensions ──────────────────────────────────────────────────
// Usage:
//   context.sp(14)   → scaled font size
//   context.si(24)   → scaled icon size
//   context.ss(16)   → scaled spacing value

extension DsScaleContext on BuildContext {
  DsTextScale get dsScale => DsScaleScope.of(this);

  // Scaled font size
  double sp(double base) => base * dsScale.textFactor;

  // Scaled icon size
  double si(double base) => base * dsScale.iconFactor;

  // Scaled spacing
  double ss(double base) => base * dsScale.spaceFactor;
}

// ─── Scale-Aware TextStyles ───────────────────────────────────────────────────
// Returns a full TextTheme scaled to the given DsTextScale.
// Used in the app builder to override MediaQuery.textScaler.

TextScaler dsTextScaler(DsTextScale scale) =>
    TextScaler.linear(scale.textFactor);

// ─── Typography Size Reference Table ─────────────────────────────────────────
// These are the raw base sizes (at A+/medium = 1.0).
// After MediaQuery.textScaler, Flutter automatically scales all Text widgets.

class DsFontSizes {
  // Display / Hero
  static const double displayLg = 36;
  static const double displayMd = 28;
  static const double displaySm = 22;

  // Headings
  static const double headingLg = 20;
  static const double headingMd = 18;
  static const double headingSm = 16;

  // Titles
  static const double titleLg = 16;
  static const double titleMd = 14;
  static const double titleSm = 13;

  // Body
  static const double bodyLg = 16;
  static const double bodyMd = 14;
  static const double bodySm = 12;

  // Labels / UI chrome
  static const double labelLg = 14;
  static const double labelMd = 12;
  static const double labelSm = 11;
  static const double micro  = 10;
}

// ─── Icon Size Reference Table ────────────────────────────────────────────────
// Base sizes (at A+/medium). Multiply by dsScale.iconFactor in DSIcon.

class DsIconSizes {
  static const double xs  = 14; // inline in text, badge icons
  static const double sm  = 16; // secondary row icons
  static const double md  = 20; // standard UI icons
  static const double lg  = 24; // app bar, nav bar
  static const double xl  = 28; // card header icons
  static const double xxl = 32; // hero/feature icons
  static const double hero = 40; // empty state, onboarding
}

// ─── Scale Demonstration Widget ───────────────────────────────────────────────
// Used on the Profile screen scale picker.

class DsScaleSampleText extends StatelessWidget {
  final DsTextScale scale;
  final bool isSelected;

  const DsScaleSampleText({
    super.key,
    required this.scale,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final factor = scale.textFactor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aa',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 26 * factor,
            fontWeight: FontWeight.w700,
            color: isSelected ? dsColorIndigo600 : dsTextPrimary,
            height: 1.1,
          ),
        ),
        Text(
          'Society update',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13 * factor,
            fontWeight: FontWeight.w500,
            color: isSelected ? dsColorIndigo500 : dsTextSecondary,
          ),
        ),
        Text(
          'Payment due ₹2,500',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11 * factor,
            color: isSelected ? dsColorIndigo400 : dsTextTertiary,
          ),
        ),
      ],
    );
  }
}
