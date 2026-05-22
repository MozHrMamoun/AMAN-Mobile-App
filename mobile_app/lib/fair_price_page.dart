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

  Future<void> _showFairPrice() async {
    if (_month == null ||
        _transactionType == null ||
        _propertyType == null ||
        _propertyCity == null ||
        _bedrooms == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fair price fields.')),
      );
      return;
    }

    final monthNumber = _monthToNumber(_month);
    final bedroomCount = _parseBedroomCount(_bedrooms);
    if (monthNumber == null || bedroomCount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid fair price selection.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _averagePrice = null;
      _sampleCount = 0;
      _errorMessage = null;
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
        _errorMessage = result.errorMessage ?? 'Failed to load fair price.';
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
                    'Fair Price',
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
                                onChanged: (v) =>
                                    setState(() => _transactionType = v),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FormRow(
                              label: 'Property Type',
                              child: _SelectBox(
                                value: _propertyType,
                                hint: 'Place Holder...',
                                items: _propertyTypes,
                                onChanged: (v) =>
                                    setState(() => _propertyType = v),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FormRow(
                              label: 'Property City',
                              child: _SelectBox(
                                value: _propertyCity,
                                hint: 'Place Holder...',
                                items: CityData.allCities,
                                onChanged: (v) =>
                                    setState(() => _propertyCity = v),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FormRow(
                              label: 'Bedrooms',
                              child: _SelectBox(
                                value: _bedrooms,
                                hint: '4',
                                items: _counts,
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
                          onPressed: _isLoading ? null : _showFairPrice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isLoading
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
                                  'Show Fair Price',
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
                        child: _errorMessage != null
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
                                        'Fair Price',
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
                                        'Samples: $_sampleCount',
                                        style: const TextStyle(
                                          color: Color(0xFF8E949F),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'Select options and press Show Fair Price.',
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
  });

  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFDDE0E5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF1C2A4A),
            size: 26,
          ),
          hint: Text(
            hint,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFD1D4D9),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: const TextStyle(
            color: Color(0xFF1F2430),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
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
