import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase.dart' as env;

part 'models/event_models.dart';

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
          'capacity': ?capacity,
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
