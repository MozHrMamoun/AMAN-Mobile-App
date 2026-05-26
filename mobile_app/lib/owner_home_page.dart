import 'package:flutter/material.dart';

import 'add_property_page.dart';
import 'chat_detail_page.dart';
import 'core/app_session.dart';
import 'deal_detail_page.dart';
import 'edit_information_page.dart';
import 'features/owner_home/state/owner_home_controller.dart';
import 'follow_up_property_page.dart';
import 'message_page.dart';
import 'my_deals_page.dart';
import 'owner_more_page.dart';
import 'property_detail_page.dart';

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

  String _formatRelativeTime(DateTime? value) {
    if (value == null) return 'Recently';
    final diff = DateTime.now().difference(value.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${value.toLocal().day}/${value.toLocal().month}/${value.toLocal().year}';
  }

  Future<void> _openActivity(OwnerActivityItem activity) async {
    switch (activity.kind) {
      case OwnerActivityKind.chat:
        if (activity.chatId <= 0) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => ChatDetailPage(
                  chatId: activity.chatId,
                  peerName: activity.peerName,
                  propertyId: activity.propertyId,
                ),
          ),
        );
        break;
      case OwnerActivityKind.dealPending:
      case OwnerActivityKind.dealCompleted:
        final seekerUserId = activity.seekerUserId;
        final ownerUserId = activity.ownerUserId;
        final propertyId = activity.propertyId;
        if (seekerUserId == null || ownerUserId == null || propertyId == null) {
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => DealDetailPage(
                  peerName: activity.peerName,
                  seekerUserId: seekerUserId,
                  ownerUserId: ownerUserId,
                  propertyId: propertyId,
                ),
          ),
        );
        break;
      case OwnerActivityKind.listingInactive:
        final propertyId = activity.propertyId;
        if (propertyId == null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => const FollowUpPropertyPage(
                    initialFilter: ListingFilter.inactive,
                  ),
            ),
          );
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropertyDetailPage(propertyId: propertyId),
            ),
          );
        }
        break;
    }
    await _loadDashboard();
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
                              label: 'Unread Messages',
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
                        'Activity',
                        style: TextStyle(
                          color: Color(0xFF1F2430),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Messages, deals, and listing changes that need your attention.',
                        style: TextStyle(
                          color: Color(0xFF8E949F),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_activities.isEmpty)
                        _SectionEmptyState(
                          title: 'No owner activity yet',
                          description:
                              'When a seeker messages you, starts a deal, or one of your listings changes state, it will appear here.',
                          actionLabel: 'Open Messages',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        const MessagePage(initialRole: 'owner'),
                              ),
                            );
                          },
                        )
                      else
                        ..._activities.map(
                          (activity) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ActivityCard(
                              title: activity.title,
                              subject: activity.peerName,
                              message: activity.lastMessageText,
                              statusLabel: activity.statusLabel,
                              timeLabel: _formatRelativeTime(activity.lastMessageAt),
                              icon: switch (activity.kind) {
                                OwnerActivityKind.chat =>
                                  Icons.mark_chat_unread_rounded,
                                OwnerActivityKind.dealPending =>
                                  Icons.handshake_rounded,
                                OwnerActivityKind.dealCompleted =>
                                  Icons.verified_rounded,
                                OwnerActivityKind.listingInactive =>
                                  Icons.pause_circle_filled_rounded,
                              },
                              accentColor: switch (activity.kind) {
                                OwnerActivityKind.chat =>
                                  const Color(0xFF355C7D),
                                OwnerActivityKind.dealPending =>
                                  const Color(0xFFD68600),
                                OwnerActivityKind.dealCompleted =>
                                  const Color(0xFF2F7D32),
                                OwnerActivityKind.listingInactive =>
                                  const Color(0xFF7A6F8F),
                              },
                              actionLabel: switch (activity.kind) {
                                OwnerActivityKind.chat => 'Open chat',
                                OwnerActivityKind.dealPending => 'Review deal',
                                OwnerActivityKind.dealCompleted => 'View deal',
                                OwnerActivityKind.listingInactive =>
                                  'Open listing',
                              },
                              onTap: () => _openActivity(activity),
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
                          label: 'Deals',
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
    required this.title,
    required this.subject,
    required this.message,
    required this.statusLabel,
    required this.timeLabel,
    required this.icon,
    required this.accentColor,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String subject;
  final String message;
  final String statusLabel;
  final String timeLabel;
  final IconData icon;
  final Color accentColor;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = Color.lerp(accentColor, Colors.white, 0.9)!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE0E2E5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1F2430),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ActivityBadge(
                          label: statusLabel,
                          color: accentColor,
                          backgroundColor: tint,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF4A5160),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      maxLines: 2,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeLabel,
                    style: const TextStyle(
                      color: Color(0xFF8E949F),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel,
                        style: const TextStyle(
                          color: Color(0xFF1C2A4A),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Color(0xFF1C2A4A),
                      ),
                    ],
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

class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionEmptyState extends StatelessWidget {
  const _SectionEmptyState({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE0E5)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_rounded,
            color: Color(0xFF8E949F),
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1F2430),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8E949F),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
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
                actionLabel,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
