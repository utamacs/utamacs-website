import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

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
    return switch (status) {
      'active' || 'approved' || 'paid' || 'completed' => StatusBadge(
          label: status,
          backgroundColor: const Color(0xFFD1FAE5),
          textColor: const Color(0xFF065F46),
        ),
      'pending' || 'under_review' => StatusBadge(
          label: status,
          backgroundColor: const Color(0xFFFEF3C7),
          textColor: const Color(0xFF92400E),
        ),
      'overdue' || 'rejected' || 'expired' => StatusBadge(
          label: status,
          backgroundColor: const Color(0xFFFEE2E2),
          textColor: kRed600,
        ),
      _ => StatusBadge(
          label: status,
          backgroundColor: kPrimary50,
          textColor: kPrimary600,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
