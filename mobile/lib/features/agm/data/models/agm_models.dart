part of '../agm_repository.dart';

class AgmSession {
  final String id;
  final int agmYear;
  final String agmType;
  final DateTime meetingDate;
  final String? venue;
  final bool? quorumMet;
  final int? attendeesCount;
  final String status;
  final String? notes;
  final DateTime createdAt;

  const AgmSession({
    required this.id,
    required this.agmYear,
    required this.agmType,
    required this.meetingDate,
    this.venue,
    this.quorumMet,
    this.attendeesCount,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  bool get isUpcoming => meetingDate.isAfter(DateTime.now());

  String get typeLabel => switch (agmType) {
        'annual' => 'Annual General Meeting',
        'extraordinary' => 'Extraordinary General Meeting',
        'special' => 'Special General Meeting',
        _ => agmType
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) =>
                w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
            .join(' '),
      };

  factory AgmSession.fromJson(Map<String, dynamic> j) => AgmSession(
        id: j['id'] as String,
        agmYear: j['agm_year'] as int,
        agmType: j['agm_type'] as String? ?? 'annual',
        meetingDate: DateTime.parse(j['meeting_date'] as String),
        venue: j['venue'] as String?,
        quorumMet: j['quorum_met'] as bool?,
        attendeesCount: j['attendees_count'] as int?,
        status: j['status'] as String? ?? 'scheduled',
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class AgmDocument {
  final String id;
  final String? sessionId;
  final String documentType;
  final String title;
  final String? description;
  final String? fileName;
  final String status;
  final bool isPublic;
  final DateTime createdAt;

  const AgmDocument({
    required this.id,
    this.sessionId,
    required this.documentType,
    required this.title,
    this.description,
    this.fileName,
    required this.status,
    required this.isPublic,
    required this.createdAt,
  });

  String get typeLabel => switch (documentType) {
        'minutes' => 'Minutes',
        'financial_statement' => 'Financial Statement',
        'audit_report' => 'Audit Report',
        'resolution' => 'Resolution',
        'notice' => 'Notice / Agenda',
        'proxy_form' => 'Proxy Form',
        _ => 'Document',
      };

  factory AgmDocument.fromJson(Map<String, dynamic> j) => AgmDocument(
        id: j['id'] as String,
        sessionId: j['agm_session_id'] as String?,
        documentType: j['document_type'] as String? ?? 'other',
        title: j['title'] as String,
        description: j['description'] as String?,
        fileName: j['file_name'] as String?,
        status: j['status'] as String? ?? 'draft',
        isPublic: j['is_public'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class AgmResolution {
  final String id;
  final String sessionId;
  final String resolutionNo;
  final String title;
  final String? description;
  final String resolutionType;
  final String status;
  final int? votesFor;
  final int? votesAgainst;
  final int? votesAbstain;
  final DateTime? passedAt;

  const AgmResolution({
    required this.id,
    required this.sessionId,
    required this.resolutionNo,
    required this.title,
    this.description,
    required this.resolutionType,
    required this.status,
    this.votesFor,
    this.votesAgainst,
    this.votesAbstain,
    this.passedAt,
  });

  factory AgmResolution.fromJson(Map<String, dynamic> j) => AgmResolution(
        id: j['id'] as String,
        sessionId: j['agm_session_id'] as String,
        resolutionNo: j['resolution_no'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        resolutionType: j['resolution_type'] as String? ?? 'ordinary',
        status: j['status'] as String? ?? 'proposed',
        votesFor: j['votes_for'] as int?,
        votesAgainst: j['votes_against'] as int?,
        votesAbstain: j['votes_abstain'] as int?,
        passedAt: j['passed_at'] != null
            ? DateTime.parse(j['passed_at'] as String)
            : null,
      );
}
