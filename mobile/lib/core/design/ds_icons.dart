import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ds_tokens.dart';
import 'ds_typography_scale.dart';

// ============================================================================
// UTAMACS Design System — Context-Aware Icon System
//
// Three layers:
//   1. DSIcons     — semantic icon map (module name → Material icon data)
//   2. DSIcon      — widget that auto-scales via context.si() + reads theme
//   3. Custom painters — hand-drawn icons for the 8 most distinctive modules
// ============================================================================

// ─── 1. SEMANTIC ICON MAP ────────────────────────────────────────────────────
// All icon references in the app go through DSIcons.* — never raw Icons.*
// This makes it trivial to swap any icon app-wide from one place.

class DSIcons {
  DSIcons._();

  // ── Navigation ─────────────────────────────────────────────────
  static const IconData home          = Icons.home_rounded;
  static const IconData homeOutlined  = Icons.home_outlined;
  static const IconData services      = Icons.grid_view_rounded;
  static const IconData profile       = Icons.person_rounded;
  static const IconData profileOutline = Icons.person_outline_rounded;

  // ── Notices & Communication ─────────────────────────────────────
  static const IconData notices       = Icons.campaign_rounded;
  static const IconData noticePin     = Icons.push_pin_rounded;
  static const IconData noticeCircular = Icons.article_rounded;
  static const IconData notification  = Icons.notifications_rounded;
  static const IconData notificationOff = Icons.notifications_none_rounded;
  static const IconData bell          = Icons.notifications_outlined;
  static const IconData letters       = Icons.mail_rounded;
  static const IconData lettersOpen   = Icons.drafts_rounded;

  // ── Visitors & Security ─────────────────────────────────────────
  static const IconData visitors      = Icons.badge_rounded;
  static const IconData visitorPass   = Icons.assignment_ind_rounded;
  static const IconData gate          = Icons.meeting_room_rounded;
  static const IconData security      = Icons.shield_rounded;
  static const IconData securityGuard = Icons.security_rounded;
  static const IconData qrCode        = Icons.qr_code_2_rounded;
  static const IconData qrScan        = Icons.qr_code_scanner_rounded;
  static const IconData walkIn        = Icons.directions_walk_rounded;
  static const IconData delivery      = Icons.local_shipping_rounded;
  static const IconData otp           = Icons.pin_rounded;

  // ── Complaints & Support ────────────────────────────────────────
  static const IconData complaints    = Icons.support_agent_rounded;
  static const IconData complaintNew  = Icons.report_problem_rounded;
  static const IconData ticket        = Icons.confirmation_number_rounded;
  static const IconData resolved      = Icons.check_circle_rounded;
  static const IconData escalate      = Icons.trending_up_rounded;
  static const IconData category      = Icons.label_rounded;

  // ── Finance ─────────────────────────────────────────────────────
  static const IconData finance       = Icons.account_balance_wallet_rounded;
  static const IconData payment       = Icons.payments_rounded;
  static const IconData receipt       = Icons.receipt_long_rounded;
  static const IconData invoice       = Icons.request_quote_rounded;
  static const IconData rupee         = Icons.currency_rupee_rounded;
  static const IconData due           = Icons.pending_actions_rounded;
  static const IconData paid          = Icons.done_all_rounded;
  static const IconData overdueIcon   = Icons.warning_rounded;

  // ── Facilities & Booking ────────────────────────────────────────
  static const IconData facilities    = Icons.meeting_room_rounded;
  static const IconData facility      = Icons.holiday_village_rounded;
  static const IconData booking       = Icons.calendar_month_rounded;
  static const IconData booked        = Icons.event_available_rounded;
  static const IconData pool          = Icons.pool_rounded;
  static const IconData gym           = Icons.fitness_center_rounded;
  static const IconData clubhouse     = Icons.villa_rounded;

  // ── Community ───────────────────────────────────────────────────
  static const IconData community     = Icons.groups_rounded;
  static const IconData post          = Icons.forum_rounded;
  static const IconData marketplace   = Icons.storefront_rounded;
  static const IconData like          = Icons.favorite_rounded;
  static const IconData likeOutline   = Icons.favorite_border_rounded;
  static const IconData comment       = Icons.chat_bubble_outline_rounded;

  // ── Documents ───────────────────────────────────────────────────
  static const IconData documents     = Icons.folder_rounded;
  static const IconData document      = Icons.description_rounded;
  static const IconData pdf           = Icons.picture_as_pdf_rounded;
  static const IconData upload        = Icons.upload_file_rounded;
  static const IconData download      = Icons.download_rounded;
  static const IconData version       = Icons.history_rounded;

  // ── Parking ─────────────────────────────────────────────────────
  static const IconData parking       = Icons.local_parking_rounded;
  static const IconData vehicle       = Icons.directions_car_rounded;
  static const IconData twoWheeler    = Icons.two_wheeler_rounded;
  static const IconData plateNumber   = Icons.pin_rounded;

  // ── Members ─────────────────────────────────────────────────────
  static const IconData members       = Icons.people_rounded;
  static const IconData member        = Icons.person_rounded;
  static const IconData flat          = Icons.apartment_rounded;
  static const IconData owner         = Icons.home_rounded;
  static const IconData tenant        = Icons.person_pin_rounded;

  // ── Events ──────────────────────────────────────────────────────
  static const IconData events        = Icons.event_rounded;
  static const IconData eventLive     = Icons.live_tv_rounded;
  static const IconData rsvp          = Icons.how_to_reg_rounded;
  static const IconData attendee      = Icons.group_rounded;
  static const IconData calendar      = Icons.calendar_today_rounded;

  // ── Polls ───────────────────────────────────────────────────────
  static const IconData polls         = Icons.how_to_vote_rounded;
  static const IconData vote          = Icons.ballot_rounded;
  static const IconData results       = Icons.bar_chart_rounded;
  static const IconData anonymous     = Icons.no_accounts_rounded;

  // ── Gallery ─────────────────────────────────────────────────────
  static const IconData gallery       = Icons.photo_library_rounded;
  static const IconData photo         = Icons.image_rounded;
  static const IconData album         = Icons.photo_album_rounded;
  static const IconData camera        = Icons.camera_alt_rounded;

  // ── Maids & Domestic Help ───────────────────────────────────────
  static const IconData maids         = Icons.cleaning_services_rounded;
  static const IconData kycPass       = Icons.badge_rounded;
  static const IconData attendance    = Icons.fact_check_rounded;

  // ── Staff ───────────────────────────────────────────────────────
  static const IconData staff         = Icons.manage_accounts_rounded;
  static const IconData staffId       = Icons.credit_card_rounded;

  // ── Water Tankers ───────────────────────────────────────────────
  static const IconData waterTankers  = Icons.water_drop_rounded;
  static const IconData tanker        = Icons.local_shipping_rounded;
  static const IconData waterMeter    = Icons.water_outlined;

  // ── Vendors & Work Orders ───────────────────────────────────────
  static const IconData vendors       = Icons.handyman_rounded;
  static const IconData workOrder     = Icons.assignment_rounded;
  static const IconData amc           = Icons.auto_fix_high_rounded;
  static const IconData contractor    = Icons.engineering_rounded;

  // ── Feedback ────────────────────────────────────────────────────
  static const IconData feedback      = Icons.rate_review_rounded;
  static const IconData rating        = Icons.star_rounded;
  static const IconData ratingEmpty   = Icons.star_border_rounded;
  static const IconData anonymous2    = Icons.visibility_off_rounded;

  // ── Snags & Defects ─────────────────────────────────────────────
  static const IconData snags         = Icons.construction_rounded;
  static const IconData snag          = Icons.build_circle_rounded;
  static const IconData defect        = Icons.report_rounded;
  static const IconData rectified     = Icons.verified_rounded;

  // ── AGM & Governance ────────────────────────────────────────────
  static const IconData agm           = Icons.gavel_rounded;
  static const IconData quorum        = Icons.groups_rounded;
  static const IconData minutes       = Icons.summarize_rounded;
  static const IconData resolution    = Icons.how_to_vote_rounded;

  // ── Policies ────────────────────────────────────────────────────
  static const IconData policies      = Icons.policy_rounded;
  static const IconData policyAck     = Icons.verified_user_rounded;
  static const IconData compliance    = Icons.fact_check_rounded;
  static const IconData consent       = Icons.thumb_up_rounded;

  // ── HOTO & Handover ─────────────────────────────────────────────
  static const IconData hoto          = Icons.swap_horiz_rounded;
  static const IconData handover      = Icons.handshake_rounded;
  static const IconData takeover      = Icons.login_rounded;
  static const IconData snagsHoto     = Icons.format_list_bulleted_rounded;

  // ── Membership & Registration ───────────────────────────────────
  static const IconData register      = Icons.card_membership_rounded;
  static const IconData membership    = Icons.workspace_premium_rounded;
  static const IconData share         = Icons.share_rounded;

  // ── Tenant KYC ──────────────────────────────────────────────────
  static const IconData tenantKyc     = Icons.how_to_reg_rounded;
  static const IconData kyc           = Icons.verified_user_rounded;
  static const IconData aadhaar       = Icons.fingerprint_rounded;
  static const IconData idDoc         = Icons.credit_card_rounded;

  // ── Analytics ───────────────────────────────────────────────────
  static const IconData analytics     = Icons.bar_chart_rounded;
  static const IconData trend         = Icons.trending_up_rounded;
  static const IconData pie           = Icons.pie_chart_rounded;
  static const IconData occupancy     = Icons.apartment_rounded;

  // ── Security Patrol ─────────────────────────────────────────────
  static const IconData patrol        = Icons.route_rounded;
  static const IconData checkpoint    = Icons.flag_rounded;
  static const IconData guardShift    = Icons.watch_later_rounded;

  // ── Common UI Actions ───────────────────────────────────────────
  static const IconData add           = Icons.add_rounded;
  static const IconData edit          = Icons.edit_rounded;
  static const IconData delete        = Icons.delete_rounded;
  static const IconData close         = Icons.close_rounded;
  static const IconData back          = Icons.arrow_back_rounded;
  static const IconData forward       = Icons.arrow_forward_ios_rounded;
  static const IconData chevronRight  = Icons.chevron_right_rounded;
  static const IconData chevronDown   = Icons.keyboard_arrow_down_rounded;
  static const IconData search        = Icons.search_rounded;
  static const IconData filter        = Icons.tune_rounded;
  static const IconData sort          = Icons.sort_rounded;
  static const IconData refresh       = Icons.refresh_rounded;
  static const IconData share2        = Icons.ios_share_rounded;
  static const IconData moreVert      = Icons.more_vert_rounded;
  static const IconData moreHoriz     = Icons.more_horiz_rounded;
  static const IconData info          = Icons.info_rounded;
  static const IconData help          = Icons.help_rounded;
  static const IconData settings      = Icons.settings_rounded;
  static const IconData logout        = Icons.logout_rounded;
  static const IconData darkMode      = Icons.dark_mode_rounded;
  static const IconData lightMode     = Icons.light_mode_rounded;
  static const IconData check         = Icons.check_rounded;
  static const IconData checkCircle   = Icons.check_circle_rounded;
  static const IconData error         = Icons.error_rounded;
  static const IconData warning       = Icons.warning_rounded;
  static const IconData attach        = Icons.attach_file_rounded;
  static const IconData location      = Icons.location_on_rounded;
  static const IconData phone         = Icons.phone_rounded;
  static const IconData link          = Icons.open_in_new_rounded;
  static const IconData copy          = Icons.copy_rounded;
  static const IconData time          = Icons.schedule_rounded;
  static const IconData date          = Icons.calendar_today_rounded;
  static const IconData eye           = Icons.visibility_rounded;
  static const IconData eyeOff        = Icons.visibility_off_rounded;
  static const IconData lock          = Icons.lock_rounded;
  static const IconData unlock        = Icons.lock_open_rounded;
  static const IconData verified      = Icons.verified_rounded;
  static const IconData image         = Icons.image_rounded;
  static const IconData emoji         = Icons.emoji_emotions_rounded;
  static const IconData exit          = Icons.exit_to_app_rounded;
  static const IconData admit         = Icons.how_to_reg_rounded;
}

// ─── 2. DSIcon WIDGET ────────────────────────────────────────────────────────
// Automatically scales with the active DsTextScale.
// Reads color from context (respects dark/light theme).

class DSIcon extends StatelessWidget {
  final IconData icon;
  final double size;       // base size, will be scaled
  final Color? color;
  final bool semanticLabel;

  const DSIcon(
    this.icon, {
    super.key,
    this.size = DsIconSizes.md,
    this.color,
    this.semanticLabel = false,
  });

  /// Convenience: small inline icon (e.g., in a row with text)
  const DSIcon.sm(this.icon, {super.key, this.color})
      : size = DsIconSizes.sm,
        semanticLabel = false;

  /// Convenience: large card-header icon
  const DSIcon.lg(this.icon, {super.key, this.color})
      : size = DsIconSizes.xl,
        semanticLabel = false;

  @override
  Widget build(BuildContext context) {
    final scaledSize = context.si(size);
    final effectiveColor = color ?? IconTheme.of(context).color;
    return Icon(icon, size: scaledSize, color: effectiveColor);
  }
}

// ─── 3. CUSTOM PAINTED ICONS ─────────────────────────────────────────────────
// Hand-drawn Path-based icons. These are the genuinely unique UTAMACS icons.

// ── Society / Apartment Building icon ────────────────────────────────────────
class DSApartmentPainter extends CustomPainter {
  final Color color;
  const DSApartmentPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final s = size.width;

    // Base building body
    final body = Rect.fromLTWH(s * 0.12, s * 0.38, s * 0.76, s * 0.58);
    canvas.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(s * 0.04)), p);

    // Roof triangle
    final roof = Path()
      ..moveTo(s * 0.05, s * 0.40)
      ..lineTo(s * 0.50, s * 0.06)
      ..lineTo(s * 0.95, s * 0.40)
      ..close();
    canvas.drawPath(roof, p);

    // Windows (3×3 grid)
    final wp = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final wSize = s * 0.12;
    final wRadius = Radius.circular(s * 0.025);
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 3; col++) {
        final wx = s * 0.18 + col * (wSize + s * 0.095);
        final wy = s * 0.47 + row * (wSize + s * 0.08);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(wx, wy, wSize, wSize), wRadius),
          wp,
        );
      }
    }

    // Door
    final door = RRect.fromRectAndCorners(
      Rect.fromLTWH(s * 0.40, s * 0.68, s * 0.20, s * 0.28),
      topLeft: Radius.circular(s * 0.10),
      topRight: Radius.circular(s * 0.10),
    );
    canvas.drawRRect(door, wp);
  }

  @override
  bool shouldRepaint(DSApartmentPainter old) => old.color != color;
}

// ── Visitor Pass / Badge icon ─────────────────────────────────────────────────
class DSPassPainter extends CustomPainter {
  final Color color;
  const DSPassPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final s = size.width;

    // Badge body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.08, s * 0.10, s * 0.84, s * 0.82),
        Radius.circular(s * 0.14),
      ),
      p,
    );

    // Lanyard notch at top
    final np = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.38, s * 0.05, s * 0.24, s * 0.12),
        Radius.circular(s * 0.06),
      ),
      np,
    );

    // Person silhouette
    final head = Paint()
      ..color = Colors.white.withValues(alpha: 0.90)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(s * 0.50, s * 0.38), s * 0.13, head);

    // Shoulders arc
    final shoulderPath = Path()
      ..moveTo(s * 0.20, s * 0.72)
      ..quadraticBezierTo(s * 0.50, s * 0.50, s * 0.80, s * 0.72)
      ..close();
    canvas.drawPath(shoulderPath, head);

    // Check mark bottom-right
    final ck = Paint()
      ..color = dsColorEmerald500
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(s * 0.73, s * 0.76), s * 0.14, ck);
    final tick = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.04
      ..strokeCap = StrokeCap.round;
    final tickPath = Path()
      ..moveTo(s * 0.64, s * 0.76)
      ..lineTo(s * 0.71, s * 0.83)
      ..lineTo(s * 0.82, s * 0.69);
    canvas.drawPath(tickPath, tick);
  }

  @override
  bool shouldRepaint(DSPassPainter old) => old.color != color;
}

// ── Gate / Archway icon ───────────────────────────────────────────────────────
class DSGatePainter extends CustomPainter {
  final Color color;
  const DSGatePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final s = size.width;

    // Left pillar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.04, s * 0.30, s * 0.20, s * 0.66),
        Radius.circular(s * 0.04),
      ),
      p,
    );
    // Right pillar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.76, s * 0.30, s * 0.20, s * 0.66),
        Radius.circular(s * 0.04),
      ),
      p,
    );

    // Arch
    final archRect = Rect.fromLTWH(s * 0.04, s * 0.08, s * 0.92, s * 0.48);
    final archPath = Path()
      ..moveTo(s * 0.04, s * 0.32)
      ..arcTo(archRect, math.pi, math.pi, false)
      ..lineTo(s * 0.96, s * 0.32)
      ..lineTo(s * 0.76, s * 0.32)
      ..arcTo(
        Rect.fromLTWH(s * 0.20, s * 0.16, s * 0.60, s * 0.36),
        0,
        -math.pi,
        false,
      )
      ..lineTo(s * 0.24, s * 0.32)
      ..close();
    canvas.drawPath(archPath, p);

    // Gate bar (horizontal cross-bar)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.24, s * 0.52, s * 0.52, s * 0.08),
        Radius.circular(s * 0.04),
      ),
      p,
    );
  }

  @override
  bool shouldRepaint(DSGatePainter old) => old.color != color;
}

// ── Rupee Receipt icon ────────────────────────────────────────────────────────
class DSReceiptPainter extends CustomPainter {
  final Color color;
  const DSReceiptPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final s = size.width;

    // Paper body with zigzag bottom
    final paperPath = Path()
      ..moveTo(s * 0.14, s * 0.04)
      ..lineTo(s * 0.86, s * 0.04)
      ..lineTo(s * 0.86, s * 0.82)
      // Zigzag bottom
      ..lineTo(s * 0.79, s * 0.90)
      ..lineTo(s * 0.71, s * 0.82)
      ..lineTo(s * 0.64, s * 0.90)
      ..lineTo(s * 0.57, s * 0.82)
      ..lineTo(s * 0.50, s * 0.90)
      ..lineTo(s * 0.43, s * 0.82)
      ..lineTo(s * 0.36, s * 0.90)
      ..lineTo(s * 0.29, s * 0.82)
      ..lineTo(s * 0.21, s * 0.90)
      ..lineTo(s * 0.14, s * 0.82)
      ..close();
    canvas.drawPath(paperPath, p);

    // Rupee ₹ symbol in center
    final rp = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.07
      ..strokeCap = StrokeCap.round;

    // ₹ — two horizontal bars at top + diagonal
    canvas.drawLine(
        Offset(s * 0.34, s * 0.26), Offset(s * 0.66, s * 0.26), rp);
    canvas.drawLine(
        Offset(s * 0.34, s * 0.38), Offset(s * 0.66, s * 0.38), rp);
    // Vertical stroke
    canvas.drawLine(
        Offset(s * 0.40, s * 0.22), Offset(s * 0.40, s * 0.62), rp);
    // Diagonal down
    canvas.drawLine(
        Offset(s * 0.40, s * 0.38), Offset(s * 0.65, s * 0.62), rp);
  }

  @override
  bool shouldRepaint(DSReceiptPainter old) => old.color != color;
}

// ── Water Wave (tanker/water) icon ────────────────────────────────────────────
class DSWaterPainter extends CustomPainter {
  final Color color;
  const DSWaterPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final s = size.width;

    // Drop body
    final drop = Path()
      ..moveTo(s * 0.50, s * 0.04)
      ..cubicTo(s * 0.50, s * 0.04, s * 0.92, s * 0.46, s * 0.92, s * 0.64)
      ..arcToPoint(
        Offset(s * 0.08, s * 0.64),
        radius: Radius.circular(s * 0.42),
        clockwise: false,
      )
      ..cubicTo(s * 0.08, s * 0.46, s * 0.50, s * 0.04, s * 0.50, s * 0.04)
      ..close();
    canvas.drawPath(drop, p);

    // Inner highlight wave
    final wp = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..style = PaintingStyle.fill;
    final wave = Path()
      ..moveTo(s * 0.20, s * 0.70)
      ..quadraticBezierTo(s * 0.35, s * 0.60, s * 0.50, s * 0.70)
      ..quadraticBezierTo(s * 0.65, s * 0.80, s * 0.80, s * 0.70)
      ..arcToPoint(Offset(s * 0.20, s * 0.70),
          radius: Radius.circular(s * 0.35), clockwise: false)
      ..close();
    canvas.drawPath(wave, wp);
  }

  @override
  bool shouldRepaint(DSWaterPainter old) => old.color != color;
}

// ── Wrench + Circle (Snags/Complaints) ───────────────────────────────────────
class DSSnagPainter extends CustomPainter {
  final Color color;
  const DSSnagPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final s = size.width;

    // Outer circle
    canvas.drawCircle(Offset(s / 2, s / 2), s * 0.44, p);

    // Wrench cutout (white)
    final wp = Paint()
      ..color = Colors.white.withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.10
      ..strokeCap = StrokeCap.round;

    // Wrench handle
    canvas.drawLine(Offset(s * 0.62, s * 0.62), Offset(s * 0.82, s * 0.82), wp);

    // Wrench head (circle + notch)
    final headP = Paint()
      ..color = Colors.white.withValues(alpha: 0.90)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(s * 0.42, s * 0.38), s * 0.18, headP);
    canvas.drawCircle(Offset(s * 0.42, s * 0.38), s * 0.08, p);
  }

  @override
  bool shouldRepaint(DSSnagPainter old) => old.color != color;
}

// ── Handshake (Community/Vendors) ────────────────────────────────────────────
class DSHandshakePainter extends CustomPainter {
  final Color color;
  const DSHandshakePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final s = size.width;

    // Left hand
    final left = Path()
      ..moveTo(s * 0.04, s * 0.60)
      ..lineTo(s * 0.20, s * 0.46)
      ..lineTo(s * 0.32, s * 0.42)
      ..lineTo(s * 0.44, s * 0.38)
      ..lineTo(s * 0.50, s * 0.50);
    canvas.drawPath(left, p);

    // Right hand
    final right = Path()
      ..moveTo(s * 0.96, s * 0.60)
      ..lineTo(s * 0.80, s * 0.46)
      ..lineTo(s * 0.68, s * 0.42)
      ..lineTo(s * 0.56, s * 0.38)
      ..lineTo(s * 0.50, s * 0.50);
    canvas.drawPath(right, p);

    // Clasp in center
    canvas.drawCircle(Offset(s * 0.50, s * 0.50), s * 0.10, Paint()
      ..color = color
      ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(DSHandshakePainter old) => old.color != color;
}

// ── Gavel (AGM/Governance) ────────────────────────────────────────────────────
class DSGavelPainter extends CustomPainter {
  final Color color;
  const DSGavelPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final s = size.width;

    // Gavel head
    canvas.save();
    canvas.translate(s * 0.50, s * 0.50);
    canvas.rotate(-math.pi / 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-s * 0.30, -s * 0.10, s * 0.52, s * 0.20),
        Radius.circular(s * 0.05),
      ),
      p,
    );
    canvas.restore();

    // Handle
    canvas.save();
    canvas.translate(s * 0.50, s * 0.50);
    canvas.rotate(-math.pi / 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.14, -s * 0.05, s * 0.36, s * 0.10),
        Radius.circular(s * 0.05),
      ),
      p,
    );
    canvas.restore();

    // Sound block base
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.12, s * 0.76, s * 0.76, s * 0.14),
        Radius.circular(s * 0.04),
      ),
      p,
    );
  }

  @override
  bool shouldRepaint(DSGavelPainter old) => old.color != color;
}

// ─── Module → CustomPainter registry ─────────────────────────────────────────
// Returns a CustomPainter for the given module key, null = use Material icon

CustomPainter? dsCustomPainter(String moduleKey, Color color) =>
    switch (moduleKey) {
      'members'    || 'register' || 'hoto' => DSApartmentPainter(color),
      'visitors'                           => DSPassPainter(color),
      'security_patrol'                    => DSGatePainter(color),
      'finance'                            => DSReceiptPainter(color),
      'water_tankers'                      => DSWaterPainter(color),
      'snags'      || 'complaints'         => DSSnagPainter(color),
      'community'  || 'vendors'            => DSHandshakePainter(color),
      'agm'                                => DSGavelPainter(color),
      _                                    => null,
    };

// ─── DSModuleIcon widget ──────────────────────────────────────────────────────
// Automatically picks the custom painter if one exists, falls back to DSIcon.

class DSModuleIcon extends StatelessWidget {
  final String moduleKey;
  final IconData fallbackIcon;
  final double size;
  final Color color;
  final Color bgColor;
  final bool showBg;

  const DSModuleIcon({
    super.key,
    required this.moduleKey,
    required this.fallbackIcon,
    required this.color,
    this.bgColor = Colors.transparent,
    this.size = 44,
    this.showBg = true,
  });

  @override
  Widget build(BuildContext context) {
    final scaledSize = context.si(size);
    final painter = dsCustomPainter(moduleKey, color);

    Widget iconWidget;
    if (painter != null) {
      iconWidget = SizedBox(
        width: scaledSize * 0.58,
        height: scaledSize * 0.58,
        child: CustomPaint(painter: painter),
      );
    } else {
      iconWidget = Icon(fallbackIcon, size: scaledSize * 0.52, color: color);
    }

    if (!showBg) return iconWidget;

    return Container(
      width: scaledSize,
      height: scaledSize,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(scaledSize * 0.28),
      ),
      child: Center(child: iconWidget),
    );
  }
}
