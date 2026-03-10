import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client_provider.dart';

class AuthRepository {
  AuthRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> findUserByUsername(String username) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    return _client
        .from('user')
        .select('email, role')
        .ilike('username', normalized)
        .maybeSingle();
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  Future<void> upsertUser({
    required String userId,
    required String email,
    required String username,
    required String role,
    required String fullName,
    required String phone,
    required String idNumber,
  }) {
    return _client.from('user').upsert({
      'user_id': userId,
      'email': email.trim().toLowerCase(),
      'username': username.trim().toLowerCase(),
      'role': role,
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'id_number': idNumber.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<String?> getRoleByUserId(String userId) async {
    final user = await _client
        .from('user')
        .select('role')
        .eq('user_id', userId)
        .maybeSingle();

    return (user?['role'] as String?)?.toLowerCase();
  }
}
