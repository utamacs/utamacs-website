part of '../letter_repository.dart';

class GeneratedLetter {
  final String id;
  final String title;
  final String? subject;
  final String? recipient;
  final String createdBy;
  final DateTime createdAt;
  final String? referenceNumber;
  final String? letterType;
  final String? status;
  final DateTime? letterDate;

  const GeneratedLetter({
    required this.id,
    required this.title,
    this.subject,
    this.recipient,
    required this.createdBy,
    required this.createdAt,
    this.referenceNumber,
    this.letterType,
    this.status,
    this.letterDate,
  });

  factory GeneratedLetter.fromJson(Map<String, dynamic> j) => GeneratedLetter(
        id: j['id'] as String,
        title: j['title'] as String,
        subject: j['subject'] as String?,
        recipient: j['recipient'] as String?,
        createdBy: j['created_by'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        referenceNumber: j['reference_number'] as String?,
        letterType: j['letter_type'] as String?,
        status: j['status'] as String?,
        letterDate: j['letter_date'] != null
            ? DateTime.tryParse(j['letter_date'] as String)
            : null,
      );
}
