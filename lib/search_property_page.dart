import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_theme.dart';
import 'core/city_data.dart';
import 'features/properties/state/search_properties_controller.dart';
import 'search_result_page.dart';
import 'seeker_home_page.dart';

class SearchPropertyPage extends StatefulWidget {
  const SearchPropertyPage({super.key});

  @override
  State<SearchPropertyPage> createState() => _SearchPropertyPageState();
}

class _SearchPropertyPageState extends State<SearchPropertyPage> {
  bool _isBuySelected = true;
  String? _propertyType;
  String? _propertyState;
  String? _propertyCity;
  String? _bathrooms;
  String? _bedrooms;
  final TextEditingController _priceFromController = TextEditingController();
  final TextEditingController _priceToController = TextEditingController();

  final List<String> _propertyTypes = ['Apartment', 'House'];
  final List<String> _roomCounts = ['1', '2', '3', '4', '5+'];

  List<String> get _availableCities =>
      _propertyState == null ? const [] : (CityData.citiesByState[_propertyState] ?? const []);

  void _goToSeekerHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SeekerHomePage()),
    );
  }

  @override
  void dispose() {
    _priceFromController.dispose();
    _priceToController.dispose();
    super.dispose();
  }

  void _onPriceToChanged(String value) {
    final String fromText = _priceFromController.text;
    if (fromText.isEmpty || value.isEmpty) {
      return;
    }

    final int? from = int.tryParse(fromText);
    final int? to = int.tryParse(value);
    if (from == null || to == null || to >= from) {
      return;
    }

    final String corrected = fromText;
    _priceToController.value = TextEditingValue(
      text: corrected,
      selection: TextSelection.collapsed(offset: corrected.length),
    );
  }

  int? _parseRoomFilter(String? value) {
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value.replaceAll('+', ''));
  }

  bool _isAtLeastFilter(String? value) {
    return value != null && value.endsWith('+');
  }

  double? _parsePrice(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    const primary = AppColors.primary;
    const page = AppColors.page;
    const card = AppColors.card;
    const border = AppColors.border;
    const inputBg = AppColors.inputBackground;

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
                    'Search Property',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 37 / 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _goToSeekerHome,
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
                          border: Border.all(color: border),
                          borderRadius: BorderRadius.circular(10),
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
                            Row(
                              children: [
                                Expanded(
                                  child: _DealTypeTab(
                                    label: 'Buy',
                                    selected: _isBuySelected,
                                    onTap: () => setState(() => _isBuySelected = true),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _DealTypeTab(
                                    label: 'Rent',
                                    selected: !_isBuySelected,
                                    onTap: () => setState(() => _isBuySelected = false),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _LabeledRow(
                              label: 'Property Type',
                              child: _SelectBox(
                                hint: 'Place Holder...',
                                value: _propertyType,
                                items: _propertyTypes,
                                onChanged: (value) {
                                  setState(() {
                                    _propertyType = value;
                                  });
                                },
                                border: border,
                                fill: inputBg,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _LabeledRow(
                              label: 'Property State',
                              child: _SelectBox(
                                hint: 'Place Holder...',
                                value: _propertyState,
                                items: CityData.states,
                                onChanged: (value) {
                                  setState(() {
                                    _propertyState = value;
                                    if (!_availableCities.contains(_propertyCity)) {
                                      _propertyCity = null;
                                    }
                                  });
                                },
                                border: border,
                                fill: inputBg,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _LabeledRow(
                              label: 'Property City',
                              child: _SelectBox(
                                hint: _propertyState == null
                                    ? 'Select state first'
                                    : 'Place Holder...',
                                value: _propertyCity,
                                items: _availableCities,
                                onChanged: (value) {
                                  setState(() {
                                    _propertyCity = value;
                                  });
                                },
                                border: border,
                                fill: inputBg,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _LabeledRow(
                              label: 'Bathrooms',
                              child: _SelectBox(
                                hint: '4',
                                value: _bathrooms,
                                items: _roomCounts,
                                onChanged: (value) {
                                  setState(() {
                                    _bathrooms = value;
                                  });
                                },
                                border: border,
                                fill: inputBg,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _LabeledRow(
                              label: 'Bedrooms',
                              child: _SelectBox(
                                hint: '4',
                                value: _bedrooms,
                                items: _roomCounts,
                                onChanged: (value) {
                                  setState(() {
                                    _bedrooms = value;
                                  });
                                },
                                border: border,
                                fill: inputBg,
                              ),
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool compact = constraints.maxWidth < 360;
                                final Widget priceRange = Row(
                                  children: [
                                    Expanded(
                                      child: _TextFieldBox(
                                        controller: _priceFromController,
                                        hint: 'From',
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        border: border,
                                        fill: inputBg,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'TO',
                                      style: TextStyle(
                                        color: Color(0xFF1F2430),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _TextFieldBox(
                                        controller: _priceToController,
                                        hint: 'To',
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        border: border,
                                        fill: inputBg,
                                        onChanged: _onPriceToChanged,
                                      ),
                                    ),
                                  ],
                                );

                                if (compact) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Price',
                                        style: TextStyle(
                                          color: Color(0xFF1F2430),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      priceRange,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    const Expanded(
                                      flex: 4,
                                      child: Text(
                                        'Price',
                                        style: TextStyle(
                                          color: Color(0xFF1F2430),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Expanded(flex: 6, child: priceRange),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: ElevatedButton(
                                onPressed: _goToSeekerHome,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: ElevatedButton(
                                onPressed: () {
                                  final criteria = SearchCriteria(
                                    transactionType: _isBuySelected ? 'buy' : 'rent',
                                    propertyType: _propertyType,
                                    propertyState: _propertyState,
                                    propertyCity: _propertyCity,
                                    bathrooms: _parseRoomFilter(_bathrooms),
                                    bathroomsAtLeast: _isAtLeastFilter(_bathrooms),
                                    bedrooms: _parseRoomFilter(_bedrooms),
                                    bedroomsAtLeast: _isAtLeastFilter(_bedrooms),
                                    minPrice: _parsePrice(_priceFromController.text),
                                    maxPrice: _parsePrice(_priceToController.text),
                                  );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SearchResultPage(criteria: criteria),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Search',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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

class _DealTypeTab extends StatelessWidget {
  const _DealTypeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Material(
        color: selected ? const Color(0xFF1C2A4A) : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          borderRadius: BorderRadius.circular(2),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF1F2430),
                fontSize: 16,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  const _LabeledRow({required this.label, required this.child});

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
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.border,
    required this.fill,
  });

  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final Color border;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
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

class _TextFieldBox extends StatelessWidget {
  const _TextFieldBox({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    required this.inputFormatters,
    required this.border,
    required this.fill,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final Color border;
  final Color fill;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFFD1D4D9),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
