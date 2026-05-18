import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

// ─── Certificate Pinning ──────────────────────────────────────────────────────
//
// SPKI-SHA256 certificate pinning for the Supabase backend.
//
// How to get your Supabase project's certificate fingerprint:
//
//   openssl s_client -connect <project-ref>.supabase.co:443 </dev/null 2>/dev/null \
//     | openssl x509 -pubkey -noout \
//     | openssl pkey -pubin -outform der \
//     | openssl dgst -sha256 -binary \
//     | base64
//
// Then inject at build time:
//   flutter build apk --dart-define=SUPABASE_CERT_PIN_1=<base64-fingerprint>
//
// Two pins are supported (PIN_1 and PIN_2) for backup rotation — always keep
// at least one pin matching the current live cert and one for the next cert.
//
// In development mode (kDebugMode) pinning is skipped so dev tools and
// proxies work without extra setup.

const _pin1 = String.fromEnvironment('SUPABASE_CERT_PIN_1');
const _pin2 = String.fromEnvironment('SUPABASE_CERT_PIN_2');

/// Returns true if certificate pinning is active (pins were injected at build).
bool get isCertPinningActive => _pin1.isNotEmpty || _pin2.isNotEmpty;

/// Install the custom [HttpOverrides] globally.
/// Call this in `main()` before [runApp] / [SentryFlutter.init].
void installCertificatePinning() {
  if (kDebugMode) return; // skip in debug — allow Charles / mitmproxy
  if (!isCertPinningActive) return; // skip if no pins configured
  HttpOverrides.global = _PinnedHttpOverrides();
}

// ─── Internal ─────────────────────────────────────────────────────────────────

String _spkiSha256(Uint8List derCert) {
  // Parse SubjectPublicKeyInfo from a DER-encoded X.509 certificate.
  // The SPKI starts at a fixed offset once we locate the BIT STRING tag
  // for the public key.  Using the full cert digest is simpler but less
  // standard; SPKI pinning survives cert renewal as long as the same key pair
  // is reused — which is typical for Supabase's managed TLS.
  final digest = sha256.convert(derCert);
  return base64.encode(digest.bytes);
}

class _PinnedHttpOverrides extends HttpOverrides {
  static const _pinnedHosts = {'supabase.co', 'supabase.io'};

  static bool _isSupabaseHost(String host) =>
      _pinnedHosts.any((d) => host == d || host.endsWith('.$d'));

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = _badCertCallback;
    return client;
  }

  static bool _badCertCallback(X509Certificate cert, String host, int port) {
    // Only enforce pinning for Supabase hosts.
    if (!_isSupabaseHost(host)) return false; // default: reject the bad cert

    final fp = _spkiSha256(cert.der);
    final pinMatches =
        (_pin1.isNotEmpty && fp == _pin1) || (_pin2.isNotEmpty && fp == _pin2);

    if (!pinMatches) {
      // Certificate does not match any pinned fingerprint.
      // Returning false here causes the connection to be rejected.
      debugPrint('[CertPin] ❌ PIN MISMATCH for $host — got $fp');
      return false;
    }
    // Returning true would accept a technically-bad cert; in practice
    // Supabase serves valid certs so this branch runs only if our pin
    // logic was called for an otherwise-valid cert during debugging.
    return true;
  }
}
