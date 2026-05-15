import 'package:riverpod_annotation/riverpod_annotation.dart';
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
        final profile = await repo.fetchProfile();
        state = AuthState(
          status: AuthStatus.authenticated,
          profile: profile,
        );
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
      });
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> sendOtp(String phone) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.signInWithOtp(phone);
  }

  Future<void> verifyOtp(String phone, String token) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.verifyOtp(phone, token);
  }

  Future<void> signOut() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
