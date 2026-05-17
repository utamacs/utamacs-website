import 'package:flutter/material.dart';
import '../../core/design/ds_tokens.dart';

// Upgraded AppCard — shadow-based elevation, no border.
// Drop-in replacement for all existing AppCard(child: ...) usages.

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? dsSurface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: dsShadowMd,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          highlightColor: dsColorIndigo600.withValues(alpha: 0.04),
          splashColor: dsColorIndigo600.withValues(alpha: 0.06),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(dsSpaceCardPadding),
            child: child,
          ),
        ),
      ),
    );
  }
}
