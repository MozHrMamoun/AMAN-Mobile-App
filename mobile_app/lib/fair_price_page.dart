import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'core/city_data.dart';
import 'features/fair_price/state/fair_price_controller.dart';

class FairPricePage extends StatefulWidget {
  const FairPricePage({super.key});

  @override
  State<FairPricePage> createState() => _FairPricePageState();
}

class _FairPricePageState extends State<FairPricePage> {
  final FairPriceController _controller = FairPriceController();

  final List<String> _propertyTypes = ['Apartment', 'House', 'Land'];
  final List<String> _counts = ['1', '2', '3', '4', '5+'];
  final List<String> _months = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final List<String> _transactionTypes = ['Buy', 'Rent'];

  String? _month;
  String? _transactionType;
  String? _propertyType;
  String? _propertyCity;
  String? _bedrooms;
  bool _isLoading = false;
  double? _averagePrice;
  int _sampleCount = 0;
  String? _errorMessage;
  String? _formMessage;
  bool _hasSearched = false;

  bool get _isLandSelected => _propertyType == 'Land';

  int? _parseBedroomCount(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value == '5+') return 5;
    return int.tryParse(value);
  }

  int? _monthToNumber(String? monthName) {
    if (monthName == null) return null;
    final index = _months.indexOf(monthName);
    if (index == -1) return null;
    return index + 1;
  }

  Future<void> _pickCity() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _SearchableSelectionSheet(
            title: 'Select City',
            items: CityData.allCities,
            selectedValue: _propertyCity,
          ),
    );

    if (!mounted || selected == null) return;
    setState(() {
      _propertyCity = selected;
    });
  }

  Future<void> _showAveragePrice() async {
    if (_month == null ||
        _transactionType == null ||
        _propertyType == null ||
        _propertyCity == null ||
        _bedrooms == null) {
      setState(() {
        _formMessage = 'Please complete all average price fields.';
      });
      return;
    }

    final monthNumber = _monthToNumber(_month);
    final bedroomCount = _parseBedroomCount(_bedrooms);
    if (monthNumber == null || bedroomCount == null) {
      setState(() {
        _formMessage = 'Invalid average price selection.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _averagePrice = null;
      _sampleCount = 0;
      _errorMessage = null;
      _formMessage = null;
      _hasSearched = true;
    });

    final now = DateTime.now();
    final monthStart = DateTime(now.year, monthNumber, 1);
    final monthStartText = monthStart.toIso8601String().split('T').first;

    final result = await _controller.fetchAverage(
      monthStart: monthStartText,
      transactionType: _transactionType!,
      propertyType: _propertyType!,
      propertyCity: _propertyCity!,
      bedrooms: bedroomCount,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage ?? 'Failed to load average price.';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _averagePrice = result.averagePrice;
      _sampleCount = result.sampleCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    const primary = AppColors.primary;
    const page = AppColors.page;
    const card = AppColors.card;
    const border = AppColors.border;

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
                  const Text(
                    'Average Price',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    children: [
                      if (_formMessage != null) ...[
                        _InlineHintCard(message: _formMessage!),
                        const SizedBox(height: 14),
                      ],
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: border),
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
                            _FormRow(
                              label: 'Month',
                              child: _SelectBox(
                                value: _month,
                                hint: 'Place Holder...',
                                items: _months,
                                onChanged: (v) => setState(() => _month = v),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FormRow(
                              label: 'Transaction Type',
                              child: _SelectBox(
                                value: _transactionType,
                                hint: 'Place Holder...',
                                items: _transactionTypes,
                                onChanged:
                                    (v) => setState(() => _transactionType = v),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FormRow(
                              label: 'Property Type',
                              child: _SelectBox(
                                value: _propertyType,
                                hint: 'Place Holder...',
                                items: _propertyTypes,
                                onChanged:
                                    (v) => setState(() {
                                      _propertyType = v;
                                      if (_isLandSelected) {
                                        _bedrooms = null;
                                      }
                                    }),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FormRow(
                              label: 'Property City',
                              child: _SearchTriggerField(
                                hint: 'Property City',
                                value: _propertyCity,
                                onTap: _pickCity,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FormRow(
                              label: 'Bedrooms',
                              child: _SelectBox(
                                value: _isLandSelected ? null : _bedrooms,
                                hint:
                                    _isLandSelected ? 'Not used for land' : '4',
                                items: _counts,
                                enabled: !_isLandSelected,
                                onChanged: (v) => setState(() => _bedrooms = v),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _showAveragePrice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child:
                              _isLoading
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
                                    'Show Average Price',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000000),
                              offset: Offset(0, 3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child:
                            _errorMessage != null
                                ? Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFB00020),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                                : _averagePrice != null
                                ? Column(
                                  children: [
                                    const Text(
                                      'Average Price',
                                      style: TextStyle(
                                        color: Color(0xFF1F2430),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _averagePrice!.toStringAsFixed(2),
                                      style: const TextStyle(
                                        color: Color(0xFF1C2A4A),
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Based on $_sampleCount listings',
                                      style: const TextStyle(
                                        color: Color(0xFF8E949F),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                                : _hasSearched
                                ? const Text(
                                  'No average price data was found for this selection. Try a different month, city, or property type.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF8E949F),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                )
                                : const Text(
                                  'Select options and press Show Average Price.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF8E949F),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
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

class _InlineHintCard extends StatelessWidget {
  const _InlineHintCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF4C7B5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFC2410C),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFC2410C),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 360;

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1F2430),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              child,
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1F2430),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(flex: 6, child: child),
          ],
        );
      },
    );
  }
}

class _SelectBox extends StatelessWidget {
  const _SelectBox({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFF8F8F9) : const Color(0xFFEEF0F3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: enabled ? const Color(0xFFDDE0E5) : const Color(0xFFE1E4E8),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(
            enabled
                ? Icons.keyboard_arrow_down_rounded
                : Icons.lock_outline_rounded,
            color: enabled ? const Color(0xFF1C2A4A) : const Color(0xFF9AA1AD),
            size: enabled ? 26 : 20,
          ),
          hint: Text(
            hint,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  enabled ? const Color(0xFFD1D4D9) : const Color(0xFF9AA1AD),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: TextStyle(
            color: enabled ? const Color(0xFF1F2430) : const Color(0xFF9AA1AD),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          items:
              items
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
          onChanged: enabled ? onChanged : null,
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
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F9),
            borderRadius: BorderRadius.circular(6),
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
                            ? const Color(0xFFD1D4D9)
                            : const Color(0xFF1F2430),
                    fontSize: 15,
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
