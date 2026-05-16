import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/hoto_repository.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class HotoScreen extends ConsumerWidget {
  const HotoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(hotoSummaryProvider);

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('HOTO Tracker'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(hotoSummaryProvider);
              ref.invalidate(hotoFilteredItemsProvider);
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          summaryAsync.when(
            loading: () => const _SummarySkeleton(),
            error: (_, __) => const SizedBox.shrink(),
            data: (counts) {
              final open = (counts['pending'] ?? 0) +
                  (counts['in_progress'] ?? 0) +
                  (counts['escalated'] ?? 0);
              final completed = counts['completed'] ?? 0;
              return _SummaryRow(open: open, completed: completed);
            },
          ),
          // Filter chips + list
          const Expanded(child: _FilterableList()),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary row
// ---------------------------------------------------------------------------

class _SummaryRow extends StatelessWidget {
  final int open;
  final int completed;
  const _SummaryRow({required this.open, required this.completed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'Open',
              count: open,
              countColor: kPrimary600,
              bgColor: kPrimary50,
              borderColor: kPrimary100,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              label: 'Completed',
              count: completed,
              countColor: kSecondary500,
              bgColor: const Color(0xFFD1FAE5),
              borderColor: const Color(0xFFA7F3D0),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final Color countColor;
  final Color bgColor;
  final Color borderColor;

  const _SummaryCard({
    required this.label,
    required this.count,
    required this.countColor,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: countColor,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: kBorderLight,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: kBorderLight,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filterable list (StatefulWidget to hold chip selection)
// ---------------------------------------------------------------------------

const _kFilters = <_ChipDef>[
  _ChipDef(label: 'All', value: null),
  _ChipDef(label: 'Pending', value: 'pending'),
  _ChipDef(label: 'In Progress', value: 'in_progress'),
  _ChipDef(label: 'Completed', value: 'completed'),
  _ChipDef(label: 'Escalated', value: 'escalated'),
];

class _ChipDef {
  final String label;
  final String? value;
  const _ChipDef({required this.label, required this.value});
}

class _FilterableList extends StatefulWidget {
  const _FilterableList();

  @override
  State<_FilterableList> createState() => _FilterableListState();
}

class _FilterableListState extends State<_FilterableList> {
  String? _selectedFilter; // null = All

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Chip row
        Container(
          color: Colors.white,
          child: SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _kFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final chip = _kFilters[i];
                final selected = _selectedFilter == chip.value;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = chip.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? kPrimary600 : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? kPrimary600 : kBorderLight,
                      ),
                    ),
                    child: Text(
                      chip.label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color:
                            selected ? Colors.white : kTextSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const Divider(height: 1),
        // List
        Expanded(
          child: _HotoList(filter: _selectedFilter),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// List consumer
// ---------------------------------------------------------------------------

class _HotoList extends ConsumerWidget {
  final String? filter;
  const _HotoList({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(hotoFilteredItemsProvider(filter));

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load items',
        subtitle: e.toString(),
        action: ElevatedButton(
          onPressed: () => ref.invalidate(hotoFilteredItemsProvider(filter)),
          child: const Text('Retry'),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.checklist_rounded,
            title: 'No items found',
            subtitle:
                'No HOTO items match the selected filter.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(hotoFilteredItemsProvider(filter)),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _HotoItemCard(item: items[i]),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Item card
// ---------------------------------------------------------------------------

class _HotoItemCard extends StatelessWidget {
  final HotoItem item;
  const _HotoItemCard({required this.item});

  Color get _priorityBorderColor {
    return switch (item.priority) {
      'critical' => kRed600,
      'high' => kAccent500,
      'medium' => kPrimary600,
      _ => kBorderLight,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderLight),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Priority left border
              Container(
                width: 4,
                color: _priorityBorderColor,
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: ID + category + status
                      Row(
                        children: [
                          _IdChip(id: item.id),
                          const SizedBox(width: 6),
                          _CategoryChip(category: item.category),
                          const Spacer(),
                          StatusBadge.forStatus(item.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Title
                      Text(
                        item.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.deadline != null) ...[
                        const SizedBox(height: 6),
                        _DeadlineRow(
                          deadline: item.deadline!,
                          isOverdue: item.isOverdue,
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

class _IdChip extends StatelessWidget {
  final String id;
  const _IdChip({required this.id});

  String get _short {
    // Show first 8 chars as prefix
    final s = id.replaceAll('-', '');
    return '#${s.substring(0, s.length >= 8 ? 8 : s.length).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: kPrimary50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kPrimary100),
      ),
      child: Text(
        _short,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: kPrimary600,
          letterSpacing: 0.4,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: kSectionAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kBorderLight),
      ),
      child: Text(
        category.replaceAll('_', ' '),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: kTextSecondary,
          letterSpacing: 0.3,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _DeadlineRow extends StatelessWidget {
  final DateTime deadline;
  final bool isOverdue;
  const _DeadlineRow({required this.deadline, required this.isOverdue});

  @override
  Widget build(BuildContext context) {
    final color = isOverdue ? kRed600 : kTextSecondary;
    final label = isOverdue ? 'Overdue — ' : 'Due ';
    return Row(
      children: [
        Icon(
          isOverdue ? Icons.warning_amber_rounded : Icons.calendar_today,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          '$label${DateFormat('d MMM yyyy').format(deadline)}',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
            color: color,
          ),
        ),
      ],
    );
  }
}
