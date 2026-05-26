import 'package:aman/features/auth/data/auth_repository.dart';
import 'package:aman/features/auth/state/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AuthController.login', () {
    test('returns validation error when username or password is empty', () async {
      final controller = AuthController(repository: FakeAuthRepository());

      final result = await controller.login(username: ' ', password: '');

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Please enter username and password.');
    });

    test('returns username not found when repository has no profile', () async {
      final controller = AuthController(
        repository: FakeAuthRepository(findUserResult: null),
      );

      final result = await controller.login(
        username: 'missing-user',
        password: 'secret123',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Username not found.');
    });

    test('uses role from user table before profile or metadata', () async {
      final user = _testUser(
        id: 'user-1',
        email: 'owner@aman.com',
        metadataRole: 'owner',
      );
      final repository = FakeAuthRepository(
        findUserResult: {
          'email': 'owner@aman.com',
          'role': 'seeker',
        },
        signInResult: AuthResponse(user: user),
        roleByUserIdResult: 'admin',
      );
      final controller = AuthController(repository: repository);

      final result = await controller.login(
        username: 'owner',
        password: 'secret123',
      );

      expect(result.success, isTrue);
      expect(result.role, 'admin');
      expect(repository.lastSignInEmail, 'owner@aman.com');
      expect(repository.lastSignInPassword, 'secret123');
    });

    test('returns auth exception message from repository', () async {
      final controller = AuthController(
        repository: FakeAuthRepository(
          findUserResult: {
            'email': 'user@aman.com',
            'role': 'seeker',
          },
          signInException: const AuthException('Invalid login credentials'),
        ),
      );

      final result = await controller.login(
        username: 'user',
        password: 'wrong-password',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Invalid login credentials');
    });
  });

  group('AuthController.register', () {
    test('rejects incomplete form data', () async {
      final controller = AuthController(repository: FakeAuthRepository());

      final result = await controller.register(
        fullName: '',
        email: 'admin@aman.com',
        username: 'admin',
        password: 'secret123',
        phone: '000',
        idNumber: 'ID-1',
        role: 'owner',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Please fill all fields.');
    });

    test('rejects invalid email during registration', () async {
      final controller = AuthController(repository: FakeAuthRepository());

      final result = await controller.register(
        fullName: 'Admin User',
        email: 'not-an-email',
        username: 'admin',
        password: 'Strong1!',
        phone: '+249123456789',
        idNumber: '12345678901',
        role: 'owner',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Please enter a valid email address.');
    });

    test('rejects weak password during registration', () async {
      final controller = AuthController(repository: FakeAuthRepository());

      final result = await controller.register(
        fullName: 'Admin User',
        email: 'admin@aman.com',
        username: 'admin',
        password: 'weakpass',
        phone: '+249123456789',
        idNumber: '12345678901',
        role: 'owner',
      );

      expect(result.success, isFalse);
      expect(
        result.errorMessage,
        'Password must be at least 8 characters and include uppercase, lowercase, number, and special character.',
      );
    });

    test('rejects invalid Sudan phone number during registration', () async {
      final controller = AuthController(repository: FakeAuthRepository());

      final result = await controller.register(
        fullName: 'Admin User',
        email: 'admin@aman.com',
        username: 'admin',
        password: 'Strong1!',
        phone: '0912345678',
        idNumber: '12345678901',
        role: 'owner',
      );

      expect(result.success, isFalse);
      expect(
        result.errorMessage,
        'Phone number must start with +249 and contain 9 digits after it.',
      );
    });

    test('rejects invalid id number during registration', () async {
      final controller = AuthController(repository: FakeAuthRepository());

      final result = await controller.register(
        fullName: 'Admin User',
        email: 'admin@aman.com',
        username: 'admin',
        password: 'Strong1!',
        phone: '+249123456789',
        idNumber: '12345',
        role: 'owner',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'ID number must be exactly 11 digits.');
    });

    test('returns verification required when session is null', () async {
      final user = _testUser(id: 'user-2', email: 'new@aman.com');
      final repository = FakeAuthRepository(
        findUserResult: null,
        signUpResult: AuthResponse(user: user),
      );
      final controller = AuthController(repository: repository);

      final result = await controller.register(
        fullName: 'New User',
        email: 'NEW@aman.com',
        username: 'NewUser',
        password: 'Secret1!',
        phone: '+249123456789',
        idNumber: '12345678901',
        role: 'seeker',
      );

      expect(result.success, isTrue);
      expect(result.requiresEmailVerification, isTrue);
      expect(repository.upsertedUserId, 'user-2');
      expect(repository.upsertedEmail, 'new@aman.com');
      expect(repository.upsertedUsername, 'newuser');
    });

    test('returns success when sign up creates a session', () async {
      final user = _testUser(id: 'user-3', email: 'owner@aman.com');
      final repository = FakeAuthRepository(
        findUserResult: null,
        signUpResult: AuthResponse(
          user: user,
          session: Session(
            accessToken: 'token',
            tokenType: 'bearer',
            user: user,
          ),
        ),
      );
      final controller = AuthController(repository: repository);

      final result = await controller.register(
        fullName: 'Owner User',
        email: 'owner@aman.com',
        username: 'owneruser',
        password: 'Secret1!',
        phone: '+249123456789',
        idNumber: '12345678901',
        role: 'owner',
      );

      expect(result.success, isTrue);
      expect(result.requiresEmailVerification, isFalse);
      expect(result.role, 'owner');
    });
  });

  group('AuthController.sendPasswordResetByUsername', () {
    test('rejects empty username', () async {
      final controller = AuthController(repository: FakeAuthRepository());

      final result = await controller.sendPasswordResetByUsername(username: ' ');

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Please enter your username.');
    });

    test('returns username not found when no matching profile exists', () async {
      final controller = AuthController(
        repository: FakeAuthRepository(findUserResult: null),
      );

      final result = await controller.sendPasswordResetByUsername(
        username: 'missing-user',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Username not found.');
    });

    test('sends matched email to repository', () async {
      final repository = FakeAuthRepository(
        findUserResult: {
          'email': 'reset@aman.com',
          'role': 'seeker',
        },
      );
      final controller = AuthController(repository: repository);

      final result = await controller.sendPasswordResetByUsername(
        username: ' ResetUser ',
      );

      expect(result.success, isTrue);
      expect(repository.lastResetEmail, 'reset@aman.com');
    });
  });
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.findUserResult,
    this.signInResult,
    this.signUpResult,
    this.roleByUserIdResult,
    this.signInException,
    this.signUpException,
    this.resetException,
  });

  final Map<String, dynamic>? findUserResult;
  final AuthResponse? signInResult;
  final AuthResponse? signUpResult;
  final String? roleByUserIdResult;
  final AuthException? signInException;
  final Exception? signUpException;
  final AuthException? resetException;

  String? lastSignInEmail;
  String? lastSignInPassword;
  String? lastResetEmail;
  String? upsertedUserId;
  String? upsertedEmail;
  String? upsertedUsername;

  @override
  Future<Map<String, dynamic>?> findUserByUsername(String username) async {
    return findUserResult;
  }

  @override
  Future<String?> getRoleByUserId(String userId) async {
    return roleByUserIdResult;
  }

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    lastSignInEmail = email;
    lastSignInPassword = password;

    if (signInException != null) throw signInException!;
    return signInResult ?? AuthResponse();
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) async {
    if (signUpException != null) throw signUpException!;
    return signUpResult ?? AuthResponse();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    lastResetEmail = email;
    if (resetException != null) throw resetException!;
  }

  @override
  Future<void> upsertUser({
    required String userId,
    required String email,
    required String username,
    required String role,
    required String fullName,
    required String phone,
    required String idNumber,
  }) async {
    upsertedUserId = userId;
    upsertedEmail = email;
    upsertedUsername = username;
  }
}

User _testUser({
  required String id,
  required String email,
  String? metadataRole,
}) {
  return User(
    id: id,
    appMetadata: const {},
    userMetadata: metadataRole == null ? null : {'role': metadataRole},
    aud: 'authenticated',
    email: email,
    createdAt: '2026-04-19T00:00:00.000Z',
  );
}
