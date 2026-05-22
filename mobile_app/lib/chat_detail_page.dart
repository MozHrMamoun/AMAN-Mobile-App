import 'package:flutter/material.dart';

import 'features/chat/state/chat_detail_controller.dart';
import 'features/chat/state/chat_list_controller.dart';
import 'features/deals/state/deal_controller.dart';
import 'features/ratings/state/rating_controller.dart';
import 'deal_detail_page.dart';
import 'property_detail_page.dart';

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({
    super.key,
    required this.chatId,
    required this.peerName,
    this.propertyId,
  });

  final int chatId;
  final String peerName;
  final int? propertyId;

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final ChatDetailController _controller = ChatDetailController();
  final RatingController _ratingController = RatingController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  List<ChatMessageItem> _messages = const [];
  String _peerName = 'User';
  String? _seekerUserId;
  String? _ownerUserId;
  int? _propertyId;
  ChatPropertySummary? _propertySummary;
  bool _isDealPending = false;
  bool _isDealCompleted = false;
  bool _dealStatusLoaded = false;
  bool _isDealStatusLoading = false;
  bool _isLoadingMoreMessages = false;
  bool _hasMoreMessages = true;
  int _messagePage = 0;
  String? _currentUserId;
  String? _peerUserId;
  double? _peerAverageRating;
  int _peerRatingCount = 0;
  bool _isRatingLoading = false;
  static const int _messagePageSize = 30;

  String _formatMessageTime(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final h = hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $suffix';
  }

  @override
  void initState() {
    super.initState();
    _peerName = widget.peerName;
    _load();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isDealStatusLoading = true;
      _dealStatusLoaded = false;
      _messagePage = 0;
      _hasMoreMessages = true;
    });

    final chatFuture = _controller.loadChat(
      chatId: widget.chatId,
      peerNameHint: _peerName,
      limit: _messagePageSize,
      offset: _messagePage * _messagePageSize,
    );
    final result = await chatFuture;
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _errorMessage = result.success ? null : result.errorMessage;
      _messages = result.messages;
      _peerName = result.peerName ?? _peerName;
      _seekerUserId = result.seekerUserId;
      _ownerUserId = result.ownerUserId;
      _propertyId = widget.propertyId ?? result.propertyId;
      _propertySummary = result.propertySummary;
      _currentUserId = result.currentUserId;
    });

    _peerUserId = _resolvePeerUserId();
    if (_peerUserId != null) {
      await _loadPeerRating(_peerUserId!);
    }

    if (result.success &&
        result.seekerUserId != null &&
        result.ownerUserId != null &&
        _propertyId != null) {
      await _loadDealPreviewStatus();
    } else {
      if (mounted) {
        setState(() {
          _isDealStatusLoading = false;
          _dealStatusLoaded = true;
        });
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Future<void> _loadDealPreviewStatus() async {
    final seekerId = _seekerUserId;
    final ownerId = _ownerUserId;
    final propertyId = _propertyId;
    if (seekerId == null || ownerId == null || propertyId == null) {
      return;
    }

    final status = await DealController().loadStatus(
      seekerId: seekerId,
      ownerId: ownerId,
      propertyId: propertyId,
    );
    if (!mounted) return;

    if (!status.success) return;
    setState(() {
      _isDealCompleted = status.isCompleted;
      _isDealPending = status.isPending && !status.isCompleted;
      _dealStatusLoaded = true;
      _isDealStatusLoading = false;
    });
  }

  String? _resolvePeerUserId() {
    final currentUserId = _currentUserId;
    final seekerId = _seekerUserId;
    final ownerId = _ownerUserId;
    if (currentUserId == null || seekerId == null || ownerId == null) {
      return null;
    }
    return currentUserId == seekerId ? ownerId : seekerId;
  }

  Future<void> _loadPeerRating(String userId) async {
    setState(() {
      _isRatingLoading = true;
    });
    final result = await _ratingController.fetchUserRatingSummary(
      targetUserId: userId,
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _isRatingLoading = false;
        _peerAverageRating = null;
        _peerRatingCount = 0;
      });
      return;
    }
    setState(() {
      _isRatingLoading = false;
      _peerAverageRating = result.averageRating;
      _peerRatingCount = result.ratingCount;
    });
  }

  Future<void> _loadSilently() async {
    if (!mounted) return;
    final result = await _controller.loadChat(
      chatId: widget.chatId,
      peerNameHint: _peerName,
      limit: _messagePageSize,
      offset: 0,
    );
    if (!mounted || !result.success) return;

    setState(() {
      _messages = result.messages;
      _peerName = result.peerName ?? _peerName;
      _messagePage = 0;
      _hasMoreMessages = result.messages.length == _messagePageSize;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 120 &&
        !_isLoadingMoreMessages &&
        _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMoreMessages || !_hasMoreMessages) return;
    setState(() {
      _isLoadingMoreMessages = true;
    });

    final beforeMax = _scrollController.position.maxScrollExtent;
    final beforeOffset = _scrollController.offset;

    final nextPage = _messagePage + 1;
    final result = await _controller.loadChat(
      chatId: widget.chatId,
      peerNameHint: _peerName,
      limit: _messagePageSize,
      offset: nextPage * _messagePageSize,
    );
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isLoadingMoreMessages = false;
      });
      return;
    }

    final older = result.messages;
    setState(() {
      _messages = [...older, ..._messages];
      _messagePage = nextPage;
      _hasMoreMessages = older.length == _messagePageSize;
      _isLoadingMoreMessages = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final afterMax = _scrollController.position.maxScrollExtent;
      final delta = afterMax - beforeMax;
      _scrollController.jumpTo(beforeOffset + delta);
    });
  }

  Future<void> _send() async {
    if (_isSending) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final tempMessage = ChatMessageItem(
      messageId: -DateTime.now().millisecondsSinceEpoch,
      senderUserId: '',
      messageText: text,
      createdAt: DateTime.now(),
      isMine: true,
    );

    _messageController.clear();

    setState(() {
      _isSending = true;
      _messages = [..._messages, tempMessage];
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    final result = await _controller.sendMessage(
      chatId: widget.chatId,
      messageText: text,
    );
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isSending = false;
        _messages = _messages.where((m) => m.messageId != tempMessage.messageId).toList();
      });
      _messageController.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Failed to send message.')),
      );
      return;
    }

    setState(() {
      _isSending = false;
    });

    await _loadSilently();
  }

  Widget _buildDealActions() {
    if (_isDealStatusLoading) {
      return const Text(
        'Checking deal...',
        style: TextStyle(
          color: Color(0xFF8E949F),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (!_dealStatusLoaded) {
      return const SizedBox.shrink();
    }
    final seekerId = _seekerUserId;
    final ownerId = _ownerUserId;
    final propertyId = _propertyId;

    if (seekerId == null || ownerId == null) {
      return const SizedBox.shrink();
    }

    if (propertyId == null) {
      return const Text(
        'This chat is not linked to a property.',
        style: TextStyle(
          color: Color(0xFF8E949F),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    String statusText;
    Color statusColor;
    if (_isDealCompleted) {
      statusText = 'Deal completed';
      statusColor = const Color(0xFF2F7D32);
    } else if (_isDealPending) {
      statusText = 'Pending confirmation';
      statusColor = const Color(0xFFD68600);
    } else {
      statusText = 'No deal request yet';
      statusColor = const Color(0xFF8E949F);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        TextButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DealDetailPage(
                  peerName: _peerName,
                  seekerUserId: seekerId,
                  ownerUserId: ownerId,
                  propertyId: propertyId,
                  propertySummary: _propertySummary,
                ),
              ),
            );
            await _loadDealPreviewStatus();
            final peerId = _peerUserId;
            if (peerId != null) {
              await _loadPeerRating(peerId);
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF1C2A4A),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('View Deal'),
        ),
      ],
    );
  }

  Widget _buildRatingSummary() {
    if (_isRatingLoading) {
      return const Text(
        'Loading rating...',
        style: TextStyle(
          color: Color(0xFFD1D4D9),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (_peerRatingCount == 0 || _peerAverageRating == null) {
      return const Text(
        'No ratings yet',
        style: TextStyle(
          color: Color(0xFFD1D4D9),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.star_rounded,
          color: Color(0xFFF4C542),
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '${_peerAverageRating!.toStringAsFixed(1)} ($_peerRatingCount)',
          style: const TextStyle(
            color: Color(0xFFD1D4D9),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPropertySummaryCard() {
    final property = _propertySummary;
    if (property == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PropertyDetailPage(propertyId: property.propertyId),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDE0E5)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 62,
                    height: 62,
                    child: property.imageUrl == null || property.imageUrl!.trim().isEmpty
                        ? Container(
                            color: const Color(0xFFF2F2F3),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.home_work_outlined,
                              color: Color(0xFF8E949F),
                            ),
                          )
                        : Image.network(
                            property.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFF2F2F3),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: Color(0xFF8E949F),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2430),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        property.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6E7583),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bedrooms: ${property.bedrooms ?? '-'}   Bathrooms: ${property.bathrooms ?? '-'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6E7583),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Color(0xFF1C2A4A),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1C2A4A);
    const page = Color(0xFFE9EAEC);

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
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _peerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildRatingSummary(),
                    ],
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
                  child: Column(
                    children: [
                      _buildPropertySummaryCard(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _buildDealActions(),
                        ),
                      ),
                      Expanded(
                        child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _errorMessage != null
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Color(0xFF1F2430),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _load,
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      16,
                                      16,
                                      10,
                                    ),
                                    itemCount:
                                        _messages.length + (_isLoadingMoreMessages ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (_isLoadingMoreMessages && index == 0) {
                                        return const Padding(
                                          padding: EdgeInsets.only(bottom: 8),
                                          child: Center(
                                            child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                        );
                                      }
                                      final message = _messages[
                                          index - (_isLoadingMoreMessages ? 1 : 0)];
                                      return Align(
                                        alignment: message.isMine
                                            ? Alignment.centerRight
                                            : Alignment.centerLeft,
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          constraints: const BoxConstraints(
                                            maxWidth: 280,
                                          ),
                                          decoration: BoxDecoration(
                                            color: message.isMine
                                                ? const Color(0xFF1C2A4A)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: message.isMine
                                                  ? const Color(0xFF1C2A4A)
                                                  : const Color(0xFFDDE0E5),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: message.isMine
                                                ? CrossAxisAlignment.end
                                                : CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                message.messageText,
                                                style: TextStyle(
                                                  color: message.isMine
                                                      ? Colors.white
                                                      : const Color(0xFF1F2430),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatMessageTime(message.createdAt),
                                                style: TextStyle(
                                                  color: message.isMine
                                                      ? const Color(0xFFD1D4D9)
                                                      : const Color(0xFF8E949F),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE9EAEC),
                        border: Border(
                          top: BorderSide(color: Color(0xFFDDE0E5)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              maxLines: 3,
                              minLines: 1,
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFDDE0E5),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFDDE0E5),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF1C2A4A),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 46,
                            width: 46,
                            child: ElevatedButton(
                              onPressed: _isSending ? null : _send,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isSending
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
                                  : const Icon(Icons.send_rounded, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
