import 'package:flutter/material.dart';

import 'core/app_session.dart';
import 'edit_information_page.dart';
import 'features/properties/state/search_properties_controller.dart';
import 'features/notifications/state/notification_controller.dart';
import 'features/wished/state/wished_property_controller.dart';
import 'message_page.dart';
import 'notification_page.dart';
import 'property_detail_page.dart';
import 'more_service_page.dart';
import 'search_property_page.dart';
import 'seeker_home_page.dart';

class SearchResultPage extends StatefulWidget {
  const SearchResultPage({super.key, required this.criteria});

  final SearchCriteria criteria;

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  final SearchPropertiesController _controller = SearchPropertiesController();
  final NotificationController _notificationController =
      NotificationController();
  final WishedPropertyController _wishedPropertyController =
      WishedPropertyController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  String? _errorMessage;
  List<SearchPropertyItem> _items = const [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  int _unreadNotifications = 0;
  bool _isSavingPreference = false;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
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
      _load(reset: false);
    }
  }

  Future<void> _load({required bool reset}) async {
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

    final result = await _controller.search(
      widget.criteria,
      limit: _pageSize,
      offset: _page * _pageSize,
    );
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = result.errorMessage;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _isLoadingMore = false;
      _errorMessage = null;
      if (reset) {
        _items = result.items;
      } else {
        _items = [..._items, ...result.items];
      }
      _hasMore = result.items.length == _pageSize;
      if (_hasMore) {
        _page += 1;
      }
    });
  }

  void _openLoginRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please login to use this feature.')),
    );
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
      _openLoginRequired();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationPage()),
    );
    if (!mounted) return;
    _loadNotificationCount();
  }

  Future<void> _openRecommendation() async {
    if (AppSession.isGuestMode) {
      _openLoginRequired();
      return;
    }
    setState(() {
      _isSavingPreference = true;
    });

    final preferredPrice = widget.criteria.maxPrice ?? widget.criteria.minPrice;
    final result = await _wishedPropertyController.saveWish(
      isBuy: widget.criteria.transactionType.toLowerCase() != 'rent',
      rentType: _formatRentType(widget.criteria.rentType),
      propertyType: widget.criteria.propertyType,
      city: widget.criteria.propertyCity,
      bedrooms: _countToLabel(
        widget.criteria.bedrooms,
        widget.criteria.bedroomsAtLeast,
      ),
      bathrooms: _countToLabel(
        widget.criteria.bathrooms,
        widget.criteria.bathroomsAtLeast,
      ),
      priceText: preferredPrice?.toStringAsFixed(0) ?? '',
    );
    if (!mounted) return;

    setState(() {
      _isSavingPreference = false;
    });

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(result.success ? 'Preference saved' : 'Unable to save'),
          content: Text(
            result.success
                ? 'Your search preferences were saved successfully. We will use them to match you with suitable properties in the future.'
                : (result.errorMessage ?? 'Failed to save your preferences.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String? _countToLabel(int? value, bool atLeast) {
    if (value == null) return null;
    if (atLeast && value >= 5) return '5+';
    return value.toString();
  }

  String? _formatRentType(String? rentType) {
    if (rentType == null || rentType.isEmpty) return null;
    return '${rentType[0].toUpperCase()}${rentType.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1C2A4A);
    const page = Color(0xFFE9EAEC);

    void onNavTap(int index) {
      if (AppSession.isGuestMode && index != 0 && index != 1) {
        _openLoginRequired();
        return;
      }

      switch (index) {
        case 0:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SeekerHomePage()),
          );
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
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
                        child: _TopIconsRow(
                          onNotificationTap: _openNotifications,
                          notificationCount: _unreadNotifications,
                          onProfileTap: () {
                            if (AppSession.isGuestMode) {
                              _openLoginRequired();
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
                      ),
                      const SizedBox(height: 22),
                      const SizedBox(height: 46),
                      Expanded(
                        child:
                            _isLoading
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
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
                                : _items.isEmpty
                                ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: _SearchEmptyState(
                                      isSaving: _isSavingPreference,
                                      onDismiss: () => Navigator.of(context).pop(),
                                      onSaveTap: _openRecommendation,
                                    ),
                                  ),
                                )
                                : RefreshIndicator(
                                  onRefresh: () => _load(reset: true),
                                  child: GridView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      16,
                                    ),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16,
                                          mainAxisExtent: 340,
                                        ),
                                    itemCount:
                                        _items.length +
                                        (_isLoadingMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index >= _items.length) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                      final item = _items[index];
                                      return _ResultCard(
                                        item: item,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => PropertyDetailPage(
                                                    propertyId: item.propertyId,
                                                  ),
                                            ),
                                          );
                                        },
                                      );
                                    },
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
          selectedIndex: 1,
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

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({
    required this.isSaving,
    required this.onDismiss,
    required this.onSaveTap,
  });

  final bool isSaving;
  final VoidCallback onDismiss;
  final VoidCallback onSaveTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE0E5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: Color(0xFF8E949F),
            size: 30,
          ),
          const SizedBox(height: 10),
          const Text(
            'No matching properties found',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF1F2430),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Would you like to save these preferences so we can match you when a suitable property appears in the future?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8E949F),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1C2A4A),
                      side: const BorderSide(color: Color(0xFFD7DBE2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'No',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : onSaveTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C2A4A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child:
                        isSaving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Text(
                              'Yes, Save It',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                  ),
                ),
              ),
            ],
          ),
        ],
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

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.item, required this.onTap});

  final SearchPropertyItem item;
  final VoidCallback onTap;

  String _buildShortName(String value) {
    final parts =
        value
            .trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .toList();
    if (parts.isEmpty) return 'Unknown';
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts.last}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E2E5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                offset: Offset(0, 2),
                blurRadius: 5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 156,
                  width: double.infinity,
                  child:
                      item.imageUrl == null
                          ? Container(
                            color: const Color(0xFFE7E7E8),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xFF9AA1AD),
                            ),
                          )
                          : Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            cacheWidth: 320,
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
              const SizedBox(height: 10),
              Text(
                item.propertyType,
                style: const TextStyle(
                  color: Color(0xFF1F2430),
                  fontSize: 34 / 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CardInfoLine(
                      label: 'Transaction',
                      value: item.transactionType == 'rent' ? 'Rent' : 'Buy',
                    ),
                    if (item.transactionType == 'rent' && item.rentType != null)
                      _CardInfoLine(
                        label: 'Type of Rent',
                        value:
                            item.rentType == 'monthly' ? 'Monthly' : 'Yearly',
                      ),
                    _CardInfoLine(
                      label: 'Bedrooms',
                      value: '${item.bedrooms ?? '-'}',
                    ),
                    _CardInfoLine(
                      label: 'Bathrooms',
                      value: '${item.bathrooms ?? '-'}',
                    ),
                    _CardInfoLine(
                      label: 'Owner',
                      value: _buildShortName(item.ownerName),
                    ),
                    _CardInfoLine(
                      label: 'Rating',
                      value:
                          item.ownerRating == null
                              ? '-'
                              : item.ownerRating!.toStringAsFixed(1),
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

class _CardInfoLine extends StatelessWidget {
  const _CardInfoLine({required this.label, required this.value});

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
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Color(0xFF7D8491),
                fontSize: 13.5,
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
