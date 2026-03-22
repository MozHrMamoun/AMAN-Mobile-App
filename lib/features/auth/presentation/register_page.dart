import 'package:flutter/material.dart';

import '../../../core/app_session.dart';
import '../../home/presentation/home_page.dart';
import '../state/auth_controller.dart';
import 'login_page.dart';

class AuthRegisterPage extends StatefulWidget {
  const AuthRegisterPage({super.key});

  @override
  State<AuthRegisterPage> createState() => _AuthRegisterPageState();
}

class _AuthRegisterPageState extends State<AuthRegisterPage> {
  bool _isOwnerSelected = true;
  bool _isLoading = false;

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _authController = AuthController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthLoginPage()),
    );
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _authController.register(
      fullName: _fullNameController.text,
      email: _emailController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      phone: _phoneController.text,
      idNumber: _idNumberController.text,
      role: _isOwnerSelected ? 'owner' : 'seeker',
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Register failed.')),
      );
      return;
    }

    if (result.requiresEmailVerification) {
      AppSession.clearGuestMode();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registered. Please verify your email, then login.'),
        ),
      );
      _goToLogin();
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
  Widget build(BuildContext context) {
    const primary = Color(0xFF1C2A4A);
    const page = Color(0xFFE9EAEC);
    const border = Color(0xFFDDE0E5);

    return Scaffold(
      backgroundColor: primary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Register Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 50 / 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _goToLogin,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: page,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 32, 18, 64),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8F9),
                          border: Border.all(color: border),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000000),
                              offset: Offset(0, 3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F8F9),
                                border: Border.all(color: border),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _TypeTab(
                                      label: 'Owner',
                                      selected: _isOwnerSelected,
                                      onTap: () {
                                        setState(() {
                                          _isOwnerSelected = true;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _TypeTab(
                                      label: 'Seeker',
                                      selected: !_isOwnerSelected,
                                      onTap: () {
                                        setState(() {
                                          _isOwnerSelected = false;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            const _InputLabel('Full Name'),
                            _InputField(
                              hint: 'Enter Your Name',
                              icon: Icons.person,
                              controller: _fullNameController,
                            ),
                            const SizedBox(height: 12),
                            const _InputLabel('Email'),
                            _InputField(
                              hint: 'Enter Your Email',
                              icon: Icons.email,
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            const _InputLabel('User Name'),
                            _InputField(
                              hint: 'Enter Your User Name',
                              icon: Icons.person,
                              controller: _usernameController,
                            ),
                            const SizedBox(height: 12),
                            const _InputLabel('Password'),
                            _InputField(
                              hint: 'Enter Your Password',
                              icon: Icons.password,
                              controller: _passwordController,
                              obscure: true,
                            ),
                            const SizedBox(height: 12),
                            const _InputLabel('Phone Number'),
                            _InputField(
                              hint: 'Enter Your Phone Number',
                              icon: Icons.phone,
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 12),
                            const _InputLabel('ID Number'),
                            _InputField(
                              hint: 'Enter Your ID Number',
                              icon: Icons.badge,
                              controller: _idNumberController,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
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
                                  'Register',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 30 / 2,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'You already have an account!  ',
                            style: TextStyle(
                              color: primary,
                              fontSize: 32 / 2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          GestureDetector(
                            onTap: _goToLogin,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Login Now',
                                  style: TextStyle(
                                    color: Color(0xFFE64D83),
                                    fontSize: 32 / 2,
                                    fontWeight: FontWeight.w600,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1C2A4A) : const Color(0xFFF8F8F9),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFD1D4D9)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF1F2430),
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
    );
  }
}

class _InputLabel extends StatelessWidget {
  const _InputLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF1F2430),
            fontWeight: FontWeight.w500,
            fontSize: 28 / 2,
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.hint,
    required this.icon,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
  });

  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8F8F9),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFD1D4D9), fontSize: 14),
        suffixIcon: Icon(icon, color: const Color(0xFF1C2A4A), size: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFD1D4D9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF1C2A4A)),
        ),
      ),
    );
  }
}
