import 'package:utamacs_portal/features/visitors/data/visitor_repository.dart'
    show VisitorPreApproval, VisitorLog, UnitItem;
import 'package:utamacs_portal/shared/models/profile.dart';

abstract interface class IVisitorRepository {
  Future<List<VisitorPreApproval>> fetchMyPreApprovals();

  Future<VisitorPreApproval> createPreApproval({
    required String visitorName,
    String? visitorPhone,
    String? vehicleNumber,
    String? purpose,
    required DateTime expectedDate,
    DateTime? expiresAt,
    String? notes,
  });

  Future<List<VisitorLog>> fetchRecentLogs({int limit});

  Future<List<VisitorLog>> fetchActiveVisitors({Profile? profile});

  Future<List<VisitorPreApproval>> fetchExpectedToday();

  Future<VisitorPreApproval?> verifyOtp(String otp);

  Future<void> admitByPassId(String passId, String gate, Profile profile);

  Future<void> logWalkIn({
    required String visitorName,
    required String visitorType,
    required String hostUnitId,
    required String gate,
    required Profile profile,
    String? vehicleNumber,
  });

  Future<void> logExit(String logId, Profile profile);

  Future<List<VisitorLog>> fetchAllLogs({
    Profile? profile,
    String? visitorType,
    String? gate,
    DateTime? dateFrom,
    DateTime? dateTo,
  });

  Future<List<UnitItem>> fetchUnits();

  Future<List<String>> fetchFrequentVisitors();
}
