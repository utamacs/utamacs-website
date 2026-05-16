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
