import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/profile.dart';
import '../../../core/constants/supabase.dart' as env;

part 'auth_repository.g.dart';

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) => AuthRepository();

class AuthRepository {
  final _client = Supabase.instance.client;

  Future<void> sendEmailOtp(String email) async {
    await _client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: false,
    );
  }

  Future<void> verifyEmailOtp(String email, String token) async {
    await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<Profile?> fetchProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    final data = await _client
        .from('profiles')
        .select('*, units(unit_number, block)')
        .eq('id', uid)
        .eq('society_id', env.societyId)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromJson(data);
  }

  Future<Profile?> updateProfile({
    String? fullName,
    String? bio,
    String? whatsappNumber,
    String? preferredLanguage,
    Map<String, dynamic>? emergencyContact,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) throw Exception('Not authenticated');

    final updates = <String, dynamic>{};
    if (fullName != null) {
      updates['full_name'] = fullName.trim().isEmpty ? null : fullName.trim();
    }
    if (bio != null) {
      updates['bio'] = bio.trim().isEmpty ? null : bio.trim();
    }
    if (whatsappNumber != null) {
      updates['whatsapp_number'] =
          whatsappNumber.trim().isEmpty ? null : whatsappNumber.trim();
    }
    if (preferredLanguage != null) {
      updates['preferred_language'] = preferredLanguage;
    }
    if (emergencyContact != null) {
      updates['emergency_contact'] = emergencyContact;
    }

    if (updates.isNotEmpty) {
      await _client.from('profiles').update(updates).eq('id', uid);
    }
    return fetchProfile();
  }
}
