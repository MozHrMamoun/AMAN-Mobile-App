import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/reset_password_page.dart';
import '../landing_page.dart';

class AmanApp extends StatefulWidget {
  const AmanApp({super.key});

  @override
  State<AmanApp> createState() => _AmanAppState();
}

class _AmanAppState extends State<AmanApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<AuthState>? _authErrorSubscription;
  StreamSubscription<Uri>? _deepLinkSubscription;
  bool _isShowingResetPasswordPage = false;

  @override
  void initState() {
    super.initState();
    _startDeepLinkListener();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _openResetPasswordPage();
      }
    });
    _authErrorSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) {},
      onError: _handleAuthError,
    );
  }

  Future<void> _startDeepLinkListener() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleIncomingUri(initialUri);
      }
    } catch (_) {
      // Ignore malformed initial link errors here; Supabase auth listener will
      // still handle valid recovery links.
    }

    _deepLinkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingUri(uri);
    });
  }

  void _handleIncomingUri(Uri uri) {
    final message = _extractRecoveryErrorMessage(uri);
    if (message == null) return;

    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    _isShowingResetPasswordPage = false;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LandingPage()),
      (_) => false,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }

  String? _extractRecoveryErrorMessage(Uri uri) {
    String? rawErrorDescription = uri.queryParameters['error_description'];

    if ((rawErrorDescription == null || rawErrorDescription.isEmpty) &&
        uri.fragment.isNotEmpty) {
      final fragment = uri.fragment.startsWith('?')
          ? uri.fragment.substring(1)
          : uri.fragment;
      final fragmentParams = Uri.splitQueryString(
        fragment.replaceAll('#', '&'),
      );
      rawErrorDescription = fragmentParams['error_description'];
    }

    final rawError = uri.queryParameters['error'] ??
        (uri.fragment.isNotEmpty
            ? Uri.splitQueryString(
                uri.fragment.startsWith('?')
                    ? uri.fragment.substring(1)
                    : uri.fragment,
              )['error']
            : null);

    if (rawErrorDescription == null || rawErrorDescription.isEmpty) {
      return null;
    }

    final lowerDescription = rawErrorDescription.toLowerCase();
    final lowerError = rawError?.toLowerCase() ?? '';
    if (lowerDescription.contains('invalid or has expired') ||
        lowerError == 'access_denied') {
      return 'This password reset link is invalid or has expired. Please request a new reset email.';
    }

    return rawErrorDescription.replaceAll('+', ' ');
  }

  void _openResetPasswordPage() {
    if (_isShowingResetPasswordPage) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    _isShowingResetPasswordPage = true;
    navigator
        .push(
          MaterialPageRoute(
            builder: (_) => const ResetPasswordPage(),
          ),
        )
        .whenComplete(() {
          _isShowingResetPasswordPage = false;
        });
  }

  void _handleAuthError(Object error, StackTrace stackTrace) {
    final navigator = _navigatorKey.currentState;
    final messenger = _messengerKey.currentState;
    if (navigator == null || messenger == null) return;

    String message = 'Authentication error. Please try again.';
    var shouldRouteToLogin = false;
    if (error is AuthException) {
      final lower = error.message.toLowerCase();
      if (lower.contains('invalid or has expired') ||
          error.statusCode == 'otp_expired' ||
          error.code == 'access_denied') {
        message =
            'This password reset link is invalid or has expired. Please request a new reset email.';
        shouldRouteToLogin = true;
      } else if (error.message.isNotEmpty) {
        message = error.message;
      }
    }

    if (shouldRouteToLogin) {
      _isShowingResetPasswordPage = false;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LandingPage()),
        (_) => false,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(message)),
        );
      });
      return;
    }

    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authErrorSubscription?.cancel();
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFE9EAEC),
        useMaterial3: true,
      ),
      home: const LandingPage(),
    );
  }
}
