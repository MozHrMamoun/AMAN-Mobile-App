import 'package:flutter/material.dart';

import 'core/app_session.dart';
import 'core/app_theme.dart';
import 'fair_price_page.dart';
import 'my_deals_page.dart';
import 'recommendation_page.dart';
import 'seeker_home_page.dart';

class MoreServicePage extends StatelessWidget {
  const MoreServicePage({super.key});

  void _openRestrictedPage(
    BuildContext context, {
    required Widget page,
  }) {
    if (AppSession.isGuestMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to use this feature.')),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    const primary = AppColors.primary;
    const page = AppColors.page;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SeekerHomePage()),
          );
        }
      },
      child: Scaffold(
        backgroundColor: primary,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text(
                      'More Service',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SeekerHomePage(),
                            ),
                          );
                        },
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
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    children: [
                      const Text(
                        'Choose a service',
                        style: TextStyle(
                          color: Color(0xFF1F2430),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const SizedBox(height: 22),
                      _ServiceCard(
                        icon: Icons.query_stats_rounded,
                        title: 'Fair Price',
                        description:
                            'Check the monthly average property price based on selected filters.',
                        onTap: () => _openRestrictedPage(
                          context,
                          page: const FairPricePage(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ServiceCard(
                        icon: Icons.lightbulb_outline_rounded,
                        title: 'Recommendation',
                        description:
                            'Save the exact property details you want when search does not find a match.',
                        onTap: () => _openRestrictedPage(
                          context,
                          page: const RecommendationPage(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ServiceCard(
                        icon: Icons.handshake_outlined,
                        title: 'My Deals',
                        description:
                            'Track active and completed deals.',
                        onTap: () => _openRestrictedPage(
                          context,
                          page: const MyDealsPage(initialRole: 'seeker'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDDE0E5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                offset: Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF1F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF1C2A4A), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF1F2430),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF6E7583),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF1C2A4A),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
