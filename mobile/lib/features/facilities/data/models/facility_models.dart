part of '../facility_repository.dart';

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
