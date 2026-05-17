import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

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
// Parking slot with occupancy (exec view)
// ---------------------------------------------------------------------------

class ParkingSlotWithOccupancy {
  final String id;
  final String slotNumber;
  final String slotType;
  final String vehicleType;
  final int? level;
  final double? monthlyCharge;
  final bool isOccupied;
  final String? vehicleNumber;
  final String? activeAllocationId;

  const ParkingSlotWithOccupancy({
    required this.id,
    required this.slotNumber,
    required this.slotType,
    required this.vehicleType,
    this.level,
    this.monthlyCharge,
    required this.isOccupied,
    this.vehicleNumber,
    this.activeAllocationId,
  });

  factory ParkingSlotWithOccupancy.fromJson(Map<String, dynamic> j) {
    final allocations =
        (j['parking_allocations'] as List? ?? []).cast<Map<String, dynamic>>();
    final active = allocations.where((a) => a['status'] == 'active');
    final Map<String, dynamic>? activeAlloc =
        active.isEmpty ? null : active.first;
    return ParkingSlotWithOccupancy(
      id: j['id'] as String,
      slotNumber: j['slot_number'] as String,
      slotType: j['slot_type'] as String? ?? 'covered',
      vehicleType: j['vehicle_type'] as String? ?? 'car',
      level: j['level'] as int?,
      monthlyCharge: j['monthly_charge'] != null
          ? (j['monthly_charge'] as num).toDouble()
          : null,
      isOccupied: activeAlloc != null,
      vehicleNumber: activeAlloc?['vehicle_number'] as String?,
      activeAllocationId: activeAlloc?['id'] as String?,
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

  Future<List<ParkingAllocation>> fetchMyAllocationHistory() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('parking_allocations')
        .select(
            '*, parking_slots(slot_number, slot_type, vehicle_type, level, monthly_charge)')
        .eq('user_id', uid)
        .eq('society_id', env.societyId)
        .inFilter('status', ['released', 'suspended'])
        .order('created_at', ascending: false)
        .limit(10);
    return (data as List).map((e) => ParkingAllocation.fromJson(e)).toList();
  }

  Future<List<ParkingSlotWithOccupancy>> fetchAllSlots() async {
    final data = await _client
        .from('parking_slots')
        .select('*, parking_allocations(id, unit_id, status, vehicle_number)')
        .eq('society_id', env.societyId)
        .eq('is_active', true)
        .order('level', ascending: true, nullsFirst: true)
        .order('slot_number', ascending: true);
    return (data as List)
        .map((e) => ParkingSlotWithOccupancy.fromJson(e))
        .toList();
  }

  Future<String?> fetchUnitIdByNumber(String unitNumber) async {
    final data = await _client
        .from('units')
        .select('id')
        .eq('society_id', env.societyId)
        .eq('unit_number', unitNumber.trim().toUpperCase())
        .maybeSingle();
    return data?['id'] as String?;
  }

  Future<ParkingAllocation> allocateSlot({
    required String slotId,
    required String unitId,
    String? vehicleNumber,
    String? vehicleMake,
  }) async {
    final data = await _client
        .from('parking_allocations')
        .insert({
          'society_id': env.societyId,
          'slot_id': slotId,
          'unit_id': unitId,
          if (vehicleNumber != null && vehicleNumber.trim().isNotEmpty)
            'vehicle_number': vehicleNumber.trim(),
          if (vehicleMake != null && vehicleMake.trim().isNotEmpty)
            'vehicle_make': vehicleMake.trim(),
          'status': 'active',
          'allocated_at': DateTime.now().toIso8601String(),
        })
        .select(
            '*, parking_slots(slot_number, slot_type, vehicle_type, level, monthly_charge)')
        .single();
    return ParkingAllocation.fromJson(data);
  }

  Future<void> releaseAllocation(String allocationId) async {
    await _client
        .from('parking_allocations')
        .update({'status': 'released'})
        .eq('id', allocationId)
        .eq('society_id', env.societyId);
  }

  Future<ParkingSlotWithOccupancy> createSlot({
    required String slotNumber,
    required String slotType,
    required String vehicleType,
    int? level,
    double? monthlyCharge,
  }) async {
    final data = await _client
        .from('parking_slots')
        .insert({
          'society_id': env.societyId,
          'slot_number': slotNumber.trim().toUpperCase(),
          'slot_type': slotType,
          'vehicle_type': vehicleType,
          if (level != null) 'level': level,
          if (monthlyCharge != null) 'monthly_charge': monthlyCharge,
          'is_active': true,
        })
        .select()
        .single();
    return ParkingSlotWithOccupancy.fromJson(
        {...data, 'parking_allocations': []});
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

final myParkingHistoryProvider =
    FutureProvider.autoDispose<List<ParkingAllocation>>((ref) =>
        ref.read(parkingRepositoryProvider).fetchMyAllocationHistory());

final allSlotsProvider =
    FutureProvider.autoDispose<List<ParkingSlotWithOccupancy>>((ref) =>
        ref.read(parkingRepositoryProvider).fetchAllSlots());
