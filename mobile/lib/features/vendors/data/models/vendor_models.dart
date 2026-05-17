part of '../vendor_repository.dart';

class Vendor {
  final String id;
  final String name;
  final String category;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? gstin;
  final String? pan;
  final String? bankIfsc;
  final DateTime? contractEnd;
  final bool isActive;
  final DateTime createdAt;

  const Vendor({
    required this.id,
    required this.name,
    required this.category,
    this.contactPerson,
    this.phone,
    this.email,
    this.gstin,
    this.pan,
    this.bankIfsc,
    this.contractEnd,
    required this.isActive,
    required this.createdAt,
  });

  factory Vendor.fromJson(Map<String, dynamic> j) => Vendor(
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String,
        contactPerson: j['contact_person'] as String?,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        gstin: j['gstin'] as String?,
        pan: j['pan'] as String?,
        bankIfsc: j['bank_ifsc'] as String?,
        contractEnd: j['contract_end'] != null
            ? DateTime.tryParse(j['contract_end'] as String)
            : null,
        isActive: j['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class WorkOrder {
  final String id;
  final String vendorId;
  final String title;
  final String? description;
  final String status;
  final DateTime? issuedAt;
  final DateTime? deadline;
  final double? quotedAmount;
  final double? finalAmount;
  final DateTime createdAt;
  final int? vendorRating;
  final String? vendorReview;
  final String? complaintId;
  final String? snagId;

  const WorkOrder({
    required this.id,
    required this.vendorId,
    required this.title,
    this.description,
    required this.status,
    this.issuedAt,
    this.deadline,
    this.quotedAmount,
    this.finalAmount,
    required this.createdAt,
    this.vendorRating,
    this.vendorReview,
    this.complaintId,
    this.snagId,
  });

  bool get tdsFlag => (quotedAmount ?? 0) >= 30000;

  factory WorkOrder.fromJson(Map<String, dynamic> j) => WorkOrder(
        id: j['id'] as String,
        vendorId: j['vendor_id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        status: j['status'] as String,
        issuedAt: j['issued_at'] != null
            ? DateTime.parse(j['issued_at'] as String)
            : null,
        deadline: j['deadline'] != null
            ? DateTime.parse(j['deadline'] as String)
            : null,
        quotedAmount: j['quoted_amount'] != null
            ? (j['quoted_amount'] as num).toDouble()
            : null,
        finalAmount: j['final_amount'] != null
            ? (j['final_amount'] as num).toDouble()
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
        vendorRating: j['vendor_rating'] as int?,
        vendorReview: j['vendor_review'] as String?,
        complaintId: j['complaint_id'] as String?,
        snagId: j['snag_id'] as String?,
      );
}
