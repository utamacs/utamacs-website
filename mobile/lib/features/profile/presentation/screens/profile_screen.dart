import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/profile.dart';
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
        actions: [
          if (profile != null)
            TextButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _EditProfileModal(profile: profile),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
              style: TextButton.styleFrom(foregroundColor: kPrimary600),
            ),
        ],
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
                  if (profile?.bio != null && profile!.bio!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      profile.bio!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
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
                  if (profile?.whatsappNumber != null &&
                      profile!.whatsappNumber!.isNotEmpty) ...[
                    const Divider(height: 1, indent: 56),
                    _InfoRow(
                      icon: Icons.chat_outlined,
                      label: 'WhatsApp',
                      value: profile.whatsappNumber!,
                    ),
                  ],
                  const Divider(height: 1, indent: 56),
                  _InfoRow(
                    icon: Icons.language_outlined,
                    label: 'Language',
                    value: _langLabel(profile?.preferredLanguage ?? 'en'),
                  ),
                ],
              ),
            ),

            // Emergency contact card (if set)
            if (profile?.emergencyContact != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emergency_outlined,
                            size: 18, color: kRed600),
                        const SizedBox(width: 8),
                        Text(
                          'Emergency Contact',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kRed600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (profile!.emergencyContact!['name'] != null)
                      Text(
                        profile.emergencyContact!['name'] as String,
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    if (profile.emergencyContact!['relationship'] != null)
                      Text(
                        profile.emergencyContact!['relationship'] as String,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: kTextSecondary),
                      ),
                  ],
                ),
              ),
            ],

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

  String _langLabel(String code) {
    const labels = {'en': 'English', 'te': 'Telugu', 'hi': 'Hindi'};
    return labels[code] ?? code;
  }
}

// ---------------------------------------------------------------------------
// Edit profile modal
// ---------------------------------------------------------------------------

class _EditProfileModal extends ConsumerStatefulWidget {
  final Profile profile;
  const _EditProfileModal({required this.profile});

  @override
  ConsumerState<_EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends ConsumerState<_EditProfileModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _whatsappCtrl;
  late final TextEditingController _ecNameCtrl;
  late final TextEditingController _ecPhoneCtrl;
  late String _preferredLanguage;
  late String? _ecRelationship;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.profile.fullName ?? '');
    _bioCtrl = TextEditingController(text: widget.profile.bio ?? '');
    _whatsappCtrl =
        TextEditingController(text: widget.profile.whatsappNumber ?? '');
    _preferredLanguage = widget.profile.preferredLanguage;
    final ec = widget.profile.emergencyContact;
    _ecNameCtrl = TextEditingController(text: ec?['name'] as String? ?? '');
    _ecPhoneCtrl =
        TextEditingController(text: ec?['phone'] as String? ?? '');
    _ecRelationship = ec?['relationship'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _whatsappCtrl.dispose();
    _ecNameCtrl.dispose();
    _ecPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    Map<String, dynamic>? ecMap;
    if (_ecNameCtrl.text.trim().isNotEmpty) {
      ecMap = {
        'name': _ecNameCtrl.text.trim(),
        if (_ecPhoneCtrl.text.trim().isNotEmpty)
          'phone': _ecPhoneCtrl.text.trim(),
        if (_ecRelationship != null) 'relationship': _ecRelationship,
      };
    }

    try {
      await ref.read(authNotifierProvider.notifier).updateProfile(
            fullName: _nameCtrl.text.trim(),
            bio: _bioCtrl.text.trim(),
            whatsappNumber: _whatsappCtrl.text.trim(),
            preferredLanguage: _preferredLanguage,
            emergencyContact: ecMap,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: kSecondary500,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e', style: GoogleFonts.inter()),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kBorderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Text(
                    'Edit Profile',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: kPrimary600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: kTextSecondary,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Full name',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _bioCtrl,
                      maxLines: 3,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Bio (optional)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _whatsappCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 15,
                      decoration: InputDecoration(
                        labelText: 'WhatsApp number (optional)',
                        hintText: '+919876543210',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _preferredLanguage,
                      decoration: InputDecoration(
                        labelText: 'Preferred language',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'te', child: Text('Telugu')),
                        DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                      ],
                      onChanged: (v) => setState(
                          () => _preferredLanguage = v ?? _preferredLanguage),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'EMERGENCY CONTACT',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kPrimary600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _ecNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Contact name',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _ecPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Contact phone',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String?>(
                      value: _ecRelationship,
                      decoration: InputDecoration(
                        labelText: 'Relationship',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('— None —')),
                        DropdownMenuItem(
                            value: 'spouse', child: Text('Spouse')),
                        DropdownMenuItem(
                            value: 'parent', child: Text('Parent')),
                        DropdownMenuItem(
                            value: 'sibling', child: Text('Sibling')),
                        DropdownMenuItem(
                            value: 'child', child: Text('Child')),
                        DropdownMenuItem(
                            value: 'friend', child: Text('Friend')),
                        DropdownMenuItem(
                            value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) =>
                          setState(() => _ecRelationship = v),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
