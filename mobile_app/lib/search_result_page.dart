import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final TextEditingController _priceFromController = TextEditingController();
  final TextEditingController _priceToController = TextEditingController();
  bool _isLoading = true;
  String? _errorMessage;
  List<SearchPropertyItem> _items = const [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  int _unreadNotifications = 0;
  bool _isSavingPreference = false;
  late SearchCriteria _criteria;
  static const int _pageSize = 20;
  static const List<String> _roomCounts = ['Any', '1', '2', '3', '4', '5+'];
  String _selectedBedrooms = 'Any';
  String _selectedBathrooms = 'Any';

  @override
  void initState() {
    super.initState();
    _criteria = widget.criteria;
    _selectedBedrooms = _countToFilterLabel(
      _criteria.bedrooms,
      _criteria.bedroomsAtLeast,
    );
    _selectedBathrooms = _countToFilterLabel(
      _criteria.bathrooms,
      _criteria.bathroomsAtLeast,
    );
    if (_criteria.minPrice != null) {
      _priceFromController.text = _criteria.minPrice!.toStringAsFixed(0);
    }
    if (_criteria.maxPrice != null) {
      _priceToController.text = _criteria.maxPrice!.toStringAsFixed(0);
    }
    _load(reset: true);
    _loadNotificationCount();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _priceFromController.dispose();
    _priceToController.dispose();
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
      _criteria,
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

    final preferredPrice = _criteria.maxPrice ?? _criteria.minPrice;
    final result = await _wishedPropertyController.saveWish(
      isBuy: _criteria.transactionType.toLowerCase() != 'rent',
      rentType: _formatRentType(_criteria.rentType),
      propertyType: _criteria.propertyType,
      city: _criteria.propertyCity,
      bedrooms: _countToLabel(_criteria.bedrooms, _criteria.bedroomsAtLeast),
      bathrooms: _countToLabel(_criteria.bathrooms, _criteria.bathroomsAtLeast),
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

  String _countToFilterLabel(int? value, bool atLeast) {
    if (value == null) return 'Any';
    if (atLeast && value >= 5) return '5+';
    return value.toString();
  }

  int? _parseCountFilter(String value) {
    if (value == 'Any') return null;
    return int.tryParse(value.replaceAll('+', ''));
  }

  bool _isAtLeastFilter(String value) {
    return value.endsWith('+');
  }

  double? _parsePrice(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  Future<void> _applyTopFilters() async {
    FocusScope.of(context).unfocus();

    final minPrice = _parsePrice(_priceFromController.text);
    final rawMaxPrice = _parsePrice(_priceToController.text);
    final maxPrice =
        minPrice != null && rawMaxPrice != null && rawMaxPrice < minPrice
            ? minPrice
            : rawMaxPrice;

    setState(() {
      _criteria = _criteria.copyWith(
        bedrooms: _parseCountFilter(_selectedBedrooms),
        bedroomsAtLeast: _isAtLeastFilter(_selectedBedrooms),
        clearBedrooms: _selectedBedrooms == 'Any',
        bathrooms: _parseCountFilter(_selectedBathrooms),
        bathroomsAtLeast: _isAtLeastFilter(_selectedBathrooms),
        clearBathrooms: _selectedBathrooms == 'Any',
        minPrice: minPrice,
        clearMinPrice: minPrice == null,
        maxPrice: maxPrice,
        clearMaxPrice: maxPrice == null,
      );
    });

    await _load(reset: true);
  }

  Future<void> _clearTopFilters() async {
    FocusScope.of(context).unfocus();
    _priceFromController.clear();
    _priceToController.clear();
    setState(() {
      _selectedBedrooms = 'Any';
      _selectedBathrooms = 'Any';
      _criteria = _criteria.copyWith(
        clearBedrooms: true,
        clearBathrooms: true,
        clearMinPrice: true,
        clearMaxPrice: true,
      );
    });
    await _load(reset: true);
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
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: _ResultsFilterCard(
                          selectedBedrooms: _selectedBedrooms,
                          selectedBathrooms: _selectedBathrooms,
                          roomCounts: _roomCounts,
                          priceFromController: _priceFromController,
                          priceToController: _priceToController,
                          onBedroomsChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedBedrooms = value;
                            });
                          },
                          onBathroomsChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedBathrooms = value;
                            });
                          },
                          onApply: _applyTopFilters,
                          onClear: _clearTopFilters,
                        ),
                      ),
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
                                      onDismiss:
                                          () => Navigator.of(context).pop(),
                                      onSaveTap: _openRecommendation,
                                    ),
                                  ),
                                )
                                : RefreshIndicator(
                                  onRefresh: () => _load(reset: true),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final showSingleColumn =
                                          constraints.maxWidth < 350;
                                      return GridView.builder(
                                        controller: _scrollController,
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          16,
                                        ),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount:
                                                  showSingleColumn ? 1 : 2,
                                              crossAxisSpacing: 12,
                                              mainAxisSpacing: 12,
                                              mainAxisExtent:
                                                  showSingleColumn ? 278 : 292,
                                            ),
                                        itemCount:
                                            _items.length +
                                            (_isLoadingMore
                                                ? 1
                                                : (!_hasMore ? 1 : 0)),
                                        itemBuilder: (context, index) {
                                          if (index >= _items.length) {
                                            if (_isLoadingMore) {
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                            }
                                            return _SearchReachedEndState(
                                              isSaving: _isSavingPreference,
                                              onSaveTap: _openRecommendation,
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
                                                        propertyId:
                                                            item.propertyId,
                                                      ),
                                                ),
                                              );
                                            },
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

class _ResultsFilterCard extends StatelessWidget {
  const _ResultsFilterCard({
    required this.selectedBedrooms,
    required this.selectedBathrooms,
    required this.roomCounts,
    required this.priceFromController,
    required this.priceToController,
    required this.onBedroomsChanged,
    required this.onBathroomsChanged,
    required this.onApply,
    required this.onClear,
  });

  final String selectedBedrooms;
  final String selectedBathrooms;
  final List<String> roomCounts;
  final TextEditingController priceFromController;
  final TextEditingController priceToController;
  final ValueChanged<String?> onBedroomsChanged;
  final ValueChanged<String?> onBathroomsChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE0E5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E1C2A4A),
            offset: Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: Color(0xFF1C2A4A), size: 16),
              SizedBox(width: 6),
              Text(
                'Refine Results',
                style: TextStyle(
                  color: Color(0xFF1F2430),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _FilterDropdown(
                  label: 'Bedrooms',
                  value: selectedBedrooms,
                  items: roomCounts,
                  onChanged: onBedroomsChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FilterDropdown(
                  label: 'Bathrooms',
                  value: selectedBathrooms,
                  items: roomCounts,
                  onChanged: onBathroomsChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _FilterTextField(
                  label: 'Price From',
                  controller: priceFromController,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FilterTextField(
                  label: 'Price To',
                  controller: priceToController,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onClear,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1C2A4A),
                    side: const BorderSide(color: Color(0xFFD7DBE2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: const Size.fromHeight(38),
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C2A4A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: const Size.fromHeight(38),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
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

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF4A5160),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF7F8FA),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDDE0E5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDDE0E5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1C2A4A)),
            ),
          ),
          items:
              items
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item),
                    ),
                  )
                  .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _FilterTextField extends StatelessWidget {
  const _FilterTextField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF4A5160),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: label.endsWith('From') ? 'Minimum' : 'Maximum',
            filled: true,
            fillColor: const Color(0xFFF7F8FA),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDDE0E5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDDE0E5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1C2A4A)),
            ),
          ),
        ),
      ],
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

class _SearchReachedEndState extends StatelessWidget {
  const _SearchReachedEndState({
    required this.isSaving,
    required this.onSaveTap,
  });

  final bool isSaving;
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.travel_explore_rounded,
            color: Color(0xFF8E949F),
            size: 30,
          ),
          const SizedBox(height: 10),
          const Text(
            'Reached the end of the results',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF1F2430),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Didn't find exactly what you like? Save this search as a recommendation and we can match you when something closer appears.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8E949F),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
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
                        'Save As Recommendation',
                        style: TextStyle(
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
          padding: const EdgeInsets.all(9),
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
                  height: 124,
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
              const SizedBox(height: 8),
              Text(
                item.propertyType,
                style: const TextStyle(
                  color: Color(0xFF1F2430),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
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
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Color(0xFF4A5160),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Color(0xFF7D8491),
                fontSize: 12.5,
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
