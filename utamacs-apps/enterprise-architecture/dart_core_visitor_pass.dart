// dart_core/lib/domain/visitor_pass.dart
// HMAC-SHA256 signed visitor passes — offline verifiable by guard app
// Addresses: Critical Finding #8 — Gate verification must work without network
// All pass verification logic is in Pure Dart (no Flutter dependency)

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';    // dart pub add crypto

/// Represents a cryptographically signed visitor pass.
/// The guard app can verify this pass locally without any network call.
class VisitorPass {
  final String passId;           // UUID v4 — server-generated
  final String tenantId;         // Society UUID
  final String unitId;           // Residential unit UUID
  final String unitNumber;       // Display: "204B"
  final String visitorName;
  final int validFromEpoch;      // Unix timestamp (seconds UTC)
  final int validUntilEpoch;     // Unix timestamp (seconds UTC)
  final String passType;         // 'qr_pass' | 'pre_approved' | 'otp_pass'
  final String? visitorPhone;    // Optional, masked in QR payload
  final String signature;        // HMAC-SHA256 of canonical fields

  const VisitorPass({
    required this.passId,
    required this.tenantId,
    required this.unitId,
    required this.unitNumber,
    required this.visitorName,
    required this.validFromEpoch,
    required this.validUntilEpoch,
    required this.passType,
    this.visitorPhone,
    required this.signature,
  });

  /// Canonical signing string — field order is FROZEN and must never change.
  /// Adding new fields appends to the end; removing fields requires a new schema version.
  String get _signingInput =>
    '$passId:$tenantId:$unitId:$validFromEpoch:$validUntilEpoch:$passType';

  /// Verify the pass signature using the tenant's HMAC key.
  /// [tenantHmacKey] is fetched from Azure Key Vault on login, stored in SecureStore.
  /// Returns [PassVerificationResult] with reason for any failure.
  PassVerificationResult verify(String tenantHmacKey) {
    // 1. Check temporal validity first (cheap check, no crypto)
    final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (nowEpoch < validFromEpoch) {
      return PassVerificationResult.notYetValid(
        validFrom: DateTime.fromMillisecondsSinceEpoch(validFromEpoch * 1000),
      );
    }
    // Allow 5-minute clock skew tolerance
    if (nowEpoch > validUntilEpoch + 300) {
      return PassVerificationResult.expired(
        expiredAt: DateTime.fromMillisecondsSinceEpoch(validUntilEpoch * 1000),
      );
    }

    // 2. Verify HMAC signature (constant-time comparison prevents timing attacks)
    final mac = Hmac(sha256, utf8.encode(tenantHmacKey));
    final expectedBytes = mac.convert(utf8.encode(_signingInput)).bytes;
    final expectedSig = base64Url.encode(expectedBytes);

    if (!_constantTimeEquals(signature, expectedSig)) {
      return PassVerificationResult.invalid(reason: 'Signature mismatch');
    }

    return PassVerificationResult.valid(
      unitNumber: unitNumber,
      visitorName: visitorName,
      validUntil: DateTime.fromMillisecondsSinceEpoch(validUntilEpoch * 1000),
    );
  }

  /// Encode the pass into a compact QR payload string.
  /// Format: UTAMACS:v1:<passId>:<tenantIdLast8>:<unitIdLast8>:<validUntil>:<sigFirst22>
  /// Fits in a 200x200 QR code at error correction level M.
  String toQrPayload() {
    final tenantShort = tenantId.replaceAll('-', '').substring(24);  // last 8 chars
    final unitShort   = unitId.replaceAll('-', '').substring(24);
    final sigShort    = signature.substring(0, 22);  // First 22 chars of base64url sig
    return 'UTAMACS:v1:$passId:$tenantShort:$unitShort:$validUntilEpoch:$sigShort';
  }

  /// Parse a QR payload back into a [VisitorPass] stub for verification.
  /// The stub has limited fields — full pass data comes from server cache.
  static VisitorPassStub parseQrPayload(String payload) {
    final parts = payload.split(':');
    if (parts.length != 7 || parts[0] != 'UTAMACS' || parts[1] != 'v1') {
      throw const FormatException('Invalid QR payload format');
    }
    return VisitorPassStub(
      passId: parts[2],
      tenantIdSuffix: parts[3],
      unitIdSuffix: parts[4],
      validUntilEpoch: int.parse(parts[5]),
      signaturePrefix: parts[6],
    );
  }

  /// Constant-time string comparison — prevents timing attacks on HMAC verification.
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}

/// Lightweight stub parsed from QR payload — used for quick offline pre-check
class VisitorPassStub {
  final String passId;
  final String tenantIdSuffix;
  final String unitIdSuffix;
  final int validUntilEpoch;
  final String signaturePrefix;

  const VisitorPassStub({
    required this.passId,
    required this.tenantIdSuffix,
    required this.unitIdSuffix,
    required this.validUntilEpoch,
    required this.signaturePrefix,
  });

  bool get isExpired =>
    DateTime.now().millisecondsSinceEpoch ~/ 1000 > validUntilEpoch + 300;
}

/// Result of pass verification — includes enough info to show the guard a useful UI
sealed class PassVerificationResult {
  const PassVerificationResult();

  factory PassVerificationResult.valid({
    required String unitNumber,
    required String visitorName,
    required DateTime validUntil,
  }) = ValidPass;

  factory PassVerificationResult.expired({required DateTime expiredAt}) = ExpiredPass;

  factory PassVerificationResult.notYetValid({required DateTime validFrom}) = NotYetValidPass;

  factory PassVerificationResult.invalid({required String reason}) = InvalidPass;

  factory PassVerificationResult.revoked() = RevokedPass;
}

final class ValidPass extends PassVerificationResult {
  final String unitNumber;
  final String visitorName;
  final DateTime validUntil;
  const ValidPass({required this.unitNumber, required this.visitorName, required this.validUntil});
}

final class ExpiredPass   extends PassVerificationResult {
  final DateTime expiredAt;
  const ExpiredPass({required this.expiredAt});
}

final class NotYetValidPass extends PassVerificationResult {
  final DateTime validFrom;
  const NotYetValidPass({required this.validFrom});
}

final class InvalidPass   extends PassVerificationResult {
  final String reason;
  const InvalidPass({required this.reason});
}

final class RevokedPass   extends PassVerificationResult {
  const RevokedPass();
}

/// Guard-side QR scanner use case — offline-first verification
/// Uses: locally cached HMAC key + locally cached revocation bloom filter
class VerifyVisitorPassUseCase {
  final SecureStorageRepository _secureStorage;
  final PassRevocationRepository _revocationRepo;
  final VisitorLogRepository _logRepo;

  const VerifyVisitorPassUseCase({
    required SecureStorageRepository secureStorage,
    required PassRevocationRepository revocationRepo,
    required VisitorLogRepository logRepo,
  }) : _secureStorage = secureStorage,
       _revocationRepo = revocationRepo,
       _logRepo = logRepo;

  Future<PassVerificationResult> execute(String qrPayload) async {
    // Parse QR payload
    late VisitorPassStub stub;
    try {
      stub = VisitorPass.parseQrPayload(qrPayload);
    } on FormatException {
      return const InvalidPass(reason: 'QR code is not a valid UTAMACS pass');
    }

    // Quick expiry check before any crypto
    if (stub.isExpired) {
      return ExpiredPass(
        expiredAt: DateTime.fromMillisecondsSinceEpoch(stub.validUntilEpoch * 1000),
      );
    }

    // Check local revocation bloom filter (refreshed every 5 min when online)
    final isRevoked = await _revocationRepo.isRevoked(stub.passId);
    if (isRevoked) return const RevokedPass();

    // For full offline verification, we need the full pass from local cache
    // Guard app caches recently scanned/expected passes when online
    final cachedPass = await _secureStorage.getCachedPass(stub.passId);
    if (cachedPass != null) {
      final hmacKey = await _secureStorage.getTenantHmacKey(stub.tenantIdSuffix);
      if (hmacKey != null) {
        final result = cachedPass.verify(hmacKey);
        if (result is ValidPass) {
          // Log entry locally; sync when online
          await _logRepo.logEntryLocally(
            passId: stub.passId,
            unitIdSuffix: stub.unitIdSuffix,
            verifiedAt: DateTime.now(),
          );
        }
        return result;
      }
    }

    // If not in local cache, must go online for full verification
    // Return a "needs_network" signal so the UI prompts guard to reconnect
    return const InvalidPass(reason: 'Pass not in local cache. Please connect to verify.');
  }
}

// Abstract interfaces — implemented per-platform
abstract class SecureStorageRepository {
  Future<VisitorPass?> getCachedPass(String passId);
  Future<String?> getTenantHmacKey(String tenantIdSuffix);
}

abstract class PassRevocationRepository {
  Future<bool> isRevoked(String passId);
}

abstract class VisitorLogRepository {
  Future<void> logEntryLocally({
    required String passId,
    required String unitIdSuffix,
    required DateTime verifiedAt,
  });
}
