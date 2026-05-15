import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/visitor_repository.dart';

class PreApproveScreen extends ConsumerStatefulWidget {
  const PreApproveScreen({super.key});

  @override
  ConsumerState<PreApproveScreen> createState() => _PreApproveScreenState();
}

class _PreApproveScreenState extends ConsumerState<PreApproveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  DateTime _validFrom = DateTime.now();
  DateTime? _expiresAt;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _purposeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isExpiry}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isExpiry
          ? (_expiresAt ?? DateTime.now().add(const Duration(days: 1)))
          : _validFrom,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isExpiry) {
        _expiresAt = picked;
      } else {
        _validFrom = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(visitorRepositoryProvider).createPreApproval(
            visitorName: _nameCtrl.text.trim(),
            visitorPhone: _phoneCtrl.text.trim().isEmpty
                ? null
                : _phoneCtrl.text.trim(),
            purpose: _purposeCtrl.text.trim().isEmpty
                ? null
                : _purposeCtrl.text.trim(),
            expectedDate: _validFrom,
            expiresAt: _expiresAt,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visitor pass created'),
            backgroundColor: kSecondary500,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: kRed600),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pre-approve Visitor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel('Visitor details'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Visitor name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mobile number (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _purposeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Purpose of visit (optional)',
                  prefixIcon: Icon(Icons.info_outline),
                ),
              ),
              const SizedBox(height: 28),
              _SectionLabel('Validity'),
              const SizedBox(height: 12),
              _DateTile(
                label: 'Valid from',
                date: _validFrom,
                onTap: () => _pickDate(isExpiry: false),
              ),
              const SizedBox(height: 10),
              _DateTile(
                label: 'Expires on (optional)',
                date: _expiresAt,
                placeholder: 'No expiry',
                onTap: () => _pickDate(isExpiry: true),
                trailing: _expiresAt != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _expiresAt = null),
                      )
                    : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Create Visitor Pass'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: kPrimary600, fontWeight: FontWeight.w600),
      );
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final String placeholder;
  final VoidCallback onTap;
  final Widget? trailing;

  const _DateTile({
    required this.label,
    required this.date,
    this.placeholder = '',
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: kBorderLight),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: kTextSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, color: kTextSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    date != null
                        ? '${date!.day}/${date!.month}/${date!.year}'
                        : placeholder,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: date != null ? kTextPrimary : kTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right, color: kTextSecondary),
          ],
        ),
      ),
    );
  }
}
