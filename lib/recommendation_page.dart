import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_session.dart';
import 'core/app_theme.dart';
import 'core/city_data.dart';
import 'features/wished/state/wished_property_controller.dart';
import 'seeker_home_page.dart';

class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  final WishedPropertyController _controller = WishedPropertyController();

  bool _isBuySelected = true;
  String? _propertyType;
  String? _propertyCity;
  String? _bedrooms;
  String? _bathrooms;
  bool _isSaving = false;

  final TextEditingController _priceController = TextEditingController();

  final List<String> _propertyTypes = ['Apartment', 'House', 'Land'];
  final List<String> _counts = ['1', '2', '3', '4', '5+'];

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveWish() async {
    if (AppSession.isGuestMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to use this feature.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final result = await _controller.saveWish(
      isBuy: _isBuySelected,
      propertyType: _propertyType,
      city: _propertyCity,
      bedrooms: _bedrooms,
      bathrooms: _bathrooms,
      priceText: _priceController.text,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Failed to save request.')),
      );
      return;
    }

    await _showSavedSuccessfullyDialog();

    setState(() {
      _propertyType = null;
      _propertyCity = null;
      _bedrooms = null;
      _bathrooms = null;
      _priceController.clear();
    });
  }

  Future<void> _showSavedSuccessfullyDialog() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              width: 290,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2F5),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    offset: Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1C2A4A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Saved\nSuccessfully!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1F2430),
                      fontSize: 36 / 2,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
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
                    'Recommendation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 35 / 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SeekerHomePage(),
                          ),
                        );
                      },
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
                            _FormRow(
                              label: 'Price',
                              child: _TextFieldBox(
                                controller: _priceController,
                                hint: 'Type price',
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FormRow(
                              label: 'Property Type',
                              child: _SelectBox(
                                value: _propertyType,
                                hint: 'Place Holder...',
                                items: _propertyTypes,
                                onChanged: (v) => setState(() => _propertyType = v),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FormRow(
                              label: 'Property City',
                              child: _SelectBox(
                                value: _propertyCity,
                                hint: 'Place Holder...',
                                items: CityData.allCities,
                                onChanged: (v) => setState(() => _propertyCity = v),
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
                            const SizedBox(height: 14),
                            _FormRow(
                              label: 'Bathrooms',
                              child: _SelectBox(
                                value: _bathrooms,
                                hint: '4',
                                items: _counts,
                                onChanged: (v) => setState(() => _bathrooms = v),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveWish,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
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

class _TextFieldBox extends StatelessWidget {
  const _TextFieldBox({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    required this.inputFormatters,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F9),
        border: Border.all(color: const Color(0xFFDDE0E5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
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
