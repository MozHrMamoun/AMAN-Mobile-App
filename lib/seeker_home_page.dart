import 'package:flutter/material.dart';

import 'chat_detail_page.dart';
import 'core/app_session.dart';
import 'core/app_theme.dart';
import 'edit_information_page.dart';
import 'features/chat/state/chat_list_controller.dart';
import 'features/properties/state/seeker_home_controller.dart';
import 'message_page.dart';
import 'notification_page.dart';
import 'property_detail_page.dart';
import 'more_service_page.dart';
import 'search_property_page.dart';
import 'features/notifications/state/notification_controller.dart';

class SeekerHomePage extends StatefulWidget {
  const SeekerHomePage({super.key});

  @override
  State<SeekerHomePage> createState() => _SeekerHomePageState();
}

class _SeekerHomePageState extends State<SeekerHomePage> {
  final SeekerHomeController _controller = SeekerHomeController();
  final ChatListController _chatController = ChatListController();
  final NotificationController _notificationController =
      NotificationController();
  final ScrollController _scrollController = ScrollController();

  String? _selectedCity;
  String? _selectedType;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  static const int _pageSize = 20;

  List<SeekerHomePropertyItem> _allProperties = const [];
  List<SeekerHomePropertyItem> _filteredProperties = const [];
  int _unreadNotifications = 0;

  List<String> get _typeOptions {
    final set = _allProperties.map((e) => e.propertyType).toSet().toList();
    set.sort();
    return set;
  }

  List<String> get _cityOptions {
    final set = _allProperties.map((e) => e.propertyCity).toSet().toList();
    set.sort();
    return set;
  }

  @override
  void initState() {
    super.initState();
    _loadProperties(reset: true);
    _loadNotificationCount();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadProperties(reset: false);
    }
  }

  Future<void> _loadProperties({required bool reset}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _page = 0;
        _hasMore = true;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    final result = await _controller.loadProperties(
      limit: _pageSize,
      offset: _page * _pageSize,
    );
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = result.errorMessage ?? 'Failed to load properties.';
      });
      return;
    }

    if (reset) {
      _allProperties = result.items;
    } else {
      _allProperties = [..._allProperties, ...result.items];
    }
    _hasMore = result.items.length == _pageSize;
    if (_hasMore) {
      _page += 1;
    }
    _applyFilters();
    setState(() {
      _isLoading = false;
      _isLoadingMore = false;
    });
  }

  void _applyFilters() {
    _filteredProperties = _allProperties.where((property) {
      final cityMatch =
          _selectedCity == null || property.propertyCity == _selectedCity;
      final typeMatch =
          _selectedType == null || property.propertyType == _selectedType;
      return cityMatch && typeMatch;
    }).toList();
  }

  Future<void> _loadNotificationCount() async {
    if (AppSession.isGuestMode) return;
    final count = await _notificationController.loadUnreadCount();
    if (!mounted) return;
    setState(() {
      _unreadNotifications = count;
    });
  }

  Future<void> _openNotifications() async {
    if (AppSession.isGuestMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to use this feature.')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationPage()),
    );
    if (!mounted) return;
    _loadNotificationCount();
  }

  Future<void> _openOwnerChat(
    String ownerUserId, {
    required int propertyId,
  }) async {
    if (AppSession.isGuestMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to use this feature.')),
      );
      return;
    }

    final result = await _chatController.openOrCreateChatWithOwner(
      ownerUserId: ownerUserId,
      propertyId: propertyId,
    );
    if (!mounted) return;

    if (!result.success || result.chatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Failed to open chat.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          chatId: result.chatId!,
          peerName: result.peerName ?? 'Owner',
          propertyId: propertyId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = AppColors.primary;
    const page = AppColors.page;

    void onNavTap(int index) {
      if (AppSession.isGuestMode && index != 0 && index != 1) {
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
            MaterialPageRoute(builder: (_) => const SearchPropertyPage()),
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
            MaterialPageRoute(builder: (_) => const MoreServicePage()),
          );
          break;
      }
    }

    return Scaffold(
      backgroundColor: primary,
      body: SafeArea(
        bottom: false,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
          child: Container(
            color: page,
            child: _isLoading
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
                        onRefresh: () => _loadProperties(reset: true),
                        child: ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                          children: [
                            _TopIconsRow(
                              onNotificationTap: _openNotifications,
                              notificationCount: _unreadNotifications,
                              onProfileTap: () {
                                if (AppSession.isGuestMode) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please login to use this feature.'),
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
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _FilterDropdown(
                                    hint: 'Property City',
                                    value: _selectedCity,
                                    items: _cityOptions,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedCity = value;
                                        _applyFilters();
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: _FilterDropdown(
                                    hint: 'Property Type',
                                    value: _selectedType,
                                    items: _typeOptions,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedType = value;
                                        _applyFilters();
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            if (_filteredProperties.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 40),
                                child: Text(
                                  'No properties found for selected filters.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF1F2430),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else
                              ..._filteredProperties.map(
                                (property) => Padding(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: _PropertyCard(
                                    property: property,
                                    onContactTap: () => _openOwnerChat(
                                      property.ownerUserId,
                                      propertyId: property.propertyId,
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PropertyDetailPage(
                                            propertyId: property.propertyId,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            if (_isLoadingMore)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(child: CircularProgressIndicator()),
                              ),
                          ],
                        ),
                      ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: const NavigationBarThemeData(
          height: 72,
          indicatorColor: Colors.transparent,
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: WidgetStatePropertyAll(
            IconThemeData(color: Colors.white, size: 30),
          ),
        ),
        child: NavigationBar(
          backgroundColor: primary,
          selectedIndex: 0,
          onDestinationSelected: onNavTap,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_rounded),
              label: 'HOME',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_rounded),
              label: 'SEARCH',
            ),
            NavigationDestination(
              icon: Icon(Icons.send_rounded),
              label: 'MESSAGE',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_rounded),
              label: 'MORE',
            ),
          ],
        ),
      ),
    );
  }
}

class _TopIconsRow extends StatelessWidget {
  const _TopIconsRow({
    required this.onProfileTap,
    required this.onNotificationTap,
    required this.notificationCount,
  });

  final VoidCallback onProfileTap;
  final VoidCallback onNotificationTap;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onNotificationTap,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications,
                color: Color(0xFF1C2A4A),
                size: 30,
              ),
              if (notificationCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB2455D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      notificationCount > 99
                          ? '99+'
                          : notificationCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: onProfileTap,
          icon: const Icon(Icons.account_circle, color: Color(0xFF1C2A4A), size: 34),
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = value != null && items.contains(value) ? value : null;

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE0E5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF1C2A4A),
            size: 28,
          ),
          hint: Text(
            hint,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF5A606D),
              fontSize: 21 / 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: const TextStyle(
            color: Color(0xFF1F2430),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: Colors.white,
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({
    required this.property,
    required this.onTap,
    required this.onContactTap,
  });

  final SeekerHomePropertyItem property;
  final VoidCallback onTap;
  final VoidCallback onContactTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
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
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 160,
                  height: 120,
                  child: property.imageUrl == null
                      ? Container(
                          color: const Color(0xFFE7E7E8),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Color(0xFF9AA1AD),
                          ),
                        )
                      : Image.network(
                          property.imageUrl!,
                          fit: BoxFit.cover,
                          cacheWidth: 360,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFE7E7E8),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: Color(0xFF9AA1AD),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.propertyType,
                      style: const TextStyle(
                        color: Color(0xFF1F2430),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bedrooms: ${property.bedrooms ?? '-'}\n'
                      'Bathrooms: ${property.bathrooms ?? '-'}\n'
                      'Owner: ${property.ownerName}\n'
                      'Rating: ${property.ownerRating == null ? '-' : property.ownerRating!.toStringAsFixed(1)}',
                      style: const TextStyle(
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
                        onPressed: onContactTap,
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
        ),
      ),
    );
  }
}
