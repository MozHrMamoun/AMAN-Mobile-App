import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'features/properties/state/update_property_controller.dart';

class UpdatePropertyPage extends StatefulWidget {
  const UpdatePropertyPage({super.key, required this.propertyId});

  final int propertyId;

  @override
  State<UpdatePropertyPage> createState() => _UpdatePropertyPageState();
}

class _UpdatePropertyPageState extends State<UpdatePropertyPage> {
  final List<XFile> _propertyImageFiles = [];
  bool _isActive = true;
  bool _isLoading = true;
  bool _isSubmitting = false;

  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final UpdatePropertyController _controller = UpdatePropertyController();

  @override
  void initState() {
    super.initState();
    _loadProperty();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadProperty() async {
    final result = await _controller.loadProperty(widget.propertyId);

    if (!mounted) return;

    if (!result.success || result.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Failed to load property.')),
      );
      Navigator.of(context).pop();
      return;
    }

    _priceController.text = result.data!.price;
    _locationController.text = result.data!.location;
    _descriptionController.text = result.data!.description;
    _isActive = result.data!.isActive;

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _pickPropertyImages() async {
    final picked = await _imagePicker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _propertyImageFiles
          ..clear()
          ..addAll(picked);
      });
    }
  }

  Future<void> _updateProperty() async {
    setState(() {
      _isSubmitting = true;
    });

    final result = await _controller.updateProperty(
      propertyId: widget.propertyId,
      priceText: _priceController.text,
      location: _locationController.text,
      description: _descriptionController.text,
      isActive: _isActive,
      newImages: _propertyImageFiles,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Failed to update property.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Property updated successfully.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1C2A4A);
    const page = Color(0xFFE9EAEC);
    const card = Color(0xFFF1F1F2);
    const border = Color(0xFFDDE0E5);

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
                    'Update Property',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 35 / 2,
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
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
                                  _LabeledRow(
                                    label: 'Price',
                                    child: _TextFieldBox(
                                      controller: _priceController,
                                      hint: 'Type price',
                                      keyboardType: const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'^\d*\.?\d{0,2}$'),
                                        ),
                                      ],
                                      border: border,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _LabeledRow(
                                    label: 'Property Location',
                                    child: _TextFieldBox(
                                      controller: _locationController,
                                      hint: 'Paste location URL',
                                      keyboardType: TextInputType.url,
                                      border: border,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _LabeledRow(
                                    label: 'Property Images',
                                    child: _AttachmentField(
                                      fileName: _propertyImageFiles.isEmpty
                                          ? null
                                          : '${_propertyImageFiles.length} images selected',
                                      buttonLabel: 'Attach Images',
                                      onTap: _pickPropertyImages,
                                      border: border,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _LabeledRow(
                                    label: 'Description',
                                    alignTop: true,
                                    child: Container(
                                      height: 66,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F8F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: border),
                                      ),
                                      child: TextField(
                                        controller: _descriptionController,
                                        maxLines: null,
                                        expands: true,
                                        decoration: const InputDecoration(
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
                                  const SizedBox(height: 24),
                                  _LabeledRow(
                                    label: 'Status',
                                    forceInline: true,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: SizedBox(
                                        height: 34,
                                        child: FittedBox(
                                          fit: BoxFit.contain,
                                          child: Switch(
                                            value: _isActive,
                                            onChanged: (value) {
                                              setState(() {
                                                _isActive = value;
                                              });
                                            },
                                            activeColor: Colors.white,
                                            activeTrackColor: primary,
                                            inactiveThumbColor: Colors.white,
                                            inactiveTrackColor: const Color(0xFFB5BBC7),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: 36,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _updateProperty,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isSubmitting
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
                                        'Update Property',
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

class _LabeledRow extends StatelessWidget {
  const _LabeledRow({
    required this.label,
    required this.child,
    this.alignTop = false,
    this.forceInline = false,
  });

  final String label;
  final Widget child;
  final bool alignTop;
  final bool forceInline;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = !forceInline && constraints.maxWidth < 360;

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

class _TextFieldBox extends StatelessWidget {
  const _TextFieldBox({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    required this.border,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final Color border;
  final List<TextInputFormatter>? inputFormatters;

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
              color: hasFile ? const Color(0xFFDDE9FF) : const Color(0xFFEDEFF2),
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
                color: hasFile ? const Color(0xFF1F2430) : const Color(0xFF9AA1AD),
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
