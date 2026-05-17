import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/domain/auth_notifier.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../data/staff_repository.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(activeStaffProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Society Staff'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(activeStaffProvider),
          ),
        ],
      ),
      floatingActionButton: isExec
          ? FloatingActionButton.extended(
              backgroundColor: kPrimary600,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_outlined),
              label: Text(
                'Register Staff',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
              onPressed: () async {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _RegisterStaffModal(
                    onSaved: () => ref.invalidate(activeStaffProvider),
                  ),
                );
              },
            )
          : null,
      body: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load staff',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(activeStaffProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (staff) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(activeStaffProvider),
          child: CustomScrollView(
            slivers: [
              // Info banner
              const SliverToBoxAdapter(child: _InfoBanner()),
              if (staff.isEmpty)
                const SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.badge_outlined,
                    title: 'No active staff found',
                    subtitle:
                        'Active society staff members will appear here once registered.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: _GroupedStaffList(staff: staff),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info banner
// ---------------------------------------------------------------------------

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kPrimary50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPrimary100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: kPrimary600, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Showing active society staff with verified KYC.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: kPrimary600,
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
// Grouped list
// ---------------------------------------------------------------------------

class _GroupedStaffList extends StatelessWidget {
  final List<StaffMember> staff;
  const _GroupedStaffList({required this.staff});

  Map<String, List<StaffMember>> get _grouped {
    final map = <String, List<StaffMember>>{};
    for (final s in staff) {
      map.putIfAbsent(s.role, () => []).add(s);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _grouped;
    final roles = groups.keys.toList()..sort();

    final items = <Widget>[];
    for (final role in roles) {
      items.add(_RoleHeader(role: role));
      items.add(const SizedBox(height: 8));
      for (final member in groups[role]!) {
        items.add(_StaffCard(member: member));
        items.add(const SizedBox(height: 10));
      }
      items.add(const SizedBox(height: 4));
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) => items[i],
        childCount: items.length,
      ),
    );
  }
}

class _RoleHeader extends StatelessWidget {
  final String role;
  const _RoleHeader({required this.role});

  @override
  Widget build(BuildContext context) {
    return Text(
      role.replaceAll('_', ' ').toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: kTextSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Staff card
// ---------------------------------------------------------------------------

class _StaffCard extends StatelessWidget {
  final StaffMember member;
  const _StaffCard({required this.member});

  String get _initials {
    final parts = member.name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return member.name.substring(0, member.name.length >= 2 ? 2 : 1)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          _Avatar(initials: _initials),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + role badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoleBadge(role: member.role),
                  ],
                ),
                const SizedBox(height: 6),
                // Joining date
                if (member.joiningDate != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 12, color: kTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Since ${DateFormat('d MMM yyyy').format(member.joiningDate!)}',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: kTextSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                // KYC + pass badges row
                Row(
                  children: [
                    _KycBadge(status: member.kycStatus),
                    const SizedBox(width: 8),
                    _PassBadge(member: member),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar
// ---------------------------------------------------------------------------

class _Avatar extends StatelessWidget {
  final String initials;
  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: kPrimary100,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: kPrimary600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Role badge
// ---------------------------------------------------------------------------

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kSectionAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kBorderLight),
      ),
      child: Text(
        role.replaceAll('_', ' '),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: kTextSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KYC badge
// ---------------------------------------------------------------------------

class _KycBadge extends StatelessWidget {
  final String status;
  const _KycBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg, label) = switch (status) {
      'verified' => (
          Icons.check_circle_outline,
          kSecondary500,
          const Color(0xFFD1FAE5),
          'KYC Verified'
        ),
      'rejected' => (
          Icons.cancel_outlined,
          kRed600,
          const Color(0xFFFEE2E2),
          'KYC Rejected'
        ),
      _ => (
          Icons.hourglass_empty_outlined,
          kAccent500,
          const Color(0xFFFEF3C7),
          'KYC Pending'
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Security pass badge
// ---------------------------------------------------------------------------

class _PassBadge extends StatelessWidget {
  final StaffMember member;
  const _PassBadge({required this.member});

  @override
  Widget build(BuildContext context) {
    if (!member.securityPassIssued) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: kSectionAlt,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: kBorderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 12, color: kTextSecondary),
            const SizedBox(width: 4),
            Text(
              'No Pass',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: kTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final isExpired = member.securityPassExpiresAt != null &&
        member.securityPassExpiresAt!.isBefore(DateTime.now());

    if (isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 12, color: kRed600),
            const SizedBox(width: 4),
            Text(
              'Pass Expired',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: kRed600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_outlined, size: 12, color: kSecondary500),
          const SizedBox(width: 4),
          Text(
            'Pass Valid',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: kSecondary500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Register Staff Modal
// ---------------------------------------------------------------------------

const _kStaffRoles = [
  'security_guard',
  'housekeeping',
  'gardening',
  'maintenance',
  'electrician',
  'plumber',
  'management',
  'other',
];

const _kIdTypes = [
  'aadhaar',
  'pan',
  'passport',
  'voter_id',
  'driving_licence',
];

class _RegisterStaffModal extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _RegisterStaffModal({required this.onSaved});

  @override
  ConsumerState<_RegisterStaffModal> createState() =>
      _RegisterStaffModalState();
}

class _RegisterStaffModalState extends ConsumerState<_RegisterStaffModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  String _role = 'security_guard';
  String? _idType;
  DateTime? _joiningDate;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idNumberCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDeco(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
        hintStyle: GoogleFonts.inter(fontSize: 13, color: kTextSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kPrimary600, width: 1.5),
        ),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(staffRepositoryProvider).registerStaff(
            name: _nameCtrl.text.trim(),
            role: _role,
            joiningDate: _joiningDate,
            idType: _idType,
            idNumber: _idNumberCtrl.text.isNotEmpty
                ? _idNumberCtrl.text.trim()
                : null,
          );
      widget.onSaved();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff member registered')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kBorderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'Register Staff Member',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kPrimary600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Name
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _inputDeco('Full Name *'),
                        style: GoogleFonts.inter(fontSize: 14),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Role
                      DropdownButtonFormField<String>(
                        value: _role,
                        decoration: _inputDeco('Role *'),
                        style: GoogleFonts.inter(
                            fontSize: 14, color: kTextPrimary),
                        items: _kStaffRoles
                            .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(
                                    r.replaceAll('_', ' ').split(' ').map(
                                      (w) {
                                        if (w.isEmpty) return w;
                                        return '${w[0].toUpperCase()}${w.substring(1)}';
                                      },
                                    ).join(' '),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _role = v ?? 'security_guard'),
                      ),
                      const SizedBox(height: 14),

                      // Joining date
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _joiningDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _joiningDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: _inputDeco('Joining Date (optional)'),
                          child: Text(
                            _joiningDate != null
                                ? df.format(_joiningDate!)
                                : 'Select date',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: _joiningDate != null
                                  ? kTextPrimary
                                  : kTextSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ID type
                      DropdownButtonFormField<String>(
                        value: _idType,
                        decoration:
                            _inputDeco('ID Document Type (optional)'),
                        style: GoogleFonts.inter(
                            fontSize: 14, color: kTextPrimary),
                        items: [
                          const DropdownMenuItem(
                              value: null,
                              child: Text('None')),
                          ..._kIdTypes.map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                t.replaceAll('_', ' ').split(' ').map(
                                  (w) {
                                    if (w.isEmpty) return w;
                                    return '${w[0].toUpperCase()}${w.substring(1)}';
                                  },
                                ).join(' '),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _idType = v),
                      ),

                      if (_idType != null) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _idNumberCtrl,
                          decoration: _inputDeco('ID Number'),
                          style: GoogleFonts.inter(fontSize: 14),
                          textCapitalization: TextCapitalization.characters,
                        ),
                      ],

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary600,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Register Staff Member',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
