import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
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
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;
    final membersAsync = ref.watch(membersProvider);

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Member Directory'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          if (isExec)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export CSV',
              onPressed: () async {
                final uri = Uri.parse(
                    'https://portal.utamacs.org/portal/members?export=csv');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(membersProvider),
          ),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load members',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(membersProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (members) {
          final expiringIds =
              ref.watch(expiringTenancyUnitIdsProvider).valueOrNull ?? {};
          final filtered = _filtered(members, expiringIds);
          return Column(
            children: [
              // Search bar
              Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  style: GoogleFonts.inter(fontSize: 14, color: kTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search by name or unit…',
                    prefixIcon: const Icon(Icons.search, color: kTextSecondary),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: kTextSecondary, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: kSectionAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kBorderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kBorderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: kPrimary600, width: 2),
                    ),
                  ),
                ),
              ),
              // Filter chips
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Tenancy Expiring (30d)',
                      selected: _filterExpiring,
                      onTap: () => setState(
                          () => _filterExpiring = !_filterExpiring),
                      color: kAccent500,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: kBorderLight),
              // List
              Expanded(
                child: filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline,
                        title: _filterExpiring
                            ? 'No expiring tenancies'
                            : _query.isEmpty
                                ? 'No members found'
                                : 'No results for "$_query"',
                        subtitle: _filterExpiring
                            ? 'No tenant KYC records expire within 30 days.'
                            : _query.isEmpty
                                ? 'The member directory is currently empty.'
                                : 'Try a different name or unit number.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(membersProvider),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) =>
                              _MemberCard(member: filtered[i]),
                        ),
                      ),
              ),
            ],
          );
        },
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
    final uri = Uri.parse('https://portal.utamacs.org/portal/$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = member.fullName.isNotEmpty
        ? member.fullName[0].toUpperCase()
        : '?';
    final myId = ref.watch(authNotifierProvider).profile?.id;
    final isOwnProfile = myId == member.id;

    return AppCard(
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: kPrimary600,
                child: Text(
                  initial,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (isOwnProfile)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () =>
                        _openPortal('profile?action=upload-avatar'),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: kPrimary600,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.camera_alt,
                          size: 10, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          // Name + unit
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.fullName,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                  ),
                ),
                if (member.unitDisplay.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Unit ${member.unitDisplay}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: kTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // NRI badge
          if (member.isNri)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                'NRI',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D4ED8),
                ),
              ),
            ),
          // Role chip — only for exec roles
          if (member.isExec)
            _RoleChip(label: member.roleLabel),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : kBorderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_circle, size: 13, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? color : kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  const _RoleChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kPrimary50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPrimary100),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: kPrimary600,
        ),
      ),
    );
  }
}
