import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/profile_repository.dart';

class ProfileData {
  const ProfileData({
    required this.fullName,
    required this.email,
    required this.username,
    required this.phone,
    required this.role,
  });

  final String fullName;
  final String email;
  final String username;
  final String phone;
  final String role;

  factory ProfileData.fromMap(Map<String, dynamic> map) {
    return ProfileData(
      fullName: (map['full_name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      username: (map['username'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      role: ((map['role'] as String?) ?? 'seeker').toLowerCase(),
    );
  }
}

class ProfileActionResult {
  const ProfileActionResult._({
    required this.success,
    this.errorMessage,
  });

  final bool success;
  final String? errorMessage;

  factory ProfileActionResult.success() {
    return const ProfileActionResult._(success: true);
  }

  factory ProfileActionResult.error(String message) {
    return ProfileActionResult._(success: false, errorMessage: message);
  }
}

class ProfileController {
  ProfileController({ProfileRepository? repository})
      : _repository = repository ?? ProfileRepository();

  final ProfileRepository _repository;

  Future<ProfileData?> loadProfile() async {
    final row = await _repository.fetchCurrentProfile();
    if (row == null) return null;
    return ProfileData.fromMap(row);
  }

  Future<ProfileActionResult> updateProfile({
    required String fullName,
    required String email,
    required String username,
    required String phone,
    required String password,
  }) async {
    if (fullName.trim().isEmpty ||
        email.trim().isEmpty ||
        username.trim().isEmpty ||
        phone.trim().isEmpty) {
      return ProfileActionResult.error('Please fill all required fields.');
    }

    try {
      await _repository.updateProfile(
        fullName: fullName,
        email: email,
        username: username,
        phone: phone,
      );

      if (password.trim().isNotEmpty) {
        if (password.trim().length < 6) {
          return ProfileActionResult.error(
            'Password should be at least 6 characters.',
          );
        }
        await _repository.updatePassword(password.trim());
      }

      return ProfileActionResult.success();
    } on AuthException catch (e) {
      return ProfileActionResult.error(e.message);
    } on PostgrestException catch (e) {
      return ProfileActionResult.error(
        e.message.isEmpty ? 'Failed to update profile.' : e.message,
      );
    } catch (_) {
      return ProfileActionResult.error('Unexpected error. Please try again.');
    }
  }

  Future<ProfileActionResult> signOut() async {
    try {
      await _repository.signOut();
      return ProfileActionResult.success();
    } on AuthException catch (e) {
      return ProfileActionResult.error(e.message);
    } catch (_) {
      return ProfileActionResult.error('Failed to logout. Please try again.');
    }
  }
}
