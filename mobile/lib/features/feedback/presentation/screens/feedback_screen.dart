import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../../core/utils/input_validators.dart';
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

Color _categoryColor(String category) => switch (category) {
      'maintenance'  => dsColorIndigo600,
      'security'     => dsColorRed600,
      'cleanliness'  => dsColorEmerald600,
      'governance'   => dsColorViolet600,
      'billing'      => dsColorAmber600,
      _              => dsColorSlate500,
    };

Color _categoryBg(String category) => switch (category) {
      'maintenance'  => dsColorIndigo50,
      'security'     => dsColorRed50,
      'cleanliness'  => dsColorEmerald50,
      'governance'   => dsColorViolet50,
      'billing'      => dsColorAmber50,
      _              => dsColorSlate100,
    };

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
            content: Text('Feedback submitted. Thank you!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: dsColorEmerald600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: dsColorRed600,
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
    final isDark = ref.watch(effectiveDarkProvider);
    final feedbackAsync = ref.watch(myFeedbackProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    if (isExec) {
      return _ExecFeedbackView(
        isDark: isDark,
        myTab: _buildMyTab(context, isDark, feedbackAsync),
      );
    }

    return DsScreenShell(
      title: 'Feedback',
      subtitle: 'Share suggestions & ratings',
      actions: [
        DsActionButton(
          icon: Icons.refresh_rounded,
          onTap: () => ref.invalidate(myFeedbackProvider),
        ),
      ],
      onRefresh: () async => ref.invalidate(myFeedbackProvider),
      slivers: [_buildMyTab(context, isDark, feedbackAsync)],
    );
  }

  Widget _buildMyTab(
    BuildContext context,
    bool isDark,
    AsyncValue<List<FeedbackItem>> feedbackAsync,
  ) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Feedback form card
        Padding(
          padding: const EdgeInsets.fromLTRB(
              dsSpace4, dsSpace3, dsSpace4, 0),
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(dsRadiusCard),
              boxShadow: isDark ? [] : dsShadowMd,
              border: isDark
                  ? Border.all(color: dsDarkBorderSubtle)
                  : null,
            ),
            padding: const EdgeInsets.all(dsSpace4),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: dsColorAmber600.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(dsRadiusSm),
                        ),
                        child: Icon(Icons.feedback_outlined,
                            size: context.si(18),
                            color: dsColorAmber600),
                      ),
                      const SizedBox(width: dsSpace3),
                      Text(
                        'Share Feedback',
                        style: GoogleFonts.poppins(
                          fontSize: context.sp(15),
                          fontWeight: FontWeight.w700,
                          color: dsColorIndigo600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: dsSpace4),

                  // Category dropdown
                  _FormLabel(label: 'Category', isDark: isDark),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? dsDarkSurfaceMuted
                          : dsSurfaceMuted,
                      borderRadius: BorderRadius.circular(dsRadiusMd),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: dsSpace4),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        style: GoogleFonts.inter(
                          fontSize: context.sp(14),
                          color: textPrimary,
                        ),
                        dropdownColor: surface,
                        items: _categories
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c[0].toUpperCase() + c.substring(1),
                                    style: GoogleFonts.inter(
                                      fontSize: context.sp(14),
                                      color: textPrimary,
                                    ),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(
                            () => _selectedCategory = v ?? _selectedCategory),
                      ),
                    ),
                  ),
                  const SizedBox(height: dsSpace3),

                  // Subject
                  _FormLabel(label: 'Subject *', isDark: isDark),
                  const SizedBox(height: 6),
                  _FormField(
                    controller: _subjectCtrl,
                    hint: 'Brief summary of your feedback',
                    isDark: isDark,
                    maxLength: 255,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => InputValidators.shortText(v, label: 'Subject', max: 255),
                  ),
                  const SizedBox(height: dsSpace3),

                  // Details
                  _FormLabel(label: 'Details *', isDark: isDark),
                  const SizedBox(height: 6),
                  _FormField(
                    controller: _bodyCtrl,
                    hint: 'Describe your feedback in detail…',
                    isDark: isDark,
                    maxLines: 4,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => InputValidators.longText(v, label: 'Feedback details'),
                  ),
                  const SizedBox(height: dsSpace3),

                  // Star rating
                  _FormLabel(label: 'Rating (optional)', isDark: isDark),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (i) {
                      final starVal = i + 1;
                      return GestureDetector(
                        onTap: () => setState(() =>
                            _rating =
                                _rating == starVal ? 0 : starVal),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            starVal <= _rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: starVal <= _rating
                                ? dsColorAmber500
                                : (isDark
                                    ? dsDarkBorderLight
                                    : dsBorderDefault),
                            size: context.si(28),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: dsSpace3),

                  // Anonymous toggle
                  Container(
                    padding: const EdgeInsets.all(dsSpace3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? dsDarkSurfaceMuted
                          : dsSurfaceMuted,
                      borderRadius: BorderRadius.circular(dsRadiusMd),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Submit Anonymously',
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(14),
                                  fontWeight: FontWeight.w500,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                'Your name will not be shown',
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(12),
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isAnonymous,
                          activeThumbColor: dsColorIndigo600,
                          onChanged: (v) =>
                              setState(() => _isAnonymous = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: dsSpace4),

                  // Submit button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(dsRadiusButton),
                      boxShadow: dsShadowBrand,
                    ),
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dsColorIndigo600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            vertical: dsSpace4),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(dsRadiusButton),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Submit Feedback',
                              style: GoogleFonts.inter(
                                fontSize: context.sp(15),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // My Submissions section header
        Padding(
          padding: const EdgeInsets.fromLTRB(
              dsSpace4, dsSpace6, dsSpace4, dsSpace2),
          child: Text(
            'My Submissions',
            style: GoogleFonts.poppins(
              fontSize: context.sp(14),
              fontWeight: FontWeight.w700,
              color: isDark ? dsDarkTextPrimary : dsTextPrimary,
            ),
          ),
        ),

        feedbackAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load feedback',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(myFeedbackProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const DsEmptyPlaceholder(
                icon: Icons.feedback_outlined,
                title: 'No submissions yet',
                message: 'Your submitted feedback will appear here.',
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: dsSpace4),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: dsSpace2),
              itemBuilder: (context, i) => DSFadeSlide(
                delay: Duration(milliseconds: i * 30),
                child: _FeedbackItemCard(item: items[i]),
              ),
            );
          },
        ),
        const SizedBox(height: dsSpace8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Exec view — 2 tabs
// ---------------------------------------------------------------------------

class _ExecFeedbackView extends ConsumerWidget {
  final bool isDark;
  final Widget myTab;

  const _ExecFeedbackView({required this.isDark, required this.myTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaceColor = isDark ? dsDarkSurface : dsSurface;
    final titleColor = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final subtitleColor = isDark ? dsDarkTextSecondary : dsTextSecondary;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? dsDarkBackground : dsBackground,
        extendBody: true,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              backgroundColor: surfaceColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: isDark ? 0.5 : 1,
              shadowColor: isDark ? dsDarkBorderLight : dsBorderLight,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsets.only(left: dsSpace4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Feedback',
                      style: GoogleFonts.poppins(
                        fontSize: context.sp(16),
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'Resident suggestions & ratings',
                      style: GoogleFonts.inter(
                        fontSize: context.sp(11),
                        color: subtitleColor,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                DsActionButton(
                  icon: Icons.refresh_rounded,
                  onTap: () {
                    ref.invalidate(myFeedbackProvider);
                    ref.invalidate(allFeedbackProvider);
                  },
                ),
                const SizedBox(width: dsSpace2),
              ],
              bottom: TabBar(
                labelColor: dsColorIndigo600,
                unselectedLabelColor:
                    isDark ? dsDarkTextSecondary : dsTextSecondary,
                indicatorColor: dsColorIndigo600,
                indicatorWeight: 2.5,
                labelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: context.sp(13),
                ),
                unselectedLabelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  fontSize: context.sp(13),
                ),
                tabs: const [
                  Tab(text: 'My Feedback'),
                  Tab(text: 'All Feedback'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              SingleChildScrollView(child: myTab),
              const _AllFeedbackTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// All Feedback tab (exec only)
// ---------------------------------------------------------------------------

class _AllFeedbackTab extends ConsumerWidget {
  const _AllFeedbackTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(allFeedbackProvider);

    return allAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DsEmptyPlaceholder(
        icon: Icons.error_outline_rounded,
        title: 'Could not load feedback',
        message: e.toString(),
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(allFeedbackProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const DsEmptyPlaceholder(
            icon: Icons.feedback_outlined,
            title: 'No feedback yet',
            message: 'No feedback submissions have been made.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(allFeedbackProvider),
          color: dsColorIndigo600,
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              dsSpace4,
              dsSpace4,
              dsSpace4,
              80 + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: dsSpace2),
            itemBuilder: (context, i) => DSFadeSlide(
              delay: Duration(milliseconds: i * 25),
              child: _FeedbackItemCard(item: items[i], showUnit: true),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Feedback item card
// ---------------------------------------------------------------------------

class _FeedbackItemCard extends ConsumerWidget {
  final FeedbackItem item;
  final bool showUnit;
  const _FeedbackItemCard({required this.item, this.showUnit = false});

  (Color bg, Color text) _statusColors(String status) => switch (status) {
        'new'         => (dsColorIndigo50, dsColorIndigo600),
        'acknowledged'=> (dsColorAmber50, dsColorAmber700),
        'resolved'    => (dsColorEmerald50, dsColorEmerald700),
        'closed'      => (dsColorSlate100, dsColorSlate600),
        _             => (dsColorSlate100, dsColorSlate600),
      };

  String _statusLabel(String s) => switch (s) {
        'new'          => 'New',
        'acknowledged' => 'Acknowledged',
        'resolved'     => 'Resolved',
        'closed'       => 'Closed',
        _              => s[0].toUpperCase() + s.substring(1),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(effectiveDarkProvider);
    final catColor = _categoryColor(item.category);
    final catBg = isDark
        ? catColor.withValues(alpha: 0.15)
        : _categoryBg(item.category);
    final (statusBg, statusText) = _statusColors(item.status);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? dsDarkSurface : dsSurface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: isDark ? [] : dsShadowSm,
        border: isDark ? Border.all(color: dsDarkBorderSubtle) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(dsRadiusCard),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: catColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(dsSpace3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject + status
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.subject,
                              style: GoogleFonts.inter(
                                fontSize: context.sp(13),
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? dsDarkTextPrimary
                                    : dsTextPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: dsSpace2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? statusText.withValues(alpha: 0.15)
                                  : statusBg,
                              borderRadius:
                                  BorderRadius.circular(dsRadiusFull),
                            ),
                            child: Text(
                              _statusLabel(item.status),
                              style: GoogleFonts.inter(
                                fontSize: context.sp(10),
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? statusText.withValues(alpha: 0.9)
                                    : statusText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: dsSpace2),

                      // Category + stars + timeago
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: catBg,
                              borderRadius:
                                  BorderRadius.circular(dsRadiusXs),
                            ),
                            child: Text(
                              item.category.replaceAll('_', ' ').toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: context.sp(9),
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? catColor.withValues(alpha: 0.9)
                                    : catColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          if (item.rating != null) ...[
                            const SizedBox(width: dsSpace2),
                            ...List.generate(
                              5,
                              (i) => Icon(
                                i < item.rating!
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: context.si(12),
                                color: dsColorAmber500,
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            timeago.format(item.createdAt),
                            style: GoogleFonts.inter(
                              fontSize: context.sp(10),
                              color: isDark
                                  ? dsDarkTextSecondary
                                  : dsTextSecondary,
                            ),
                          ),
                        ],
                      ),

                      // Unit (exec view)
                      if (showUnit &&
                          !item.isAnonymous &&
                          item.unitId != null) ...[
                        const SizedBox(height: dsSpace2),
                        Row(
                          children: [
                            Icon(
                              Icons.home_outlined,
                              size: context.si(12),
                              color: isDark
                                  ? dsDarkTextSecondary
                                  : dsTextSecondary,
                            ),
                            const SizedBox(width: dsSpace1),
                            Text(
                              'Unit ${item.unitId}',
                              style: GoogleFonts.inter(
                                fontSize: context.sp(11),
                                color: isDark
                                    ? dsDarkTextSecondary
                                    : dsTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Response box
                      if (item.response != null) ...[
                        const SizedBox(height: dsSpace3),
                        Container(
                          padding: const EdgeInsets.all(dsSpace3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? dsColorIndigo600.withValues(alpha: 0.12)
                                : dsColorIndigo25,
                            borderRadius:
                                BorderRadius.circular(dsRadiusSm),
                            border: Border.all(
                              color: isDark
                                  ? dsColorIndigo600.withValues(alpha: 0.3)
                                  : dsColorIndigo100,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RESPONSE',
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(9),
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? dsColorIndigo300
                                      : dsColorIndigo600,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: dsSpace1),
                              Text(
                                item.response!,
                                style: GoogleFonts.inter(
                                  fontSize: context.sp(12),
                                  color: isDark
                                      ? dsDarkTextPrimary
                                      : dsTextPrimary,
                                  height: 1.4,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

class _FormLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _FormLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: context.sp(12),
        fontWeight: FontWeight.w600,
        color: isDark ? dsDarkTextSecondary : dsTextSecondary,
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.hint,
    required this.isDark,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary = isDark ? dsDarkTextSecondary : dsTextSecondary;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      style: GoogleFonts.inter(
        fontSize: context.sp(14),
        color: textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: context.sp(13),
          color: textSecondary,
        ),
        filled: true,
        fillColor: isDark ? dsDarkSurfaceMuted : dsSurfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: dsSpace4, vertical: dsSpace3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd),
          borderSide:
              const BorderSide(color: dsColorIndigo600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd),
          borderSide: const BorderSide(color: dsColorRed600),
        ),
      ),
      validator: validator,
    );
  }
}
