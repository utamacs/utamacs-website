import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class ParkingSlot {
  final String id;
  final String slotNumber;
  final String slotType;
  final String vehicleType;
  final int? level;
  final double? monthlyCharge;
  final bool isOccupied;
  final String? occupiedByUnit;

  const ParkingSlot({
    required this.id,
    required this.slotNumber,
    required this.slotType,
    required this.vehicleType,
    this.level,
    this.monthlyCharge,
    required this.isOccupied,
    this.occupiedByUnit,
  });

  factory ParkingSlot.fromJson(Map<String, dynamic> j) {
    final allocations = j['parking_allocations'] as List?;
    final hasActive = allocations?.any((a) => a['status'] == 'active') ?? false;
    String? unit;
    if (hasActive) {
      final active = allocations!.firstWhere((a) => a['status'] == 'active');
      unit = active['units']?['unit_number'] as String?;
    }
    return ParkingSlot(
      id: j['id'] as String,
      slotNumber: j['slot_number'] as String,
      slotType: j['slot_type'] as String? ?? 'open',
      vehicleType: j['vehicle_type'] as String? ?? 'car',
      level: j['level'] as int?,
      monthlyCharge: j['monthly_charge'] != null
          ? (j['monthly_charge'] as num).toDouble()
          : null,
      isOccupied: hasActive,
      occupiedByUnit: unit,
    );
  }
}

class ParkingWaitlistEntry {
  final String id;
  final String slotType;
  final int position;
  final DateTime requestedAt;
  final String status;

  const ParkingWaitlistEntry({
    required this.id,
    required this.slotType,
    required this.position,
    required this.requestedAt,
    required this.status,
  });

  factory ParkingWaitlistEntry.fromJson(Map<String, dynamic> j) =>
      ParkingWaitlistEntry(
        id: j['id'] as String,
        slotType: j['slot_type'] as String? ?? 'open',
        position: j['position'] as int? ?? 0,
        requestedAt: DateTime.parse(j['created_at'] as String),
        status: j['status'] as String? ?? 'waiting',
      );
}

class ParkingAllocation {
  final String id;
  final String slotId;
  final String unitId;
  final String? vehicleNumber;
  final String? vehicleMake;
  final String status;
  final DateTime allocatedAt;
  final DateTime? expiresAt;

  // Joined from parking_slots
  final String? slotNumber;
  final String? slotType;
  final String? vehicleType;
  final int? level;
  final double? monthlyCharge;

  const ParkingAllocation({
    required this.id,
    required this.slotId,
    required this.unitId,
    this.vehicleNumber,
    this.vehicleMake,
    required this.status,
    required this.allocatedAt,
    this.expiresAt,
    this.slotNumber,
    this.slotType,
    this.vehicleType,
    this.level,
    this.monthlyCharge,
  });

  factory ParkingAllocation.fromJson(Map<String, dynamic> j) {
    final slotMap = j['parking_slots'] as Map<String, dynamic>?;
    return ParkingAllocation(
      id: j['id'] as String,
      slotId: j['slot_id'] as String,
      unitId: j['unit_id'] as String,
      vehicleNumber: j['vehicle_number'] as String?,
      vehicleMake: j['vehicle_make'] as String?,
      status: j['status'] as String,
      allocatedAt: DateTime.parse(j['allocated_at'] as String),
      expiresAt: j['expires_at'] != null
          ? DateTime.parse(j['expires_at'] as String)
          : null,
      slotNumber: slotMap?['slot_number'] as String?,
      slotType: slotMap?['slot_type'] as String?,
      vehicleType: slotMap?['vehicle_type'] as String?,
      level: slotMap?['level'] as int?,
      monthlyCharge: slotMap?['monthly_charge'] != null
          ? (slotMap!['monthly_charge'] as num).toDouble()
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class ParkingRepository {
  final _client = Supabase.instance.client;

  Future<ParkingAllocation?> fetchMyAllocation() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final data = await _client
        .from('parking_allocations')
        .select('*, parking_slots(slot_number, slot_type, vehicle_type, level, monthly_charge)')
        .eq('user_id', uid)
        .eq('society_id', env.societyId)
        .eq('status', 'active')
        .maybeSingle();
    if (data == null) return null;
    return ParkingAllocation.fromJson(data);
  }

  Future<List<ParkingSlot>> fetchAllSlots() async {
    final data = await _client
        .from('parking_slots')
        .select(
            '*, parking_allocations(status, units(unit_number))')
        .eq('society_id', env.societyId)
        .order('slot_number', ascending: true);
    return (data as List)
        .map((e) => ParkingSlot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ParkingWaitlistEntry>> fetchMyWaitlist() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('parking_waitlist')
        .select()
        .eq('user_id', uid)
        .eq('society_id', env.societyId)
        .eq('status', 'waiting')
        .order('created_at', ascending: true);
    return (data as List)
        .map((e) => ParkingWaitlistEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> joinWaitlist(String slotType) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    final profileRow = await _client
        .from('profiles')
        .select('unit_id')
        .eq('id', uid)
        .maybeSingle();
    final unitId = profileRow?['unit_id'] as String?;

    await _client.from('parking_waitlist').insert({
      'society_id': env.societyId,
      'user_id': uid,
      if (unitId != null) 'unit_id': unitId,
      'slot_type': slotType,
      'status': 'waiting',
    });
  }

  Future<void> withdrawFromWaitlist(String waitlistId) async {
    await _client
        .from('parking_waitlist')
        .update({'status': 'withdrawn'})
        .eq('id', waitlistId);
  }

  Future<void> requestTransfer({
    required String currentSlotId,
    required String reason,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await _client.from('parking_transfer_requests').insert({
      'society_id': env.societyId,
      'user_id': uid,
      'current_slot_id': currentSlotId,
      'reason': reason,
      'status': 'pending',
    });
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final parkingRepositoryProvider = Provider<ParkingRepository>(
  (ref) => ParkingRepository(),
);

final myParkingProvider =
    FutureProvider.autoDispose<ParkingAllocation?>((ref) =>
        ref.read(parkingRepositoryProvider).fetchMyAllocation());

final allParkingSlotsProvider =
    FutureProvider.autoDispose<List<ParkingSlot>>((ref) =>
        ref.read(parkingRepositoryProvider).fetchAllSlots());

final myWaitlistProvider =
    FutureProvider.autoDispose<List<ParkingWaitlistEntry>>((ref) =>
        ref.read(parkingRepositoryProvider).fetchMyWaitlist());
