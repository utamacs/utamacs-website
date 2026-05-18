import 'package:flutter/material.dart';

// Breakpoints aligned with Material 3 adaptive layout guidance.
// Phone:  < 600 dp  → bottom navigation bar
// Tablet: ≥ 600 dp  → navigation rail (compact, no labels by default)
// Desktop/large tablet: ≥ 1200 dp → expanded navigation drawer

const double kTabletBreakpoint = 600.0;
const double kDesktopBreakpoint = 1200.0;

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isPhone   => screenWidth < kTabletBreakpoint;
  bool get isTablet  => screenWidth >= kTabletBreakpoint && screenWidth < kDesktopBreakpoint;
  bool get isDesktop => screenWidth >= kDesktopBreakpoint;

  /// True when a navigation rail / side drawer is preferred over a bottom bar.
  bool get useSideNav => !isPhone;
}
