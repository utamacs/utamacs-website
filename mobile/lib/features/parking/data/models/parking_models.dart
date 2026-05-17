part of '../parking_repository.dart';

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
