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
import '../../data/staff_repository.dart';

part 'staff_directory_tab.dart';
part 'staff_tasks_tab.dart';
part 'staff_attendance_tab.dart';
part 'staff_shifts_tab.dart';
part 'staff_agencies_tab.dart';
part 'staff_sheet_helpers.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  static Future<void> _openPortal(String path) async {
    final uri =
        Uri.parse('$portalUrl/portal/$path');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(effectiveDarkProvider);
    final isExec =
        ref.watch(authNotifierProvider).profile?.isExec ?? false;

    final surface = isDark ? dsDarkSurface : dsSurface;
    final borderColor = isDark ? dsDarkBorderLight : dsBorderLight;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: isDark ? dsDarkBackground : dsBackground,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              floating: false,
              backgroundColor: surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: isDark ? 0.5 : 1,
              shadowColor: borderColor,
              automaticallyImplyLeading: false,
              titleSpacing: dsSpace4,
              title: Text(
                'Society Staff',
                style: GoogleFonts.poppins(
                  fontSize: context.sp(17),
                  fontWeight: FontWeight.w700,
                  color:
                      isDark ? dsDarkTextPrimary : dsTextPrimary,
                  height: 1,
                ),
              ),
              actions: [
                if (isExec) ...[
                  DsActionButton(
                    icon: Icons.assignment_outlined,
                    onTap: () =>
                        _openPortal('staff?tab=proposals'),
                  ),
                  DsActionButton(
                    icon: Icons.bar_chart_outlined,
                    onTap: () =>
                        _openPortal('staff?tab=analytics'),
                  ),
                  DsActionButton(
                    icon: Icons.business_outlined,
                    onTap: () =>
                        _openPortal('admin/staff-departments'),
                  ),
                ],
                DsActionButton(
                  icon: Icons.refresh_rounded,
                  onTap: () {
                    ref.invalidate(activeStaffProvider);
                    ref.invalidate(staffTasksProvider);
                    ref.invalidate(staffAttendanceProvider);
                    ref.invalidate(staffShiftsProvider);
                    ref.invalidate(staffAgenciesProvider);
                  },
                ),
                const SizedBox(width: dsSpace2),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: context.sp(13)),
                unselectedLabelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w400,
                    fontSize: context.sp(13)),
                labelColor: dsColorIndigo600,
                unselectedLabelColor: isDark
                    ? dsDarkTextSecondary
                    : dsTextSecondary,
                indicatorColor: dsColorIndigo600,
                indicatorWeight: 2.5,
                dividerColor: borderColor,
                tabs: const [
                  Tab(text: 'Directory'),
                  Tab(text: 'Tasks'),
                  Tab(text: 'Attendance'),
                  Tab(text: 'Shifts'),
                  Tab(text: 'Agencies'),
                ],
              ),
            ),
          ],
          body: Builder(
            builder: (context) {
              final tabCtrl = DefaultTabController.of(context);
              return Stack(
                children: [
                  TabBarView(
                    children: [
                      _DirectoryTab(isDark: isDark),
                      _TasksTab(isDark: isDark),
                      _AttendanceTab(
                          isDark: isDark, isExec: isExec),
                      _ShiftsTab(isDark: isDark),
                      _AgenciesTab(isDark: isDark),
                    ],
                  ),
                  if (isExec)
                    Positioned(
                      bottom: 80 +
                          MediaQuery.paddingOf(context).bottom,
                      right: dsSpace4,
                      child: AnimatedBuilder(
                        animation: tabCtrl,
                        builder: (_, _) {
                          final idx = tabCtrl.index;
                          final showTasks = idx == 1;
                          final showShifts = idx == 3;
                          if (!showTasks && !showShifts) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            decoration: BoxDecoration(
                              boxShadow: dsShadowBrand,
                              borderRadius:
                                  BorderRadius.circular(
                                      dsRadiusFull),
                            ),
                            child: FloatingActionButton.extended(
                              elevation: 0,
                              highlightElevation: 0,
                              backgroundColor: dsColorIndigo600,
                              icon: const Icon(
                                  Icons.add_rounded,
                                  color: Colors.white),
                              label: Text(
                                showTasks
                                    ? 'Assign Task'
                                    : 'Add Shift',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: context.sp(13),
                                ),
                              ),
                              onPressed: () {
                                if (showTasks) {
                                  _showCreateTaskSheet(
                                      context, ref);
                                } else {
                                  _showCreateShiftSheet(
                                      context, ref);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showCreateTaskSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateTaskSheet(
        onCreated: () => ref.invalidate(staffTasksProvider),
      ),
    );
  }

  void _showCreateShiftSheet(
      BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateShiftSheet(
        onCreated: () => ref.invalidate(staffShiftsProvider),
      ),
    );
  }
}
