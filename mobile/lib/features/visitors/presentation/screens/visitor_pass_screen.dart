import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/visitor_repository.dart';

class VisitorPassScreen extends StatelessWidget {
  final VisitorPreApproval approval;
  const VisitorPassScreen({super.key, required this.approval});

  @override
  Widget build(BuildContext context) {
    // QR payload: JSON with pass ID and token for gate scanner to verify
    final qrData = '{"pass_id":"${approval.id}","token":"${approval.qrToken ?? approval.id}"}';

    return Scaffold(
      backgroundColor: kPrimary600,
      appBar: AppBar(
        backgroundColor: kPrimary600,
        title: const Text('Visitor Pass'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(),
              // Pass card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    // Society header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: kPrimary600,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.apartment,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text('UTA MACS',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(color: kPrimary600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('VISITOR PASS',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: kTextSecondary)),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 20),
                    // QR Code
                    QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: kPrimary600,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Visitor details
                    _DetailRow(label: 'Visitor', value: approval.visitorName),
                    if (approval.purpose != null)
                      _DetailRow(label: 'Purpose', value: approval.purpose!),
                    _DetailRow(
                      label: 'Valid',
                      value: approval.expiresAt != null
                          ? '${formatDate(approval.expectedDate)} – ${formatDate(approval.expiresAt!)}'
                          : formatDate(approval.expectedDate),
                    ),
                    if (approval.isRecurring)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.repeat, size: 14, color: kSecondary500),
                            SizedBox(width: 4),
                            Text('Recurring pass',
                                style: TextStyle(
                                    fontSize: 12, color: kSecondary500)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Show this QR code to the security guard at the gate',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: kTextSecondary,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
