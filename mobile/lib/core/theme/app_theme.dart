// ============================================================================
// Backward-compatibility shim.
// All portal screens import this file for k* constants.
// These re-export the canonical design-system tokens so existing screens
// compile without modification while the DS migration proceeds.
// ============================================================================

export '../design/ds_tokens.dart';
export '../design/ds_theme.dart';
export '../design/ds_components.dart';
export '../design/ds_animations.dart';

import 'package:flutter/material.dart';
import '../design/ds_tokens.dart';
import '../design/ds_theme.dart';

// k* aliases (map to DS tokens — keep these for existing screen imports)
const Color kPrimary600    = dsColorIndigo600;
const Color kPrimary100    = dsColorIndigo100;
const Color kPrimary50     = dsColorIndigo50;
const Color kSecondary500  = dsColorEmerald500;
const Color kAccent500     = dsColorAmber500;
const Color kTextPrimary   = dsTextPrimary;
const Color kTextSecondary = dsTextSecondary;
const Color kBorderLight   = dsBorderLight;
const Color kSectionAlt    = dsSurfaceMuted;
const Color kRed600        = dsColorRed600;
const Color kBgWarm        = dsBackground;

// Legacy theme export
final appTheme = dsLightTheme;
