import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/supabase.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/letter_repository.dart';

class LettersScreen extends ConsumerWidget {
  const LettersScreen({super.key});

  static Future<void> _openPortal(String path) async {
    final uri = Uri.parse('$portalUrl/portal/$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;
    final lettersAsync = ref.watch(lettersProvider);

    return DsScreenShell(
      title: 'Official Letters',
      subtitle: 'Committee-issued correspondence',
      actions: [
        if (isExec)
          DsActionButton(
            icon: Icons.description_outlined,
            onTap: () => _openPortal('letters?tab=templates'),
          ),
        DsActionButton(
          icon: Icons.refresh_rounded,
          onTap: () => ref.invalidate(lettersProvider),
        ),
      ],
      onRefresh: () async => ref.invalidate(lettersProvider),
      extraBottomPadding: isExec ? dsSpace16 : 0,
      floatingActionButton: isExec
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(dsRadiusXl),
                boxShadow: dsShadowBrand,
              ),
              child: FloatingActionButton.extended(
                backgroundColor: dsColorIndigo600,
                foregroundColor: Colors.white,
                elevation: 0,
                focusElevation: 0,
                hoverElevation: 0,
                highlightElevation: 0,
                icon: Icon(Icons.add_rounded, size: context.si(20)),
                label: Text(
                  'Generate Letter',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: context.sp(14),
                  ),
                ),
                onPressed: () =>
                    _openPortal('letters?action=generate'),
              ),
            )
          : null,
      slivers: [
        // Info banner
        Padding(
          padding: const EdgeInsets.fromLTRB(
              dsSpace4, dsSpace3, dsSpace4, 0),
          child: _InfoBanner(isDark: isDark),
        ),
        // List
        lettersAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load letters',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(lettersProvider),
          ),
          data: (letters) {
            if (letters.isEmpty) {
              return const DsEmptyPlaceholder(
                icon: Icons.description_outlined,
                title: 'No letters yet',
                message:
                    'Letters issued by the management committee will appear here.',
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                  dsSpace4, dsSpace3, dsSpace4, 0),
              itemCount: letters.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: dsSpace2),
              itemBuilder: (context, i) => RepaintBoundary(
                child: DSFadeSlide(
                  delay: Duration(milliseconds: i * 30),
                  child: _LetterCard(
                      letter: letters[i], isExec: isExec),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Info banner
// ---------------------------------------------------------------------------

class _InfoBanner extends StatelessWidget {
  final bool isDark;
  const _InfoBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: dsSpace4, vertical: dsSpace3),
      decoration: BoxDecoration(
        color: isDark
            ? dsColorAmber600.withValues(alpha: 0.1)
            : dsColorAmber50,
        borderRadius: BorderRadius.circular(dsRadiusMd),
        border: Border.all(
          color: isDark
              ? dsColorAmber600.withValues(alpha: 0.3)
              : dsColorAmber100,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: dsColorAmber600, size: context.si(16)),
          const SizedBox(width: dsSpace3),
          Expanded(
            child: Text(
              'Letters are generated by the management committee. PDFs are available in the resident portal.',
              style: GoogleFonts.inter(
                fontSize: context.sp(12),
                color: isDark
                    ? dsColorAmber300
                    : const Color(0xFF92400E),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Letter card
// ---------------------------------------------------------------------------

class _LetterCard extends ConsumerWidget {
  final GeneratedLetter letter;
  final bool isExec;
  const _LetterCard({required this.letter, required this.isExec});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);

    return DSScalePress(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            _LetterDetailSheet(letter: letter, isExec: isExec),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? dsDarkSurface : dsSurface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border:
              isDark ? Border.all(color: dsDarkBorderSubtle) : null,
        ),
        padding: const EdgeInsets.all(dsSpace4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon container
            Container(
              width: context.si(42),
              height: context.si(42),
              decoration: BoxDecoration(
                color: isDark
                    ? dsColorViolet600.withValues(alpha: 0.15)
                    : dsColorViolet50,
                borderRadius:
                    BorderRadius.circular(dsRadiusMd),
              ),
              child: Icon(
                Icons.description_outlined,
                color: isDark
                    ? dsColorViolet500
                    : dsColorViolet600,
                size: context.si(20),
              ),
            ),
            const SizedBox(width: dsSpace3),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    letter.title,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? dsDarkTextPrimary
                          : dsTextPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (letter.subject != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      letter.subject!,
                      style: GoogleFonts.inter(
                        fontSize: context.sp(12),
                        color: isDark
                            ? dsDarkTextSecondary
                            : dsTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (letter.recipient != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded,
                            size: context.si(12),
                            color: isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary),
                        const SizedBox(width: dsSpace1),
                        Expanded(
                          child: Text(
                            letter.recipient!,
                            style: GoogleFonts.inter(
                              fontSize: context.sp(11),
                              color: isDark
                                  ? dsDarkTextSecondary
                                  : dsTextSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: dsSpace2),
                  Text(
                    DateFormat('d MMM yyyy').format(letter.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: context.sp(11),
                      color: isDark
                          ? dsDarkTextSecondary
                          : dsTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: context.si(18),
              color:
                  isDark ? dsDarkTextSecondary : dsTextSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Letter detail bottom sheet
// ---------------------------------------------------------------------------

class _LetterDetailSheet extends ConsumerWidget {
  final GeneratedLetter letter;
  final bool isExec;
  const _LetterDetailSheet(
      {required this.letter, required this.isExec});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;
    final textPrimary = isDark ? dsDarkTextPrimary : dsTextPrimary;
    final textSecondary =
        isDark ? dsDarkTextSecondary : dsTextSecondary;
    final dateFormat = DateFormat('d MMM yyyy');

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(dsRadiusXxl)),
      ),
      padding: EdgeInsets.only(
        left: dsSpace5,
        right: dsSpace5,
        top: dsSpace3,
        bottom: MediaQuery.of(context).viewInsets.bottom + dsSpace6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: dsSpace4),
          Row(
            children: [
              Icon(Icons.description_outlined,
                  color: dsColorIndigo600, size: context.si(20)),
              const SizedBox(width: dsSpace3),
              Text(
                'Letter Details',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(15),
                  fontWeight: FontWeight.w700,
                  color: dsColorIndigo600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    size: context.si(20)),
                onPressed: () => Navigator.pop(context),
                color: textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: dsSpace3),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: dsSpace4),

          Text(
            letter.title,
            style: GoogleFonts.inter(
              fontSize: context.sp(14),
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: dsSpace4),

          if (letter.referenceNumber != null)
            _DetailRow(
                icon: Icons.tag_rounded,
                label: 'Ref. No.',
                value: letter.referenceNumber!,
                textSecondary: textSecondary,
                textPrimary: textPrimary),
          if (letter.letterType != null)
            _DetailRow(
                icon: Icons.category_outlined,
                label: 'Type',
                value: letter.letterType!.replaceAll('_', ' '),
                textSecondary: textSecondary,
                textPrimary: textPrimary),
          if (letter.status != null)
            _DetailRow(
                icon: Icons.info_outline_rounded,
                label: 'Status',
                value: letter.status![0].toUpperCase() +
                    letter.status!.substring(1),
                textSecondary: textSecondary,
                textPrimary: textPrimary),
          if (letter.recipient != null)
            _DetailRow(
                icon: Icons.person_outline_rounded,
                label: 'Recipient',
                value: letter.recipient!,
                textSecondary: textSecondary,
                textPrimary: textPrimary),
          if (letter.subject != null)
            _DetailRow(
                icon: Icons.subject_rounded,
                label: 'Subject',
                value: letter.subject!,
                textSecondary: textSecondary,
                textPrimary: textPrimary),
          _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Created',
              value: dateFormat
                  .format(letter.letterDate ?? letter.createdAt),
              textSecondary: textSecondary,
              textPrimary: textPrimary),
          const SizedBox(height: dsSpace3),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: dsSpace3),

          // Portal link banner
          Container(
            padding: const EdgeInsets.all(dsSpace3),
            decoration: BoxDecoration(
              color: isDark
                  ? dsColorAmber600.withValues(alpha: 0.1)
                  : dsColorAmber50,
              borderRadius: BorderRadius.circular(dsRadiusMd),
              border: Border.all(
                color: isDark
                    ? dsColorAmber600.withValues(alpha: 0.3)
                    : dsColorAmber100,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.open_in_browser_outlined,
                    size: context.si(14), color: dsColorAmber600),
                const SizedBox(width: dsSpace2),
                Expanded(
                  child: Text(
                    'Full content and PDF download are available in the resident portal.',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(11),
                      color: isDark
                          ? dsColorAmber300
                          : const Color(0xFF92400E),
                      height: 1.4,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(
                        '$portalUrl/portal/letters/${letter.id}'),
                    mode: LaunchMode.externalApplication,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: dsColorIndigo600,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: GoogleFonts.inter(
                        fontSize: context.sp(12),
                        fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Open'),
                ),
              ],
            ),
          ),

          if (isExec) ...[
            const SizedBox(height: dsSpace3),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: dsColorIndigo600,
                      side: const BorderSide(color: dsColorIndigo600),
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(dsRadiusSm)),
                      textStyle: GoogleFonts.inter(
                          fontSize: context.sp(12),
                          fontWeight: FontWeight.w500),
                    ),
                    icon: Icon(Icons.draw_outlined,
                        size: context.si(14)),
                    label: const Text('Sign-off'),
                    onPressed: () async {
                      final uri = Uri.parse(
                          '$portalUrl/portal/letters/${letter.id}');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
                const SizedBox(width: dsSpace2),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textSecondary,
                      side: BorderSide(color: borderColor),
                      padding:
                          const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(dsRadiusSm)),
                      textStyle: GoogleFonts.inter(
                          fontSize: context.sp(12),
                          fontWeight: FontWeight.w500),
                    ),
                    icon: Icon(Icons.link_outlined,
                        size: context.si(14)),
                    label: const Text('Link Module'),
                    onPressed: () async {
                      final uri = Uri.parse(
                          '$portalUrl/portal/letters/${letter.id}');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textSecondary;
  final Color textPrimary;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textSecondary,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: dsSpace3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: context.si(14), color: textSecondary),
          const SizedBox(width: dsSpace3),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: context.sp(12),
                color: textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: context.sp(12),
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
