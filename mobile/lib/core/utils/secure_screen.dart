import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Secure Screen Utility ────────────────────────────────────────────────────
//
// Prevents screenshots and screen recordings on Android via FLAG_SECURE.
// The flag is set in initState and cleared in dispose of the screen's State.
//
// Usage:
//   @override void initState() { super.initState(); SecureScreen.enable(); }
//   @override void dispose()   { SecureScreen.disable(); super.dispose(); }
//
// iOS: screenshots of secure text fields are already suppressed by the OS.
// No iOS implementation needed here.

// ─── Secure Screen Wrapper Widget ─────────────────────────────────────────────
//
// Wrap a screen's top-level widget with this to enable FLAG_SECURE while it is
// visible and restore the flag when navigated away.
//
// Usage:
//   return SecureScreenWrapper(child: DefaultTabController(...));

class SecureScreenWrapper extends StatefulWidget {
  final Widget child;
  const SecureScreenWrapper({super.key, required this.child});

  @override
  State<SecureScreenWrapper> createState() => _SecureScreenWrapperState();
}

class _SecureScreenWrapperState extends State<SecureScreenWrapper> {
  @override
  void initState() {
    super.initState();
    SecureScreen.enable();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─── Low-level channel calls ──────────────────────────────────────────────────

abstract final class SecureScreen {
  static const _channel = MethodChannel('org.utamacs.app/security');

  static Future<void> enable() async {
    try {
      await _channel.invokeMethod<void>('setSecureScreen', {'secure': true});
    } catch (_) {
      // Platform doesn't support or channel not available — safe to ignore.
    }
  }

  static Future<void> disable() async {
    try {
      await _channel.invokeMethod<void>('setSecureScreen', {'secure': false});
    } catch (_) {}
  }
}
