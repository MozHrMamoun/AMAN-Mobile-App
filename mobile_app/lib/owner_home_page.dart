import 'package:flutter/material.dart';

import 'add_property_page.dart';
import 'core/app_session.dart';
import 'edit_information_page.dart';
import 'features/owner_home/state/owner_home_controller.dart';
import 'follow_up_property_page.dart';
import 'message_page.dart';
import 'my_deals_page.dart';
import 'owner_more_page.dart';

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  final OwnerHomeController _controller = OwnerHomeController();

  bool _isLoading = true;
  String? _errorMessage;
  int _activeListings = 0;
  int _inactiveListings = 0;
  int _pendingDeals = 0;
  int _unreadMessages = 0;
  List<OwnerActivityItem> _activities = const [];

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
      return;
    }
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _controller.loadDashboard();
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage ?? 'Failed to load dashboard.';
      });
      return;
    }
    setState(() {
      _isLoading = false;
      _activeListings = result.activeListings;
      _inactiveListings = result.inactiveListings;
      _pendingDeals = result.pendingDeals;
      _unreadMessages = result.unreadMessages;
      _activities = result.activities;
    });
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final h = hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $suffix';
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
          MaterialPageRoute(
            builder: (_) => const MessagePage(initialRole: 'owner'),
          ),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OwnerMorePage()),
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
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFF1F2430),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
                : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                    children: [
                      _TopIconsRow(
                        onProfileTap: () {
                          if (AppSession.isGuestMode) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please login to use this feature.',
                                ),
                              ),
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
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Active Listings',
                              value: _activeListings.toString(),
                              icon: Icons.home_work_rounded,
                              accentColor: const Color(0xFF355C7D),
                              helperText: 'Live on market',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const FollowUpPropertyPage(
                                          initialFilter: ListingFilter.active,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Pending Deals',
                              value: _pendingDeals.toString(),
                              icon: Icons.handshake_rounded,
                              accentColor: const Color(0xFF6C7A9A),
                              helperText: 'Need your review',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const MyDealsPage(
                                          initialRole: 'owner',
                                          initialFilter: DealsFilter.active,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: 'Inactive Listings',
                              value: _inactiveListings.toString(),
                              icon: Icons.pause_circle_filled_rounded,
                              accentColor: const Color(0xFF7A6F8F),
                              helperText: 'Currently hidden',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const FollowUpPropertyPage(
                                          initialFilter: ListingFilter.inactive,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: 'Unread Msg',
                              value: _unreadMessages.toString(),
                              icon: Icons.mark_chat_unread_rounded,
                              accentColor: const Color(0xFF4A6785),
                              helperText: 'New conversations',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const MessagePage(
                                          initialRole: 'owner',
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Recent Activity',
                        style: TextStyle(
                          color: Color(0xFF1F2430),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_activities.isEmpty)
                        const Text(
                          'No recent activity.',
                          style: TextStyle(
                            color: Color(0xFF8E949F),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        ..._activities.map(
                          (activity) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ActivityCard(
                              name: activity.peerName,
                              message: activity.lastMessageText,
                              timeLabel: _formatTime(activity.lastMessageAt),
                            ),
                          ),
                        ),
                      const SizedBox(height: 22),
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          color: Color(0xFF1F2430),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              label: 'Add Property',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AddPropertyPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionButton(
                              label: 'Manage Listings',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const FollowUpPropertyPage(
                                          initialFilter: ListingFilter.active,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: _ActionButton(
                          label: 'My Deals',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        const MyDealsPage(initialRole: 'owner'),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
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
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD7DBE2)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C1C2A4A),
                    offset: Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.manage_accounts_rounded,
                color: Color(0xFF1C2A4A),
                size: 30,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.helperText,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String helperText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundTint = Color.lerp(accentColor, Colors.white, 0.95)!;
    final borderTone = Color.lerp(accentColor, const Color(0xFFDDE0E5), 0.75)!;
    final iconBackground = Color.lerp(accentColor, Colors.white, 0.82)!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 170,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [backgroundTint, const Color(0xFFF7F7F8)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderTone),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F1C2A4A),
                offset: Offset(0, 8),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    color:
                        onTap == null
                            ? const Color(0xFFB7BCC6)
                            : accentColor.withValues(alpha: 0.68),
                    size: 18,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF1F2430),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    helperText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8E949F),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.name,
    required this.message,
    required this.timeLabel,
  });

  final String name;
  final String message;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E2E5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_circle_rounded,
            size: 34,
            color: Color(0xFF1C2A4A),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2430),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8E949F),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeLabel,
            style: const TextStyle(
              color: Color(0xFF8E949F),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1C2A4A),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
