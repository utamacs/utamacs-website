import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../../shared/models/profile.dart';
import '../data/auth_repository.dart';

part 'auth_notifier.g.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final Profile? profile;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.profile,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, Profile? profile, String? error}) =>
      AuthState(
        status: status ?? this.status,
        profile: profile ?? this.profile,
        error: error,
      );
}

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    _init();
    return const AuthState();
  }

  void _init() {
    final repo = ref.read(authRepositoryProvider);
    repo.authStateChanges.listen((event) async {
      if (event.session != null) {
        try {
          final profile = await repo.fetchProfile();
          state = AuthState(
            status: AuthStatus.authenticated,
            profile: profile,
          );
        } catch (_) {
          // Profile fetch failed after auth event — sign out to recover clean state
          await repo.signOut();
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });

    // Check current session on startup
    final user = repo.currentUser;
    if (user != null) {
      repo.fetchProfile().then((profile) {
        state = AuthState(
          status: AuthStatus.authenticated,
          profile: profile,
        );
      }).catchError((_) {
        // Token may have expired silently — clear state
        state = const AuthState(status: AuthStatus.unauthenticated);
      });
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> sendEmailOtp(String email) async {
    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.sendEmailOtp(email);
    } on AuthException catch (e) {
      // Supabase returns 429 when OTP rate limit is exceeded
      if (e.statusCode == '429') {
        throw Exception(
            'Too many requests — please wait a moment before requesting another code.');
      }
      rethrow;
    }
  }

  Future<void> verifyEmailOtp(String email, String token) async {
    final repo = ref.read(authRepositoryProvider);
    try {
      await repo.verifyEmailOtp(email, token);
    } on AuthException catch (e) {
      if (e.statusCode == '429') {
        throw Exception('Too many verification attempts — please wait and try again.');
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> updateProfile({
    String? fullName,
    String? bio,
    String? whatsappNumber,
    String? preferredLanguage,
    Map<String, dynamic>? emergencyContact,
  }) async {
    final updatedProfile = await ref.read(authRepositoryProvider).updateProfile(
          fullName: fullName,
          bio: bio,
          whatsappNumber: whatsappNumber,
          preferredLanguage: preferredLanguage,
          emergencyContact: emergencyContact,
        );
    if (updatedProfile != null) {
      state = state.copyWith(profile: updatedProfile);
    }
  }
}
