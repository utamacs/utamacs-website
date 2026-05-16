import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/profile.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/auth_notifier.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  final Profile profile;
  const ProfileEditScreen({super.key, required this.profile});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bioCtrl;
  late final TextEditingController _whatsappCtrl;
  late final TextEditingController _emergencyNameCtrl;
  late final TextEditingController _emergencyPhoneCtrl;
  late final TextEditingController _emergencyRelationCtrl;
  String _preferredLanguage = 'en';
  bool _saving = false;

  static const _languages = [
    ('en', 'English'),
    ('te', 'Telugu'),
    ('hi', 'Hindi'),
    ('ta', 'Tamil'),
    ('kn', 'Kannada'),
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _bioCtrl = TextEditingController(text: p.bio ?? '');
    _whatsappCtrl = TextEditingController(text: p.whatsappNumber ?? '');
    _emergencyNameCtrl =
        TextEditingController(text: p.emergencyContactName ?? '');
    _emergencyPhoneCtrl =
        TextEditingController(text: p.emergencyContactPhone ?? '');
    _emergencyRelationCtrl =
        TextEditingController(text: p.emergencyContactRelation ?? '');
    _preferredLanguage = p.preferredLanguage ?? 'en';
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _whatsappCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _emergencyRelationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile(
            bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
            whatsappNumber: _whatsappCtrl.text.trim().isEmpty
                ? null
                : _whatsappCtrl.text.trim(),
            preferredLanguage: _preferredLanguage,
            emergencyContactName: _emergencyNameCtrl.text.trim().isEmpty
                ? null
                : _emergencyNameCtrl.text.trim(),
            emergencyContactPhone: _emergencyPhoneCtrl.text.trim().isEmpty
                ? null
                : _emergencyPhoneCtrl.text.trim(),
            emergencyContactRelation: _emergencyRelationCtrl.text.trim().isEmpty
                ? null
                : _emergencyRelationCtrl.text.trim(),
          );
      // Reload profile in auth state
      await ref.read(authNotifierProvider.notifier).reloadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: kSecondary500,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(strokeWidth: 2))
                : Text('Save',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: kPrimary600,
                        fontSize: 15)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _GroupHeader('About You'),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label('Bio'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _bioCtrl,
                    maxLines: 3,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'A short intro about yourself (optional)',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Label('Preferred Language'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _preferredLanguage,
                    decoration: const InputDecoration(),
                    items: _languages
                        .map((l) => DropdownMenuItem(
                              value: l.$1,
                              child: Text(l.$2,
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: kTextPrimary)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _preferredLanguage = v);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _GroupHeader('Contact Details'),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label('WhatsApp Number'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _whatsappCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '+91 98765 43210',
                      prefixIcon:
                          Icon(Icons.chat_outlined, size: 18),
                    ),
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty) {
                        final digits = v.trim().replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 10) {
                          return 'Enter a valid phone number';
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _GroupHeader('Emergency Contact'),
            const SizedBox(height: 4),
            Text(
              'This information is only visible to society executives.',
              style: GoogleFonts.inter(
                  fontSize: 11, color: kTextSecondary),
            ),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label('Name'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emergencyNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        hintText: 'Emergency contact full name'),
                  ),
                  const SizedBox(height: 16),
                  _Label('Phone'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emergencyPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '+91 98765 43210',
                      prefixIcon: Icon(Icons.phone_outlined, size: 18),
                    ),
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty) {
                        final digits = v.trim().replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 10) {
                          return 'Enter a valid phone number';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _Label('Relation'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emergencyRelationCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        hintText: 'e.g. Spouse, Parent, Sibling'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: kTextSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary),
    );
  }
}
