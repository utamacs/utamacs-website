import 'package:utamacs_portal/features/complaints/data/complaint_repository.dart'
    show Complaint, ComplaintHistory, ComplaintAttachment;
import 'package:utamacs_portal/shared/models/profile.dart';

abstract interface class IComplaintRepository {
  Future<List<Complaint>> fetchMyComplaints({
    String? statusFilter,
    int limit,
    String? after,
  });

  Future<Complaint> submitComplaint({
    required String title,
    required String description,
    required String category,
    required String priority,
    String? unitId,
  });

  Future<void> updateComplaintStatus({
    required String complaintId,
    required String status,
    required Profile profile,
    String? note,
  });

  Future<List<Complaint>> fetchAllComplaints({
    String? statusFilter,
    required Profile profile,
  });

  Future<List<ComplaintHistory>> fetchCommentHistory(String complaintId);

  Future<void> submitFeedback({
    required String complaintId,
    required int rating,
    String? comment,
  });

  Future<List<ComplaintAttachment>> fetchAttachments(String complaintId);

  Future<String?> getAttachmentSignedUrl(String storageKey);

  Future<void> reopenComplaint(String complaintId);
}
