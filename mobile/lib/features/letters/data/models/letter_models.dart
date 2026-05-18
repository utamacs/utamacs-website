part of '../letter_repository.dart';

class GeneratedLetter {
  final String id;
  final String title;
  final String? subject;
  final String? recipient;
  final String createdBy;
  final DateTime createdAt;
  final String? templateId;
  final String? gitPathPdf;
  final String? gitPathDocx;
  final int downloadCount;

  const GeneratedLetter({
    required this.id,
    required this.title,
    this.subject,
    this.recipient,
    required this.createdBy,
    required this.createdAt,
    this.templateId,
    this.gitPathPdf,
    this.gitPathDocx,
    this.downloadCount = 0,
  });

  factory GeneratedLetter.fromJson(Map<String, dynamic> j) => GeneratedLetter(
        id: j['id'] as String,
        title: j['title'] as String,
        subject: j['subject'] as String?,
        recipient: j['recipient'] as String?,
        createdBy: j['created_by'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        templateId: j['template_id'] as String?,
        gitPathPdf: j['git_path_pdf'] as String?,
        gitPathDocx: j['git_path_docx'] as String?,
        downloadCount: (j['download_count'] as int?) ?? 0,
      );

  bool get hasPdf => gitPathPdf != null && gitPathPdf!.isNotEmpty;
}
