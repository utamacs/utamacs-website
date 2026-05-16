import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/member_repository.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Member> _filtered(List<Member> all) {
    if (_query.isEmpty) return all;
    final lower = _query.toLowerCase();
    return all
        .where((m) =>
            m.fullName.toLowerCase().contains(lower) ||
            m.unitDisplay.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Member Directory'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
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
          final filtered = _filtered(members);
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
              const Divider(height: 1, color: kBorderLight),
              // List
              Expanded(
                child: filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline,
                        title: _query.isEmpty
                            ? 'No members found'
                            : 'No results for "$_query"',
                        subtitle: _query.isEmpty
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

class _MemberCard extends StatelessWidget {
  final Member member;
  const _MemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    final initial = member.fullName.isNotEmpty
        ? member.fullName[0].toUpperCase()
        : '?';

    return AppCard(
      child: Row(
        children: [
          // Avatar
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
          // Role chip — only for exec roles
          if (member.isExec)
            _RoleChip(label: member.roleLabel),
        ],
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
