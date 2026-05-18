import 'package:flutter_test/flutter_test.dart';
import 'package:utamacs_portal/features/complaints/data/complaint_repository.dart'
    show Complaint;

void main() {
  final _now = DateTime.now();

  Map<String, dynamic> _minJson({
    String status = 'open',
    String? slaDeadline,
    String? resolvedAt,
    int reopenCount = 0,
  }) =>
      {
        'id': 'c1',
        'ticket_number': 'TKT-001',
        'title': 'Water leak',
        'category': 'maintenance',
        'priority': 'high',
        'status': status,
        'raised_by': 'uid-1',
        'created_at': _now.toIso8601String(),
        'updated_at': _now.toIso8601String(),
        if (slaDeadline != null) 'sla_deadline': slaDeadline,
        if (resolvedAt != null) 'resolved_at': resolvedAt,
        'reopen_count': reopenCount,
      };

  group('Complaint.fromJson', () {
    test('parses required fields', () {
      final c = Complaint.fromJson(_minJson());
      expect(c.id, 'c1');
      expect(c.ticketNumber, 'TKT-001');
      expect(c.title, 'Water leak');
      expect(c.status, 'open');
      expect(c.priority, 'high');
    });

    test('parses optional sla_deadline', () {
      final deadline = _now.add(const Duration(days: 3));
      final c = Complaint.fromJson(
          _minJson(slaDeadline: deadline.toIso8601String()));
      expect(c.slaDeadline, isNotNull);
      expect(c.slaDeadline!.isAfter(_now), isTrue);
    });

    test('parses optional resolved_at', () {
      final resolved = _now.subtract(const Duration(hours: 2));
      final c = Complaint.fromJson(
          _minJson(resolvedAt: resolved.toIso8601String()));
      expect(c.resolvedAt, isNotNull);
      expect(c.resolvedAt!.isBefore(_now), isTrue);
    });

    test('slaDeadline null when absent', () {
      final c = Complaint.fromJson(_minJson());
      expect(c.slaDeadline, isNull);
    });

    test('reopenCount defaults to 0', () {
      final j = _minJson()..remove('reopen_count');
      final c = Complaint.fromJson(j);
      expect(c.reopenCount, 0);
    });

    test('parses non-zero reopenCount', () {
      final c = Complaint.fromJson(_minJson(reopenCount: 2));
      expect(c.reopenCount, 2);
    });
  });
}
