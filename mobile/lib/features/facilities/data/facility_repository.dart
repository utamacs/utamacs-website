import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/facility_models.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class FacilityRepository {
  final _client = Supabase.instance.client;

  /// Returns all active facilities for the society, sorted by name.
  Future<List<Facility>> fetchFacilities() async {
    final data = await _client
        .from('facilities')
        .select()
        .eq('society_id', env.societyId)
        .eq('is_active', true)
        .order('name', ascending: true);
    return (data as List).map((e) => Facility.fromJson(e)).toList();
  }

  /// Returns the current user's non-cancelled bookings, most recent first.
  Future<List<FacilityBooking>> fetchMyBookings() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('facility_bookings')
        .select()
        .eq('user_id', uid)
        .eq('society_id', env.societyId)
        .neq('status', 'cancelled')
        .order('start_time', ascending: false)
        .limit(20);
    return (data as List).map((e) => FacilityBooking.fromJson(e)).toList();
  }

  /// Creates a new booking and returns the inserted record.
  Future<FacilityBooking> createBooking({
    required String facilityId,
    required DateTime bookingDate,
    required DateTime startTime,
    required DateTime endTime,
    int? attendeesCount,
    String? purpose,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    // Resolve the unit_id for this user from their profile.
    final profileData = await _client
        .from('profiles')
        .select('unit_id')
        .eq('id', uid)
        .single();
    final unitId = profileData['unit_id'] as String?;
    if (unitId == null) throw Exception('Unit not found for user');

    final inserted = await _client
        .from('facility_bookings')
        .insert({
          'society_id': env.societyId,
          'facility_id': facilityId,
          'user_id': uid,
          'unit_id': unitId,
          'booking_date': bookingDate.toIso8601String().substring(0, 10),
          'start_time': startTime.toUtc().toIso8601String(),
          'end_time': endTime.toUtc().toIso8601String(),
          'attendees_count': ?attendeesCount,
          if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
          'status': 'pending',
        })
        .select()
        .single();
    return FacilityBooking.fromJson(inserted);
  }

  /// Marks a booking as cancelled (only the owner can cancel their own booking).
  Future<void> cancelBooking(String bookingId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await _client
        .from('facility_bookings')
        .update({
          'status': 'cancelled',
          'cancelled_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', bookingId)
        .eq('user_id', uid);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final facilityRepositoryProvider = Provider<FacilityRepository>(
  (ref) => FacilityRepository(),
);

final facilitiesProvider = FutureProvider.autoDispose<List<Facility>>((ref) {
  return ref.read(facilityRepositoryProvider).fetchFacilities();
});

final myFacilityBookingsProvider =
    FutureProvider.autoDispose<List<FacilityBooking>>((ref) {
  return ref.read(facilityRepositoryProvider).fetchMyBookings();
});
