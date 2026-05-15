import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/auth_notifier.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final profile = authState.profile;

    final initial = (profile?.fullName?.isNotEmpty == true)
        ? profile!.fullName![0].toUpperCase()
        : 'R';
    final name = profile?.displayName ?? 'Resident';
    final unit = profile?.unitDisplay ?? '';
    final role = profile?.portalRole ?? 'member';

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: kPrimary600,
                    child: Text(
                      initial,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Unit $unit',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: kTextSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: _roleColor(role).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _roleLabel(role),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _roleColor(role),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Info rows
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.apartment_outlined,
                    label: 'Society',
                    value: 'UTA MACS',
                  ),
                  const Divider(height: 1, indent: 56),
                  _InfoRow(
                    icon: Icons.home_outlined,
                    label: 'Unit',
                    value: unit.isNotEmpty ? 'Unit $unit' : '—',
                  ),
                  const Divider(height: 1, indent: 56),
                  _InfoRow(
                    icon: Icons.shield_outlined,
                    label: 'Role',
                    value: _roleLabel(role),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Sign out
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    ref.read(authNotifierProvider.notifier).signOut(),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kRed600,
                  side: const BorderSide(color: kRed600),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'UTA MACS Resident Portal',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    const labels = {
      'member': 'Member',
      'executive': 'Executive',
      'secretary': 'Secretary',
      'president': 'President',
      'security_guard': 'Security Guard',
    };
    return labels[role] ?? role;
  }

  Color _roleColor(String role) {
    if (['executive', 'secretary', 'president'].contains(role)) {
      return kPrimary600;
    }
    if (role == 'security_guard') return kSecondary500;
    return kTextSecondary;
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kPrimary50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: kPrimary600),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: kTextSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
