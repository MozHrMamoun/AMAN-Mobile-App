import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chat_detail_page.dart';
import 'core/app_session.dart';
import 'features/chat/state/chat_list_controller.dart';
import 'features/properties/state/property_detail_controller.dart';
import 'update_property_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PropertyDetailPage extends StatefulWidget {
  const PropertyDetailPage({super.key, this.propertyId});

  final int? propertyId;

  @override
  State<PropertyDetailPage> createState() => _PropertyDetailPageState();
}

class _PropertyDetailPageState extends State<PropertyDetailPage> {
  final PropertyDetailController _controller = PropertyDetailController();
  final ChatListController _chatController = ChatListController();
  final PageController _imagePageController = PageController();
  bool _isLoading = true;
  String? _errorMessage;
  PropertyDetailItem? _item;
  int _currentImageIndex = 0;

  bool get _isOwnerViewingOwnProperty {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final item = _item;
    if (currentUserId == null || item == null) return false;
    return item.ownerUserId == currentUserId;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.propertyId;
    if (id == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Property id is missing.';
      });
      return;
    }

    final result = await _controller.loadPropertyDetail(id);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _errorMessage = result.success ? null : result.errorMessage;
      _item = result.item;
    });
  }

  Future<void> _openLocation(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '-') return;

    final directUri = Uri.tryParse(trimmed);
    Uri target;
    if (directUri != null &&
        (directUri.scheme == 'http' || directUri.scheme == 'https')) {
      target = directUri;
    } else {
      target = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(trimmed)}',
      );
    }

    final opened = await launchUrl(
      target,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open location link.')),
      );
    }
  }

  Future<void> _openOwnerChat() async {
    if (_item == null) return;
    if (AppSession.isGuestMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to use this feature.')),
      );
      return;
    }

    final ownerUserId = _item!.ownerUserId;
    if (ownerUserId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owner info is not available.')),
      );
      return;
    }

    final result = await _chatController.openOrCreateChatWithOwner(
      ownerUserId: ownerUserId,
      propertyId: _item!.propertyId,
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
              peerName: result.peerName ?? _item!.ownerName,
              propertyId: _item!.propertyId,
            ),
      ),
    );
  }

  Future<void> _manageProperty() async {
    final item = _item;
    if (item == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UpdatePropertyPage(propertyId: item.propertyId),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1C2A4A);
    const page = Color(0xFFE9EAEC);
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
                    'Property Detail',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 37 / 2,
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
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _errorMessage != null || _item == null
                        ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _errorMessage ?? 'Failed to load property.',
                              style: const TextStyle(
                                color: Color(0xFF1F2430),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                        : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                          child: Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F8F9),
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
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        height: 310,
                                        width: double.infinity,
                                        child:
                                            _item!.imageUrls.isEmpty
                                                ? Container(
                                                  color: const Color(
                                                    0xFFF8F8F9,
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                    Icons
                                                        .image_not_supported_outlined,
                                                    color: Color(0xFF9AA1AD),
                                                    size: 36,
                                                  ),
                                                )
                                                : PageView.builder(
                                                  controller:
                                                      _imagePageController,
                                                  itemCount:
                                                      _item!.imageUrls.length,
                                                  onPageChanged: (index) {
                                                    setState(() {
                                                      _currentImageIndex =
                                                          index;
                                                    });
                                                  },
                                                  itemBuilder: (
                                                    context,
                                                    index,
                                                  ) {
                                                    final imageUrl =
                                                        _item!.imageUrls[index];
                                                    return Image.network(
                                                      imageUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            _,
                                                            __,
                                                            ___,
                                                          ) => Container(
                                                            color: const Color(
                                                              0xFFF8F8F9,
                                                            ),
                                                            alignment:
                                                                Alignment
                                                                    .center,
                                                            child: const Icon(
                                                              Icons
                                                                  .broken_image_outlined,
                                                              color: Color(
                                                                0xFF9AA1AD,
                                                              ),
                                                              size: 36,
                                                            ),
                                                          ),
                                                    );
                                                  },
                                                ),
                                      ),
                                    ),
                                    if (_item!.imageUrls.length > 1) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: List.generate(
                                          _item!.imageUrls.length,
                                          (index) => Container(
                                            width: 7,
                                            height: 7,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  index == _currentImageIndex
                                                      ? const Color(0xFF1C2A4A)
                                                      : const Color(0xFFC5C9D1),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 18),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Expanded(
                                          flex: 3,
                                          child: Text(
                                            'Description',
                                            style: TextStyle(
                                              color: Color(0xFF1F2430),
                                              fontSize: 36 / 2,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            _item!.description,
                                            style: const TextStyle(
                                              color: Color(0xFF6E7583),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              height: 1.25,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        14,
                                        16,
                                        14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F8F9),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: border),
                                      ),
                                      child: Column(
                                        children: [
                                          _DetailRow(
                                            label: 'Transaction Type',
                                            value:
                                                _item!.transactionType.isEmpty
                                                    ? '-'
                                                    : _item!.transactionType[0]
                                                            .toUpperCase() +
                                                        _item!.transactionType
                                                            .substring(1),
                                          ),
                                          if (_item!.transactionType ==
                                                  'rent' &&
                                              _item!.rentType != null) ...[
                                            const SizedBox(height: 10),
                                            _DetailRow(
                                              label: 'Type of Rent',
                                              value:
                                                  _item!.rentType == 'monthly'
                                                      ? 'Monthly'
                                                      : 'Yearly',
                                            ),
                                          ],
                                          const SizedBox(height: 10),
                                          _DetailRow(
                                            label: 'Property Type',
                                            value: _item!.propertyType,
                                          ),
                                          const SizedBox(height: 10),
                                          _DetailRow(
                                            label: 'Property State',
                                            value: _item!.propertyState,
                                          ),
                                          const SizedBox(height: 10),
                                          _DetailRow(
                                            label: 'Property City',
                                            value: _item!.propertyCity,
                                          ),
                                          const SizedBox(height: 10),
                                          _DetailRow(
                                            label: 'Bedrooms',
                                            value: '${_item!.bedrooms ?? '-'}',
                                          ),
                                          const SizedBox(height: 10),
                                          _DetailRow(
                                            label: 'Bathrooms',
                                            value: '${_item!.bathrooms ?? '-'}',
                                          ),
                                          const SizedBox(height: 10),
                                          _DetailRow(
                                            label: 'Price',
                                            value: _item!.price,
                                          ),
                                          const SizedBox(height: 10),
                                          _DetailRow(
                                            label: 'Area',
                                            value: _item!.areaSqm,
                                          ),
                                          const SizedBox(height: 10),
                                          _DetailRow(
                                            label: 'Owner',
                                            value: _item!.ownerName,
                                          ),
                                          const SizedBox(height: 10),
                                          _DetailRow(
                                            label: 'Location',
                                            customValue: _LocationAction(
                                              label: 'View on Map',
                                              onTap:
                                                  () => _openLocation(
                                                    _item!.location,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed:
                                      _isOwnerViewingOwnProperty
                                          ? _manageProperty
                                          : _openOwnerChat,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    _isOwnerViewingOwnProperty
                                        ? 'Manage This Property'
                                        : 'Contact The Owner',
                                    style: const TextStyle(
                                      fontSize: 34 / 2,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, this.value = '', this.customValue});

  final String label;
  final String value;
  final Widget? customValue;

  @override
  Widget build(BuildContext context) {
    final valueChild =
        customValue ??
        Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(
            color: Color(0xFF6E7583),
            fontSize: 34 / 2,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        );

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1F2430),
              fontSize: 34 / 2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: customValue ?? valueChild),
      ],
    );
  }
}

class _LocationAction extends StatelessWidget {
  const _LocationAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF1C2A4A),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Color(0xFF1A5FB4),
                    fontSize: 34 / 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
