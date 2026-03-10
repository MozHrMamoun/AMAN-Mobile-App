import 'package:flutter/material.dart';

import 'features/chat/state/chat_detail_controller.dart';

class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({
    super.key,
    required this.chatId,
    required this.peerName,
  });

  final int chatId;
  final String peerName;

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final ChatDetailController _controller = ChatDetailController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  List<ChatMessageItem> _messages = const [];
  String _peerName = 'User';

  @override
  void initState() {
    super.initState();
    _peerName = widget.peerName;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _controller.loadChat(
      chatId: widget.chatId,
      peerNameHint: _peerName,
    );
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _errorMessage = result.success ? null : result.errorMessage;
      _messages = result.messages;
      _peerName = result.peerName ?? _peerName;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Future<void> _loadSilently() async {
    final result = await _controller.loadChat(
      chatId: widget.chatId,
      peerNameHint: _peerName,
    );
    if (!mounted || !result.success) return;

    setState(() {
      _messages = result.messages;
      _peerName = result.peerName ?? _peerName;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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
                  Text(
                    _peerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
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
                child: Column(
                  children: [
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
                                    itemCount: _messages.length,
                                    itemBuilder: (context, index) {
                                      final message = _messages[index];
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
                                          child: Text(
                                            message.messageText,
                                            style: TextStyle(
                                              color: message.isMine
                                                  ? Colors.white
                                                  : const Color(0xFF1F2430),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
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
