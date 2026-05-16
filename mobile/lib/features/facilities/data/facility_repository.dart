import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class Facility {
  final String id;
  final String name;
  final String? description;
  final int? capacity;
  final List<String> amenities;
  final double? bookingFee;
  final double? depositAmount;
  final bool isActive;
  final int? advanceBookingDays;

  const Facility({
    required this.id,
    required this.name,
    this.description,
    this.capacity,
    required this.amenities,
    this.bookingFee,
    this.depositAmount,
    required this.isActive,
    this.advanceBookingDays,
  });

  factory Facility.fromJson(Map<String, dynamic> j) => Facility(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        capacity: j['capacity'] as int?,
        amenities: (j['amenities'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        bookingFee: (j['booking_fee'] as num?)?.toDouble(),
        depositAmount: (j['deposit_amount'] as num?)?.toDouble(),
        isActive: j['is_active'] as bool? ?? true,
        advanceBookingDays: j['advance_booking_days'] as int?,
      );
}

class FacilityBooking {
  final String id;
  final String facilityId;
  final String userId;
  final String unitId;
  final DateTime bookingDate;
  final DateTime startTime;
  final DateTime endTime;
  final int? attendeesCount;
  final String? purpose;
  final String status;
  final double? feeCharged;
  final double? depositPaid;
  final DateTime createdAt;

  const FacilityBooking({
    required this.id,
    required this.facilityId,
    required this.userId,
    required this.unitId,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    this.attendeesCount,
    this.purpose,
    required this.status,
    this.feeCharged,
    this.depositPaid,
    required this.createdAt,
  });

  /// Returns true when the booking has not started yet.
  bool get isUpcoming => startTime.isAfter(DateTime.now());

  /// Returns true when the booking has fully ended.
  bool get isPast => endTime.isBefore(DateTime.now());

  factory FacilityBooking.fromJson(Map<String, dynamic> j) => FacilityBooking(
        id: j['id'] as String,
        facilityId: j['facility_id'] as String,
        userId: j['user_id'] as String,
        unitId: j['unit_id'] as String,
        bookingDate: DateTime.parse(j['booking_date'] as String),
        startTime: DateTime.parse(j['start_time'] as String).toLocal(),
        endTime: DateTime.parse(j['end_time'] as String).toLocal(),
        attendeesCount: j['attendees_count'] as int?,
        purpose: j['purpose'] as String?,
        status: j['status'] as String,
        feeCharged: (j['fee_charged'] as num?)?.toDouble(),
        depositPaid: (j['deposit_paid'] as num?)?.toDouble(),
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );
}

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
          if (attendeesCount != null) 'attendees_count': attendeesCount,
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
