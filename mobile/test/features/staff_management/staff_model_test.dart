import 'package:flutter_test/flutter_test.dart';
import 'package:utamacs_portal/features/staff_management/data/staff_repository.dart'
    show StaffMember, StaffTask, StaffAgency;

void main() {
  final _now = DateTime.now();

  // ─── StaffMember helpers ──────────────────────────────────────────────────────
  Map<String, dynamic> _memberJson({
    bool securityPassIssued = false,
    String? securityPassExpiresAt,
    String kycStatus = 'approved',
  }) =>
      {
        'id': 'sm-1',
        'name': 'Raju',
        'role': 'security_guard',
        'is_active': true,
        'kyc_status': kycStatus,
        'security_pass_issued': securityPassIssued,
        if (securityPassExpiresAt != null)
          'security_pass_expires_at': securityPassExpiresAt,
        'created_at': _now.toIso8601String(),
      };

  // ─── StaffMember.fromJson ─────────────────────────────────────────────────────
  group('StaffMember.fromJson', () {
    test('parses required fields', () {
      final m = StaffMember.fromJson(_memberJson());
      expect(m.id, 'sm-1');
      expect(m.name, 'Raju');
      expect(m.role, 'security_guard');
      expect(m.isActive, isTrue);
      expect(m.kycStatus, 'approved');
    });

    test('kycStatus defaults to pending when absent', () {
      final j = _memberJson()..remove('kyc_status');
      expect(StaffMember.fromJson(j).kycStatus, 'pending');
    });

    test('securityPassIssued defaults to false when absent', () {
      final j = _memberJson()..remove('security_pass_issued');
      expect(StaffMember.fromJson(j).securityPassIssued, isFalse);
    });

    test('parses securityPassExpiresAt when present', () {
      final future = _now.add(const Duration(days: 365));
      final m = StaffMember.fromJson(
          _memberJson(securityPassIssued: true, securityPassExpiresAt: future.toIso8601String()));
      expect(m.securityPassExpiresAt, isNotNull);
      expect(m.securityPassExpiresAt!.isAfter(_now), isTrue);
    });

    test('securityPassExpiresAt is null when absent', () {
      expect(StaffMember.fromJson(_memberJson()).securityPassExpiresAt, isNull);
    });
  });

  // ─── StaffMember.hasValidPass ─────────────────────────────────────────────────
  group('StaffMember.hasValidPass', () {
    test('false when pass not issued', () {
      final m = StaffMember.fromJson(_memberJson(securityPassIssued: false));
      expect(m.hasValidPass, isFalse);
    });

    test('true when pass issued with no expiry', () {
      final m = StaffMember.fromJson(_memberJson(securityPassIssued: true));
      expect(m.hasValidPass, isTrue);
    });

    test('true when pass issued with future expiry', () {
      final future = _now.add(const Duration(days: 30));
      final m = StaffMember.fromJson(_memberJson(
        securityPassIssued: true,
        securityPassExpiresAt: future.toIso8601String(),
      ));
      expect(m.hasValidPass, isTrue);
    });

    test('false when pass issued but already expired', () {
      final past = _now.subtract(const Duration(days: 1));
      final m = StaffMember.fromJson(_memberJson(
        securityPassIssued: true,
        securityPassExpiresAt: past.toIso8601String(),
      ));
      expect(m.hasValidPass, isFalse);
    });
  });

  // ─── StaffTask helpers ────────────────────────────────────────────────────────
  Map<String, dynamic> _taskJson({
    String status = 'open',
    DateTime? dueDate,
  }) =>
      {
        'id': 'task-1',
        'assigned_to': 'sm-1',
        'title': 'Clean lobby',
        'due_date': (dueDate ?? _now.add(const Duration(days: 1))).toIso8601String(),
        'status': status,
        'priority': 'medium',
        'created_at': _now.toIso8601String(),
      };

  // ─── StaffTask.fromJson ───────────────────────────────────────────────────────
  group('StaffTask.fromJson', () {
    test('parses required fields', () {
      final t = StaffTask.fromJson(_taskJson());
      expect(t.id, 'task-1');
      expect(t.assignedTo, 'sm-1');
      expect(t.title, 'Clean lobby');
      expect(t.status, 'open');
      expect(t.priority, 'medium');
    });

    test('completedAt is null when absent', () {
      expect(StaffTask.fromJson(_taskJson()).completedAt, isNull);
    });

    test('parses completedAt when present', () {
      final j = _taskJson(status: 'completed')
        ..['completed_at'] = _now.toIso8601String();
      expect(StaffTask.fromJson(j).completedAt, isNotNull);
    });
  });

  // ─── StaffTask.isOverdue ──────────────────────────────────────────────────────
  group('StaffTask.isOverdue', () {
    test('false when due in the future', () {
      final t = StaffTask.fromJson(
          _taskJson(dueDate: _now.add(const Duration(hours: 1))));
      expect(t.isOverdue, isFalse);
    });

    test('true when past due and status is open', () {
      final t = StaffTask.fromJson(
          _taskJson(status: 'open', dueDate: _now.subtract(const Duration(hours: 1))));
      expect(t.isOverdue, isTrue);
    });

    test('false when past due but status is completed', () {
      final t = StaffTask.fromJson(
          _taskJson(status: 'completed', dueDate: _now.subtract(const Duration(days: 5))));
      expect(t.isOverdue, isFalse);
    });

    test('true for in_progress past due', () {
      final t = StaffTask.fromJson(
          _taskJson(status: 'in_progress', dueDate: _now.subtract(const Duration(hours: 2))));
      expect(t.isOverdue, isTrue);
    });
  });

  // ─── StaffAgency.contractExpiringSoon ─────────────────────────────────────────
  group('StaffAgency.hasComplianceWarning', () {
    Map<String, dynamic> agencyJson({
      String? contractEnd,
      String? psaraExpiry,
    }) =>
        {
          'id': 'ag-1',
          'name': 'SecurePro',
          'type': 'security',
          'is_active': true,
          if (contractEnd != null) 'contract_end': contractEnd,
          if (psaraExpiry != null) 'psara_expiry': psaraExpiry,
          'created_at': _now.toIso8601String(),
        };

    test('no warning when no contract/psara dates', () {
      final a = StaffAgency.fromJson(agencyJson());
      expect(a.hasComplianceWarning, isFalse);
    });

    test('warning when contract ends in 15 days', () {
      final soon = _now.add(const Duration(days: 15)).toIso8601String();
      final a = StaffAgency.fromJson(agencyJson(contractEnd: soon));
      expect(a.contractExpiringSoon, isTrue);
      expect(a.hasComplianceWarning, isTrue);
    });

    test('no warning when contract ends in 60 days', () {
      final far = _now.add(const Duration(days: 60)).toIso8601String();
      final a = StaffAgency.fromJson(agencyJson(contractEnd: far));
      expect(a.contractExpiringSoon, isFalse);
    });

    test('warning when psara expires in 10 days', () {
      final soon = _now.add(const Duration(days: 10)).toIso8601String();
      final a = StaffAgency.fromJson(agencyJson(psaraExpiry: soon));
      expect(a.psaraExpiringSoon, isTrue);
      expect(a.hasComplianceWarning, isTrue);
    });
  });
}
