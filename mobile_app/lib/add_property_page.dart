import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_theme.dart';
import 'core/city_data.dart';
import 'features/properties/state/add_property_controller.dart';
import 'owner_home_page.dart';

class AddPropertyPage extends StatefulWidget {
  const AddPropertyPage({super.key});

  @override
  State<AddPropertyPage> createState() => _AddPropertyPageState();
}

class _AddPropertyPageState extends State<AddPropertyPage> {
  static const String _draftKey = 'add_property_draft';
  bool _isBuySelected = true;
  bool _isSaving = false;
  String? _propertyType;
  String? _rentType;
  String? _propertyState;
  String? _propertyCity;
  String? _bathrooms;
  String? _bedrooms;
  List<XFile> _propertyImageFiles = [];
  XFile? _certificateFile;

  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _locationUrlController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final AddPropertyController _addPropertyController = AddPropertyController();

  final List<String> _propertyTypes = ['Apartment', 'House', 'Land'];
  final List<String> _rentTypes = ['Monthly', 'Yearly'];
  final List<String> _numbers = ['1', '2', '3', '4', '5+'];

  bool get _isLandSelected => _propertyType == 'Land';

  List<String> get _availableCities =>
      _propertyState == null
          ? const []
          : (CityData.citiesByState[_propertyState] ?? const []);

  @override
  void initState() {
    super.initState();
    _priceController.addListener(_saveDraft);
    _areaController.addListener(_saveDraft);
    _locationUrlController.addListener(_saveDraft);
    _descriptionController.addListener(_saveDraft);
    _loadDraft();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _areaController.dispose();
    _locationUrlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null) return;
    try {
      final Map<String, dynamic> data = jsonDecode(raw);
      final List<dynamic> images =
          (data['propertyImages'] as List<dynamic>? ?? const []);
      final String? cert = data['certificateFile'] as String?;
      setState(() {
        _isBuySelected = (data['isBuy'] as bool?) ?? true;
        _propertyType = data['propertyType'] as String?;
        _rentType = data['rentType'] as String?;
        _propertyState = data['propertyState'] as String?;
        _propertyCity = data['propertyCity'] as String?;
        _bedrooms = data['bedrooms'] as String?;
        _bathrooms = data['bathrooms'] as String?;
        _priceController.text = (data['price'] as String?) ?? '';
        _areaController.text = (data['area'] as String?) ?? '';
        _locationUrlController.text = (data['locationUrl'] as String?) ?? '';
        _descriptionController.text = (data['description'] as String?) ?? '';
        _propertyImageFiles =
            images
                .whereType<String>()
                .where((path) => path.isNotEmpty && File(path).existsSync())
                .map(XFile.new)
                .toList();
        _certificateFile =
            (cert != null && cert.isNotEmpty && File(cert).existsSync())
                ? XFile(cert)
                : null;
      });
    } catch (_) {
      // Ignore corrupted draft.
    }
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'isBuy': _isBuySelected,
      'propertyType': _propertyType,
      'rentType': _rentType,
      'propertyState': _propertyState,
      'propertyCity': _propertyCity,
      'bedrooms': _bedrooms,
      'bathrooms': _bathrooms,
      'price': _priceController.text,
      'area': _areaController.text,
      'locationUrl': _locationUrlController.text,
      'description': _descriptionController.text,
      'propertyImages': _propertyImageFiles.map((f) => f.path).toList(),
      'certificateFile': _certificateFile?.path,
    };
    await prefs.setString(_draftKey, jsonEncode(data));
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  void _goToOwnerHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OwnerHomePage()),
    );
  }

  Future<void> _pickPropertyImage() async {
    final List<XFile> picked = await _imagePicker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _propertyImageFiles = [..._propertyImageFiles, ...picked];
      });
      await _saveDraft();
    }
  }

  Future<void> _pickCertificateImage() async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (picked != null) {
      setState(() {
        _certificateFile = picked;
      });
      await _saveDraft();
    }
  }

  Future<void> _removePropertyImage(int index) async {
    setState(() {
      _propertyImageFiles.removeAt(index);
    });
    await _saveDraft();
  }

  Future<void> _reorderPropertyImages(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _propertyImageFiles.removeAt(oldIndex);
      _propertyImageFiles.insert(newIndex, item);
    });
    await _saveDraft();
  }

  Future<void> _addProperty() async {
    setState(() {
      _isSaving = true;
    });

    final result = await _addPropertyController.submit(
      isBuy: _isBuySelected,
      rentType: _rentType,
      propertyType: _propertyType,
      propertyState: _propertyState,
      propertyCity: _propertyCity,
      bedrooms: _bedrooms,
      bathrooms: _bathrooms,
      priceText: _priceController.text,
      areaText: _areaController.text,
      locationUrl: _locationUrlController.text,
      description: _descriptionController.text,
      propertyImages: _propertyImageFiles,
      certificateFile: _certificateFile,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Failed to add property.'),
        ),
      );
      return;
    }

    await _showSavedSuccessfullyDialog();
    await _clearDraft();
    _goToOwnerHome();
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
    const hint = AppColors.hint;

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
                    'Add Property',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 35 / 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _goToOwnerHome,
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
                                    onTap: () {
                                      setState(() {
                                        _isBuySelected = true;
                                        _rentType = null;
                                      });
                                      _saveDraft();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _DealTypeTab(
                                    label: 'Rent',
                                    selected: !_isBuySelected,
                                    onTap: () {
                                      setState(() => _isBuySelected = false);
                                      _saveDraft();
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (!_isBuySelected) ...[
                              const SizedBox(height: 14),
                              _FieldRow(
                                label: 'Type of Rent',
                                child: _SelectField(
                                  value: _rentType,
                                  hint: 'Place Holder...',
                                  items: _rentTypes,
                                  border: border,
                                  hintColor: hint,
                                  onChanged: (v) {
                                    setState(() => _rentType = v);
                                    _saveDraft();
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            _FieldRow(
                              label: 'Property Type',
                              child: _SelectField(
                                value: _propertyType,
                                hint: 'Place Holder...',
                                items: _propertyTypes,
                                border: border,
                                hintColor: hint,
                                onChanged: (v) {
                                  setState(() {
                                    _propertyType = v;
                                    if (_isLandSelected) {
                                      _bedrooms = null;
                                      _bathrooms = null;
                                    }
                                  });
                                  _saveDraft();
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FieldRow(
                              label: 'Property State',
                              child: _SelectField(
                                value: _propertyState,
                                hint: 'Place Holder...',
                                items: CityData.states,
                                border: border,
                                hintColor: hint,
                                onChanged: (v) {
                                  setState(() {
                                    _propertyState = v;
                                    if (!_availableCities.contains(
                                      _propertyCity,
                                    )) {
                                      _propertyCity = null;
                                    }
                                  });
                                  _saveDraft();
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FieldRow(
                              label: 'Property City',
                              child: _SelectField(
                                value: _propertyCity,
                                hint:
                                    _propertyState == null
                                        ? 'Select state first'
                                        : 'Place Holder...',
                                items: _availableCities,
                                border: border,
                                hintColor: hint,
                                onChanged: (v) {
                                  setState(() => _propertyCity = v);
                                  _saveDraft();
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FieldRow(
                              label: 'Bedrooms',
                              child: _SelectField(
                                value: _isLandSelected ? null : _bedrooms,
                                hint:
                                    _isLandSelected ? 'Not used for land' : '4',
                                items: _numbers,
                                border: border,
                                hintColor: hint,
                                enabled: !_isLandSelected,
                                onChanged: (v) {
                                  setState(() => _bedrooms = v);
                                  _saveDraft();
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FieldRow(
                              label: 'Bathrooms',
                              child: _SelectField(
                                value: _isLandSelected ? null : _bathrooms,
                                hint:
                                    _isLandSelected ? 'Not used for land' : '4',
                                items: _numbers,
                                border: border,
                                hintColor: hint,
                                enabled: !_isLandSelected,
                                onChanged: (v) {
                                  setState(() => _bathrooms = v);
                                  _saveDraft();
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FieldRow(
                              label: 'Price',
                              child: _TextFieldBox(
                                controller: _priceController,
                                hint: 'Type price',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                border: border,
                                suffixText: 'SDG',
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FieldRow(
                              label: 'Area (sqm)',
                              child: _TextFieldBox(
                                controller: _areaController,
                                hint: 'Type area',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}$'),
                                  ),
                                ],
                                border: border,
                                suffixText: 'sqm',
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FieldRow(
                              label: 'Location URL',
                              child: _TextFieldBox(
                                controller: _locationUrlController,
                                hint: 'Paste location URL',
                                keyboardType: TextInputType.url,
                                border: border,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FieldRow(
                              label: 'Property Images',
                              child: _AttachmentField(
                                fileName:
                                    _propertyImageFiles.isEmpty
                                        ? null
                                        : '${_propertyImageFiles.length} images selected',
                                buttonLabel: 'Attach Images',
                                onTap: _pickPropertyImage,
                                border: border,
                              ),
                            ),
                            if (_propertyImageFiles.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 82,
                                child: ReorderableListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  onReorder: _reorderPropertyImages,
                                  proxyDecorator:
                                      (child, _, __) => Material(
                                        color: Colors.transparent,
                                        child: child,
                                      ),
                                  itemCount: _propertyImageFiles.length,
                                  itemBuilder: (context, index) {
                                    final file = _propertyImageFiles[index];
                                    return ReorderableDragStartListener(
                                      key: ValueKey('${file.path}-$index'),
                                      index: index,
                                      child: Container(
                                        margin: EdgeInsets.only(
                                          right:
                                              index ==
                                                      _propertyImageFiles
                                                              .length -
                                                          1
                                                  ? 0
                                                  : 10,
                                        ),
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.file(
                                                File(file.path),
                                                width: 82,
                                                height: 82,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            if (index == 0)
                                              Positioned(
                                                left: 6,
                                                top: 6,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF1C2A4A,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'Cover',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            Positioned(
                                              right: 4,
                                              top: 4,
                                              child: InkWell(
                                                onTap:
                                                    () => _removePropertyImage(
                                                      index,
                                                    ),
                                                child: Container(
                                                  width: 22,
                                                  height: 22,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black54,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          11,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.close_rounded,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            _FieldRow(
                              label: 'Certificate',
                              child: _AttachmentField(
                                fileName: _certificateFile?.name,
                                buttonLabel: 'Attach Image',
                                onTap: _pickCertificateImage,
                                border: border,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FieldRow(
                              label: 'Description',
                              alignTop: true,
                              child: Container(
                                height: 66,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F8F9),
                                  border: Border.all(color: border),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: TextField(
                                  controller: _descriptionController,
                                  maxLines: null,
                                  expands: true,
                                  decoration: InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    border: InputBorder.none,
                                    hintText: 'Description...',
                                    hintStyle: TextStyle(
                                      color: Color(0xFFD1D4D9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
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
                                onPressed: _goToOwnerHome,
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
                                onPressed: _isSaving ? null : _addProperty,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child:
                                    _isSaving
                                        ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                        : const Text(
                                          'Add',
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

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.child,
    this.alignTop = false,
  });

  final String label;
  final Widget child;
  final bool alignTop;

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
          crossAxisAlignment:
              alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 4,
              child: Padding(
                padding: EdgeInsets.only(top: alignTop ? 6 : 0),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF1F2430),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    required this.border,
    required this.hintColor,
    this.enabled = true,
  });

  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final Color border;
  final Color hintColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFF8F8F9) : const Color(0xFFEEF0F3),
        border: Border.all(color: enabled ? border : const Color(0xFFE1E4E8)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(
            enabled
                ? Icons.keyboard_arrow_down_rounded
                : Icons.lock_outline_rounded,
            color: enabled ? const Color(0xFF1F2430) : const Color(0xFF9AA1AD),
            size: enabled ? 26 : 20,
          ),
          hint: Text(
            hint,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: enabled ? hintColor : const Color(0xFF9AA1AD),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: TextStyle(
            color: enabled ? const Color(0xFF1F2430) : const Color(0xFF9AA1AD),
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
          onChanged: enabled ? onChanged : null,
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
    required this.border,
    this.inputFormatters,
    this.suffixText,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final Color border;
  final List<TextInputFormatter>? inputFormatters;
  final String? suffixText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F9),
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 12,
          ),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFD1D4D9), fontSize: 14),
          suffixText: suffixText,
          suffixStyle: const TextStyle(
            color: Color(0xFF9AA1AD),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AttachmentField extends StatelessWidget {
  const _AttachmentField({
    required this.fileName,
    required this.buttonLabel,
    required this.onTap,
    required this.border,
  });

  final String? fileName;
  final String buttonLabel;
  final VoidCallback onTap;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final bool hasFile = fileName != null;

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F9),
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color:
                  hasFile ? const Color(0xFFDDE9FF) : const Color(0xFFEDEFF2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              hasFile ? Icons.check_circle_rounded : Icons.image_outlined,
              color: const Color(0xFF1C2A4A),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fileName ?? 'No image selected',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    hasFile ? const Color(0xFF1F2430) : const Color(0xFF9AA1AD),
                fontSize: 13.5,
                fontWeight: hasFile ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onTap,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF1C2A4A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.attach_file_rounded, size: 16),
            label: Text(
              hasFile ? 'Change' : buttonLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
