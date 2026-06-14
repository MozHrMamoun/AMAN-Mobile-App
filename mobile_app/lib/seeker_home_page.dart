import 'package:flutter/material.dart';

import 'chat_detail_page.dart';
import 'core/app_session.dart';
import 'core/app_theme.dart';
import 'core/city_data.dart';
import 'core/guest_login_prompt.dart';
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
  static const int _pageSize = 5000;

  List<SeekerHomePropertyItem> _allProperties = const [];
  List<SeekerHomePropertyItem> _filteredProperties = const [];
  int _unreadNotifications = 0;

  List<String> get _typeOptions {
    final set = _allProperties.map((e) => e.propertyType).toSet().toList();
    set.sort();
    return set;
  }

  List<String> get _cityOptions {
    final cities = CityData.allCities.toSet().toList();
    cities.sort();
    return cities;
  }

  String _normalizeFilterValue(String value) {
    return value.trim().toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    _loadProperties(reset: true);
    _runAiMatchingIfNeeded();
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
    final selectedCity =
        _selectedCity == null ? null : _normalizeFilterValue(_selectedCity!);
    final selectedType =
        _selectedType == null ? null : _normalizeFilterValue(_selectedType!);

    _filteredProperties =
        _allProperties.where((property) {
          final cityMatch =
              selectedCity == null ||
              _normalizeFilterValue(property.propertyCity) == selectedCity;
          final typeMatch =
              selectedType == null ||
              _normalizeFilterValue(property.propertyType) == selectedType;
          return cityMatch && typeMatch;
        }).toList();
  }

  Future<void> _pickCity() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _SearchableSelectionSheet(
            title: 'Select City',
            items: _cityOptions,
            selectedValue: _selectedCity,
          ),
    );

    if (!mounted || selected == null) return;
    setState(() {
      _selectedCity = selected;
      _applyFilters();
    });
  }

  Future<void> _loadNotificationCount() async {
    if (AppSession.isGuestMode) return;
    final count = await _notificationController.loadUnreadCount();
    if (!mounted) return;
    setState(() {
      _unreadNotifications = count;
    });
  }

  Future<void> _runAiMatchingIfNeeded() async {
    if (AppSession.isGuestMode || AppSession.hasRunAiMatch) return;
    try {
      await _notificationController.runAiMatchingOnly();
    } catch (_) {
      // Ignore matching errors on home load.
    } finally {
      AppSession.markAiMatchRan();
    }
  }

  Future<void> _openNotifications() async {
    if (AppSession.isGuestMode) {
      await showGuestLoginPrompt(context);
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
      await showGuestLoginPrompt(context);
      return;
    }

    final result = await _chatController.openOrCreateChatWithOwner(
      ownerUserId: ownerUserId,
      propertyId: propertyId,
    );
    if (!mounted) return;

    if (!result.success || result.chatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Failed to open chat.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ChatDetailPage(
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
        showGuestLoginPrompt(context);
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
            MaterialPageRoute(
              builder: (_) => const MessagePage(initialRole: 'seeker'),
            ),
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
                                showGuestLoginPrompt(context);
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
                                child: _SearchTriggerField(
                                  hint: 'Property City',
                                  value: _selectedCity,
                                  onTap: _pickCity,
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
                            Padding(
                              padding: EdgeInsets.only(top: 40),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFDDE0E5),
                                  ),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(
                                      Icons.search_off_rounded,
                                      color: Color(0xFF8E949F),
                                      size: 30,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'No properties found for these filters',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFF1F2430),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Try another city or property type to see more listings.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFF8E949F),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ..._filteredProperties.map(
                              (property) => Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: _PropertyCard(
                                  property: property,
                                  onContactTap:
                                      () => _openOwnerChat(
                                        property.ownerUserId,
                                        propertyId: property.propertyId,
                                      ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => PropertyDetailPage(
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
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onNotificationTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              width: 48,
              height: 48,
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
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF1C2A4A),
                    size: 26,
                  ),
                  if (notificationCount > 0)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 19,
                          minHeight: 19,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB2455D),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          notificationCount > 99
                              ? '99+'
                              : notificationCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              width: 48,
              height: 48,
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
                size: 26,
              ),
            ),
          ),
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
          items:
              items
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

class _SearchTriggerField extends StatelessWidget {
  const _SearchTriggerField({
    required this.hint,
    required this.value,
    required this.onTap,
  });

  final String hint;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDDE0E5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value ?? hint,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        value == null
                            ? const Color(0xFF5A606D)
                            : const Color(0xFF1F2430),
                    fontSize: 14,
                    fontWeight:
                        value == null ? FontWeight.w500 : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.search_rounded,
                color: Color(0xFF1C2A4A),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchableSelectionSheet extends StatefulWidget {
  const _SearchableSelectionSheet({
    required this.title,
    required this.items,
    required this.selectedValue,
  });

  final String title;
  final List<String> items;
  final String? selectedValue;

  @override
  State<_SearchableSelectionSheet> createState() =>
      _SearchableSelectionSheetState();
}

class _SearchableSelectionSheetState extends State<_SearchableSelectionSheet> {
  late final TextEditingController _controller;
  late List<String> _filteredItems;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _filteredItems = widget.items;
    _controller.addListener(_filterItems);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_filterItems)
      ..dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _controller.text.trim().toLowerCase();
    setState(() {
      _filteredItems =
          query.isEmpty
              ? widget.items
              : widget.items
                  .where((item) => item.toLowerCase().contains(query))
                  .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F8FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D5DD),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Color(0xFF1F2430),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDDE0E5)),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: Color(0xFF1C2A4A),
                          ),
                          hintText: 'Type to search city',
                          hintStyle: TextStyle(
                            color: Color(0xFF98A2B3),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    _filteredItems.isEmpty
                        ? const Center(
                          child: Text(
                            'No matching city found.',
                            style: TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                        : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: _filteredItems.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final isSelected = item == widget.selectedValue;
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.of(context).pop(item),
                                borderRadius: BorderRadius.circular(16),
                                child: Ink(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? const Color(0xFFEAF0FF)
                                            : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          isSelected
                                              ? const Color(0xFFB8C8EA)
                                              : const Color(0xFFDDE0E5),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item,
                                          style: const TextStyle(
                                            color: Color(0xFF1F2430),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF1C2A4A),
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        );
      },
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

  String _ratingText(double? rating) {
    return rating == null ? '-' : rating.toStringAsFixed(1);
  }

  String _priceText(double price) {
    return '${price.toStringAsFixed(0)} SDG';
  }

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
                  child:
                      property.imageUrl == null
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
                            errorBuilder:
                                (_, __, ___) => Container(
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
                    _InfoLine(
                      label: 'Bedrooms',
                      value: '${property.bedrooms ?? '-'}',
                    ),
                    _InfoLine(
                      label: 'Bathrooms',
                      value: '${property.bathrooms ?? '-'}',
                    ),
                    _InfoLine(
                      label: 'Price',
                      value: _priceText(property.price),
                    ),
                    _InfoLine(
                      label: 'Rating',
                      value: _ratingText(property.ownerRating),
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

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Color(0xFF4A5160),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Color(0xFF7D8491),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
