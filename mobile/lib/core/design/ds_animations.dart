import 'package:flutter/material.dart';
import 'ds_tokens.dart';

// ============================================================================
// UTAMACS Design System — Motion & Animation System
// Premium, intentional motion that enhances usability without distraction.
// ============================================================================

// ─── EASING CURVES ───────────────────────────────────────────────────────────

// Entrance (elements appearing): fast decelerate → settle naturally
const Curve dsEaseEntrance = Curves.easeOutCubic;

// Exit (elements leaving): accelerate out → quick
const Curve dsEaseExit = Curves.easeInCubic;

// Standard (repositioning): smooth in-out
const Curve dsEaseStandard = Curves.easeInOutCubic;

// Spring-like (interactive): overshoot → settle (bouncy feel)
const Curve dsEaseSpring = Curves.elasticOut;

// Emphasis (special moments): elastic spring
const Curve dsEaseEmphasis = Curves.elasticOut;

// Decelerate (list entrance): things sliding in from off-screen
const Curve dsEaseDecelerate = Curves.decelerate;

// ─── STAGGER ANIMATION BUILDER ───────────────────────────────────────────────
// Wraps a list of widgets with staggered entrance animations.

class DSStaggerList extends StatefulWidget {
  final List<Widget> children;
  final Duration itemDelay;
  final Duration itemDuration;
  final double slideOffset;
  final bool enabled;

  const DSStaggerList({
    super.key,
    required this.children,
    this.itemDelay = const Duration(milliseconds: 55),
    this.itemDuration = dsDurationNormal,
    this.slideOffset = 18.0,
    this.enabled = true,
  });

  @override
  State<DSStaggerList> createState() => _DSStaggerListState();
}

class _DSStaggerListState extends State<DSStaggerList>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<Animation<double>> _opacities;
  late List<Animation<double>> _slides;

  @override
  void initState() {
    super.initState();
    final count = widget.children.length;
    final totalMs = widget.itemDuration.inMilliseconds +
        (count - 1) * widget.itemDelay.inMilliseconds;
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );
    _opacities = List.generate(count, (i) {
      final start = (i * widget.itemDelay.inMilliseconds) / totalMs;
      final end = (start + widget.itemDuration.inMilliseconds / totalMs).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, end, curve: dsEaseEntrance),
        ),
      );
    });
    _slides = List.generate(count, (i) {
      final start = (i * widget.itemDelay.inMilliseconds) / totalMs;
      final end = (start + widget.itemDuration.inMilliseconds / totalMs).clamp(0.0, 1.0);
      return Tween<double>(begin: widget.slideOffset, end: 0).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, end, curve: dsEaseEntrance),
        ),
      );
    });
    if (widget.enabled) _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return Column(children: widget.children);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        return Column(
          children: List.generate(widget.children.length, (i) {
            return Transform.translate(
              offset: Offset(0, _slides[i].value),
              child: Opacity(
                opacity: _opacities[i].value,
                child: widget.children[i],
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── FADE-SLIDE WIDGET ───────────────────────────────────────────────────────
// Single element entrance animation. Wrap any widget for premium entrance.

class DSFadeSlide extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double slideOffset;
  final Axis axis;

  const DSFadeSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = dsDurationNormal,
    this.slideOffset = 20.0,
    this.axis = Axis.vertical,
  });

  @override
  State<DSFadeSlide> createState() => _DSFadeSlideState();
}

class _DSFadeSlideState extends State<DSFadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: dsEaseEntrance),
    );
    _slide = Tween<double>(begin: widget.slideOffset, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: dsEaseEntrance),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) {
        final offset = widget.axis == Axis.vertical
            ? Offset(0, _slide.value)
            : Offset(_slide.value, 0);
        return Transform.translate(
          offset: offset,
          child: Opacity(opacity: _opacity.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}

// ─── SCALE PRESS WIDGET ──────────────────────────────────────────────────────
// Adds a subtle scale-down effect on press for any tappable widget.

class DSScalePress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const DSScalePress({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
  });

  @override
  State<DSScalePress> createState() => _DSScalePressState();
}

class _DSScalePressState extends State<DSScalePress>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: dsDurationInstant);
    _scale = Tween<double>(begin: 1.0, end: widget.scale).animate(
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
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

// ─── ANIMATED COUNTER ────────────────────────────────────────────────────────
// Smoothly animates between numeric values (useful for stats).

class DSAnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  const DSAnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: dsDurationSlow,
      curve: dsEaseEntrance,
      builder: (ctx, val, _) {
        return Text(
          '$prefix${val.toInt()}$suffix',
          style: style,
        );
      },
    );
  }
}

// ─── PAGE ROUTE TRANSITIONS ──────────────────────────────────────────────────

class DSSlideRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final AxisDirection direction;

  DSSlideRoute({
    required this.page,
    this.direction = AxisDirection.up,
  }) : super(
          pageBuilder: (ctx, anim, secondAnim) => page,
          transitionDuration: dsDurationPageTrans,
          reverseTransitionDuration: dsDurationNormal,
          transitionsBuilder: (ctx, anim, secondAnim, child) {
            final offset = switch (direction) {
              AxisDirection.up    => const Offset(0, 0.04),
              AxisDirection.right => const Offset(-0.04, 0),
              AxisDirection.down  => const Offset(0, -0.04),
              AxisDirection.left  => const Offset(0.04, 0),
            };
            return FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(
                CurvedAnimation(parent: anim, curve: dsEaseEntrance),
              ),
              child: SlideTransition(
                position: Tween<Offset>(begin: offset, end: Offset.zero).animate(
                  CurvedAnimation(parent: anim, curve: dsEaseEntrance),
                ),
                child: child,
              ),
            );
          },
        );
}

// ─── PULSE ANIMATION (for notification dots, active indicators) ──────────────

class DSPulse extends StatefulWidget {
  final Widget child;
  final Color color;
  final double radius;

  const DSPulse({
    super.key,
    required this.child,
    this.color = dsColorIndigo600,
    this.radius = 20,
  });

  @override
  State<DSPulse> createState() => _DSPulseState();
}

class _DSPulseState extends State<DSPulse> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
    _scale = Tween<double>(begin: 0.8, end: 1.6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.6, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _ctrl,
          builder: (ctx, _) => Transform.scale(
            scale: _scale.value,
            child: Container(
              width: widget.radius * 2,
              height: widget.radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: _opacity.value * 0.4),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

// ─── SHIMMER GRADIENT ANIMATION ──────────────────────────────────────────────
// Utility for building custom shimmer effects with custom gradients.

class DSShimmerGradient extends StatefulWidget {
  final Widget child;

  const DSShimmerGradient({super.key, required this.child});

  @override
  State<DSShimmerGradient> createState() => _DSShimmerGradientState();
}

class _DSShimmerGradientState extends State<DSShimmerGradient>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(-1.5 + _ctrl.value * 3, 0),
          end: Alignment(-0.5 + _ctrl.value * 3, 0),
          colors: const [
            Color(0xFFF1F5F9),
            Color(0xFFE8EFFE),
            Color(0xFFF1F5F9),
          ],
        ).createShader(bounds),
        child: child,
      ),
      child: widget.child,
    );
  }
}
