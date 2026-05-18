import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/supabase.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../auth/domain/auth_notifier.dart';
import '../../data/member_repository.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _filterExpiring = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Member> _filtered(List<Member> all, Set<String> expiringUnitIds) {
    var result = all;
    if (_filterExpiring) {
      result = result
          .where((m) => m.unitId != null && expiringUnitIds.contains(m.unitId))
          .toList();
    }
    if (_query.isEmpty) return result;
    final lower = _query.toLowerCase();
    return result
        .where((m) =>
            m.fullName.toLowerCase().contains(lower) ||
            m.unitDisplay.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final isExec = ref.watch(authNotifierProvider).profile?.isExec ?? false;
    final membersAsync = ref.watch(membersProvider);

    return DsScreenShell(
      title: 'Member Directory',
      subtitle: 'Registered flat owners & tenants',
      actions: [
        if (isExec)
          DsActionButton(
            icon: Icons.download_outlined,
            onTap: () async {
              final uri = Uri.parse(
                  '$portalUrl/portal/members?export=csv');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        DsActionButton(
          icon: Icons.refresh_rounded,
          onTap: () => ref.invalidate(membersProvider),
        ),
      ],
      onRefresh: () async => ref.invalidate(membersProvider),
      slivers: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(
              dsSpace4, dsSpace3, dsSpace4, 0),
          child: _SearchBar(
            controller: _searchController,
            isDark: isDark,
            onChanged: (v) => setState(() => _query = v.trim()),
            onClear: () {
              _searchController.clear();
              setState(() => _query = '');
            },
          ),
        ),
        // Expiring tenancy filter chip
        Padding(
          padding: const EdgeInsets.fromLTRB(
              dsSpace4, dsSpace2, dsSpace4, dsSpace3),
          child: _ExpiringChip(
            selected: _filterExpiring,
            isDark: isDark,
            onTap: () =>
                setState(() => _filterExpiring = !_filterExpiring),
          ),
        ),
        // Main content
        membersAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => DsEmptyPlaceholder(
            icon: Icons.error_outline_rounded,
            title: 'Could not load members',
            message: e.toString(),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(membersProvider),
          ),
          data: (members) {
            final expiringIds =
                ref.watch(expiringTenancyUnitIdsProvider).valueOrNull ?? {};
            final filtered = _filtered(members, expiringIds);
            final nriCount = members.where((m) => m.isNri).length;
            final execCount = members.where((m) => m.isExec).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DsStatsRow(stats: [
                  DsStatItem(
                    label: 'Total Members',
                    value: '${members.length}',
                    icon: Icons.people_alt_rounded,
                    color: dsColorIndigo600,
                  ),
                  DsStatItem(
                    label: 'NRI Members',
                    value: '$nriCount',
                    icon: Icons.flight_rounded,
                    color: dsColorSky600,
                  ),
                  DsStatItem(
                    label: 'Executives',
                    value: '$execCount',
                    icon: Icons.verified_user_rounded,
                    color: dsColorEmerald600,
                  ),
                ]),
                const SizedBox(height: dsSpace4),
                if (filtered.isEmpty)
                  DsEmptyPlaceholder(
                    icon: Icons.people_outline_rounded,
                    title: _filterExpiring
                        ? 'No expiring tenancies'
                        : _query.isEmpty
                            ? 'No members found'
                            : 'No results for "$_query"',
                    message: _filterExpiring
                        ? 'No tenant KYC records expire within 30 days.'
                        : _query.isEmpty
                            ? 'The member directory is currently empty.'
                            : 'Try a different name or unit number.',
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: dsSpace4),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: dsSpace2),
                    itemBuilder: (context, i) => DSFadeSlide(
                      delay: Duration(milliseconds: i * 25),
                      child: _MemberCard(member: filtered[i]),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Search bar
// ---------------------------------------------------------------------------

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.isDark,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? dsDarkSurface : dsSurface,
        borderRadius: BorderRadius.circular(dsRadiusMd),
        boxShadow: isDark ? [] : dsShadowSm,
        border: Border.all(
          color: isDark ? dsDarkBorderLight : dsBorderLight,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.inter(
          fontSize: context.sp(14),
          color: isDark ? dsDarkTextPrimary : dsTextPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Search by name or unit…',
          hintStyle: GoogleFonts.inter(
            fontSize: context.sp(14),
            color: isDark ? dsDarkTextTertiary : dsTextTertiary,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: context.si(20),
            color: isDark ? dsDarkTextSecondary : dsTextSecondary,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: context.si(18),
                      color:
                          isDark ? dsDarkTextSecondary : dsTextSecondary),
                  onPressed: onClear,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: dsSpace4, vertical: dsSpace3),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expiring tenancy filter chip
// ---------------------------------------------------------------------------

class _ExpiringChip extends StatelessWidget {
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _ExpiringChip({
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: dsDurationFast,
        padding:
            const EdgeInsets.symmetric(horizontal: dsSpace3, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? dsColorAmber600.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(dsRadiusFull),
          border: Border.all(
            color: selected
                ? dsColorAmber600
                : (isDark ? dsDarkBorderLight : dsBorderLight),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.hourglass_top_rounded,
              size: context.si(13),
              color: dsColorAmber600,
            ),
            const SizedBox(width: dsSpace1),
            Text(
              'Tenancy Expiring (30d)',
              style: GoogleFonts.inter(
                fontSize: context.sp(12),
                fontWeight: FontWeight.w500,
                color: selected
                    ? dsColorAmber600
                    : (isDark ? dsDarkTextSecondary : dsTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Member card
// ---------------------------------------------------------------------------

class _MemberCard extends ConsumerWidget {
  final Member member;
  const _MemberCard({required this.member});

  static Future<void> _openPortal(String path) async {
    final uri = Uri.parse('$portalUrl/portal/$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);
    final initial = member.fullName.isNotEmpty
        ? member.fullName[0].toUpperCase()
        : '?';
    final myId = ref.watch(authNotifierProvider).profile?.id;
    final isOwnProfile = myId == member.id;

    return DSScalePress(
      onTap: () => _openPortal('members/${member.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? dsDarkSurface : dsSurface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border: isDark
              ? Border.all(color: dsDarkBorderSubtle)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(dsRadiusCard),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // 4px brand accent strip
                Container(
                  width: 4,
                  color: dsColorIndigo600,
                ),
                const SizedBox(width: dsSpace3),
                // Avatar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: dsSpace3),
                  child: Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: dsColorIndigo600,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: GoogleFonts.poppins(
                              fontSize: context.sp(17),
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (isOwnProfile)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () => _openPortal(
                                'profile?action=upload-avatar'),
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: dsColorIndigo600,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? dsDarkSurface
                                      : dsSurface,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: context.si(10),
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: dsSpace3),
                // Name + unit
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: dsSpace3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          member.fullName,
                          style: GoogleFonts.inter(
                            fontSize: context.sp(14),
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? dsDarkTextPrimary
                                : dsTextPrimary,
                          ),
                        ),
                        if (member.unitDisplay.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Unit ${member.unitDisplay}',
                            style: GoogleFonts.inter(
                              fontSize: context.sp(12),
                              color: isDark
                                  ? dsDarkTextSecondary
                                  : dsTextSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // NRI badge
                if (member.isNri)
                  Container(
                    margin: const EdgeInsets.only(right: dsSpace2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: dsColorSky50,
                      borderRadius:
                          BorderRadius.circular(dsRadiusFull),
                      border: Border.all(color: dsColorSky100),
                    ),
                    child: Text(
                      'NRI',
                      style: GoogleFonts.inter(
                        fontSize: context.sp(10),
                        fontWeight: FontWeight.w700,
                        color: dsColorSky700,
                      ),
                    ),
                  ),
                // Role chip — exec only
                if (member.isExec)
                  Container(
                    margin: const EdgeInsets.only(right: dsSpace3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: dsColorIndigo50,
                      borderRadius:
                          BorderRadius.circular(dsRadiusFull),
                      border: Border.all(color: dsColorIndigo100),
                    ),
                    child: Text(
                      member.roleLabel,
                      style: GoogleFonts.inter(
                        fontSize: context.sp(11),
                        fontWeight: FontWeight.w600,
                        color: dsColorIndigo600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
