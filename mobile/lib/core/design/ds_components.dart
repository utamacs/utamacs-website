import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ds_tokens.dart';

// ============================================================================
// UTAMACS Design System — Core Component Library
// Every component is a self-contained, themeable, accessible widget.
// ============================================================================

// ─── DS CARD ─────────────────────────────────────────────────────────────────
// Standard shadow-elevated card (no border). Three size variants.

enum DsCardSize { sm, md, lg }

class DSCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final List<BoxShadow>? shadows;
  final DsCardSize size;
  final double? borderRadius;
  final Border? border;

  const DSCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.color,
    this.shadows,
    this.size = DsCardSize.md,
    this.borderRadius,
    this.border,
  });

  EdgeInsets get _defaultPadding => switch (size) {
    DsCardSize.sm => const EdgeInsets.all(dsSpace3),
    DsCardSize.md => const EdgeInsets.all(dsSpace4),
    DsCardSize.lg => const EdgeInsets.all(dsSpace5),
  };

  double get _defaultRadius => switch (size) {
    DsCardSize.sm => dsRadiusMd,
    DsCardSize.md => dsRadiusCard,
    DsCardSize.lg => dsRadiusCardLg,
  };

  List<BoxShadow> get _defaultShadows => switch (size) {
    DsCardSize.sm => dsShadowSm,
    DsCardSize.md => dsShadowMd,
    DsCardSize.lg => dsShadowLg,
  };

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? _defaultRadius;
    return Container(
      decoration: BoxDecoration(
        color: color ?? dsSurface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows ?? _defaultShadows,
        border: border,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          highlightColor: dsBrandPrimary.withValues(alpha: 0.04),
          splashColor: dsBrandPrimary.withValues(alpha: 0.06),
          child: Padding(
            padding: padding ?? _defaultPadding,
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─── DS BUTTON ───────────────────────────────────────────────────────────────
// Unified button with variant + size system. Replaces ElevatedButton/OutlinedButton.

enum DsButtonVariant { primary, secondary, outline, ghost, danger, success }
enum DsButtonSize { sm, md, lg }

class DSButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final DsButtonVariant variant;
  final DsButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const DSButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = DsButtonVariant.primary,
    this.size = DsButtonSize.md,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
  });

  // Compact icon-only variant
  const DSButton.icon({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.variant = DsButtonVariant.primary,
    this.size = DsButtonSize.md,
    this.isLoading = false,
  }) : fullWidth = false;

  double get _height => switch (size) {
    DsButtonSize.sm => 38.0,
    DsButtonSize.md => 50.0,
    DsButtonSize.lg => 56.0,
  };

  double get _fontSize => switch (size) {
    DsButtonSize.sm => 13.0,
    DsButtonSize.md => 15.0,
    DsButtonSize.lg => 16.0,
  };

  EdgeInsets get _padding => switch (size) {
    DsButtonSize.sm => const EdgeInsets.symmetric(horizontal: dsSpace3),
    DsButtonSize.md => const EdgeInsets.symmetric(horizontal: dsSpace5),
    DsButtonSize.lg => const EdgeInsets.symmetric(horizontal: dsSpace6),
  };

  _ButtonStyle get _style => switch (variant) {
    DsButtonVariant.primary  => const _ButtonStyle(bg: dsColorIndigo600, fg: Colors.white, border: null),
    DsButtonVariant.secondary => const _ButtonStyle(bg: dsColorEmerald500, fg: Colors.white, border: null),
    DsButtonVariant.outline  => const _ButtonStyle(bg: Colors.transparent, fg: dsColorIndigo600, border: dsColorIndigo600),
    DsButtonVariant.ghost    => const _ButtonStyle(bg: Colors.transparent, fg: dsColorIndigo600, border: null),
    DsButtonVariant.danger   => const _ButtonStyle(bg: dsColorRed600, fg: Colors.white, border: null),
    DsButtonVariant.success  => const _ButtonStyle(bg: dsColorEmerald500, fg: Colors.white, border: null),
  };

  List<BoxShadow> get _shadows => switch (variant) {
    DsButtonVariant.primary  => dsShadowBrand,
    DsButtonVariant.secondary => dsShadowSuccess,
    _ => dsShadowNone,
  };

  @override
  Widget build(BuildContext context) {
    final style = _style;
    final disabled = onPressed == null || isLoading;
    final effectiveBg = disabled
        ? (variant == DsButtonVariant.outline || variant == DsButtonVariant.ghost
            ? Colors.transparent
            : dsColorSlate200)
        : style.bg;
    final effectiveFg = disabled ? dsColorSlate400 : style.fg;

    Widget content = isLoading
        ? SizedBox(
            width: _fontSize + 2,
            height: _fontSize + 2,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: effectiveFg,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: _fontSize + 2, color: effectiveFg),
                const SizedBox(width: dsSpace2),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: _fontSize,
                  color: effectiveFg,
                  height: 1,
                ),
              ),
            ],
          );

    return AnimatedContainer(
      duration: dsDurationFast,
      width: fullWidth ? double.infinity : null,
      height: _height,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(dsRadiusButton),
        border: style.border != null && !disabled
            ? Border.all(color: style.border!, width: 1.5)
            : style.border != null && disabled
                ? Border.all(color: dsColorSlate300, width: 1.5)
                : null,
        boxShadow: disabled ? dsShadowNone : _shadows,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(dsRadiusButton),
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(dsRadiusButton),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          splashColor: Colors.white.withValues(alpha: 0.10),
          child: Center(child: Padding(padding: _padding, child: content)),
        ),
      ),
    );
  }
}

class _ButtonStyle {
  final Color bg;
  final Color fg;
  final Color? border;
  const _ButtonStyle({required this.bg, required this.fg, required this.border});
}

// ─── DS ICON BUTTON ──────────────────────────────────────────────────────────

class DSIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? bgColor;
  final double size;
  final int badgeCount;

  const DSIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.iconColor,
    this.bgColor,
    this.size = 40,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bgColor ?? dsSurfaceMuted,
            borderRadius: BorderRadius.circular(dsRadiusMd),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(dsRadiusMd),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(dsRadiusMd),
              child: Center(
                child: Icon(
                  icon,
                  size: size * 0.50,
                  color: iconColor ?? dsTextSecondary,
                ),
              ),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: dsStatusError,
                borderRadius: BorderRadius.circular(dsRadiusFull),
                border: Border.all(color: dsSurface, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                badgeCount > 99 ? '99+' : badgeCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── DS STATUS BADGE ─────────────────────────────────────────────────────────

enum DsBadgeVariant { success, warning, error, info, neutral, primary }

class DSBadge extends StatelessWidget {
  final String label;
  final DsBadgeVariant variant;
  final bool dot;

  const DSBadge(this.label, {
    super.key,
    this.variant = DsBadgeVariant.neutral,
    this.dot = false,
  });

  factory DSBadge.forStatus(String status) {
    final v = switch (status.toLowerCase()) {
      'active' || 'approved' || 'resolved' || 'paid' || 'completed' =>
          DsBadgeVariant.success,
      'pending' || 'open' || 'review' || 'in_progress' =>
          DsBadgeVariant.warning,
      'rejected' || 'expired' || 'cancelled' || 'overdue' =>
          DsBadgeVariant.error,
      'info' || 'processing' => DsBadgeVariant.info,
      _ => DsBadgeVariant.neutral,
    };
    return DSBadge(
      status[0].toUpperCase() + status.substring(1).replaceAll('_', ' '),
      variant: v,
    );
  }

  _BadgeColors get _colors => switch (variant) {
    DsBadgeVariant.success  => const _BadgeColors(bg: dsColorEmerald50, fg: dsColorEmerald700, dot: dsColorEmerald500),
    DsBadgeVariant.warning  => const _BadgeColors(bg: dsColorAmber50,   fg: dsColorAmber700,   dot: dsColorAmber500),
    DsBadgeVariant.error    => const _BadgeColors(bg: dsColorRed50,     fg: dsColorRed700,     dot: dsColorRed600),
    DsBadgeVariant.info     => const _BadgeColors(bg: dsColorSky50,     fg: dsColorSky700,     dot: dsColorSky500),
    DsBadgeVariant.primary  => const _BadgeColors(bg: dsColorIndigo50,  fg: dsColorIndigo700,  dot: dsColorIndigo600),
    DsBadgeVariant.neutral  => const _BadgeColors(bg: dsColorSlate100,  fg: dsColorSlate700,   dot: dsColorSlate400),
  };

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(dsRadiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: c.dot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.fg,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeColors {
  final Color bg, fg, dot;
  const _BadgeColors({required this.bg, required this.fg, required this.dot});
}

// ─── DS TAG / CHIP (non-interactive label) ───────────────────────────────────

class DSTag extends StatelessWidget {
  final String label;
  final Color? bgColor;
  final Color? textColor;
  final IconData? icon;

  const DSTag(this.label, {
    super.key,
    this.bgColor,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor ?? dsSurfaceMuted,
        borderRadius: BorderRadius.circular(dsRadiusSm),
        border: Border.all(color: dsBorderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dsIconXs, color: textColor ?? dsTextSecondary),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor ?? dsTextSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DS EMPTY STATE ──────────────────────────────────────────────────────────

class DSEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final Color? iconColor;

  const DSEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(dsSpace8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: dsColorIndigo50,
                borderRadius: BorderRadius.circular(dsRadiusXxl),
              ),
              child: Icon(
                icon,
                size: 32,
                color: iconColor ?? dsColorIndigo300,
              ),
            ),
            const SizedBox(height: dsSpace4),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: dsTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: dsSpace2),
              Text(
                subtitle!,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: dsTextSecondary,
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: dsSpace5),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─── DS ERROR STATE ──────────────────────────────────────────────────────────

class DSErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const DSErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return DSEmptyState(
      icon: Icons.wifi_off_rounded,
      iconColor: dsColorRed600,
      title: 'Something went wrong',
      subtitle: message,
      action: onRetry != null
          ? DSButton(
              label: 'Try again',
              variant: DsButtonVariant.outline,
              fullWidth: false,
              onPressed: onRetry,
              icon: Icons.refresh_rounded,
            )
          : null,
    );
  }
}

// ─── DS SHIMMER (loading skeleton) ───────────────────────────────────────────

class DSShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const DSShimmer({
    super.key,
    required this.width,
    required this.height,
    this.radius = dsRadiusSm,
  });

  // Convenience: full-width block
  const DSShimmer.block({
    super.key,
    required this.height,
    this.radius = dsRadiusSm,
  }) : width = double.infinity;

  @override
  State<DSShimmer> createState() => _DSShimmerState();
}

class _DSShimmerState extends State<DSShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _anim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value, 0),
              colors: const [
                Color(0xFFF1F5F9),
                Color(0xFFE8EFFE),
                Color(0xFFF1F5F9),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// Card-shaped shimmer placeholder
class DSShimmerCard extends StatelessWidget {
  final double height;
  const DSShimmerCard({super.key, this.height = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: dsSurface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: dsShadowSm,
      ),
      padding: const EdgeInsets.all(dsSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const DSShimmer(width: 40, height: 40, radius: dsRadiusMd),
            const SizedBox(width: dsSpace3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const DSShimmer.block(height: 14, radius: dsRadiusXs),
                const SizedBox(height: 6),
                DSShimmer(width: MediaQuery.sizeOf(context).width * 0.4, height: 11, radius: dsRadiusXs),
              ]),
            ),
          ]),
          if (height > 80) ...[
            const SizedBox(height: dsSpace3),
            const DSShimmer.block(height: 11, radius: dsRadiusXs),
            const SizedBox(height: dsSpace1 + 2),
            DSShimmer(width: MediaQuery.sizeOf(context).width * 0.6, height: 11, radius: dsRadiusXs),
          ],
        ],
      ),
    );
  }
}

// ─── DS PAGE HEADER ──────────────────────────────────────────────────────────

class DSPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;

  const DSPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBack)
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              margin: const EdgeInsets.only(right: dsSpace3, top: 2),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: dsSurfaceMuted,
                borderRadius: BorderRadius.circular(dsRadiusSm),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: dsIconMd, color: dsTextPrimary),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: dsTextBrand,
                  height: 1.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: dsTextSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        ...actions.map((a) => Padding(
          padding: const EdgeInsets.only(left: dsSpace2),
          child: a,
        )),
      ],
    );
  }
}

// ─── DS SECTION HEADER ───────────────────────────────────────────────────────

class DSSectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  const DSSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: dsTextPrimary,
              letterSpacing: -0.1,
            ),
          ),
        ),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailing!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: dsColorIndigo600,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 10, color: dsColorIndigo600),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── DS ICON CONTAINER ───────────────────────────────────────────────────────
// Consistently styled icon wrapper used in service tiles, list rows, etc.

class DSIconContainer extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;
  final double iconSize;

  const DSIconContainer({
    super.key,
    required this.icon,
    required this.bg,
    required this.fg,
    this.size = 44,
    this.iconSize = 22,
  });

  const DSIconContainer.sm({
    super.key,
    required this.icon,
    required this.bg,
    required this.fg,
  })  : size = 36,
        iconSize = 18;

  const DSIconContainer.lg({
    super.key,
    required this.icon,
    required this.bg,
    required this.fg,
  })  : size = 52,
        iconSize = 26;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.27),
      ),
      child: Icon(icon, size: iconSize, color: fg),
    );
  }
}

// ─── DS STAT CARD ────────────────────────────────────────────────────────────

class DSStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final String? trend;
  final bool trendUp;

  const DSStatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.trend,
    this.trendUp = true,
  });

  @override
  Widget build(BuildContext context) {
    return DSCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(dsRadiusMd),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (trendUp ? dsColorEmerald50 : dsColorRed50),
                    borderRadius: BorderRadius.circular(dsRadiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trendUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 12,
                        color: trendUp ? dsColorEmerald600 : dsColorRed600,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        trend!,
                        style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: trendUp ? dsColorEmerald600 : dsColorRed600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: dsSpace3),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: dsTextPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: dsTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DS NOTICE BANNER ────────────────────────────────────────────────────────

class DSNoticeBanner extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool pinned;

  const DSNoticeBanner({
    super.key,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.pinned = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: dsSpace4, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              dsColorAmber50,
              const Color(0xFFFFFDF5),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(dsRadiusMd),
          border: Border.all(color: dsColorAmber100, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: dsColorAmber100,
                borderRadius: BorderRadius.circular(dsRadiusSm),
              ),
              child: const Icon(Icons.campaign_rounded, size: 17, color: dsColorAmber700),
            ),
            const SizedBox(width: dsSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: dsColorAmber700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: GoogleFonts.inter(fontSize: 11, color: dsColorAmber600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: dsSpace2),
            const Icon(Icons.chevron_right_rounded, size: dsIconMd, color: dsColorAmber600),
          ],
        ),
      ),
    );
  }
}

// ─── DS FILTER CHIP ROW ──────────────────────────────────────────────────────

class DSFilterChipRow extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final String? allLabel;

  const DSFilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.allLabel = 'All',
  });

  @override
  Widget build(BuildContext context) {
    final all = [if (allLabel != null) null, ...options.map<String?>((o) => o)];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: dsSpace4),
      child: Row(
        children: all.map((opt) {
          final isSelected = opt == selected;
          return Padding(
            padding: const EdgeInsets.only(right: dsSpace2),
            child: GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: dsDurationFast,
                padding: const EdgeInsets.symmetric(horizontal: dsSpace3, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? dsColorIndigo600 : dsSurface,
                  borderRadius: BorderRadius.circular(dsRadiusFull),
                  border: Border.all(
                    color: isSelected ? dsColorIndigo600 : dsBorderLight,
                    width: isSelected ? 0 : 1,
                  ),
                  boxShadow: isSelected ? dsShadowBrand : dsShadowXs,
                ),
                child: Text(
                  opt ?? allLabel!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Colors.white : dsTextSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── DS TOAST ────────────────────────────────────────────────────────────────

class DsToast {
  static void show(
    BuildContext context,
    String message, {
    DsBadgeVariant variant = DsBadgeVariant.success,
    Duration duration = const Duration(seconds: 3),
  }) {
    final colors = switch (variant) {
      DsBadgeVariant.success  => (bg: dsColorSlate900, icon: Icons.check_circle_rounded),
      DsBadgeVariant.error    => (bg: dsColorRed700, icon: Icons.error_rounded),
      DsBadgeVariant.warning  => (bg: dsColorAmber700, icon: Icons.warning_rounded),
      DsBadgeVariant.info     => (bg: dsColorSky700, icon: Icons.info_rounded),
      _                       => (bg: dsColorSlate900, icon: Icons.info_rounded),
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(colors.icon, size: 18, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white,
              ),
            ),
          ),
        ]),
        backgroundColor: colors.bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(dsRadiusMd)),
        duration: duration,
        margin: const EdgeInsets.all(dsSpace4),
      ),
    );
  }
}

// ─── DS ROLE BADGE ───────────────────────────────────────────────────────────

class DSRoleBadge extends StatelessWidget {
  final String role;
  const DSRoleBadge(this.role, {super.key});

  @override
  Widget build(BuildContext context) {
    final normalized = role.toLowerCase();
    final (bg, fg, label) = switch (normalized) {
      'president'  => (dsColorIndigo800, Colors.white, 'President'),
      'secretary'  => (dsColorIndigo600, Colors.white, 'Secretary'),
      'executive'  => (dsColorIndigo500, Colors.white, 'Exec'),
      'admin'      => (dsColorTerra600, Colors.white, 'Admin'),
      'security_guard' => (dsColorEmerald700, Colors.white, 'Guard'),
      _            => (dsColorSlate700, Colors.white, role.toUpperCase()),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(dsRadiusXs),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ─── DS DIVIDER WITH LABEL ───────────────────────────────────────────────────

class DSLabeledDivider extends StatelessWidget {
  final String label;
  const DSLabeledDivider(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Expanded(child: Divider(height: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: dsSpace3),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: dsTextTertiary,
          ),
        ),
      ),
      const Expanded(child: Divider(height: 1)),
    ]);
  }
}
