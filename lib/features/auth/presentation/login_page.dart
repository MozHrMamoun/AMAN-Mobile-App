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

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _authController.login(
      username: _usernameController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Login failed.')),
      );
      return;
    }

    AppSession.clearGuestMode();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomePageByRole.fromRole(result.role ?? 'seeker'),
      ),
      (_) => false,
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
                      top: 12,
                      left: 8,
                      child: IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: Colors.white,
                      ),
                    ),
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
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      child: _isLoading
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
