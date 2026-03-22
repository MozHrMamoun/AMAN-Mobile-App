import 'package:flutter/material.dart';

import 'core/app_session.dart';
import 'login_page.dart';
import 'seeker_home_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1C2A4A);
    const page = Color(0xFFFFFFFF);

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
                      bottom: -10,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(42),
                        ),
                        child: Container(
                          height: 400,
                          color: page,
                          padding: const EdgeInsets.fromLTRB(14, 18, 14, 56),
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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome to AMAN your best\noption in real estate!',
                    style: TextStyle(
                      color: Color(0xFF1F2430),
                      fontSize: 22 / 1.2,
                      fontWeight: FontWeight.w700,
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _ActionButton(
                    text: 'Start Your  Journey',
                    filled: true,
                    onTap: () {
                      AppSession.clearGuestMode();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _ActionButton(
                    text: 'Guest Mode',
                    filled: false,
                    onTap: () {
                      AppSession.enterGuestMode();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SeekerHomePage(),
                        ),
                      );
                    },
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.text,
    required this.filled,
    required this.onTap,
  });

  final String text;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1C2A4A);

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? primary : const Color(0xFFF8F8F9),
          foregroundColor: filled ? Colors.white : const Color(0xFF1F2430),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side:
                filled
                    ? BorderSide.none
                    : const BorderSide(color: Color(0xFFD1D4D9)),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
