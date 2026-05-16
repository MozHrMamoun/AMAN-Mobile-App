import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client_provider.dart';

class ProfileRepository {
  ProfileRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Future<Map<String, dynamic>?> fetchCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    return _client
        .from('user')
        .select('full_name, email, username, phone, role')
        .eq('user_id', user.id)
        .maybeSingle();
  }

  Future<void> updateProfile({
    required String fullName,
    required String email,
    required String username,
    required String phone,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException('You are not logged in.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedUsername = username.trim().toLowerCase();

    await _client.auth.updateUser(
      UserAttributes(email: normalizedEmail),
    );

    await _client.from('user').update({
      'full_name': fullName.trim(),
      'email': normalizedEmail,
      'username': normalizedUsername,
      'phone': phone.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', user.id);
  }

  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(
      UserAttributes(password: password),
    );
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }
}
