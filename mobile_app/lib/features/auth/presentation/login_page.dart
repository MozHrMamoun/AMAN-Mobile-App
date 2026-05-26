import 'package:flutter/material.dart';

import '../../../core/app_session.dart';
import '../../home/presentation/home_page.dart';
import '../state/auth_controller.dart';
import 'register_page.dart';

class AuthLoginPage extends StatefulWidget {
  const AuthLoginPage({super.key});

  @override
  State<AuthLoginPage> createState() => _AuthLoginPageState();
}

class _AuthLoginPageState extends State<AuthLoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authController = AuthController();
  bool _isLoading = false;
  String? _authMessage;
  bool _isAuthMessageError = false;

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _authMessage = null;
    });

    try {
      final result = await _authController.login(
        username: _usernameController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _authMessage = result.errorMessage ?? 'Login failed.';
          _isAuthMessageError = true;
        });
        return;
      }

      AppSession.clearGuestMode();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => HomePageByRole.fromRole(result.role ?? 'seeker'),
        ),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _authMessage = 'Unexpected error while logging in. Please try again.';
        _isAuthMessageError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(controller: _authController),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1C2A4A);
    const page = Color(0xFFFFFFFF);
    const border = Color(0xFFDDE0E5);

    return Scaffold(
      backgroundColor: primary,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(42),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -6,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(42),
                        ),
                        child: Container(
                          height: 320,
                          color: page,
                          padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
                          child: Image.asset(
                            'assets/background.jpg',
                            fit: BoxFit.contain,
                            alignment: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              color: page,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_authMessage != null) ...[
                    _InlineFeedbackCard(
                      message: _authMessage!,
                      isError: _isAuthMessageError,
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'User Name',
                    style: TextStyle(
                      color: Color(0xFF1F2430),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8F8F9),
                      hintText: 'Enter Your User Name',
                      hintStyle: const TextStyle(
                        color: Color(0xFFD1D4D9),
                        fontSize: 15,
                      ),
                      suffixIcon: const Icon(
                        Icons.person_rounded,
                        color: primary,
                        size: 18,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Password',
                    style: TextStyle(
                      color: Color(0xFF1F2430),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8F8F9),
                      hintText: 'Enter Your Password',
                      hintStyle: const TextStyle(
                        color: Color(0xFFD1D4D9),
                        fontSize: 15,
                      ),
                      suffixIcon: const Icon(
                        Icons.key_rounded,
                        color: primary,
                        size: 18,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _isLoading ? null : _showForgotPasswordDialog,
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Color(0xFFD96486),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Text(
                                'Login',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Text(
                        'You dont have an account? ',
                        style: TextStyle(
                          color: Color(0xFF1F2430),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AuthRegisterPage(),
                            ),
                          );
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Register Now',
                              style: TextStyle(
                                color: Color(0xFFD96486),
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Color(0xFF1F2430),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.controller});

  final AuthController controller;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isSending = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isSending = true;
      _message = null;
    });

    final result = await widget.controller.sendPasswordResetByUsername(
      username: _usernameController.text,
    );

    if (!mounted) return;

    setState(() {
      _isSending = false;
      _message =
          result.success
              ? 'Password reset email sent. Please check the email linked to this username.'
              : (result.errorMessage ?? 'Failed to send reset email.');
      _isError = !result.success;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Forgot Password?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_message != null) ...[
            _InlineFeedbackCard(
              message: _message!,
              isError: _isError,
            ),
            const SizedBox(height: 14),
          ],
          const Text(
            'Enter the username linked to your account and we will send a reset link to its email.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              hintText: 'Enter your username',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSending ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1C2A4A),
            foregroundColor: Colors.white,
          ),
          child:
              _isSending
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : const Text('Send'),
        ),
      ],
    );
  }
}

class _InlineFeedbackCard extends StatelessWidget {
  const _InlineFeedbackCard({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color =
        isError ? const Color(0xFFC2410C) : const Color(0xFF2F7D32);
    final background =
        isError ? const Color(0xFFFFF1E8) : const Color(0xFFE8F5EC);
    final border =
        isError ? const Color(0xFFF4C7B5) : const Color(0xFFCFE8D6);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.info_outline_rounded : Icons.check_circle_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
