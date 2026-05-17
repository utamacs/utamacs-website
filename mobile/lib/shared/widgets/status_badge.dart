import 'package:flutter/material.dart';
import '../../core/design/ds_components.dart';

// StatusBadge — upgraded to use DSBadge.
// All existing StatusBadge.forStatus(status) call sites work unchanged.

class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  factory StatusBadge.forStatus(String status) {
    // Delegate to DSBadge.forStatus which handles all status strings correctly.
    // We wrap it in a StatusBadge that just renders DSBadge.
    return StatusBadge(
      label: status,
      backgroundColor: Colors.transparent,
      textColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use DSBadge for the actual rendering — ignores legacy color fields
    // since DSBadge derives colors from its own semantic system.
    return DSBadge.forStatus(label);
  }
}
