import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/feedback_repository.dart';

const _categories = [
  'general',
  'maintenance',
  'security',
  'cleanliness',
  'governance',
  'billing',
];

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  String _selectedCategory = _categories.first;
  int _rating = 0;
  bool _isAnonymous = false;
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(feedbackRepositoryProvider).submitFeedback(
            category: _selectedCategory,
            subject: _subjectCtrl.text.trim(),
            body: _bodyCtrl.text.trim(),
            rating: _rating > 0 ? _rating : null,
            isAnonymous: _isAnonymous,
          );
      ref.invalidate(myFeedbackProvider);
      _formKey.currentState!.reset();
      _subjectCtrl.clear();
      _bodyCtrl.clear();
      setState(() {
        _selectedCategory = _categories.first;
        _rating = 0;
        _isAnonymous = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Feedback submitted. Thank you!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            backgroundColor: kSecondary500,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedbackAsync = ref.watch(myFeedbackProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    if (isExec) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: kBgWarm,
          appBar: AppBar(
            title: const Text('Feedback'),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  ref.invalidate(myFeedbackProvider);
                  ref.invalidate(allFeedbackProvider);
                },
              ),
            ],
            bottom: TabBar(
              labelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w600, fontSize: 14),
              unselectedLabelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w400, fontSize: 14),
              labelColor: kPrimary600,
              unselectedLabelColor: kTextSecondary,
              indicatorColor: kPrimary600,
              indicatorWeight: 2.5,
              tabs: const [
                Tab(text: 'My Feedback'),
                Tab(text: 'All Feedback'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildContent(context, feedbackAsync),
              const _AllFeedbackTab(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Feedback'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myFeedbackProvider),
          ),
        ],
      ),
      body: _buildContent(context, feedbackAsync),
    );
  }

  Widget _buildContent(BuildContext context, AsyncValue<List<FeedbackItem>> feedbackAsync) {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------------------------------------------------------
            // Feedback Form Card
            // ------------------------------------------------------------------
            AppCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.feedback_outlined,
                            color: kPrimary600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Share Feedback',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: kPrimary600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Category dropdown
                    Text('Category',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: kTextSecondary,
                        )),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: _categories
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c[0].toUpperCase() + c.substring(1),
                                  style: GoogleFonts.inter(fontSize: 14),
                                ),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedCategory = v ?? _selectedCategory),
                    ),
                    const SizedBox(height: 14),

                    // Subject field
                    Text('Subject',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: kTextSecondary,
                        )),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _subjectCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Brief summary of your feedback',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Subject is required' : null,
                    ),
                    const SizedBox(height: 14),

                    // Body text area
                    Text('Details',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: kTextSecondary,
                        )),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _bodyCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Describe your feedback in detail…',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Feedback details are required' : null,
                    ),
                    const SizedBox(height: 14),

                    // Star rating
                    Text('Rating (optional)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: kTextSecondary,
                        )),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (i) {
                        final starValue = i + 1;
                        return GestureDetector(
                          onTap: () => setState(() =>
                              _rating = _rating == starValue ? 0 : starValue),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              starValue <= _rating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: starValue <= _rating
                                  ? kAccent500
                                  : kBorderLight,
                              size: 30,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),

                    // Anonymous toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Submit Anonymously',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: kTextPrimary,
                              ),
                            ),
                            Text(
                              'Your name will not be shown',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: kTextSecondary),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isAnonymous,
                          activeColor: kPrimary600,
                          onChanged: (v) => setState(() => _isAnonymous = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Submit Feedback',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ------------------------------------------------------------------
            // Previous Submissions
            // ------------------------------------------------------------------
            Text(
              'My Submissions',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kPrimary600,
              ),
            ),
            const SizedBox(height: 12),

            feedbackAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline,
                title: 'Could not load feedback',
                subtitle: e.toString(),
                action: ElevatedButton(
                  onPressed: () => ref.invalidate(myFeedbackProvider),
                  child: const Text('Retry'),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.feedback_outlined,
                    title: 'No submissions yet',
                    subtitle: 'Your submitted feedback will appear here.',
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) =>
                      _FeedbackItemCard(item: items[i]),
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
    );
  }
}

// ---------------------------------------------------------------------------
// All Feedback Tab (exec only)
// ---------------------------------------------------------------------------

class _AllFeedbackTab extends ConsumerWidget {
  const _AllFeedbackTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(allFeedbackProvider);

    return allAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load feedback',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(allFeedbackProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.feedback_outlined,
            title: 'No feedback yet',
            subtitle: 'No feedback submissions have been made.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allFeedbackProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) =>
                _FeedbackItemCard(item: items[i], showUnit: true),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Feedback Item Card
// ---------------------------------------------------------------------------

class _FeedbackItemCard extends StatelessWidget {
  final FeedbackItem item;
  final bool showUnit;
  const _FeedbackItemCard({required this.item, this.showUnit = false});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.subject,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge.forStatus(item.status),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _CategoryChip(category: item.category),
              if (item.rating != null) ...[
                const SizedBox(width: 8),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < item.rating! ? Icons.star : Icons.star_border,
                      size: 13,
                      color: kAccent500,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                timeago.format(item.createdAt),
                style:
                    GoogleFonts.inter(fontSize: 11, color: kTextSecondary),
              ),
            ],
          ),
          if (showUnit && !item.isAnonymous && item.unitId != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.home_outlined, size: 13, color: kTextSecondary),
                const SizedBox(width: 4),
                Text(
                  'Unit ${item.unitId}',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: kTextSecondary),
                ),
              ],
            ),
          ],
          if (item.response != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kPrimary50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kPrimary100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Response',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kPrimary600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.response!,
                    style:
                        GoogleFonts.inter(fontSize: 13, color: kTextPrimary),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: kSectionAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kBorderLight),
      ),
      child: Text(
        category.replaceAll('_', ' ').toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: kTextSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
