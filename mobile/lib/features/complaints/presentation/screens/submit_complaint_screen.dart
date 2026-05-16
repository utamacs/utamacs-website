import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/complaint_repository.dart';

// ---------------------------------------------------------------------------
// Category / sub-category data
// ---------------------------------------------------------------------------

const _categories = [
  'plumbing',
  'electrical',
  'lift',
  'security',
  'housekeeping',
  'pest_control',
  'carpentry',
  'civil_structural',
  'parking',
  'garden',
  'common_areas',
  'noise',
  'billing',
  'other',
];

const _subCategories = <String, List<String>>{
  'plumbing': [
    'Leakage',
    'Pipe burst',
    'Clog / Blockage',
    'Low water pressure',
    'No water supply',
    'Water tank issue',
    'Tap / Fixture repair',
    'Other',
  ],
  'electrical': [
    'Power outage',
    'Short circuit',
    'Wiring issue',
    'Earthing problem',
    'Faulty switch / socket',
    'Common area lighting',
    'Meter issue',
    'Other',
  ],
  'lift': [
    'Lift not working',
    'Unusual noise',
    'Door issue',
    'Emergency / Stuck',
    'Service overdue',
    'Other',
  ],
  'security': [
    'CCTV not working',
    'Access card issue',
    'Gate malfunction',
    'Guard conduct',
    'Suspicious activity',
    'Trespassing',
    'Intercom issue',
    'Other',
  ],
  'housekeeping': [
    'Dustbin overflow',
    'Common area cleaning',
    'Staircase / Corridor',
    'Rooftop / Terrace',
    'Garbage collection',
    'Drainage / Sewage',
    'Other',
  ],
  'pest_control': [
    'Cockroaches',
    'Mosquitoes / Flies',
    'Rodents',
    'Termites',
    'Ants',
    'Other insects',
    'Other',
  ],
  'carpentry': [
    'Door / Window repair',
    'Lock / Handle',
    'Furniture damage',
    'Railing',
    'Other',
  ],
  'civil_structural': [
    'Wall crack',
    'Ceiling damage',
    'Flooring',
    'Seepage / Dampness',
    'Roof leak',
    'Compound wall',
    'Other',
  ],
  'parking': [
    'Obstruction',
    'Marking faded',
    'Gate / Barrier',
    'Lighting',
    'Drainage',
    'Unauthorized vehicle',
    'Other',
  ],
  'garden': [
    'Overgrowth',
    'Tree / Branch hazard',
    'Sprinkler issue',
    'Pathway damage',
    'Lighting in garden',
    'Other',
  ],
  'common_areas': [
    'Gym equipment',
    'Pool / STP',
    'Clubhouse',
    'Children\'s play area',
    'Notice board',
    'Other',
  ],
  'noise': [
    'Construction noise',
    'Party / Loud music',
    'Pet noise',
    'Vehicle noise',
    'Other',
  ],
  'billing': [
    'Incorrect charge',
    'Maintenance amount query',
    'Late fee dispute',
    'Receipt not received',
    'Other',
  ],
};

String _categoryLabel(String c) => switch (c) {
      'plumbing' => 'Plumbing',
      'electrical' => 'Electrical',
      'lift' => 'Lift / Elevator',
      'security' => 'Security',
      'housekeeping' => 'Housekeeping',
      'pest_control' => 'Pest Control',
      'carpentry' => 'Carpentry',
      'civil_structural' => 'Civil / Structural',
      'parking' => 'Parking',
      'garden' => 'Garden / Landscaping',
      'common_areas' => 'Common Areas',
      'noise' => 'Noise',
      'billing' => 'Billing / Finance',
      _ => 'Other',
    };

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

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

  String _category = 'plumbing';
  String? _subCategory;
  String _priority = 'medium';
  bool _submitting = false;

  static const _priorities = ['low', 'medium', 'high', 'urgent'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onCategoryChanged(String? v) {
    if (v == null) return;
    setState(() {
      _category = v;
      _subCategory = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(complaintRepositoryProvider).submitComplaint(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            category: _category,
            subCategory: _subCategory,
            priority: _priority,
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
    final subCats = _subCategories[_category] ?? const <String>[];

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
            // Title
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

            // Category
            _SectionLabel('Category'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(),
              items: _categories
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          _categoryLabel(c),
                          style: GoogleFonts.inter(
                              fontSize: 14, color: kTextPrimary),
                        ),
                      ))
                  .toList(),
              onChanged: _onCategoryChanged,
            ),
            const SizedBox(height: 20),

            // Sub-category (shown only when sub-cats exist for the selected category)
            if (subCats.isNotEmpty) ...[
              _SectionLabel('Sub-category'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                value: _subCategory,
                decoration: const InputDecoration(
                    hintText: 'Select sub-category (optional)'),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'Not specified',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: kTextSecondary),
                    ),
                  ),
                  ...subCats.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s,
                            style:
                                GoogleFonts.inter(fontSize: 14, color: kTextPrimary)),
                      )),
                ],
                onChanged: (v) => setState(() => _subCategory = v),
              ),
              const SizedBox(height: 20),
            ],

            // Priority
            _SectionLabel('Priority'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(),
              items: _priorities
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Row(
                          children: [
                            Icon(Icons.circle,
                                size: 10, color: _priorityColor(p)),
                            const SizedBox(width: 8),
                            Text(
                              p[0].toUpperCase() + p.substring(1),
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: kTextPrimary),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _priority = v);
              },
            ),
            const SizedBox(height: 20),

            // Description
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
            const SizedBox(height: 32),

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

  Color _priorityColor(String priority) => switch (priority) {
        'urgent' => const Color(0xFF7C3AED),
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
