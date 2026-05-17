import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design/ds_animations.dart';
import '../../../../core/design/ds_screen_shell.dart';
import '../../../../core/design/ds_tokens.dart';
import '../../../../core/design/ds_typography_scale.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../../shared/models/profile.dart';
import '../../../auth/domain/auth_notifier.dart';

// ─── Profile Screen ───────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static Future<void> _openPortal(String path) async {
    final uri = Uri.parse('https://portal.utamacs.org/portal/$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark    = ref.watch(isDarkModeProvider);
    final authState = ref.watch(authNotifierProvider);
    final profile   = authState.profile;

    final unitDetails = ref.watch(_unitDetailsProvider).valueOrNull;
    final vehicleInfo = ref.watch(_vehicleProvider).valueOrNull;
    final consentInfo = ref.watch(_consentProvider).valueOrNull;

    final initial = (profile?.fullName?.isNotEmpty == true)
        ? profile!.fullName![0].toUpperCase()
        : 'R';
    final name = profile?.displayName ?? 'Resident';
    final unit = profile?.unitDisplay ?? '';
    final role = profile?.portalRole ?? 'member';

    return DsScreenShell(
      title: 'My Profile',
      headerStyle: DsHeaderStyle.solid,
      actions: [
        if (profile != null)
          DsActionButton(
            icon: Icons.edit_outlined,
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _EditProfileModal(profile: profile),
            ),
          ),
      ],
      slivers: [
        // ── Avatar + name card ────────────────────────────────────────────
        DSFadeSlide(
          delay: const Duration(milliseconds: 50),
          child: _ProfileHeroCard(
            initial: initial,
            name: name,
            unit: unit,
            role: role,
            bio: profile?.bio,
            isDark: isDark,
          ),
        ),

        const SizedBox(height: dsSpace4),

        // ── Appearance section ────────────────────────────────────────────
        DSFadeSlide(
          delay: const Duration(milliseconds: 100),
          child: _SectionLabel(label: 'APPEARANCE', isDark: isDark),
        ),
        DSFadeSlide(
          delay: const Duration(milliseconds: 130),
          child: _AppearanceCard(isDark: isDark),
        ),

        const SizedBox(height: dsSpace4),

        // ── Personal info section ─────────────────────────────────────────
        DSFadeSlide(
          delay: const Duration(milliseconds: 160),
          child: _SectionLabel(label: 'PERSONAL INFO', isDark: isDark),
        ),
        DSFadeSlide(
          delay: const Duration(milliseconds: 190),
          child: _InfoCard(
            isDark: isDark,
            rows: [
              _InfoRowData(
                icon: Icons.apartment_outlined,
                label: 'Society',
                value: 'UTA MACS',
              ),
              _InfoRowData(
                icon: Icons.home_outlined,
                label: 'Unit',
                value: unit.isNotEmpty ? 'Unit $unit' : '—',
              ),
              _InfoRowData(
                icon: Icons.shield_outlined,
                label: 'Role',
                value: _roleLabel(role),
              ),
              if (profile?.whatsappNumber != null &&
                  profile!.whatsappNumber!.isNotEmpty)
                _InfoRowData(
                  icon: Icons.chat_outlined,
                  label: 'WhatsApp',
                  value: profile.whatsappNumber!,
                ),
              _InfoRowData(
                icon: Icons.language_outlined,
                label: 'Language',
                value: _langLabel(profile?.preferredLanguage ?? 'en'),
              ),
            ],
          ),
        ),

        // ── Unit details card ─────────────────────────────────────────────
        if (unitDetails != null) ...[
          const SizedBox(height: dsSpace4),
          DSFadeSlide(
            delay: const Duration(milliseconds: 220),
            child: _SectionLabel(label: 'UNIT DETAILS', isDark: isDark),
          ),
          DSFadeSlide(
            delay: const Duration(milliseconds: 250),
            child: _UnitDetailsCard(details: unitDetails, isDark: isDark),
          ),
        ],

        // ── Vehicle / parking ─────────────────────────────────────────────
        if (vehicleInfo != null) ...[
          const SizedBox(height: dsSpace4),
          DSFadeSlide(
            delay: const Duration(milliseconds: 280),
            child: _SectionLabel(label: 'VEHICLE & PARKING', isDark: isDark),
          ),
          DSFadeSlide(
            delay: const Duration(milliseconds: 310),
            child: _VehicleInfoCard(info: vehicleInfo, isDark: isDark),
          ),
        ],

        // ── DPDPA consent ─────────────────────────────────────────────────
        if (consentInfo != null) ...[
          const SizedBox(height: dsSpace4),
          DSFadeSlide(
            delay: const Duration(milliseconds: 340),
            child: _SectionLabel(label: 'DATA PRIVACY', isDark: isDark),
          ),
          DSFadeSlide(
            delay: const Duration(milliseconds: 370),
            child: _InfoCard(
              isDark: isDark,
              rows: [
                _InfoRowData(
                  icon: Icons.check_circle_outline,
                  label: 'DPDPA Consent',
                  value: 'v${consentInfo.policyVersion}',
                ),
                _InfoRowData(
                  icon: Icons.calendar_today_outlined,
                  label: 'Accepted on',
                  value: DateFormat('d MMM yyyy').format(consentInfo.acceptedAt),
                ),
              ],
            ),
          ),
        ],

        // ── Emergency contact ─────────────────────────────────────────────
        if (profile?.emergencyContact != null) ...[
          const SizedBox(height: dsSpace4),
          DSFadeSlide(
            delay: const Duration(milliseconds: 400),
            child: _SectionLabel(label: 'EMERGENCY CONTACT', isDark: isDark),
          ),
          DSFadeSlide(
            delay: const Duration(milliseconds: 430),
            child: _EmergencyContactCard(
              contact: profile!.emergencyContact!,
              isDark: isDark,
            ),
          ),
        ],

        // ── Account actions ───────────────────────────────────────────────
        const SizedBox(height: dsSpace6),
        DSFadeSlide(
          delay: const Duration(milliseconds: 460),
          child: _AccountActions(isDark: isDark),
        ),

        // ── App version footer ────────────────────────────────────────────
        const SizedBox(height: dsSpace6),
        DSFadeSlide(
          delay: const Duration(milliseconds: 490),
          child: Center(
            child: Text(
              'UTA MACS Resident App · v1.0',
              style: GoogleFonts.inter(
                fontSize: context.sp(11),
                color: isDark ? dsDarkTextTertiary : dsTextTertiary,
              ),
            ),
          ),
        ),
        const SizedBox(height: dsSpace4),
      ],
    );
  }

  static String _roleLabel(String role) {
    const labels = {
      'member':         'Member',
      'executive':      'Executive',
      'secretary':      'Secretary',
      'president':      'President',
      'security_guard': 'Security Guard',
    };
    return labels[role] ?? role;
  }

  static String _langLabel(String code) {
    const labels = {'en': 'English', 'te': 'Telugu', 'hi': 'Hindi'};
    return labels[code] ?? code;
  }
}

// ─── Profile Hero Card ────────────────────────────────────────────────────────

class _ProfileHeroCard extends ConsumerWidget {
  final String initial;
  final String name;
  final String unit;
  final String role;
  final String? bio;
  final bool isDark;

  const _ProfileHeroCard({
    required this.initial,
    required this.name,
    required this.unit,
    required this.role,
    required this.isDark,
    this.bio,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final roleColor = _roleColor(role);

    return Padding(
      padding: const EdgeInsets.fromLTRB(dsSpace4, dsSpace4, dsSpace4, 0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCardLg),
          boxShadow: isDark ? [] : dsShadowMd,
          border: isDark
              ? Border.all(color: dsDarkBorderLight, width: 1)
              : null,
        ),
        child: Column(
          children: [
            // Gradient banner
            Container(
              height: 72,
              decoration: BoxDecoration(
                gradient: dsGradientHero,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(dsRadiusCardLg),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -36),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(dsSpace5, 0, dsSpace5, 0),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: dsGradientHero,
                            shape: BoxShape.circle,
                            border: Border.all(color: surface, width: 3),
                            boxShadow: dsShadowMd,
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: GoogleFonts.poppins(
                                fontSize: context.sp(26),
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () => ProfileScreen._openPortal(
                                'profile?action=upload-avatar'),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: dsColorIndigo600,
                                shape: BoxShape.circle,
                                border: Border.all(color: surface, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: dsSpace2),
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: context.sp(18),
                        fontWeight: FontWeight.w700,
                        color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                        height: 1.1,
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Unit $unit',
                        style: GoogleFonts.inter(
                          fontSize: context.sp(13),
                          color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                        ),
                      ),
                    ],
                    if (bio != null && bio!.isNotEmpty) ...[
                      const SizedBox(height: dsSpace2),
                      Text(
                        bio!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: context.sp(12),
                          color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: dsSpace3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: dsSpace3, vertical: 5),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(dsRadiusFull),
                      ),
                      child: Text(
                        _roleLabel(role),
                        style: GoogleFonts.inter(
                          fontSize: context.sp(11),
                          fontWeight: FontWeight.w700,
                          color: roleColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: dsSpace4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _roleLabel(String role) {
    const labels = {
      'member':         'Member',
      'executive':      'Executive',
      'secretary':      'Secretary',
      'president':      'President',
      'security_guard': 'Security Guard',
    };
    return labels[role] ?? role;
  }

  Color _roleColor(String role) {
    if (['executive', 'secretary', 'president'].contains(role)) {
      return dsColorIndigo600;
    }
    if (role == 'security_guard') return dsColorEmerald600;
    return dsTextSecondary;
  }
}

// ─── Appearance Card (dark mode + text scale) ─────────────────────────────────

class _AppearanceCard extends ConsumerWidget {
  final bool isDark;
  const _AppearanceCard({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface     = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderLight : dsBorderSubtle;
    final currentScale = ref.watch(textScaleProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: dsSpace4),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border: isDark ? Border.all(color: dsDarkBorderLight, width: 1) : null,
        ),
        child: Column(
          children: [
            // ── Dark mode toggle ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: dsSpace4, vertical: dsSpace3),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? dsColorIndigo600.withValues(alpha: 0.15)
                          : dsColorIndigo50,
                      borderRadius: BorderRadius.circular(dsRadiusSm),
                    ),
                    child: Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      size: context.si(18),
                      color: isDark ? dsColorIndigo400 : dsColorIndigo600,
                    ),
                  ),
                  const SizedBox(width: dsSpace3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dark Mode',
                          style: GoogleFonts.inter(
                            fontSize: context.sp(14),
                            fontWeight: FontWeight.w600,
                            color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                          ),
                        ),
                        Text(
                          isDark ? 'On — easy on the eyes' : 'Off — light theme',
                          style: GoogleFonts.inter(
                            fontSize: context.sp(11),
                            color: isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: isDark,
                    activeThumbColor: dsColorIndigo600,
                    onChanged: (v) => ref
                        .read(appPreferencesProvider.notifier)
                        .setDarkMode(v),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: borderColor),

            // ── Text scale picker ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  dsSpace4, dsSpace3, dsSpace4, dsSpace4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark
                              ? dsColorAmber500.withValues(alpha: 0.12)
                              : dsColorAmber50,
                          borderRadius: BorderRadius.circular(dsRadiusSm),
                        ),
                        child: Icon(
                          Icons.text_fields_rounded,
                          size: context.si(18),
                          color: isDark ? dsColorAmber300 : dsColorAmber700,
                        ),
                      ),
                      const SizedBox(width: dsSpace3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Text Size',
                              style: GoogleFonts.inter(
                                fontSize: context.sp(14),
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? dsDarkTextPrimary
                                    : dsTextPrimary,
                              ),
                            ),
                            Text(
                              currentScale.description,
                              style: GoogleFonts.inter(
                                fontSize: context.sp(11),
                                color: isDark
                                    ? dsDarkTextSecondary
                                    : dsTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: dsSpace4),
                  Row(
                    children: DsTextScale.values.map((scale) {
                      final isSelected = scale == currentScale;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: scale == DsTextScale.large ? 0 : dsSpace2,
                          ),
                          child: GestureDetector(
                            onTap: () => ref
                                .read(appPreferencesProvider.notifier)
                                .setTextScale(scale),
                            child: AnimatedContainer(
                              duration: dsDurationNormal,
                              curve: dsEaseStandard,
                              padding: const EdgeInsets.symmetric(
                                horizontal: dsSpace3,
                                vertical: dsSpace3,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? dsColorIndigo600
                                    : (isDark
                                        ? dsDarkSurfaceMuted
                                        : dsColorIndigo25),
                                borderRadius:
                                    BorderRadius.circular(dsRadiusMd),
                                border: Border.all(
                                  color: isSelected
                                      ? dsColorIndigo600
                                      : borderColor,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow:
                                    isSelected ? dsShadowBrand : [],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    scale.label,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12 * scale.textFactor,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark
                                              ? dsDarkTextPrimary
                                              : dsColorIndigo600),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    scale.label == 'A'
                                        ? 'Small'
                                        : scale.label == 'A+'
                                            ? 'Default'
                                            : 'Large',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.8)
                                          : (isDark
                                              ? dsDarkTextSecondary
                                              : dsTextSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Info Card (generic rows) ─────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<_InfoRowData> rows;
  final bool isDark;

  const _InfoCard({required this.rows, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final dividerColor = isDark ? dsDarkBorderSubtle : dsBorderSubtle;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: dsSpace4),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border: isDark ? Border.all(color: dsDarkBorderLight, width: 1) : null,
        ),
        child: Column(
          children: rows.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            return Column(
              children: [
                if (i > 0) Divider(height: 1, color: dividerColor, indent: 56),
                _InfoRowWidget(data: row, isDark: isDark),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _InfoRowData {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRowData({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _InfoRowWidget extends StatelessWidget {
  final _InfoRowData data;
  final bool isDark;
  const _InfoRowWidget({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: dsSpace4, vertical: dsSpace3),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? dsColorIndigo600.withValues(alpha: 0.12)
                  : dsColorIndigo50,
              borderRadius: BorderRadius.circular(dsRadiusSm),
            ),
            child: Icon(
              data.icon,
              size: context.si(17),
              color: isDark ? dsColorIndigo400 : dsColorIndigo600,
            ),
          ),
          const SizedBox(width: dsSpace3),
          Text(
            data.label,
            style: GoogleFonts.inter(
              fontSize: context.sp(13),
              color: isDark ? dsDarkTextSecondary : dsTextSecondary,
            ),
          ),
          const Spacer(),
          Text(
            data.value,
            style: GoogleFonts.inter(
              fontSize: context.sp(13),
              fontWeight: FontWeight.w600,
              color: isDark ? dsDarkTextPrimary : dsTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(dsSpace4, 0, dsSpace4, dsSpace2),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: context.sp(11),
          fontWeight: FontWeight.w700,
          color: isDark ? dsDarkTextTertiary : dsTextTertiary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Unit Details Card ────────────────────────────────────────────────────────

class _UnitDetailsCard extends StatelessWidget {
  final _UnitDetails details;
  final bool isDark;
  const _UnitDetailsCard({required this.details, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final rows = <_InfoRowData>[];
    if (details.floor != null) {
      rows.add(_InfoRowData(
        icon: Icons.layers_outlined,
        label: 'Floor',
        value: _floorLabel(details.floor!),
      ));
    }
    if (details.areaSqft != null) {
      rows.add(_InfoRowData(
        icon: Icons.square_foot_outlined,
        label: 'Area',
        value: '${details.areaSqft!.toStringAsFixed(0)} sq ft',
      ));
    }
    if (details.residencyType != null) {
      rows.add(_InfoRowData(
        icon: Icons.home_work_outlined,
        label: 'Occupancy',
        value: _residencyLabel(details.residencyType!),
      ));
    }
    if (details.moveInDate != null) {
      rows.add(_InfoRowData(
        icon: Icons.calendar_today_outlined,
        label: 'Move-in',
        value: dateFormat.format(details.moveInDate!),
      ));
    }
    if (details.numOccupants != null) {
      rows.add(_InfoRowData(
        icon: Icons.people_outlined,
        label: 'Occupants',
        value:
            '${details.numOccupants} person${details.numOccupants != 1 ? 's' : ''}',
      ));
    }
    if (details.isNri) {
      rows.add(const _InfoRowData(
        icon: Icons.flight_outlined,
        label: 'Residency',
        value: 'NRI (Non-Resident Indian)',
      ));
    }
    return _InfoCard(rows: rows, isDark: isDark);
  }

  static String _floorLabel(int floor) {
    if (floor == 0) return 'Ground Floor';
    final suffix = (floor % 100 >= 11 && floor % 100 <= 13)
        ? 'th'
        : ['th', 'st', 'nd', 'rd', 'th', 'th', 'th', 'th', 'th', 'th'][floor % 10];
    return '$floor$suffix Floor';
  }

  static String _residencyLabel(String type) {
    const labels = {'owner': 'Owner Occupied', 'tenant': 'Tenant Occupied'};
    return labels[type] ?? type;
  }
}

// ─── Vehicle Info Card ────────────────────────────────────────────────────────

class _VehicleInfoCard extends StatelessWidget {
  final _VehicleInfo info;
  final bool isDark;
  const _VehicleInfoCard({required this.info, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final rows = <_InfoRowData>[];
    if (info.slotNumber != null) {
      rows.add(_InfoRowData(
        icon: Icons.local_parking_outlined,
        label: 'Slot No.',
        value: info.slotNumber!,
      ));
    }
    if (info.vehicleNumber != null && info.vehicleNumber!.isNotEmpty) {
      rows.add(_InfoRowData(
        icon: Icons.pin_outlined,
        label: 'Reg. Number',
        value: info.vehicleNumber!,
      ));
    }
    if (info.vehicleMake != null && info.vehicleMake!.isNotEmpty) {
      rows.add(_InfoRowData(
        icon: Icons.directions_car,
        label: 'Vehicle Make',
        value: info.vehicleMake!,
      ));
    }
    if (info.slotType != null) {
      rows.add(_InfoRowData(
        icon: Icons.garage_outlined,
        label: 'Slot Type',
        value:
            info.slotType![0].toUpperCase() + info.slotType!.substring(1),
      ));
    }
    return _InfoCard(rows: rows, isDark: isDark);
  }
}

// ─── Emergency Contact Card ───────────────────────────────────────────────────

class _EmergencyContactCard extends StatelessWidget {
  final Map<String, dynamic> contact;
  final bool isDark;
  const _EmergencyContactCard(
      {required this.contact, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: dsSpace4),
      child: Container(
        padding: const EdgeInsets.all(dsSpace4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border: Border.all(
            color: isDark
                ? dsColorRed700.withValues(alpha: 0.3)
                : dsColorRed100,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark
                    ? dsColorRed700.withValues(alpha: 0.15)
                    : dsColorRed50,
                borderRadius: BorderRadius.circular(dsRadiusMd),
              ),
              child: Icon(
                Icons.emergency_rounded,
                size: context.si(20),
                color: isDark ? dsColorRed500 : dsColorRed600,
              ),
            ),
            const SizedBox(width: dsSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (contact['name'] != null)
                    Text(
                      contact['name'] as String,
                      style: GoogleFonts.inter(
                        fontSize: context.sp(14),
                        fontWeight: FontWeight.w700,
                        color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                      ),
                    ),
                  if (contact['relationship'] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      contact['relationship'] as String,
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
          ],
        ),
      ),
    );
  }
}

// ─── Account Actions ──────────────────────────────────────────────────────────

class _AccountActions extends ConsumerWidget {
  final bool isDark;
  const _AccountActions({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: dsSpace4),
      child: Column(
        children: [
          // Reset password
          GestureDetector(
            onTap: () =>
                ProfileScreen._openPortal('profile?action=reset-password'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: dsSpace5, vertical: dsSpace4),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(dsRadiusCard),
                border: Border.all(color: borderColor),
                boxShadow: isDark ? [] : dsShadowXs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_reset_outlined,
                    size: context.si(18),
                    color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                  ),
                  const SizedBox(width: dsSpace2),
                  Text(
                    'Reset Password',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w600,
                      color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: dsSpace3),
          // Sign out
          GestureDetector(
            onTap: () => _confirmSignOut(context, ref),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: dsSpace5, vertical: dsSpace4),
              decoration: BoxDecoration(
                color: isDark
                    ? dsColorRed700.withValues(alpha: 0.08)
                    : dsColorRed50,
                borderRadius: BorderRadius.circular(dsRadiusCard),
                border: Border.all(
                  color: isDark
                      ? dsColorRed700.withValues(alpha: 0.35)
                      : dsColorRed100,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    size: context.si(18),
                    color: isDark ? dsColorRed500 : dsColorRed600,
                  ),
                  const SizedBox(width: dsSpace2),
                  Text(
                    'Sign Out',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w700,
                      color: isDark ? dsColorRed500 : dsColorRed600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(dsRadiusCardLg)),
        title: Text(
          'Sign out?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'You will need to sign in again to access the app.',
          style: GoogleFonts.inter(color: dsTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: dsTextSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authNotifierProvider.notifier).signOut();
            },
            child: Text(
              'Sign Out',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, color: dsColorRed600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Edit Profile Modal ────────────────────────────────────────────────────────

class _EditProfileModal extends ConsumerStatefulWidget {
  final Profile profile;
  const _EditProfileModal({required this.profile});

  @override
  ConsumerState<_EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends ConsumerState<_EditProfileModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _whatsappCtrl;
  late final TextEditingController _ecNameCtrl;
  late final TextEditingController _ecPhoneCtrl;
  late String _preferredLanguage;
  late String? _ecRelationship;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.fullName ?? '');
    _bioCtrl  = TextEditingController(text: widget.profile.bio ?? '');
    _whatsappCtrl =
        TextEditingController(text: widget.profile.whatsappNumber ?? '');
    _preferredLanguage = widget.profile.preferredLanguage;
    final ec = widget.profile.emergencyContact;
    _ecNameCtrl  = TextEditingController(text: ec?['name'] as String? ?? '');
    _ecPhoneCtrl = TextEditingController(text: ec?['phone'] as String? ?? '');
    _ecRelationship = ec?['relationship'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _whatsappCtrl.dispose();
    _ecNameCtrl.dispose();
    _ecPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    Map<String, dynamic>? ecMap;
    if (_ecNameCtrl.text.trim().isNotEmpty) {
      ecMap = {
        'name': _ecNameCtrl.text.trim(),
        if (_ecPhoneCtrl.text.trim().isNotEmpty)
          'phone': _ecPhoneCtrl.text.trim(),
        if (_ecRelationship != null) 'relationship': _ecRelationship,
      };
    }

    try {
      await ref.read(authNotifierProvider.notifier).updateProfile(
            fullName:         _nameCtrl.text.trim(),
            bio:              _bioCtrl.text.trim(),
            whatsappNumber:   _whatsappCtrl.text.trim(),
            preferredLanguage: _preferredLanguage,
            emergencyContact: ecMap,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
            backgroundColor: dsColorEmerald600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(dsRadiusMd)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e', style: GoogleFonts.inter()),
            backgroundColor: dsColorRed600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(dsRadiusMd)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(isDarkModeProvider);
    final sheetBg = isDark ? dsDarkSurface : dsSurface;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(dsRadiusXxl)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: dsSpace3),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? dsDarkBorderLight : dsBorderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Header
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(dsSpace5, dsSpace3, dsSpace2, 0),
              child: Row(
                children: [
                  Text(
                    'Edit Profile',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: dsColorIndigo600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: isDark
                            ? dsDarkTextSecondary
                            : dsTextSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(
                color: isDark ? dsDarkBorderLight : dsBorderLight, height: 1),
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(
                      dsSpace5, dsSpace4, dsSpace5, 48),
                  children: [
                    _buildField(context, isDark, controller: _nameCtrl,
                        label: 'Full name',
                        capitalize: TextCapitalization.words),
                    const SizedBox(height: dsSpace3),
                    _buildField(context, isDark,
                        controller: _bioCtrl,
                        label: 'Bio (optional)',
                        maxLines: 3,
                        maxLength: 500,
                        capitalize: TextCapitalization.sentences),
                    const SizedBox(height: dsSpace3),
                    _buildField(context, isDark,
                        controller: _whatsappCtrl,
                        label: 'WhatsApp number (optional)',
                        hint: '+919876543210',
                        keyboard: TextInputType.phone,
                        maxLength: 15),
                    const SizedBox(height: dsSpace3),
                    _buildDropdown<String>(
                      context,
                      isDark,
                      label: 'Preferred language',
                      value: _preferredLanguage,
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'te', child: Text('Telugu')),
                        DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                      ],
                      onChanged: (v) => setState(
                          () => _preferredLanguage = v ?? _preferredLanguage),
                    ),
                    const SizedBox(height: dsSpace5),
                    Text(
                      'EMERGENCY CONTACT',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: dsColorIndigo600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: dsSpace3),
                    _buildField(context, isDark,
                        controller: _ecNameCtrl,
                        label: 'Contact name',
                        capitalize: TextCapitalization.words),
                    const SizedBox(height: dsSpace3),
                    _buildField(context, isDark,
                        controller: _ecPhoneCtrl,
                        label: 'Contact phone',
                        keyboard: TextInputType.phone),
                    const SizedBox(height: dsSpace3),
                    _buildDropdown<String?>(
                      context,
                      isDark,
                      label: 'Relationship',
                      value: _ecRelationship,
                      items: const [
                        DropdownMenuItem(
                            value: null, child: Text('— None —')),
                        DropdownMenuItem(
                            value: 'spouse', child: Text('Spouse')),
                        DropdownMenuItem(
                            value: 'parent', child: Text('Parent')),
                        DropdownMenuItem(
                            value: 'sibling', child: Text('Sibling')),
                        DropdownMenuItem(
                            value: 'child', child: Text('Child')),
                        DropdownMenuItem(
                            value: 'friend', child: Text('Friend')),
                        DropdownMenuItem(
                            value: 'other', child: Text('Other')),
                      ],
                      onChanged: (v) =>
                          setState(() => _ecRelationship = v),
                    ),
                    const SizedBox(height: dsSpace6),
                    GestureDetector(
                      onTap: _saving ? null : _save,
                      child: AnimatedContainer(
                        duration: dsDurationFast,
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _saving
                              ? dsColorIndigo300
                              : dsColorIndigo600,
                          borderRadius:
                              BorderRadius.circular(dsRadiusButton),
                          boxShadow: _saving ? [] : dsShadowBrand,
                        ),
                        child: Center(
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Save Changes',
                                  style: GoogleFonts.inter(
                                    fontSize: context.sp(15),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    bool isDark, {
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType keyboard = TextInputType.text,
    TextCapitalization capitalize = TextCapitalization.none,
  }) {
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;
    final fillColor = isDark ? dsDarkSurfaceMuted : dsBackground;
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: capitalize,
      style: GoogleFonts.inter(
        fontSize: context.sp(14),
        color: isDark ? dsDarkTextPrimary : dsTextPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: fillColor,
        labelStyle: GoogleFonts.inter(
          fontSize: context.sp(13),
          color: isDark ? dsDarkTextSecondary : dsTextSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusInput),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusInput),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusInput),
          borderSide: const BorderSide(color: dsColorIndigo600, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: dsSpace4, vertical: dsSpace3),
      ),
    );
  }

  Widget _buildDropdown<T>(
    BuildContext context,
    bool isDark, {
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;
    final fillColor   = isDark ? dsDarkSurfaceMuted : dsBackground;
    return DropdownButtonFormField<T>(
      initialValue: value,
      dropdownColor: isDark ? dsDarkSurfaceElevated : dsSurface,
      style: GoogleFonts.inter(
        fontSize: context.sp(14),
        color: isDark ? dsDarkTextPrimary : dsTextPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: fillColor,
        labelStyle: GoogleFonts.inter(
          fontSize: context.sp(13),
          color: isDark ? dsDarkTextSecondary : dsTextSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusInput),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusInput),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dsRadiusInput),
          borderSide: const BorderSide(color: dsColorIndigo600, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: dsSpace4, vertical: dsSpace3),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}

// ─── Data Models & Providers ──────────────────────────────────────────────────

class _UnitDetails {
  final double? areaSqft;
  final int? floor;
  final String? residencyType;
  final DateTime? moveInDate;
  final int? numOccupants;
  final bool isNri;

  const _UnitDetails({
    this.areaSqft,
    this.floor,
    this.residencyType,
    this.moveInDate,
    this.numOccupants,
    this.isNri = false,
  });

  bool get hasAnyData =>
      areaSqft != null ||
      floor != null ||
      residencyType != null ||
      moveInDate != null ||
      numOccupants != null ||
      isNri;

  factory _UnitDetails.fromJson(Map<String, dynamic> j) {
    final unitsMap = j['units'] as Map<String, dynamic>?;
    return _UnitDetails(
      floor:         unitsMap?['floor'] as int?,
      areaSqft:      (unitsMap?['area_sqft'] as num?)?.toDouble(),
      residencyType: j['residency_type'] as String?,
      moveInDate:    j['move_in_date'] != null
          ? DateTime.parse(j['move_in_date'] as String)
          : null,
      numOccupants: j['num_occupants'] as int?,
      isNri:        j['is_nri'] as bool? ?? false,
    );
  }
}

final _unitDetailsProvider = FutureProvider.autoDispose<_UnitDetails?>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return null;
  final data = await Supabase.instance.client
      .from('profiles')
      .select('residency_type, move_in_date, num_occupants, is_nri, units(floor, area_sqft)')
      .eq('id', uid)
      .maybeSingle();
  if (data == null) return null;
  final d = _UnitDetails.fromJson(data);
  return d.hasAnyData ? d : null;
});

class _VehicleInfo {
  final String? slotNumber;
  final String? vehicleNumber;
  final String? vehicleMake;
  final String? slotType;

  const _VehicleInfo({
    this.slotNumber,
    this.vehicleNumber,
    this.vehicleMake,
    this.slotType,
  });

  bool get hasAnyData =>
      slotNumber != null || vehicleNumber != null || vehicleMake != null;

  factory _VehicleInfo.fromJson(Map<String, dynamic> j) {
    final slotMap = j['parking_slots'] as Map<String, dynamic>?;
    return _VehicleInfo(
      slotNumber:    slotMap?['slot_number'] as String?,
      vehicleNumber: j['vehicle_number'] as String?,
      vehicleMake:   j['vehicle_make'] as String?,
      slotType:      slotMap?['slot_type'] as String?,
    );
  }
}

final _vehicleProvider = FutureProvider.autoDispose<_VehicleInfo?>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return null;
  final data = await Supabase.instance.client
      .from('parking_allocations')
      .select('vehicle_number, vehicle_make, parking_slots(slot_number, slot_type)')
      .eq('user_id', uid)
      .eq('status', 'active')
      .maybeSingle();
  if (data == null) return null;
  final v = _VehicleInfo.fromJson(data);
  return v.hasAnyData ? v : null;
});

class _ConsentInfo {
  final String policyVersion;
  final DateTime acceptedAt;

  const _ConsentInfo({required this.policyVersion, required this.acceptedAt});

  factory _ConsentInfo.fromJson(Map<String, dynamic> j) => _ConsentInfo(
        policyVersion: j['policy_version'] as String? ?? '1.0',
        acceptedAt:    DateTime.parse(j['accepted_at'] as String),
      );
}

final _consentProvider = FutureProvider.autoDispose<_ConsentInfo?>((ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return null;
  final data = await Supabase.instance.client
      .from('privacy_consents')
      .select('policy_version, accepted_at')
      .eq('user_id', uid)
      .order('accepted_at', ascending: false)
      .limit(1)
      .maybeSingle();
  if (data == null) return null;
  return _ConsentInfo.fromJson(data);
});
