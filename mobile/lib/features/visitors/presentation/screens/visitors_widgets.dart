part of 'visitors_screen.dart';

// ─── Shared Cards ─────────────────────────────────────────────────────────────

class _PreApprovalCard extends StatelessWidget {
  final VisitorPreApproval approval;
  final bool isDark;
  const _PreApprovalCard({required this.approval, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    final isActive = approval.isActive;

    return DSScalePress(
      onTap: isActive
          ? () => context.push('/visitors/pass', extra: approval)
          : null,
      child: Container(
        padding: const EdgeInsets.all(dsSpace4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(dsRadiusCard),
          boxShadow: isDark ? [] : dsShadowSm,
          border: isDark
              ? Border.all(color: dsDarkBorderSubtle, width: 1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: context.si(42),
                  height: context.si(42),
                  decoration: BoxDecoration(
                    color: isActive
                        ? dsColorIndigo50
                        : (isDark
                            ? dsDarkSurfaceMuted
                            : dsColorSlate100),
                    borderRadius: BorderRadius.circular(dsRadiusMd),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: isActive
                        ? dsColorIndigo600
                        : (isDark ? dsDarkTextTertiary : dsTextTertiary),
                    size: context.si(20),
                  ),
                ),
                const SizedBox(width: dsSpace3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        approval.visitorName,
                        style: GoogleFonts.inter(
                          fontSize: context.sp(14),
                          fontWeight: FontWeight.w600,
                          color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                        ),
                      ),
                      if (approval.purpose != null)
                        Text(
                          approval.purpose!,
                          style: GoogleFonts.inter(
                            fontSize: context.sp(12),
                            color: isDark
                                ? dsDarkTextSecondary
                                : dsTextSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: dsSpace2, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isActive ? dsColorEmerald600 : dsTextSecondary)
                        .withValues(alpha: isDark ? 0.15 : 0.10),
                    borderRadius: BorderRadius.circular(dsRadiusFull),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : approval.status.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: context.sp(9),
                      fontWeight: FontWeight.w800,
                      color: isActive
                          ? (isDark
                              ? dsColorEmerald400
                              : dsColorEmerald600)
                          : (isDark
                              ? dsDarkTextSecondary
                              : dsTextSecondary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: dsSpace3),
            Divider(
                height: 1,
                color: isDark ? dsDarkBorderSubtle : dsBorderSubtle),
            const SizedBox(height: dsSpace2),
            Row(
              children: [
                if (approval.vehicleNumber != null) ...[
                  Icon(Icons.directions_car_outlined,
                      size: context.si(13),
                      color: isDark ? dsDarkTextTertiary : dsTextTertiary),
                  const SizedBox(width: 4),
                  Text(
                    approval.vehicleNumber!,
                    style: GoogleFonts.inter(
                      fontSize: context.sp(11),
                      color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                    ),
                  ),
                  const SizedBox(width: dsSpace3),
                ],
                Icon(Icons.schedule_rounded,
                    size: context.si(13),
                    color: isDark ? dsDarkTextTertiary : dsTextTertiary),
                const SizedBox(width: 4),
                Text(
                  timeago.format(approval.expectedDate),
                  style: GoogleFonts.inter(
                    fontSize: context.sp(11),
                    color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                  ),
                ),
                if (isActive) ...[
                  const Spacer(),
                  Icon(Icons.qr_code_2_rounded,
                      size: context.si(14), color: dsColorIndigo600),
                  const SizedBox(width: 3),
                  Text(
                    'Show pass',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(11),
                      fontWeight: FontWeight.w700,
                      color: dsColorIndigo600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final VisitorLog log;
  final bool isDark;
  const _LogCard({required this.log, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isInside = log.isInside;
    final surface  = isDark ? dsDarkSurface : dsSurface;
    final iconColor = isInside
        ? (isDark ? dsColorEmerald400 : dsColorEmerald600)
        : (isDark ? dsDarkTextTertiary : dsTextTertiary);
    final iconBg = isInside
        ? (isDark
            ? dsColorEmerald600.withValues(alpha: 0.15)
            : dsColorEmerald50)
        : (isDark ? dsDarkSurfaceMuted : dsColorSlate100);

    return Container(
      padding: const EdgeInsets.all(dsSpace3),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        boxShadow: isDark ? [] : dsShadowXs,
        border: isDark
            ? Border.all(color: dsDarkBorderSubtle, width: 1)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: context.si(38),
            height: context.si(38),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(dsRadiusSm),
            ),
            child: Icon(
              isInside
                  ? Icons.person_outline_rounded
                  : Icons.person_off_outlined,
              color: iconColor,
              size: context.si(18),
            ),
          ),
          const SizedBox(width: dsSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.visitorName,
                  style: GoogleFonts.inter(
                    fontSize: context.sp(13),
                    fontWeight: FontWeight.w600,
                    color: isDark ? dsDarkTextPrimary : dsTextPrimary,
                  ),
                ),
                Text(
                  isInside
                      ? 'Inside · ${timeago.format(log.entryTime)}'
                      : 'Exited · ${timeago.format(log.entryTime)}',
                  style: GoogleFonts.inter(
                    fontSize: context.sp(11),
                    color: isDark ? dsDarkTextSecondary : dsTextSecondary,
                  ),
                ),
                if (log.gate != null)
                  Text(
                    'Gate: ${log.gate}',
                    style: GoogleFonts.inter(
                      fontSize: context.sp(10),
                      color: isDark ? dsDarkTextTertiary : dsTextTertiary,
                    ),
                  ),
              ],
            ),
          ),
          if (isInside)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: dsSpace2, vertical: 3),
              decoration: BoxDecoration(
                color: isDark
                    ? dsColorEmerald600.withValues(alpha: 0.15)
                    : dsColorEmerald50,
                borderRadius: BorderRadius.circular(dsRadiusFull),
              ),
              child: Text(
                'Inside',
                style: GoogleFonts.inter(
                  fontSize: context.sp(9),
                  fontWeight: FontWeight.w800,
                  color:
                      isDark ? dsColorEmerald400 : dsColorEmerald600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PassVerifiedCard extends StatelessWidget {
  final VisitorPreApproval pass;
  final bool isDark;
  const _PassVerifiedCard({required this.pass, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? dsDarkSurface : dsSurface;
    return Container(
      padding: const EdgeInsets.all(dsSpace4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(dsRadiusCard),
        border: Border.all(
          color: isDark
              ? dsColorEmerald600.withValues(alpha: 0.3)
              : dsColorEmerald100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: isDark ? dsColorEmerald400 : dsColorEmerald600,
                  size: context.si(17)),
              const SizedBox(width: dsSpace2),
              Text(
                'Pass verified',
                style: GoogleFonts.inter(
                  fontSize: context.sp(13),
                  fontWeight: FontWeight.w700,
                  color: isDark ? dsColorEmerald400 : dsColorEmerald600,
                ),
              ),
            ],
          ),
          const SizedBox(height: dsSpace3),
          _VerifiedRow(label: 'Visitor', value: pass.visitorName, isDark: isDark),
          if (pass.purpose != null)
            _VerifiedRow(label: 'Purpose', value: pass.purpose!, isDark: isDark),
          if (pass.vehicleNumber != null)
            _VerifiedRow(label: 'Vehicle', value: pass.vehicleNumber!, isDark: isDark),
        ],
      ),
    );
  }
}

class _VerifiedRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  const _VerifiedRow(
      {required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: context.sp(12),
                color: isDark ? dsDarkTextSecondary : dsTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: context.sp(12),
                fontWeight: FontWeight.w600,
                color: isDark ? dsDarkTextPrimary : dsTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Gate Picker Dialog ───────────────────────────────────────────────────────

class _GatePickerDialog extends StatefulWidget {
  final String passName;
  const _GatePickerDialog({required this.passName});

  @override
  State<_GatePickerDialog> createState() => _GatePickerDialogState();
}

class _GatePickerDialogState extends State<_GatePickerDialog> {
  String _gate = 'main';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dsRadiusCardLg)),
      title: Text(
        'Admit ${widget.passName}',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select gate:',
              style: GoogleFonts.inter(color: dsTextSecondary)),
          const SizedBox(height: dsSpace2),
          ...['main', 'secondary', 'pedestrian'].map(
            (g) => RadioListTile<String>(
              title: Text(g[0].toUpperCase() + g.substring(1),
                  style: GoogleFonts.inter()),
              value: g,
              // ignore: deprecated_member_use
              groupValue: _gate,
              activeColor: dsColorIndigo600,
              // ignore: deprecated_member_use
              onChanged: (v) => setState(() => _gate = v!),
              dense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: GoogleFonts.inter(color: dsTextSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _gate),
          child: Text('Admit',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, color: dsColorIndigo600)),
        ),
      ],
    );
  }
}

// ─── Filter Dropdown ──────────────────────────────────────────────────────────

class _FilterDropdown extends ConsumerWidget {
  final String label;
  final List<String> options;
  final String? selected;
  final bool isDark;
  final void Function(String?) onSelect;

  const _FilterDropdown({
    required this.label,
    required this.options,
    required this.selected,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive    = selected != null;
    final borderColor = isActive ? dsColorIndigo600 : (isDark ? dsDarkBorderLight : dsBorderLight);
    final bgColor     = isActive
        ? (isDark ? dsColorIndigo600.withValues(alpha: 0.12) : dsColorIndigo50)
        : (isDark ? dsDarkSurfaceMuted : dsBackground);

    return PopupMenuButton<String?>(
      initialValue: selected,
      onSelected: onSelect,
      color: isDark ? dsDarkSurfaceElevated : dsSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dsRadiusMd)),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: null,
          child: Text('All $label', style: GoogleFonts.inter()),
        ),
        ...options.map((o) => PopupMenuItem(
              value: o,
              child: Text(o, style: GoogleFonts.inter()),
            )),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: dsSpace3, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(dsRadiusSm),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                selected ?? label,
                style: GoogleFonts.inter(
                  fontSize: context.sp(12),
                  color: isActive
                      ? dsColorIndigo600
                      : (isDark ? dsDarkTextSecondary : dsTextSecondary),
                  fontWeight: isActive
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded,
                size: context.si(16),
                color: isDark ? dsDarkTextSecondary : dsTextSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── QR Scan Screen ───────────────────────────────────────────────────────────

class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Scan Visitor QR',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Toggle torch',
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_scanned) return;
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                _scanned = true;
                Navigator.pop(context, barcode!.rawValue);
              }
            },
          ),
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(dsRadiusXl),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Text(
              'Position the QR code within the frame',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
