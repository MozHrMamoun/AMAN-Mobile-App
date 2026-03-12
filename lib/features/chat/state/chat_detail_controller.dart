import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/chat_repository.dart';

class ChatMessageItem {
  const ChatMessageItem({
    required this.messageId,
    required this.senderUserId,
    required this.messageText,
    required this.createdAt,
    required this.isMine,
  });

  final int messageId;
  final String senderUserId;
  final String messageText;
  final DateTime? createdAt;
  final bool isMine;
}

class ChatDetailResult {
  const ChatDetailResult._({
    required this.success,
    this.errorMessage,
    this.messages = const [],
    this.currentUserId,
    this.peerName,
    this.seekerUserId,
    this.ownerUserId,
    this.propertyId,
  });

  final bool success;
  final String? errorMessage;
  final List<ChatMessageItem> messages;
  final String? currentUserId;
  final String? peerName;
  final String? seekerUserId;
  final String? ownerUserId;
  final int? propertyId;

  factory ChatDetailResult.success({
    required List<ChatMessageItem> messages,
    required String currentUserId,
    required String peerName,
    required String? seekerUserId,
    required String? ownerUserId,
    required int? propertyId,
  }) {
    return ChatDetailResult._(
      success: true,
      messages: messages,
      currentUserId: currentUserId,
      peerName: peerName,
      seekerUserId: seekerUserId,
      ownerUserId: ownerUserId,
      propertyId: propertyId,
    );
  }

  factory ChatDetailResult.error(String message) {
    return ChatDetailResult._(success: false, errorMessage: message);
  }
}

class SendMessageResult {
  const SendMessageResult._({required this.success, this.errorMessage});

  final bool success;
  final String? errorMessage;

  factory SendMessageResult.success() {
    return const SendMessageResult._(success: true);
  }

  factory SendMessageResult.error(String message) {
    return SendMessageResult._(success: false, errorMessage: message);
  }
}

class ChatDetailController {
  ChatDetailController({ChatRepository? repository})
      : _repository = repository ?? ChatRepository();

  final ChatRepository _repository;

  Future<ChatDetailResult> loadChat({
    required int chatId,
    String? peerNameHint,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final currentUserId = _repository.currentUserId;
      if (currentUserId == null) {
        return ChatDetailResult.error('Please login first.');
      }

      final chat = await _repository.fetchChatById(chatId);
      if (chat == null) return ChatDetailResult.error('Chat not found.');

      final ownerId = chat['owner_user_id']?.toString();
      final seekerId = chat['seeker_user_id']?.toString();
      final propertyIdRaw = chat['property_id'];
      final propertyId = propertyIdRaw is int
          ? propertyIdRaw
          : (propertyIdRaw is num ? propertyIdRaw.toInt() : null);
      final isParticipant = ownerId == currentUserId || seekerId == currentUserId;
      if (!isParticipant) {
        return ChatDetailResult.error('You are not allowed to access this chat.');
      }

      final peerId = ownerId == currentUserId ? seekerId : ownerId;
      final peerNames = peerId == null || peerId.isEmpty
          ? const <String, String>{}
          : await _repository.fetchUserNamesByIds([peerId]);
      final peerName = peerNameHint ??
          (peerId == null || peerId.isEmpty
              ? 'User'
              : (peerNames[peerId] ?? 'User'));

      final rows = await _repository.fetchMessagesByChatId(
        chatId,
        limit: limit,
        offset: offset,
      );
      final messages = rows.map((row) {
        final idRaw = row['message_id'];
        final messageId = idRaw is int
            ? idRaw
            : (idRaw is num ? idRaw.toInt() : 0);
        final senderId = row['sender_user_id']?.toString() ?? '';
        final text = (row['message_text'] as String?) ?? '';
        final createdRaw = row['created_at']?.toString();
        final createdAt = createdRaw == null || createdRaw.isEmpty
            ? null
            : DateTime.tryParse(createdRaw);

        return ChatMessageItem(
          messageId: messageId,
          senderUserId: senderId,
          messageText: text,
          createdAt: createdAt,
          isMine: senderId == currentUserId,
        );
      }).toList().reversed.toList();

      await _repository.markOtherMessagesRead(
        chatId: chatId,
        currentUserId: currentUserId,
      );

      return ChatDetailResult.success(
        messages: messages,
        currentUserId: currentUserId,
        peerName: peerName,
        seekerUserId: seekerId,
        ownerUserId: ownerId,
        propertyId: propertyId,
      );
    } on PostgrestException catch (e) {
      return ChatDetailResult.error(
        e.message.isEmpty ? 'Failed to load chat.' : e.message,
      );
    } catch (_) {
      return ChatDetailResult.error('Unexpected error while loading chat.');
    }
  }

  Future<SendMessageResult> sendMessage({
    required int chatId,
    required String messageText,
  }) async {
    final trimmed = messageText.trim();
    if (trimmed.isEmpty) {
      return SendMessageResult.error('Message cannot be empty.');
    }

    try {
      final currentUserId = _repository.currentUserId;
      if (currentUserId == null) {
        return SendMessageResult.error('Please login first.');
      }

      await _repository.insertMessage(
        chatId: chatId,
        senderUserId: currentUserId,
        messageText: trimmed,
      );

      return SendMessageResult.success();
    } on PostgrestException catch (e) {
      return SendMessageResult.error(
        e.message.isEmpty ? 'Failed to send message.' : e.message,
      );
    } catch (_) {
      return SendMessageResult.error('Unexpected error while sending message.');
    }
  }
}
