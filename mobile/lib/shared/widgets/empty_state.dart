import 'package:flutter/material.dart';
import '../../core/design/ds_components.dart';

// Upgraded EmptyState — delegates to DSEmptyState.
// All existing call sites (icon, title, subtitle, action) continue to work.

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return DSEmptyState(
      icon: icon,
      title: title,
      subtitle: subtitle,
      action: action,
    );
  }
}
