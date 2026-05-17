part of '../snag_repository.dart';

class SnagItem {
  final String id;
  final String snagScope;
  final String category;
  final String? subcategory;
  final String location;
  final String? flatNumber;
  final String description;
  final String severity;
  final String status;
  final String? reportedBy;
  final DateTime reportedDate;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final String? builderRef;
  final DateTime? builderCommittedDate;
  final String? responsibleRole;

  const SnagItem({
    required this.id,
    required this.snagScope,
    required this.category,
    this.subcategory,
    required this.location,
    this.flatNumber,
    required this.description,
    required this.severity,
    required this.status,
    this.reportedBy,
    required this.reportedDate,
    this.verifiedAt,
    required this.createdAt,
    this.builderRef,
    this.builderCommittedDate,
    this.responsibleRole,
  });

  factory SnagItem.fromJson(Map<String, dynamic> j) => SnagItem(
        id: j['id'] as String,
        snagScope: j['snag_scope'] as String,
        category: j['category'] as String,
        subcategory: j['subcategory'] as String?,
        location: j['location'] as String,
        flatNumber: j['flat_number'] as String?,
        description: j['description'] as String,
        severity: j['severity'] as String,
        status: j['status'] as String,
        reportedBy: j['reported_by'] as String?,
        reportedDate: DateTime.parse(j['reported_date'] as String),
        verifiedAt: j['verified_at'] != null
            ? DateTime.parse(j['verified_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
        builderRef: j['builder_ref'] as String?,
        builderCommittedDate: j['builder_committed_date'] != null
            ? DateTime.parse(j['builder_committed_date'] as String)
            : null,
        responsibleRole: j['responsible_role'] as String?,
      );
}

class SnagComment {
  final String id;
  final String content;
  final String authorId;
  final String? authorName;
  final DateTime createdAt;

  const SnagComment({
    required this.id,
    required this.content,
    required this.authorId,
    this.authorName,
    required this.createdAt,
  });

  factory SnagComment.fromJson(Map<String, dynamic> j) {
    final profileMap = j['profiles'] as Map<String, dynamic>?;
    return SnagComment(
      id: j['id'] as String,
      content: j['content'] as String,
      authorId: j['author_id'] as String,
      authorName: profileMap?['full_name'] as String?,
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }
}

class LinkedHotoItem {
  final String hotoItemId;
  final String title;
  final String status;
  final String category;

  const LinkedHotoItem({
    required this.hotoItemId,
    required this.title,
    required this.status,
    required this.category,
  });

  factory LinkedHotoItem.fromJson(Map<String, dynamic> j) {
    final hotoMap = j['hoto_items'] as Map<String, dynamic>?;
    return LinkedHotoItem(
      hotoItemId: j['hoto_item_id'] as String,
      title: hotoMap?['title'] as String? ?? 'HOTO Item',
      status: hotoMap?['status'] as String? ?? 'unknown',
      category: hotoMap?['ascenza_category'] as String? ?? 'Uncategorised',
    );
  }
}
