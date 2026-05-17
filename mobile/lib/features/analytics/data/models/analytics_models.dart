part of '../analytics_repository.dart';

class SocietyStats {
  final int totalMembers;
  final int openComplaints;
  final int activePasses;
  final int upcomingEvents;
  final int activePolls;
  final int pendingDues;

  const SocietyStats({
    required this.totalMembers,
    required this.openComplaints,
    required this.activePasses,
    required this.upcomingEvents,
    required this.activePolls,
    required this.pendingDues,
  });
}

class ComplaintBreakdown {
  final Map<String, int> countsByStatus;
  const ComplaintBreakdown({required this.countsByStatus});

  int get total => countsByStatus.values.fold(0, (a, b) => a + b);
}

class VisitorTypeBreakdown {
  final Map<String, int> countsByType;
  const VisitorTypeBreakdown({required this.countsByType});

  int get total => countsByType.values.fold(0, (a, b) => a + b);
}

class UnitOccupancyItem {
  final String unitNumber;
  final String occupancyStatus;

  const UnitOccupancyItem({
    required this.unitNumber,
    required this.occupancyStatus,
  });
}
