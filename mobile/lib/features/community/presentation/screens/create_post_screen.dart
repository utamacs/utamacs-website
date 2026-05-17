import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/input_validators.dart';
import '../../data/community_repository.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _selectedCategory = 'general';
  bool _isSubmitting = false;

  static const List<Map<String, String>> _categories = [
    {'value': 'announcement', 'label': 'Announcement'},
    {'value': 'discussion', 'label': 'Discussion'},
    {'value': 'help', 'label': 'Help'},
    {'value': 'lost_found', 'label': 'Lost & Found'},
    {'value': 'general', 'label': 'General'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      await ref.read(communityRepositoryProvider).createPost(
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            category: _selectedCategory,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post published successfully.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create post: ${e.toString()}'),
            backgroundColor: kRed600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('New Post'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category dropdown
              const _FieldLabel(text: 'Category'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  hintText: 'Select a category',
                ),
                items: _categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c['value'],
                        child: Text(c['label']!),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedCategory = v);
                },
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Please select a category' : null,
              ),
              const SizedBox(height: 16),

              // Title field
              const _FieldLabel(text: 'Title *'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                maxLength: 255,
                decoration: const InputDecoration(
                  hintText: 'Give your post a clear title',
                ),
                validator: (v) => InputValidators.shortText(v, label: 'Title', max: 255),
              ),
              const SizedBox(height: 16),

              // Body field
              const _FieldLabel(text: 'Body'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _bodyController,
                maxLines: 6,
                minLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                  hintText: 'Share details, ask a question, or start a discussion…',
                  alignLabelWithHint: true,
                ),
                validator: (v) => InputValidators.optionalText(v, max: 2000),
              ),
              const SizedBox(height: 16),

              // Image upload — opens portal
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(
                      'https://portal.utamacs.org/portal/community');
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
                      const Icon(Icons.add_photo_alternate_outlined,
                          color: kPrimary600, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Add Images (up to 5) — tap to open portal',
                          style: TextStyle(
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

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Publish Post'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: kTextSecondary,
          ),
    );
  }
}
