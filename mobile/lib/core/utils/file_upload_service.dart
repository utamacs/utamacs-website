import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase.dart' as env;

// ─── Allowed MIME types ───────────────────────────────────────────────────────
// Security policy — not configurable by users or admins.
const _imageMime = {'image/jpeg', 'image/png', 'image/webp'};
const _docMime   = {'application/pdf'};
const _allowedMime = {..._imageMime, ..._docMime};

// Default max file size per attachment (bytes). Size limit per module is read
// from the portal rules engine at upload time; this is a hard client-side cap.
const int kDefaultMaxUploadBytes = 50 * 1024 * 1024; // 50 MB

// ─── Picked file ─────────────────────────────────────────────────────────────

class MobilePickedFile {
  final File file;
  final String name;
  final String mimeType;
  final int sizeBytes;

  const MobilePickedFile({
    required this.file,
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
  });

  bool get isImage => _imageMime.contains(mimeType);
}

// ─── Upload result ────────────────────────────────────────────────────────────

class UploadResult {
  final String storageKey;
  final String? downloadUrl;
  const UploadResult({required this.storageKey, this.downloadUrl});
}

// ─── Service ──────────────────────────────────────────────────────────────────

class MobileFileUploadService {
  MobileFileUploadService._();

  static final _imagePicker = ImagePicker();

  /// Pick images from gallery or camera (returns up to [maxCount] items).
  static Future<List<MobilePickedFile>> pickImages({
    int maxCount = 5,
    ImageSource source = ImageSource.gallery,
  }) async {
    final List<XFile> xfiles;
    if (source == ImageSource.gallery && maxCount > 1) {
      xfiles = await _imagePicker.pickMultiImage(imageQuality: 85);
    } else {
      final xfile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      xfiles = xfile != null ? [xfile] : [];
    }
    return _toMobilePickedFiles(xfiles.take(maxCount).toList());
  }

  /// Pick documents (PDF) or images using the system file picker.
  static Future<List<MobilePickedFile>> pickDocuments({int maxCount = 5}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: maxCount > 1,
    );
    if (result == null) return [];
    final xfiles = result.files
        .take(maxCount)
        .where((f) => f.path != null)
        .map((f) => XFile(f.path!))
        .toList();
    return _toMobilePickedFiles(xfiles);
  }

  static Future<List<MobilePickedFile>> _toMobilePickedFiles(List<XFile> xfiles) async {
    final picked = <MobilePickedFile>[];
    for (final x in xfiles) {
      final file = File(x.path);
      final bytes = await file.length();
      final mime  = _guessMime(x.name);
      if (!_allowedMime.contains(mime)) {
        debugPrint('[Upload] Skipping ${x.name} — MIME $mime not allowed');
        continue;
      }
      picked.add(MobilePickedFile(
        file: file,
        name: x.name,
        mimeType: mime,
        sizeBytes: bytes,
      ));
    }
    return picked;
  }

  /// Upload [file] to the portal API for [module] / [resourceId].
  ///
  /// Returns the [UploadResult] with the `storage_key` stored in the DB.
  /// Throws [MobileUploadException] on validation or server errors.
  static Future<UploadResult> upload({
    required MobilePickedFile file,
    required String module,
    required String resourceId,
    int maxBytes = kDefaultMaxUploadBytes,
  }) async {
    if (!_allowedMime.contains(file.mimeType)) {
      throw MobileUploadException('File type not allowed: ${file.mimeType}');
    }
    if (file.sizeBytes > maxBytes) {
      final mb = (maxBytes / (1024 * 1024)).round();
      throw MobileUploadException('File exceeds the $mb MB size limit');
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw const MobileUploadException('Not authenticated');
    }

    final uri = Uri.parse('${env.portalUrl}/api/v1/$module/upload');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${session.accessToken}'
      ..fields['resource_id'] = resourceId
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        file.file.path,
        filename: file.name,
      ));

    final streamed = await request.send();
    final body     = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200 || streamed.statusCode == 201) {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return UploadResult(
        storageKey:  json['storage_key'] as String,
        downloadUrl: json['url'] as String?,
      );
    }

    // Parse portal error shape: { "error": "CODE", "message": "..." }
    String message = 'Upload failed (${streamed.statusCode})';
    try {
      final err = jsonDecode(body) as Map<String, dynamic>;
      message = err['message'] as String? ?? message;
    } catch (_) {}
    throw MobileUploadException(message);
  }

  // ─── MIME detection ─────────────────────────────────────────────────────────

  static String _guessMime(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png'           => 'image/png',
      'webp'          => 'image/webp',
      'pdf'           => 'application/pdf',
      _               => 'application/octet-stream',
    };
  }
}

// ─── Exception ────────────────────────────────────────────────────────────────

class MobileUploadException implements Exception {
  final String message;
  const MobileUploadException(this.message);

  @override
  String toString() => 'MobileUploadException: $message';
}
