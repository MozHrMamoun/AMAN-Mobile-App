import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chat_detail_page.dart';
import 'core/app_session.dart';
import 'features/chat/state/chat_list_controller.dart';
import 'features/properties/state/property_detail_controller.dart';

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
        builder: (_) => ChatDetailPage(
          chatId: result.chatId!,
          peerName: result.peerName ?? _item!.ownerName,
        ),
      ),
    );
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
                child: _isLoading
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
                                          child: _item!.imageUrls.isEmpty
                                              ? Container(
                                                  color: const Color(0xFFF8F8F9),
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                    Icons.image_not_supported_outlined,
                                                    color: Color(0xFF9AA1AD),
                                                    size: 36,
                                                  ),
                                                )
                                              : PageView.builder(
                                                  controller: _imagePageController,
                                                  itemCount: _item!.imageUrls.length,
                                                  onPageChanged: (index) {
                                                    setState(() {
                                                      _currentImageIndex = index;
                                                    });
                                                  },
                                                  itemBuilder: (context, index) {
                                                    final imageUrl = _item!.imageUrls[index];
                                                    return Image.network(
                                                      imageUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => Container(
                                                        color: const Color(0xFFF8F8F9),
                                                        alignment: Alignment.center,
                                                        child: const Icon(
                                                          Icons.broken_image_outlined,
                                                          color: Color(0xFF9AA1AD),
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
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: List.generate(
                                            _item!.imageUrls.length,
                                            (index) => Container(
                                              width: 7,
                                              height: 7,
                                              margin: const EdgeInsets.symmetric(horizontal: 3),
                                              decoration: BoxDecoration(
                                                color: index == _currentImageIndex
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8F8F9),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: border),
                                        ),
                                        child: Column(
                                          children: [
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
                                            _DetailRow(label: 'Price', value: _item!.price),
                                            const SizedBox(height: 10),
                                            _DetailRow(label: 'Area', value: _item!.areaSqm),
                                            const SizedBox(height: 10),
                                            _DetailRow(
                                              label: 'Owner',
                                              value: _item!.ownerName,
                                            ),
                                            const SizedBox(height: 10),
                                            _DetailRow(
                                              label: 'Location',
                                              value: _item!.location,
                                              isLink: true,
                                              onTap: () => _openLocation(_item!.location),
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
                                    onPressed: _openOwnerChat,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Contact The Owner',
                                      style: TextStyle(
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
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLink = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool isLink;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final valueWidget = Text(
      value,
      textAlign: TextAlign.end,
      style: TextStyle(
        color: isLink ? const Color(0xFF1A5FB4) : const Color(0xFF6E7583),
        fontSize: 34 / 2,
        fontWeight: FontWeight.w600,
        decoration: isLink ? TextDecoration.underline : TextDecoration.none,
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
        Expanded(
          child: isLink
              ? InkWell(
                  onTap: onTap,
                  child: valueWidget,
                )
              : valueWidget,
        ),
      ],
    );
  }
}
