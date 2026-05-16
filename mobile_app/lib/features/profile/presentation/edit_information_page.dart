import 'package:flutter/material.dart';
import 'package:aman/login_page.dart';

import '../../../core/app_session.dart';
import '../state/profile_controller.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  final ProfileController _controller = ProfileController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    if (AppSession.isGuestMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to use this feature.')),
        );
        Navigator.of(context).maybePop();
      });
      return;
    }
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _controller.loadProfile();

    if (!mounted) return;

    if (profile != null) {
      _fullNameController.text = profile.fullName;
      _emailController.text = profile.email;
      _usernameController.text = profile.username;
      _phoneController.text = profile.phone;
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _editProfile() async {
    setState(() {
      _isSubmitting = true;
    });

    final result = await _controller.updateProfile(
      fullName: _fullNameController.text,
      email: _emailController.text,
      username: _usernameController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'Profile updated successfully.'
              : (result.errorMessage ?? 'Failed to update profile.'),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    setState(() {
      _isLoggingOut = true;
    });

    final result = await _controller.signOut();

    if (!mounted) return;

    setState(() {
      _isLoggingOut = false;
    });

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Failed to logout.')),
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
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
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Edit Information',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
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
                                    hint: 'Enter New Password (optional)',
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
                                ],
                              ),
                            ),
                            const SizedBox(height: 26),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _editProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isSubmitting
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
                                        'Edit',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 30 / 2,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoggingOut ? null : _logout,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB2455D),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoggingOut
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
                                        'Logout',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 30 / 2,
                                        ),
                                      ),
                              ),
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
