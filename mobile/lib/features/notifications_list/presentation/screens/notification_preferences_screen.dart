import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/notification_repository.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  NotificationPreferences? _prefs;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _save() async {
    if (_prefs == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(notificationRepositoryProvider)
          .savePreferences(_prefs!);
      ref.invalidate(notificationPreferencesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preferences saved.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: kSecondary500,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: kRed600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      backgroundColor: kBgWarm,
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          if (_prefs != null)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Save',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: kPrimary600,
                          fontSize: 15)),
            ),
        ],
      ),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (loadedPrefs) {
          _prefs ??= loadedPrefs;
          final prefs = _prefs!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Channels ───────────────────────────────────────────────
              _SectionHeader('Notification Channels'),
              const SizedBox(height: 8),
              _PrefsCard(
                children: [
                  _ChannelTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    subtitle: 'Receive notifications by email',
                    value: prefs.emailEnabled,
                    onChanged: (v) => setState(
                        () => _prefs = prefs.copyWith(emailEnabled: v)),
                  ),
                  _ChannelTile(
                    icon: Icons.summarize_outlined,
                    label: 'Email Digest',
                    subtitle: 'Daily summary email instead of individual emails',
                    value: prefs.emailDigestEnabled,
                    onChanged: (v) => setState(
                        () => _prefs = prefs.copyWith(emailDigestEnabled: v)),
                  ),
                  _ChannelTile(
                    icon: Icons.sms_outlined,
                    label: 'SMS',
                    subtitle: 'Critical alerts only (charges may apply)',
                    value: prefs.smsEnabled,
                    onChanged: (v) => setState(
                        () => _prefs = prefs.copyWith(smsEnabled: v)),
                  ),
                  _ChannelTile(
                    icon: Icons.notifications_outlined,
                    label: 'Push Notifications',
                    subtitle: 'In-app push alerts',
                    value: prefs.pushEnabled,
                    onChanged: (v) => setState(
                        () => _prefs = prefs.copyWith(pushEnabled: v)),
                  ),
                  _ChannelTile(
                    icon: Icons.chat_outlined,
                    label: 'WhatsApp',
                    subtitle: 'Via society WhatsApp bot',
                    value: prefs.whatsappEnabled,
                    onChanged: (v) => setState(
                        () => _prefs = prefs.copyWith(whatsappEnabled: v)),
                    showDivider: false,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Categories ─────────────────────────────────────────────
              _SectionHeader('Notification Categories'),
              const SizedBox(height: 8),
              _PrefsCard(
                children: _buildCategoryTiles(prefs),
              ),

              const SizedBox(height: 20),

              // ── Quiet hours ────────────────────────────────────────────
              _SectionHeader('Quiet Hours'),
              const SizedBox(height: 4),
              Text(
                'No notifications will be sent during quiet hours.',
                style: GoogleFonts.inter(
                    fontSize: 12, color: kTextSecondary),
              ),
              const SizedBox(height: 8),
              _PrefsCard(
                children: [
                  _QuietHourTile(
                    label: 'From',
                    value: prefs.quietFrom,
                    onChanged: (v) =>
                        setState(() => _prefs = prefs.copyWith(quietFrom: v)),
                  ),
                  _QuietHourTile(
                    label: 'To',
                    value: prefs.quietTo,
                    onChanged: (v) =>
                        setState(() => _prefs = prefs.copyWith(quietTo: v)),
                    showDivider: false,
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildCategoryTiles(NotificationPreferences prefs) {
    const categories = {
      'complaint': ('Complaints', Icons.report_problem_outlined),
      'notice': ('Notices', Icons.notifications_outlined),
      'event': ('Events', Icons.event_outlined),
      'poll': ('Polls', Icons.how_to_vote_outlined),
      'payment': ('Payments & Finance', Icons.payment_outlined),
      'community': ('Community Board', Icons.forum_outlined),
      'visitor': ('Visitor Passes', Icons.badge_outlined),
      'facility': ('Facility Bookings', Icons.meeting_room_outlined),
      'amc': ('AMC & Maintenance', Icons.build_outlined),
      'feedback': ('Feedback', Icons.rate_review_outlined),
      'system': ('System Alerts', Icons.info_outlined),
      'water': ('Water Management', Icons.water_drop_outlined),
    };

    final entries = categories.entries.toList();
    return List.generate(entries.length, (i) {
      final key = entries[i].key;
      final (label, icon) = entries[i].value;
      return _ChannelTile(
        icon: icon,
        label: label,
        value: prefs.categories[key] ?? true,
        onChanged: (v) {
          final updated = Map<String, bool>.from(prefs.categories);
          updated[key] = v;
          setState(() => _prefs = prefs.copyWith(categories: updated));
        },
        showDivider: i < entries.length - 1,
      );
    });
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: kTextSecondary,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _PrefsCard extends StatelessWidget {
  final List<Widget> children;
  const _PrefsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  const _ChannelTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: kTextSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: kTextPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: kTextSecondary),
                      ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeColor: kPrimary600,
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 48),
      ],
    );
  }
}

class _QuietHourTile extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool showDivider;

  const _QuietHourTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            final parts = value?.split(':');
            final initial = parts != null && parts.length == 2
                ? TimeOfDay(
                    hour: int.tryParse(parts[0]) ?? 22,
                    minute: int.tryParse(parts[1]) ?? 0)
                : const TimeOfDay(hour: 22, minute: 0);
            final picked =
                await showTimePicker(context: context, initialTime: initial);
            if (picked != null) {
              onChanged(
                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
            }
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.bedtime_outlined,
                    size: 20, color: kTextSecondary),
                const SizedBox(width: 12),
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: kTextPrimary)),
                const Spacer(),
                Text(
                  value ?? 'Not set',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: value != null ? kPrimary600 : kTextSecondary,
                    fontWeight: value != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    size: 18, color: kTextSecondary),
              ],
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 48),
      ],
    );
  }
}
