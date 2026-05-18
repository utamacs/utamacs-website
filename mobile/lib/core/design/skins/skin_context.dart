import 'package:flutter/material.dart';
import 'skin_tokens.dart';

/// Provides [SkinTokens] to the widget tree.
/// Wrap MaterialApp (or any subtree) to make the active skin accessible everywhere.
class SkinContext extends InheritedWidget {
  const SkinContext({
    super.key,
    required this.tokens,
    required super.child,
  });

  final SkinTokens tokens;

  /// Access the active [SkinTokens] from any widget in the tree.
  static SkinTokens of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<SkinContext>();
    assert(result != null, 'SkinContext not found — wrap your MaterialApp with SkinContext');
    return result!.tokens;
  }

  /// Returns null if no [SkinContext] is in the tree (safe fallback callers).
  static SkinTokens? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkinContext>()?.tokens;

  @override
  bool updateShouldNotify(SkinContext old) => tokens != old.tokens;
}

/// BuildContext extension for ergonomic skin token access.
extension SkinContextExtension on BuildContext {
  SkinTokens get skin => SkinContext.of(this);
}
