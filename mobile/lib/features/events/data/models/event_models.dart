part of '../event_repository.dart';

class Event {
  final String id;
  final String title;
  final String? description;
  final String? category;
  final String? bannerKey;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? location;
  final int? capacity;
  final bool isPaid;
  final double? ticketPrice;
  final bool isPublished;
  final DateTime createdAt;

  const Event({
    required this.id,
    required this.title,
    this.description,
    this.category,
    this.bannerKey,
    required this.startsAt,
    this.endsAt,
    this.location,
    this.capacity,
    required this.isPaid,
    this.ticketPrice,
    required this.isPublished,
    required this.createdAt,
  });

  bool get isPast => startsAt.isBefore(DateTime.now());
  bool get isUpcoming => !isPast;

  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        category: j['category'] as String?,
        bannerKey: j['banner_key'] as String?,
        startsAt: DateTime.parse(j['starts_at'] as String),
        endsAt: j['ends_at'] != null
            ? DateTime.parse(j['ends_at'] as String)
            : null,
        location: j['location'] as String?,
        capacity: j['capacity'] as int?,
        isPaid: j['is_paid'] as bool? ?? false,
        ticketPrice: j['ticket_price'] != null
            ? (j['ticket_price'] as num).toDouble()
            : null,
        isPublished: j['is_published'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class EventRegistration {
  final String id;
  final String eventId;
  final String userId;
  final int attendeesCount;
  final String status;
  final DateTime? checkedInAt;
  final DateTime registeredAt;

  const EventRegistration({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.attendeesCount,
    required this.status,
    this.checkedInAt,
    required this.registeredAt,
  });

  bool get isActive =>
      status == 'registered' || status == 'waitlisted' || status == 'attended';

  factory EventRegistration.fromJson(Map<String, dynamic> j) =>
      EventRegistration(
        id: j['id'] as String,
        eventId: j['event_id'] as String,
        userId: j['user_id'] as String,
        attendeesCount: j['attendees_count'] as int? ?? 1,
        status: j['status'] as String,
        checkedInAt: j['checked_in_at'] != null
            ? DateTime.parse(j['checked_in_at'] as String)
            : null,
        registeredAt: DateTime.parse(j['registered_at'] as String),
      );
}

class EventAttendee {
  final String id;
  final String userId;
  final String? fullName;
  final int attendeesCount;
  final String status;
  final DateTime? checkedInAt;
  final DateTime registeredAt;

  const EventAttendee({
    required this.id,
    required this.userId,
    this.fullName,
    required this.attendeesCount,
    required this.status,
    this.checkedInAt,
    required this.registeredAt,
  });

  factory EventAttendee.fromJson(Map<String, dynamic> j) {
    final profileMap = j['profiles'] as Map<String, dynamic>?;
    return EventAttendee(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      fullName: profileMap?['full_name'] as String?,
      attendeesCount: j['attendees_count'] as int? ?? 1,
      status: j['status'] as String,
      checkedInAt: j['checked_in_at'] != null
          ? DateTime.parse(j['checked_in_at'] as String)
          : null,
      registeredAt: DateTime.parse(j['registered_at'] as String),
    );
  }
}
