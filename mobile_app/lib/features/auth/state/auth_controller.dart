import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/input_validators.dart';
import '../../notifications/state/notification_controller.dart';
import '../data/auth_repository.dart';

class AuthActionResult {
  const AuthActionResult._({
    required this.success,
    this.errorMessage,
    this.role,
    this.requiresEmailVerification = false,
  });

  final bool success;
  final String? errorMessage;
  final String? role;
  final bool requiresEmailVerification;

  factory AuthActionResult.success({String? role}) {
    return AuthActionResult._(success: true, role: role);
  }

  factory AuthActionResult.requiresVerification() {
    return const AuthActionResult._(
      success: true,
      requiresEmailVerification: true,
    );
  }

  factory AuthActionResult.error(String message) {
    return AuthActionResult._(success: false, errorMessage: message);
  }
}

class AuthController {
  AuthController({
    AuthRepository? repository,
    NotificationController? notificationController,
  })  : _repository = repository ?? AuthRepository(),
        _notificationController =
            notificationController ?? NotificationController();

  final AuthRepository _repository;
  final NotificationController _notificationController;

  Future<AuthActionResult> login({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.trim().isEmpty) {
      return AuthActionResult.error('Please enter username and password.');
    }

    try {
      final profile = await _repository.findUserByUsername(username);
      final email = (profile?['email'] as String?)?.trim();
      if (email == null || email.isEmpty) {
        return AuthActionResult.error('Username not found.');
      }

      final response = await _repository.signInWithEmail(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        return AuthActionResult.error('Login failed. Please try again.');
      }

      final roleFromProfile = (profile?['role'] as String?)?.toLowerCase();
      final roleFromDb = await _repository.getRoleByUserId(user.id);
      final roleFromMetadata =
          (user.userMetadata?['role'] as String?)?.toLowerCase();
      final role = roleFromDb ?? roleFromProfile ?? roleFromMetadata ?? 'seeker';

      if (role == 'seeker') {
        try {
          await _notificationController.runAiMatchingOnly();
        } catch (_) {
          // Ignore match trigger errors so login can still succeed.
        }
      }

      return AuthActionResult.success(role: role);
    } on AuthException catch (error) {
      return AuthActionResult.error(error.message);
    } on PostgrestException {
      return AuthActionResult.error(
        'User table is required for username login. Create user with username, email, role.',
      );
    } catch (_) {
      return AuthActionResult.error('Unexpected error. Please try again.');
    }
  }

  Future<AuthActionResult> register({
    required String fullName,
    required String email,
    required String username,
    required String password,
    required String phone,
    required String idNumber,
    required String role,
  }) async {
    if (fullName.trim().isEmpty ||
        email.trim().isEmpty ||
        username.trim().isEmpty ||
        password.trim().isEmpty ||
        phone.trim().isEmpty ||
        idNumber.trim().isEmpty) {
      return AuthActionResult.error('Please fill all fields.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedUsername = username.trim().toLowerCase();
    final emailError = InputValidators.validateEmail(normalizedEmail);
    if (emailError != null) {
      return AuthActionResult.error(emailError);
    }
    final passwordError = InputValidators.validateStrongPassword(password);
    if (passwordError != null) {
      return AuthActionResult.error(passwordError);
    }
    final phoneError = InputValidators.validateSudanPhoneNumber(phone);
    if (phoneError != null) {
      return AuthActionResult.error(phoneError);
    }
    final idNumberError = InputValidators.validateIdNumber(idNumber);
    if (idNumberError != null) {
      return AuthActionResult.error(idNumberError);
    }

    try {
      final existing = await _repository.findUserByUsername(normalizedUsername);
      if (existing != null) {
        return AuthActionResult.error('Username is already taken.');
      }

      final response = await _repository.signUp(
        email: normalizedEmail,
        password: password.trim(),
        data: {
          'full_name': fullName.trim(),
          'username': normalizedUsername,
          'phone': phone.trim(),
          'id_number': idNumber.trim(),
          'role': role,
        },
      );

      final user = response.user;
      if (user != null) {
        await _repository.upsertUser(
          userId: user.id,
          email: normalizedEmail,
          username: normalizedUsername,
          role: role,
          fullName: fullName,
          phone: phone,
          idNumber: idNumber,
        );
      }

      if (response.session == null) {
        return AuthActionResult.requiresVerification();
      }

      return AuthActionResult.success(role: role);
    } on AuthException catch (error) {
      return AuthActionResult.error(error.message);
    } on PostgrestException catch (error) {
      return AuthActionResult.error(
        error.message.isEmpty
            ? 'Failed saving profile. Ensure user table exists and RLS allows insert.'
            : error.message,
      );
    } catch (_) {
      return AuthActionResult.error('Unexpected error. Please try again.');
    }
  }

  Future<AuthActionResult> sendPasswordResetByUsername({
    required String username,
  }) async {
    final normalizedUsername = username.trim().toLowerCase();
    if (normalizedUsername.isEmpty) {
      return AuthActionResult.error('Please enter your username.');
    }

    try {
      final profile = await _repository.findUserByUsername(normalizedUsername);
      final email = (profile?['email'] as String?)?.trim().toLowerCase();
      if (email == null || email.isEmpty) {
        return AuthActionResult.error('Username not found.');
      }

      await _repository.sendPasswordResetEmail(email: email);
      return AuthActionResult.success();
    } on AuthException catch (error) {
      return AuthActionResult.error(error.message);
    } on PostgrestException {
      return AuthActionResult.error(
        'User table is required for username password reset.',
      );
    } catch (_) {
      return AuthActionResult.error(
        'Unexpected error while sending reset email.',
      );
    }
  }
}
