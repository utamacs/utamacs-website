import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/complaint_repository.dart';

class SubmitComplaintScreen extends ConsumerStatefulWidget {
  const SubmitComplaintScreen({super.key});

  @override
  ConsumerState<SubmitComplaintScreen> createState() =>
      _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState
    extends ConsumerState<SubmitComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _category = 'maintenance';
  String _priority = 'medium';
  bool _submitting = false;

  static const _categories = [
    'maintenance',
    'security',
    'noise',
    'cleanliness',
    'billing',
    'other',
  ];

  static const _priorities = ['low', 'medium', 'high'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final unitId = ref.read(authNotifierProvider).profile?.unitId;
    try {
      await ref.read(complaintRepositoryProvider).submitComplaint(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            category: _category,
            priority: _priority,
            unitId: unitId,
          );
      ref.invalidate(myComplaintsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Complaint submitted successfully.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: kSecondary500,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to submit: $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authNotifierProvider).profile;
    final unitDisplay = profile?.unitDisplay;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('New Complaint'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Unit info row
            if (unitDisplay != null && unitDisplay.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: kPrimary50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kPrimary100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.apartment_outlined,
                        size: 16, color: kPrimary600),
                    const SizedBox(width: 8),
                    Text(
                      'Filing for unit: ',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: kTextSecondary),
                    ),
                    Text(
                      unitDisplay,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kPrimary600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            _SectionLabel('Title'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Brief description of the issue',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Title is required';
                }
                if (v.trim().length < 5) {
                  return 'Title must be at least 5 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _SectionLabel('Category'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(),
              items: _categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        _labelFor(c),
                        style: GoogleFonts.inter(
                            fontSize: 14, color: kTextPrimary),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 20),
            _SectionLabel('Priority'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(),
              items: _priorities
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 10,
                            color: _priorityColor(p),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            p[0].toUpperCase() + p.substring(1),
                            style: GoogleFonts.inter(
                                fontSize: 14, color: kTextPrimary),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _priority = v);
              },
            ),
            const SizedBox(height: 20),
            _SectionLabel('Description (optional)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'Provide additional details, block/floor number, etc.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            // Attachment upload — opens portal
            GestureDetector(
              onTap: () async {
                final uri = Uri.parse(
                    'https://portal.utamacs.org/portal/complaints?action=create-with-attachments');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: kPrimary50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPrimary100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file_outlined,
                        color: kPrimary600, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Add Photos / Documents (up to 5) — tap to open portal',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: kPrimary600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(Icons.open_in_new,
                        color: kPrimary600, size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Submit Complaint',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelFor(String category) => switch (category) {
        'maintenance' => 'Maintenance',
        'security' => 'Security',
        'noise' => 'Noise',
        'cleanliness' => 'Cleanliness',
        'billing' => 'Billing',
        'other' => 'Other',
        _ => category,
      };

  Color _priorityColor(String priority) => switch (priority) {
        'high' => kRed600,
        'medium' => kAccent500,
        'low' => kSecondary500,
        _ => kTextSecondary,
      };
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: kTextSecondary,
      ),
    );
  }
}
