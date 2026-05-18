import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/file_upload_service.dart';
import '../../../../core/utils/input_validators.dart';
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
  final List<MobilePickedFile> _attachments = [];
  static const _maxAttachments = 5;

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

  Future<void> _pickFromGallery() async {
    final remaining = _maxAttachments - _attachments.length;
    if (remaining <= 0) return;
    final picked = await MobileFileUploadService.pickImages(maxCount: remaining);
    if (mounted && picked.isNotEmpty) {
      setState(() => _attachments.addAll(picked));
    }
  }

  Future<void> _pickFromCamera() async {
    if (_attachments.length >= _maxAttachments) return;
    final picked = await MobileFileUploadService.pickImages(
      maxCount: 1,
      source: ImageSource.camera,
    );
    if (mounted && picked.isNotEmpty) {
      setState(() => _attachments.addAll(picked));
    }
  }

  Future<void> _pickDocument() async {
    final remaining = _maxAttachments - _attachments.length;
    if (remaining <= 0) return;
    final picked = await MobileFileUploadService.pickDocuments(maxCount: remaining);
    if (mounted && picked.isNotEmpty) {
      setState(() => _attachments.addAll(picked));
    }
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
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
      body: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Form(
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
              maxLength: 255,
              decoration: const InputDecoration(
                hintText: 'Brief description of the issue',
              ),
              validator: (v) => InputValidators.shortText(v, label: 'Title', max: 255),
            ),
            const SizedBox(height: 20),
            _SectionLabel('Category'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _category,
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
              initialValue: _priority,
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
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'Provide additional details, block/floor number, etc.',
                alignLabelWithHint: true,
              ),
              validator: (v) => InputValidators.optionalText(v, max: 2000),
            ),
            const SizedBox(height: 20),
            // Attachments — native file picker
            _SectionLabel('Photos / Documents (up to $_maxAttachments)'),
            const SizedBox(height: 8),
            if (_attachments.isNotEmpty) ...[
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final f = _attachments[i];
                    return Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: kPrimary50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kPrimary100),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: f.isImage
                                ? Image.file(f.file, fit: BoxFit.cover)
                                : const Center(
                                    child: Icon(Icons.picture_as_pdf,
                                        size: 36, color: kPrimary600),
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeAttachment(i),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: kRed600,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_attachments.length < _maxAttachments)
              Row(
                children: [
                  _AttachButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: _pickFromGallery,
                  ),
                  const SizedBox(width: 8),
                  _AttachButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onTap: _pickFromCamera,
                  ),
                  const SizedBox(width: 8),
                  _AttachButton(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'PDF',
                    onTap: _pickDocument,
                  ),
                ],
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
        ),   // Form
      ),   // FocusTraversalGroup
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

class _AttachButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: kPrimary50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kPrimary100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: kPrimary600),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: kPrimary600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
