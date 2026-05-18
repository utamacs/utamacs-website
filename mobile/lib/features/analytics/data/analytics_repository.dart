import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/analytics_models.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class AnalyticsRepository {
  final _client = Supabase.instance.client;

  Future<SocietyStats> fetchStats() async {
    final sid = env.societyId;
    final now = DateTime.now().toUtc().toIso8601String();

    // 1. Total members — profiles linked to this society
    final membersResult = await _client
        .from('profiles')
        .select()
        .eq('society_id', sid)
        .count(CountOption.exact);
    final totalMembers = membersResult.count;

    // 2. Open complaints
    final complaintsResult = await _client
        .from('complaints')
        .select()
        .eq('society_id', sid)
        .inFilter('status', ['open', 'under_review'])
        .count(CountOption.exact);
    final openComplaints = complaintsResult.count;

    // 3. Active visitor pre-approvals (approved/pending and not expired)
    final passesResult = await _client
        .from('visitor_pre_approvals')
        .select()
        .eq('society_id', sid)
        .inFilter('status', ['approved', 'pending'])
        .or('expires_at.is.null,expires_at.gt.$now')
        .count(CountOption.exact);
    final activePasses = passesResult.count;

    // 4. Upcoming published events
    final eventsResult = await _client
        .from('events')
        .select()
        .eq('society_id', sid)
        .eq('is_published', true)
        .gt('starts_at', now)
        .count(CountOption.exact);
    final upcomingEvents = eventsResult.count;

    // 5. Active polls
    final pollsResult = await _client
        .from('polls')
        .select()
        .eq('society_id', sid)
        .eq('is_published', true)
        .or('ends_at.is.null,ends_at.gt.$now')
        .count(CountOption.exact);
    final activePolls = pollsResult.count;

    // 6. Pending dues
    final duesResult = await _client
        .from('maintenance_dues')
        .select()
        .eq('society_id', sid)
        .inFilter('status', ['pending', 'overdue'])
        .count(CountOption.exact);
    final pendingDues = duesResult.count;

    return SocietyStats(
      totalMembers: totalMembers,
      openComplaints: openComplaints,
      activePasses: activePasses,
      upcomingEvents: upcomingEvents,
      activePolls: activePolls,
      pendingDues: pendingDues,
    );
  }

  Future<ComplaintBreakdown> fetchComplaintBreakdown() async {
    final data = await _client
        .from('complaints')
        .select('status')
        .eq('society_id', env.societyId);

    final counts = <String, int>{};
    for (final row in (data as List)) {
      final s = row['status'] as String;
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return ComplaintBreakdown(countsByStatus: counts);
  }

  Future<VisitorTypeBreakdown> fetchVisitorTypeBreakdown() async {
    final data = await _client
        .from('visitor_logs')
        .select('visitor_type')
        .eq('society_id', env.societyId);

    final counts = <String, int>{};
    for (final row in (data as List)) {
      final t = (row['visitor_type'] as String?) ?? 'unknown';
      counts[t] = (counts[t] ?? 0) + 1;
    }
    return VisitorTypeBreakdown(countsByType: counts);
  }

  Future<List<UnitOccupancyItem>> fetchUnitOccupancy() async {
    final data = await _client
        .from('units')
        .select('unit_number, occupancy_status')
        .eq('society_id', env.societyId)
        .order('unit_number', ascending: true)
        .limit(200);
    return compute(_parseUnitOccupancy, data as List);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepository(),
);

final societyStatsProvider =
    FutureProvider.autoDispose<SocietyStats>((ref) {
  return ref.read(analyticsRepositoryProvider).fetchStats();
});

final complaintBreakdownProvider =
    FutureProvider.autoDispose<ComplaintBreakdown>((ref) {
  return ref.read(analyticsRepositoryProvider).fetchComplaintBreakdown();
});

final visitorTypeBreakdownProvider =
    FutureProvider.autoDispose<VisitorTypeBreakdown>((ref) {
  return ref.read(analyticsRepositoryProvider).fetchVisitorTypeBreakdown();
});

final unitOccupancyProvider =
    FutureProvider.autoDispose<List<UnitOccupancyItem>>((ref) {
  return ref.read(analyticsRepositoryProvider).fetchUnitOccupancy();
});

// ---------------------------------------------------------------------------
// Isolate parse helpers — must be top-level for compute()
// ---------------------------------------------------------------------------

List<UnitOccupancyItem> _parseUnitOccupancy(List<dynamic> json) =>
    json
        .map((r) => UnitOccupancyItem(
              unitNumber: r['unit_number'] as String,
              occupancyStatus:
                  (r['occupancy_status'] as String?) ?? 'vacant',
            ))
        .toList();
