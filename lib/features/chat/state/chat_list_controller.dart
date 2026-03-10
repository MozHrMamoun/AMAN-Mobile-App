import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/chat_repository.dart';

class ChatThreadItem {
  const ChatThreadItem({
    required this.chatId,
    required this.peerUserId,
    required this.peerName,
    required this.lastMessageText,
    required this.lastMessageAt,
  });

  final int chatId;
  final String peerUserId;
  final String peerName;
  final String lastMessageText;
  final DateTime? lastMessageAt;
}

class ChatListResult {
  const ChatListResult._({
    required this.success,
    this.errorMessage,
    this.items = const [],
    this.currentUserId,
    this.currentRole,
  });

  final bool success;
  final String? errorMessage;
  final List<ChatThreadItem> items;
  final String? currentUserId;
  final String? currentRole;

  factory ChatListResult.success({
    required List<ChatThreadItem> items,
    required String currentUserId,
    required String currentRole,
  }) {
    return ChatListResult._(
      success: true,
      items: items,
      currentUserId: currentUserId,
      currentRole: currentRole,
    );
  }

  factory ChatListResult.error(String message) {
    return ChatListResult._(success: false, errorMessage: message);
  }
}

class ChatOpenResult {
  const ChatOpenResult._({
    required this.success,
    this.errorMessage,
    this.chatId,
    this.peerName,
  });

  final bool success;
  final String? errorMessage;
  final int? chatId;
  final String? peerName;

  factory ChatOpenResult.success({
    required int chatId,
    required String peerName,
  }) {
    return ChatOpenResult._(success: true, chatId: chatId, peerName: peerName);
  }

  factory ChatOpenResult.error(String message) {
    return ChatOpenResult._(success: false, errorMessage: message);
  }
}

class ChatListController {
  ChatListController({ChatRepository? repository})
      : _repository = repository ?? ChatRepository();

  final ChatRepository _repository;

  Future<ChatListResult> loadChats() async {
    try {
      final profile = await _repository.fetchCurrentUserProfile();
      if (profile == null) {
        return ChatListResult.error('Please login first.');
      }

      final currentUserId = profile['user_id']?.toString();
      final currentRole =
          ((profile['role'] as String?) ?? 'seeker').toLowerCase();
      if (currentUserId == null || currentUserId.isEmpty) {
        return ChatListResult.error('Invalid current user.');
      }

      final chatRows = await _repository.fetchChatsForUser(currentUserId);
      final peerIds = <String>{};
      for (final row in chatRows) {
        final ownerId = row['owner_user_id']?.toString();
        final seekerId = row['seeker_user_id']?.toString();
        if (ownerId != null &&
            ownerId.isNotEmpty &&
            ownerId != currentUserId) {
          peerIds.add(ownerId);
        }
        if (seekerId != null &&
            seekerId.isNotEmpty &&
            seekerId != currentUserId) {
          peerIds.add(seekerId);
        }
      }

      final namesById = await _repository.fetchUserNamesByIds(peerIds.toList());

      DateTime? parseDate(dynamic value) {
        final raw = value?.toString();
        if (raw == null || raw.isEmpty) return null;
        return DateTime.tryParse(raw);
      }

      int parseInt(dynamic value) {
        if (value is int) return value;
        if (value is num) return value.toInt();
        return int.tryParse(value?.toString() ?? '') ?? 0;
      }

      final items = chatRows.map((row) {
        final ownerId = row['owner_user_id']?.toString();
        final seekerId = row['seeker_user_id']?.toString();
        final peerId = ownerId == currentUserId ? seekerId : ownerId;
        final safePeerId = (peerId == null || peerId.isEmpty) ? '-' : peerId;

        return ChatThreadItem(
          chatId: parseInt(row['chat_id']),
          peerUserId: safePeerId,
          peerName: namesById[safePeerId] ?? 'Unknown',
          lastMessageText:
              (row['last_message_text'] as String?)?.trim().isNotEmpty == true
                  ? (row['last_message_text'] as String)
                  : 'No messages yet.',
          lastMessageAt: parseDate(row['last_message_at']),
        );
      }).toList();

      return ChatListResult.success(
        items: items,
        currentUserId: currentUserId,
        currentRole: currentRole,
      );
    } on PostgrestException catch (e) {
      return ChatListResult.error(
        e.message.isEmpty ? 'Failed to load chats.' : e.message,
      );
    } catch (_) {
      return ChatListResult.error('Unexpected error while loading chats.');
    }
  }

  Future<ChatOpenResult> openOrCreateChatWithOwner({
    required String ownerUserId,
  }) async {
    try {
      final profile = await _repository.fetchCurrentUserProfile();
      if (profile == null) return ChatOpenResult.error('Please login first.');

      final currentUserId = profile['user_id']?.toString();
      final currentRole =
          ((profile['role'] as String?) ?? 'seeker').toLowerCase();
      if (currentUserId == null || currentUserId.isEmpty) {
        return ChatOpenResult.error('Invalid current user.');
      }

      if (ownerUserId.trim().isEmpty) {
        return ChatOpenResult.error('Owner id is missing.');
      }

      late final String ownerId;
      late final String seekerId;
      if (currentRole == 'owner') {
        ownerId = currentUserId;
        seekerId = ownerUserId;
      } else {
        ownerId = ownerUserId;
        seekerId = currentUserId;
      }

      final existing = await _repository.findChat(
        ownerUserId: ownerId,
        seekerUserId: seekerId,
      );
      final chatRow = existing ??
          await _repository.createChat(
            ownerUserId: ownerId,
            seekerUserId: seekerId,
          );

      final chatIdRaw = chatRow['chat_id'];
      final chatId = chatIdRaw is int
          ? chatIdRaw
          : (chatIdRaw is num ? chatIdRaw.toInt() : 0);
      if (chatId <= 0) return ChatOpenResult.error('Invalid chat id.');

      final names = await _repository.fetchUserNamesByIds([ownerId, seekerId]);
      final peerName = currentRole == 'owner'
          ? (names[seekerId] ?? 'Seeker')
          : (names[ownerId] ?? 'Owner');

      return ChatOpenResult.success(chatId: chatId, peerName: peerName);
    } on PostgrestException catch (e) {
      return ChatOpenResult.error(
        e.message.isEmpty ? 'Failed to open chat.' : e.message,
      );
    } catch (_) {
      return ChatOpenResult.error('Unexpected error while opening chat.');
    }
  }
}
