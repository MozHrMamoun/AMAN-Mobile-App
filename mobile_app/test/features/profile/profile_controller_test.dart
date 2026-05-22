import 'package:aman/features/profile/data/profile_repository.dart';
import 'package:aman/features/profile/state/profile_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ProfileController.updateProfile', () {
    test('rejects invalid email', () async {
      final controller = ProfileController(
        repository: FakeProfileRepository(),
      );

      final result = await controller.updateProfile(
        fullName: 'User Name',
        email: 'invalid-email',
        phone: '+249123456789',
        password: '',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Please enter a valid email address.');
    });

    test('rejects invalid Sudan phone number', () async {
      final controller = ProfileController(
        repository: FakeProfileRepository(),
      );

      final result = await controller.updateProfile(
        fullName: 'User Name',
        email: 'user@aman.com',
        phone: '0912345678',
        password: '',
      );

      expect(result.success, isFalse);
      expect(
        result.errorMessage,
        'Phone number must start with +249 and contain 9 digits after it.',
      );
    });

    test('rejects weak password when updating password', () async {
      final controller = ProfileController(
        repository: FakeProfileRepository(),
      );

      final result = await controller.updateProfile(
        fullName: 'User Name',
        email: 'user@aman.com',
        phone: '+249123456789',
        password: 'weakpass',
      );

      expect(result.success, isFalse);
      expect(
        result.errorMessage,
        'Password must be at least 8 characters and include uppercase, lowercase, number, and special character.',
      );
    });

    test('updates profile and password when values are valid', () async {
      final repository = FakeProfileRepository();
      final controller = ProfileController(repository: repository);

      final result = await controller.updateProfile(
        fullName: 'User Name',
        email: 'user@aman.com',
        phone: '+249123456789',
        password: 'Strong1!',
      );

      expect(result.success, isTrue);
      expect(repository.updatedProfile, isTrue);
      expect(repository.updatedPassword, 'Strong1!');
    });
  });
}

class FakeProfileRepository implements ProfileRepository {
  bool updatedProfile = false;
  String? updatedPassword;

  @override
  User? get currentUser => null;

  @override
  Future<Map<String, dynamic>?> fetchCurrentProfile() async {
    return null;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> updatePassword(String password) async {
    updatedPassword = password;
  }

  @override
  Future<void> updateProfile({
    required String fullName,
    required String email,
    required String phone,
  }) async {
    updatedProfile = true;
  }
}
