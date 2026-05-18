import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/supabase.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../auth/domain/auth_notifier.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class _Flag {
  final String moduleKey;
  final bool isActive;
  final int order;
  const _Flag({required this.moduleKey, required this.isActive, required this.order});
  _Flag copyWith({bool? isActive}) =>
      _Flag(moduleKey: moduleKey, isActive: isActive ?? this.isActive, order: order);
}

class _Rule {
  final String code;
  final String valueType;
  final String value;
  final String? description;
  final bool isLocked;
  const _Rule({required this.code, required this.valueType, required this.value, this.description, required this.isLocked});
  _Rule copyWith({String? value}) =>
      _Rule(code: code, valueType: valueType, value: value ?? this.value, description: description, isLocked: isLocked);
}

// ─── Providers ────────────────────────────────────────────────────────────────

class _FlagsNotifier extends AutoDisposeAsyncNotifier<List<_Flag>> {
  @override
  Future<List<_Flag>> build() async {
    final data = await Supabase.instance.client
        .from('feature_flags')
        .select('module_key, is_active, display_order')
        .eq('society_id', societyId)
        .order('display_order');
    return (data as List).map((e) => _Flag(
      moduleKey: e['module_key'] as String,
      isActive:  e['is_active']  as bool? ?? false,
      order:     e['display_order'] as int? ?? 99,
    )).toList();
  }

  Future<void> toggle(String moduleKey, bool value) async {
    await Supabase.instance.client
        .from('feature_flags')
        .update({'is_active': value})
        .eq('society_id', societyId)
        .eq('module_key', moduleKey);
    state = AsyncData(state.value!
        .map((f) => f.moduleKey == moduleKey ? f.copyWith(isActive: value) : f)
        .toList());
  }
}

final _flagsProvider =
    AsyncNotifierProvider.autoDispose<_FlagsNotifier, List<_Flag>>(_FlagsNotifier.new);

class _RulesNotifier extends AutoDisposeAsyncNotifier<List<_Rule>> {
  @override
  Future<List<_Rule>> build() async {
    final data = await Supabase.instance.client
        .from('rules')
        .select('rule_code, value_type, current_value, description, is_locked')
        .eq('society_id', societyId)
        .order('rule_code');
    return (data as List).map((e) => _Rule(
      code:        e['rule_code'] as String,
      valueType:   e['value_type'] as String? ?? 'string',
      value:       e['current_value']?.toString() ?? '',
      description: e['description'] as String?,
      isLocked:    e['is_locked'] as bool? ?? false,
    )).toList();
  }

  Future<void> setValue(String code, String value) async {
    await Supabase.instance.client
        .from('rules')
        .update({'current_value': value})
        .eq('society_id', societyId)
        .eq('rule_code', code);
    state = AsyncData(state.value!
        .map((r) => r.code == code ? r.copyWith(value: value) : r)
        .toList());
  }
}

final _rulesProvider =
    AsyncNotifierProvider.autoDispose<_RulesNotifier, List<_Rule>>(_RulesNotifier.new);

// ─── Module display metadata ──────────────────────────────────────────────────

const _moduleLabels = <String, String>{
  'members':           'Member Directory',
  'complaints':        'Complaints',
  'notices':           'Notices & Circulars',
  'events':            'Events',
  'polls':             'Polls & Voting',
  'finance':           'Finance & Dues',
  'facility_booking':  'Facility Booking',
  'visitor_mgmt':      'Visitor Management',
  'vendors':           'Vendors & Work Orders',
  'community':         'Community Board',
  'documents':         'Documents',
  'analytics':         'Analytics & Reports',
  'notifications':     'Notifications',
  'letters':           'Official Letters',
  'agm':               'AGM & Governance',
  'parking':           'Parking Management',
  'maids':             'Domestic Help Registry',
  'gallery':           'Photo Gallery',
  'policies':          'Policies & Compliance',
  'register':          'Society Membership',
  'hoto':              'HOTO Tracker',
  'snags':             'Snag List',
  'tenant_kyc':        'Tenant KYC',
  'water_tankers':     'Water Management',
  'security_patrol':   'Security Patrol Log',
  'memberships':       'Membership Registry',
  'staff_kyc':         'Staff & Maid KYC',
};

const _moduleIcons = <String, IconData>{
  'members':           Icons.people_outlined,
  'complaints':        Icons.report_problem_outlined,
  'notices':           Icons.campaign_outlined,
  'events':            Icons.event_outlined,
  'polls':             Icons.how_to_vote_outlined,
  'finance':           Icons.account_balance_wallet_outlined,
  'facility_booking':  Icons.meeting_room_outlined,
  'visitor_mgmt':      Icons.badge_outlined,
  'vendors':           Icons.handyman_outlined,
  'community':         Icons.forum_outlined,
  'documents':         Icons.folder_outlined,
  'analytics':         Icons.bar_chart_outlined,
  'notifications':     Icons.notifications_outlined,
  'letters':           Icons.mail_outlined,
  'agm':               Icons.gavel_outlined,
  'parking':           Icons.local_parking_outlined,
  'maids':             Icons.cleaning_services_outlined,
  'gallery':           Icons.photo_library_outlined,
  'policies':          Icons.policy_outlined,
  'register':          Icons.app_registration_outlined,
  'hoto':              Icons.swap_horiz_outlined,
  'snags':             Icons.construction_outlined,
  'tenant_kyc':        Icons.verified_user_outlined,
  'water_tankers':     Icons.water_drop_outlined,
  'security_patrol':   Icons.security_outlined,
  'memberships':       Icons.card_membership_outlined,
  'staff_kyc':         Icons.badge_outlined,
};

// ─── Admin Screen ─────────────────────────────────────────────────────────────

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(effectiveDarkProvider);

    return DefaultTabController(
      length: 3,
      child: DsScreenShell(
        title: 'Society Admin',
        headerStyle: DsHeaderStyle.solid,
        bottom: TabBar(
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
          indicatorColor: dsColorIndigo600,
          labelColor: dsColorIndigo600,
          unselectedLabelColor: isDark ? dsDarkTextSecondary : dsTextSecondary,
          tabs: const [
            Tab(text: 'Features'),
            Tab(text: 'Configuration'),
            Tab(text: 'Portal Links'),
          ],
        ),
        slivers: [
          SliverFillRemaining(
            child: TabBarView(
              children: [
                _FeaturesTab(isDark: isDark),
                _ConfigTab(isDark: isDark),
                _LinksTab(isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 1: Feature Flags ─────────────────────────────────────────────────────

class _FeaturesTab extends ConsumerWidget {
  final bool isDark;
  const _FeaturesTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authNotifierProvider).profile;
    final isAdmin = profile?.isAdmin == true;
    final flagsAsync = ref.watch(_flagsProvider);

    return flagsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: dsColorRed500, size: 40),
              const SizedBox(height: 12),
              Text('Failed to load feature flags',
                  style: GoogleFonts.inter(color: isDark ? dsDarkTextPrimary : dsTextPrimary)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(_flagsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (flags) => ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: flags.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 64,
          color: isDark ? dsDarkBorderSubtle : dsBorderSubtle,
        ),
        itemBuilder: (context, i) {
          final flag = flags[i];
          final label = _moduleLabels[flag.moduleKey] ?? flag.moduleKey;
          final icon  = _moduleIcons[flag.moduleKey] ?? Icons.extension_outlined;

          return ListTile(
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: flag.isActive
                    ? (isDark ? dsColorIndigo600.withValues(alpha: 0.2) : dsColorIndigo50)
                    : (isDark ? dsDarkSurfaceMuted : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(dsRadiusSm),
              ),
              child: Icon(
                icon,
                size: 18,
                color: flag.isActive
                    ? (isDark ? dsColorIndigo400 : dsColorIndigo600)
                    : (isDark ? dsDarkTextTertiary : dsTextTertiary),
              ),
            ),
            title: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? dsDarkTextPrimary : dsTextPrimary,
              ),
            ),
            subtitle: Text(
              flag.isActive ? 'Enabled' : 'Disabled',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: flag.isActive
                    ? dsColorEmerald600
                    : (isDark ? dsDarkTextTertiary : dsTextTertiary),
              ),
            ),
            trailing: Switch.adaptive(
              value: flag.isActive,
              activeColor: dsColorIndigo600,
              onChanged: isAdmin
                  ? (v) => ref.read(_flagsProvider.notifier).toggle(flag.moduleKey, v)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

// ─── Tab 2: Configuration (Rules) ────────────────────────────────────────────

class _ConfigTab extends ConsumerWidget {
  final bool isDark;
  const _ConfigTab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authNotifierProvider).profile;
    final isAdmin = profile?.isAdmin == true;
    final rulesAsync = ref.watch(_rulesProvider);

    return rulesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: dsColorRed500, size: 40),
              const SizedBox(height: 12),
              Text('Failed to load configuration',
                  style: GoogleFonts.inter(color: isDark ? dsDarkTextPrimary : dsTextPrimary)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(_rulesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (rules) => rules.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_outlined, size: 48, color: isDark ? dsDarkTextTertiary : dsTextTertiary),
                  const SizedBox(height: 12),
                  Text('No configuration rules found',
                      style: GoogleFonts.inter(color: isDark ? dsDarkTextSecondary : dsTextSecondary)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: rules.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 16,
                color: isDark ? dsDarkBorderSubtle : dsBorderSubtle,
              ),
              itemBuilder: (context, i) {
                final rule = rules[i];
                final canEdit = isAdmin && !rule.isLocked;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(
                    rule.code,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? dsColorIndigo300 : dsColorIndigo700,
                    ),
                  ),
                  subtitle: rule.description != null
                      ? Text(
                          rule.description!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                          ),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (rule.isLocked)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(Icons.lock_outlined, size: 14,
                              color: isDark ? dsDarkTextTertiary : dsTextTertiary),
                        ),
                      _RuleValueChip(rule: rule, isDark: isDark, canEdit: canEdit),
                    ],
                  ),
                  onTap: canEdit
                      ? () => _showEditDialog(context, ref, rule, isDark)
                      : null,
                );
              },
            ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, _Rule rule, bool isDark) {
    final ctrl = TextEditingController(text: rule.value);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(dsRadiusCardLg)),
        title: Text(rule.code,
            style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w700,
                color: dsColorIndigo600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rule.description != null) ...[
              Text(rule.description!,
                  style: GoogleFonts.inter(fontSize: 13, color: isDark ? dsDarkTextSecondary : dsTextSecondary)),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: ctrl,
              keyboardType: rule.valueType == 'int' ? TextInputType.number : TextInputType.text,
              style: GoogleFonts.jetBrainsMono(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Value (${rule.valueType})',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(dsRadiusInput)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { ctrl.dispose(); Navigator.pop(ctx); },
            child: Text('Cancel', style: GoogleFonts.inter(color: isDark ? dsDarkTextSecondary : dsTextSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final newValue = ctrl.text.trim();
              Navigator.pop(ctx);
              ctrl.dispose();
              if (newValue.isNotEmpty) {
                await ref.read(_rulesProvider.notifier).setValue(rule.code, newValue);
              }
            },
            child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: dsColorIndigo600)),
          ),
        ],
      ),
    );
  }
}

class _RuleValueChip extends StatelessWidget {
  final _Rule rule;
  final bool isDark;
  final bool canEdit;
  const _RuleValueChip({required this.rule, required this.isDark, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    final bg = canEdit
        ? (isDark ? dsColorIndigo600.withValues(alpha: 0.15) : dsColorIndigo50)
        : (isDark ? dsDarkSurfaceMuted : const Color(0xFFF3F4F6));
    final fg = canEdit
        ? (isDark ? dsColorIndigo300 : dsColorIndigo700)
        : (isDark ? dsDarkTextTertiary : dsTextSecondary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(dsRadiusFull),
      ),
      child: Text(
        rule.value.length > 16 ? '${rule.value.substring(0, 14)}…' : rule.value,
        style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ─── Tab 3: Portal Quick Links ────────────────────────────────────────────────

class _LinksTab extends StatelessWidget {
  final bool isDark;
  const _LinksTab({required this.isDark});

  static const _links = [
    _Link('Admin Dashboard',  Icons.admin_panel_settings_outlined, 'admin',           dsColorIndigo600),
    _Link('Feature Flags',    Icons.toggle_on_outlined,            'admin/features',  dsColorEmerald600),
    _Link('Rules & Config',   Icons.tune_outlined,                 'admin/rules',     dsColorAmber700),
    _Link('Roles & Access',   Icons.lock_person_outlined,          'admin/rbac',      dsColorIndigo500),
    _Link('Audit Log',        Icons.receipt_long_outlined,         'admin/audit',     dsTextSecondary),
    _Link('Memberships',      Icons.card_membership_outlined,      'admin/memberships', dsColorIndigo600),
    _Link('Staff & KYC',      Icons.badge_outlined,                'admin/staff-kyc', dsColorEmerald600),
    _Link('Analytics',        Icons.bar_chart_outlined,            'analytics',       dsColorAmber700),
    _Link('Branding',         Icons.palette_outlined,              'admin/branding',  dsColorIndigo500),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.9,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _links.length,
      itemBuilder: (context, i) => _LinkTile(link: _links[i], isDark: isDark),
    );
  }
}

class _Link {
  final String label;
  final IconData icon;
  final String portalPath;
  final Color color;
  const _Link(this.label, this.icon, this.portalPath, this.color);
}

class _LinkTile extends StatelessWidget {
  final _Link link;
  final bool isDark;
  const _LinkTile({required this.link, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse('$portalUrl/portal/${link.portalPath}');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: DSFadeSlide(
        child: Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(dsRadiusCard),
            boxShadow: isDark ? [] : dsShadowSm,
            border: isDark ? Border.all(color: dsDarkBorderLight) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: link.color.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(dsRadiusMd),
                ),
                child: Icon(link.icon, size: 22, color: link.color),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  link.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                    height: 1.3,
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
