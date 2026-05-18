import 'package:flutter/material.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import '../design/ds_tokens.dart';
import '../theme/app_theme.dart';

/// Checks for root / jailbreak and shows a non-blocking warning dialog.
/// Does NOT block app launch — false positives on emulators are common and
/// preventing staff/execs from using the app is worse than a missed detection.
Future<void> warnIfCompromisedDevice(BuildContext context) async {
  try {
    final isJailbroken = await FlutterJailbreakDetection.jailbroken;
    if (!isJailbroken) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Security Warning'),
        content: const Text(
          'This device appears to be rooted or jailbroken. '
          'The UTA MACS app stores sensitive society data. '
          'Using it on a compromised device may put that data at risk.\n\n'
          'Please use a secure, unmodified device for the best protection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  } catch (_) {
    // Detection failure is non-fatal — proceed normally.
  }
}

/// Authenticates the user with biometrics (fingerprint / Face ID).
/// Returns true if authentication succeeded or if biometrics are unavailable
/// (so the caller can fall back to PIN/password).
///
/// [reason] is shown in the OS biometric prompt.
Future<bool> authenticateWithBiometrics(String reason) async {
  final auth = LocalAuthentication();
  try {
    final canCheck = await auth.canCheckBiometrics;
    final isDeviceSupported = await auth.isDeviceSupported();
    if (!canCheck && !isDeviceSupported) return true; // no biometrics — allow through

    final available = await auth.getAvailableBiometrics();
    if (available.isEmpty) return true; // no enrolled biometrics — allow through

    return await auth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(
        biometricOnly: false, // fallback to device PIN if face/fingerprint fails
        stickyAuth: true,     // keep prompt alive if user switches apps
      ),
    );
  } catch (_) {
    return true; // authentication unavailable — allow through
  }
}

/// Wraps [child] behind a biometric prompt on first display.
/// If biometrics are unavailable or enrollment is empty, the child renders
/// immediately (allow-through). If the user denies auth, a retry screen is
/// shown rather than revealing the content.
class BiometricGate extends StatefulWidget {
  final Widget child;
  final String reason;

  const BiometricGate({
    super.key,
    required this.child,
    required this.reason,
  });

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate> {
  bool _authenticated = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ok = await authenticateWithBiometrics(widget.reason);
    if (mounted) setState(() { _authenticated = ok; _checking = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_authenticated) return widget.child;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fingerprint, size: 72, color: kTextSecondary),
              const SizedBox(height: 24),
              Text(
                'Authentication required',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Verify your identity to access this section.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: kTextSecondary),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.fingerprint),
                label: const Text('Try again'),
                onPressed: () {
                  setState(() => _checking = true);
                  _check();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
