import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class Event {
  final String id;
  final String title;
  final String? description;
  final String? category;
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

// ---------------------------------------------------------------------------
// Attendee model (exec-only view)
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class EventRepository {
  final _client = Supabase.instance.client;

  Future<List<Event>> fetchEvents() async {
    final data = await _client
        .from('events')
        .select()
        .eq('society_id', env.societyId)
        .eq('is_published', true)
        .order('starts_at', ascending: true)
        .limit(30);
    return (data as List).map((e) => Event.fromJson(e)).toList();
  }

  Future<List<EventRegistration>> fetchMyRegistrations() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await _client
        .from('event_registrations')
        .select()
        .eq('user_id', uid);
    return (data as List)
        .map((e) => EventRegistration.fromJson(e))
        .toList();
  }

  Future<EventRegistration> register(
    String eventId, {
    int attendees = 1,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    final data = await _client
        .from('event_registrations')
        .insert({
          'event_id': eventId,
          'user_id': uid,
          'attendees_count': attendees,
          'status': 'registered',
        })
        .select()
        .single();
    return EventRegistration.fromJson(data);
  }

  Future<void> cancelRegistration(String registrationId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');
    await _client
        .from('event_registrations')
        .update({'status': 'cancelled'})
        .eq('id', registrationId)
        .eq('user_id', uid);
  }

  Future<List<EventAttendee>> fetchEventAttendees(String eventId) async {
    final data = await _client
        .from('event_registrations')
        .select('*, profiles:user_id(full_name)')
        .eq('event_id', eventId)
        .neq('status', 'cancelled')
        .order('registered_at', ascending: true);
    return (data as List).map((e) => EventAttendee.fromJson(e)).toList();
  }

  Future<Event> createEvent({
    required String title,
    required String category,
    required DateTime startsAt,
    DateTime? endsAt,
    String? location,
    String? description,
    int? capacity,
    DateTime? registrationDeadline,
    bool isPaid = false,
    double? ticketPrice,
  }) async {
    final data = await _client
        .from('events')
        .insert({
          'society_id': env.societyId,
          'title': title,
          'category': category,
          'starts_at': startsAt.toIso8601String(),
          if (endsAt != null) 'ends_at': endsAt.toIso8601String(),
          if (location != null && location.isNotEmpty) 'location': location,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (capacity != null) 'capacity': capacity,
          if (registrationDeadline != null)
            'registration_deadline':
                registrationDeadline.toIso8601String(),
          'is_paid': isPaid,
          if (isPaid && ticketPrice != null) 'ticket_price': ticketPrice,
          'is_published': true,
        })
        .select()
        .single();
    return Event.fromJson(data);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => EventRepository(),
);

final eventsProvider = FutureProvider.autoDispose<List<Event>>((ref) {
  return ref.read(eventRepositoryProvider).fetchEvents();
});

final myEventRegistrationsProvider =
    FutureProvider.autoDispose<List<EventRegistration>>((ref) {
  return ref.read(eventRepositoryProvider).fetchMyRegistrations();
});

final eventAttendeesProvider =
    FutureProvider.autoDispose.family<List<EventAttendee>, String>(
        (ref, eventId) =>
            ref.read(eventRepositoryProvider).fetchEventAttendees(eventId));
