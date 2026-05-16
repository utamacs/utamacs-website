import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/snag_repository.dart';

const _scopes = ['common_area', 'flat', 'external'];
const _categories = [
  'structural',
  'electrical',
  'plumbing',
  'civil',
  'painting',
  'waterproofing',
  'other',
];
const _severities = ['minor', 'moderate', 'major', 'critical'];

class ReportSnagScreen extends ConsumerStatefulWidget {
  const ReportSnagScreen({super.key});

  @override
  ConsumerState<ReportSnagScreen> createState() => _ReportSnagScreenState();
}

class _ReportSnagScreenState extends ConsumerState<ReportSnagScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationCtrl = TextEditingController();
  final _flatCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  String _scope = _scopes.first;
  String _category = _categories.first;
  String _severity = _severities.first;
  bool _submitting = false;

  @override
  void dispose() {
    _locationCtrl.dispose();
    _flatCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  String _labelFor(String value) =>
      value.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(snagRepositoryProvider).reportSnag(
            description: _descriptionCtrl.text.trim(),
            category: _category,
            location: _locationCtrl.text.trim(),
            severity: _severity,
            snagScope: _scope,
            flatNumber: _flatCtrl.text.trim().isEmpty
                ? null
                : _flatCtrl.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Snag reported successfully.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: kSecondary500,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to report snag: $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Report Snag'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Scope
            _FieldLabel('Scope'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _scope,
              decoration: const InputDecoration(),
              items: _scopes
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(_labelFor(s),
                            style: GoogleFonts.inter(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _scope = v ?? _scope),
            ),
            const SizedBox(height: 16),

            // Category
            _FieldLabel('Category'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(),
              items: _categories
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(_labelFor(c),
                            style: GoogleFonts.inter(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 16),

            // Location
            _FieldLabel('Location'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                  hintText: 'e.g. Block A staircase, Lobby, Terrace'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Location is required' : null,
            ),
            const SizedBox(height: 16),

            // Flat / Unit number (optional)
            _FieldLabel('Flat / Unit Number (optional)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _flatCtrl,
              decoration: const InputDecoration(hintText: 'e.g. A-101'),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),

            // Description
            _FieldLabel('Description'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(
                  hintText:
                      'Describe the defect clearly — what, where, extent of damage…'),
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Description is required' : null,
            ),
            const SizedBox(height: 16),

            // Severity
            _FieldLabel('Severity'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _severity,
              decoration: const InputDecoration(),
              items: _severities
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Row(
                          children: [
                            _SeverityDot(severity: s),
                            const SizedBox(width: 8),
                            Text(_labelFor(s),
                                style: GoogleFonts.inter(fontSize: 14)),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _severity = v ?? _severity),
            ),
            const SizedBox(height: 8),

            // Severity hint
            _SeverityHint(severity: _severity),
            const SizedBox(height: 28),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Submit Report',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: kTextSecondary,
      ),
    );
  }
}

class _SeverityDot extends StatelessWidget {
  final String severity;
  const _SeverityDot({required this.severity});

  Color _color(String s) => switch (s) {
        'critical' => kRed600,
        'major' => const Color(0xFFEA580C),
        'moderate' => kAccent500,
        'minor' => kPrimary600,
        _ => kTextSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _color(severity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SeverityHint extends StatelessWidget {
  final String severity;
  const _SeverityHint({required this.severity});

  String _hint(String s) => switch (s) {
        'minor' => 'Cosmetic defect; does not affect use or safety.',
        'moderate' => 'Affects comfort or convenience; needs attention.',
        'major' => 'Significantly impacts use; escalate soon.',
        'critical' => 'Immediate safety risk or total loss of function.',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final hint = _hint(severity);
    if (hint.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        hint,
        style: GoogleFonts.inter(fontSize: 12, color: kTextSecondary),
      ),
    );
  }
}
