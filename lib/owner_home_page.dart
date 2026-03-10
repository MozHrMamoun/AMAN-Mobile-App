import 'package:flutter/material.dart';

import 'core/app_session.dart';
import 'add_property_page.dart';
import 'edit_information_page.dart';
import 'follow_up_property_page.dart';
import 'message_page.dart';

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  @override
  void initState() {
    super.initState();
    if (AppSession.isGuestMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to use this feature.')),
        );
      });
    }
  }

  void _onNavTap(int index) {
    if (AppSession.isGuestMode && index != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to use this feature.')),
      );
      return;
    }

    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AddPropertyPage()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MessagePage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FollowUpPropertyPage()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const page = Color(0xFFE9EAEC);
    const primary = Color(0xFF1C2A4A);

    return Scaffold(
      backgroundColor: page,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          children: [
            _TopIconsRow(
              onProfileTap: () {
                if (AppSession.isGuestMode) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please login to use this feature.')),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EditInformationPage(),
                  ),
                );
              },
            ),
            SizedBox(height: 90),
            const _PropertyCard(),
            SizedBox(height: 24),
            const _PropertyCard(),
            SizedBox(height: 24),
            const _PropertyCard(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: primary,
          height: 72,
          indicatorColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (_) => const IconThemeData(color: Colors.white, size: 30),
          ),
        ),
        child: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: _onNavTap,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_rounded),
              label: 'HOME',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_rounded),
              label: 'Add',
            ),
            NavigationDestination(
              icon: Icon(Icons.send_rounded),
              label: 'Message',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}

class _TopIconsRow extends StatelessWidget {
  const _TopIconsRow({required this.onProfileTap});

  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Icon(Icons.notifications, color: Color(0xFF1C2A4A), size: 30),
        IconButton(
          onPressed: onProfileTap,
          icon: const Icon(Icons.account_circle, color: Color(0xFF1C2A4A), size: 34),
        ),
      ],
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E2E5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            offset: Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 160,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFE7E7E8),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Title',
                  style: TextStyle(
                    color: Color(0xFF1F2430),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Bedrooms\nBathrooms\nOwner\nRating',
                  style: TextStyle(
                    color: Color(0xFF8E949F),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C2A4A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Contact',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17 / 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
