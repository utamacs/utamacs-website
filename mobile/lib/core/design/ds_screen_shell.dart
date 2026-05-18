import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../preferences/app_preferences.dart';
import 'ds_animations.dart';
import 'ds_tokens.dart';
import 'ds_typography_scale.dart';
import 'skins/skin_context.dart';

// ============================================================================
// UTAMACS Design System — Premium Screen Shell
// Unified scaffold for all feature screens: consistent header, spacing,
// dark/light surfaces, scale-awareness, and refresh support.
// ============================================================================

// ─── Shell Configuration ─────────────────────────────────────────────────────

enum DsHeaderStyle {
  solid,      // White/dark surface — default for most screens
  gradient,   // Brand gradient — for hero/landing screens
  transparent, // No header bg — for screens with custom hero content
}

// ─── Main Shell Widget ───────────────────────────────────────────────────────

class DsScreenShell extends ConsumerWidget {
  // Required
  final String title;
  final List<Widget> slivers;

  // Header
  final DsHeaderStyle headerStyle;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final double expandedHeight;
  final Widget? flexibleBackground;
  final PreferredSizeWidget? bottom;

  // Body
  final Future<void> Function()? onRefresh;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? fabLocation;

  // Extra bottom padding beyond floating nav (for FABs, banners, etc.)
  final double extraBottomPadding;

  const DsScreenShell({
    super.key,
    required this.title,
    required this.slivers,
    this.headerStyle = DsHeaderStyle.solid,
    this.subtitle,
    this.actions,
    this.leading,
    this.expandedHeight = 0,
    this.flexibleBackground,
    this.bottom,
    this.onRefresh,
    this.floatingActionButton,
    this.fabLocation,
    this.extraBottomPadding = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin      = context.skin;
    final isDark    = ref.watch(effectiveDarkProvider);

    final bgColor      = skin.background;
    final surfaceColor = skin.surface;
    final titleColor   = skin.textPrimary;
    final subtitleColor = skin.textSecondary;

    Widget appBar = _buildSliverAppBar(
      context,
      isDark: isDark,
      surfaceColor: surfaceColor,
      titleColor: titleColor,
      subtitleColor: subtitleColor,
      skin: skin,
    );

    final bottomPad = 80 + MediaQuery.paddingOf(context).bottom + extraBottomPadding;

    final scrollView = CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        appBar,
        SliverPadding(
          padding: EdgeInsets.only(bottom: bottomPad),
          sliver: SliverList(
            delegate: SliverChildListDelegate(slivers),
          ),
        ),
      ],
    );

    Widget body = scrollView;
    if (onRefresh != null) {
      body = RefreshIndicator(
        onRefresh: onRefresh!,
        color: skin.accent,
        backgroundColor: surfaceColor,
        child: scrollView,
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      extendBody: true,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: fabLocation,
    );
  }

  Widget _buildSliverAppBar(
    BuildContext context, {
    required bool isDark,
    required Color surfaceColor,
    required Color titleColor,
    required Color subtitleColor,
    required dynamic skin,
  }) {
    if (headerStyle == DsHeaderStyle.gradient) {
      return _GradientSliverAppBar(
        title: title,
        subtitle: subtitle,
        actions: actions,
        leading: leading,
        expandedHeight: expandedHeight,
        flexibleBackground: flexibleBackground,
        bottom: bottom,
        isDark: isDark,
        accentColor: skin.accent as Color,
      );
    }

    // Solid / transparent header
    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      expandedHeight: expandedHeight > 0 ? expandedHeight : null,
      backgroundColor: headerStyle == DsHeaderStyle.transparent
          ? Colors.transparent
          : surfaceColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: isDark ? 0.5 : 1,
      shadowColor: skin.border as Color,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      leading: leading,
      title: Padding(
        padding: EdgeInsets.only(
          left: leading != null ? 0 : dsSpace4,
          right: (actions?.isNotEmpty ?? false) ? 0 : dsSpace4,
        ),
        child: _AppBarTitle(
          title: title,
          subtitle: subtitle,
          titleColor: titleColor,
          subtitleColor: subtitleColor,
        ),
      ),
      actions: actions != null
          ? [
              ...actions!,
              const SizedBox(width: dsSpace2),
            ]
          : null,
      flexibleSpace: flexibleBackground != null
          ? FlexibleSpaceBar(background: flexibleBackground)
          : null,
      bottom: bottom,
    );
  }
}

// ─── Gradient App Bar ─────────────────────────────────────────────────────────

class _GradientSliverAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final double expandedHeight;
  final Widget? flexibleBackground;
  final PreferredSizeWidget? bottom;
  final bool isDark;
  final Color accentColor;

  const _GradientSliverAppBar({
    required this.title,
    required this.isDark,
    this.accentColor = dsColorIndigo600,
    this.subtitle,
    this.actions,
    this.leading,
    this.expandedHeight = 0,
    this.flexibleBackground,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: expandedHeight > 0 ? expandedHeight : null,
      backgroundColor: accentColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      leading: leading,
      title: Padding(
        padding: EdgeInsets.only(
          left: leading != null ? 0 : dsSpace4,
        ),
        child: _AppBarTitle(
          title: title,
          subtitle: subtitle,
          titleColor: Colors.white,
          subtitleColor: Colors.white.withValues(alpha: 0.75),
        ),
      ),
      actions: actions != null
          ? [
              ...actions!,
              const SizedBox(width: dsSpace2),
            ]
          : null,
      flexibleSpace: FlexibleSpaceBar(
        background: flexibleBackground ??
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    dsColorIndigo700,
                    dsColorIndigo600,
                    dsColorIndigo500,
                  ],
                ),
              ),
            ),
      ),
      bottom: bottom,
    );
  }
}

// ─── App Bar Title ────────────────────────────────────────────────────────────

class _AppBarTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color titleColor;
  final Color subtitleColor;

  const _AppBarTitle({
    required this.title,
    required this.titleColor,
    required this.subtitleColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (subtitle == null) {
      return Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: context.sp(17),
          fontWeight: FontWeight.w700,
          color: titleColor,
          height: 1,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: context.sp(16),
            fontWeight: FontWeight.w700,
            color: titleColor,
            height: 1.1,
          ),
        ),
        Text(
          subtitle!,
          style: GoogleFonts.inter(
            fontSize: context.sp(11),
            color: subtitleColor,
            height: 1,
          ),
        ),
      ],
    );
  }
}

// ─── Action Icon Button ───────────────────────────────────────────────────────
// Use this for consistent action buttons in screen headers.

class DsActionButton extends ConsumerWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final bool hasBadge;

  const DsActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.hasBadge = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconColor = color ?? context.skin.textPrimary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(dsSpace2),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: context.si(22), color: iconColor),
            if (hasBadge)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: dsColorAmber500,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Sliver Section Header ────────────────────────────────────────────────────
// Consistent section headers used inside screen sliver lists.

class DsSliverSection extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;
  final EdgeInsets padding;

  const DsSliverSection({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
    this.padding = const EdgeInsets.fromLTRB(dsSpace4, dsSpace5, dsSpace4, dsSpace2),
  });

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: context.sp(14),
                fontWeight: FontWeight.w700,
                color: skin.textPrimary,
                letterSpacing: -0.1,
              ),
            ),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Text(
                trailing!,
                style: GoogleFonts.inter(
                  fontSize: context.sp(12),
                  fontWeight: FontWeight.w600,
                  color: skin.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Premium List Item ────────────────────────────────────────────────────────
// Consistent list items used across most feature screens.

class DsListItem extends ConsumerWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final bool showDivider;

  const DsListItem({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(effectiveDarkProvider);
    final surface = isDark ? dsDarkSurface : dsSurface;

    return Material(
      color: surface,
      child: InkWell(
        onTap: onTap,
        splashColor: dsColorIndigo600.withValues(alpha: 0.06),
        highlightColor: dsColorIndigo600.withValues(alpha: 0.04),
        child: Padding(
          padding: padding ??
              const EdgeInsets.symmetric(
                horizontal: dsSpace4,
                vertical: dsSpace3,
              ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: dsSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: context.sp(14),
                        fontWeight: FontWeight.w600,
                        color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: context.sp(12),
                          color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: dsSpace2),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Module Icon Container ────────────────────────────────────────────────────
// Colored rounded square icon used in list leading positions.

class DsIconContainer extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;
  final double iconSize;

  const DsIconContainer({
    super.key,
    required this.icon,
    required this.bg,
    required this.fg,
    this.size = 44,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.si(size),
      height: context.si(size),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(dsRadiusMd),
      ),
      child: Icon(icon, size: context.si(iconSize), color: fg),
    );
  }
}

// ─── Summary Stats Row ────────────────────────────────────────────────────────
// Used at the top of many screens (complaints, finance, visitors, etc.)

class DsStatsRow extends ConsumerWidget {
  final List<DsStatItem> stats;

  const DsStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: dsSpace4),
      child: Row(
        children: stats.asMap().entries.map((entry) {
          final i = entry.key;
          final stat = entry.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? 0 : dsSpace2,
                right: i == stats.length - 1 ? 0 : dsSpace2,
              ),
              child: _StatCard(stat: stat),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class DsStatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const DsStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _StatCard extends StatelessWidget {
  final DsStatItem stat;

  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return DSFadeSlide(
      child: Container(
        padding: const EdgeInsets.all(dsSpace3),
        decoration: BoxDecoration(
          color: skin.surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: skin.isDark ? [] : dsShadowSm,
          border: skin.isDark
              ? Border.all(color: skin.borderSoft, width: 1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: stat.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(dsRadiusSm),
              ),
              child: Icon(stat.icon, size: context.si(15), color: stat.color),
            ),
            const SizedBox(height: dsSpace2),
            Text(
              stat.value,
              style: GoogleFonts.poppins(
                fontSize: context.sp(18),
                fontWeight: FontWeight.w800,
                color: skin.textPrimary,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              stat.label,
              style: GoogleFonts.inter(
                fontSize: context.sp(10),
                color: skin.textSecondary,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter Pill Row (Shell-level) ────────────────────────────────────────────
// Standard horizontal filter pills for screen-level category filtering.

class DsFilterRow extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final bool includeAll;
  final EdgeInsets padding;

  const DsFilterRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.includeAll = true,
    this.padding = const EdgeInsets.symmetric(horizontal: dsSpace4, vertical: dsSpace2),
  });

  @override
  Widget build(BuildContext context) {
    final items = includeAll ? ['All', ...options] : options;
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final label = items[i];
          final value = (includeAll && i == 0) ? null : label;
          final isSelected = value == selected;
          final skin = ctx.skin;
          return Padding(
            padding: const EdgeInsets.only(right: dsSpace2),
            child: GestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: dsDurationFast,
                padding: const EdgeInsets.symmetric(horizontal: dsSpace3, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? skin.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(dsRadiusFull),
                  border: Border.all(
                    color: isSelected ? skin.accent : skin.border,
                  ),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: ctx.sp(12),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? skin.accentText : skin.textSecondary,
                    height: 1,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Empty State Widget ───────────────────────────────────────────────────────

class DsEmptyPlaceholder extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DsEmptyPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: dsSpace16, horizontal: dsSpace8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: skin.accentSoft,
              borderRadius: BorderRadius.circular(dsRadiusXl),
            ),
            child: Icon(
              icon,
              size: context.si(32),
              color: skin.accent.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: dsSpace4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: context.sp(16),
              fontWeight: FontWeight.w700,
              color: skin.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: dsSpace2),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: context.sp(13),
              color: skin.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: dsSpace5),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: dsSpace6,
                  vertical: dsSpace3,
                ),
                decoration: BoxDecoration(
                  color: skin.accent,
                  borderRadius: BorderRadius.circular(dsRadiusButton),
                  boxShadow: dsShadowBrand,
                ),
                child: Text(
                  actionLabel!,
                  style: GoogleFonts.inter(
                    fontSize: context.sp(14),
                    fontWeight: FontWeight.w600,
                    color: skin.accentText,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
