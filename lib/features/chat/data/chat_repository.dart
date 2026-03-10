import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client_provider.dart';

class ChatRepository {
  ChatRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<Map<String, dynamic>?> fetchCurrentUserProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;

    final row = await _client
        .from('user')
        .select('user_id, role, full_name')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> fetchChatsForUser(String userId) async {
    final rows = await _client
        .from('chats')
        .select(
          'chat_id, owner_user_id, seeker_user_id, last_message_text, last_message_at, created_at',
        )
        .or('owner_user_id.eq.$userId,seeker_user_id.eq.$userId')
        .order('last_message_at', ascending: false);

    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, String>> fetchUserNamesByIds(List<String> userIds) async {
    if (userIds.isEmpty) return const {};

    final rows = await _client
        .from('user')
        .select('user_id, full_name')
        .inFilter('user_id', userIds);

    final result = <String, String>{};
    for (final raw in (rows as List)) {
      final row = Map<String, dynamic>.from(raw as Map);
      final userId = row['user_id']?.toString();
      if (userId == null || userId.isEmpty) continue;
      result[userId] = (row['full_name'] as String?) ?? 'Unknown';
    }
    return result;
  }

  Future<Map<String, dynamic>?> findChat({
    required String ownerUserId,
    required String seekerUserId,
  }) async {
    final row = await _client
        .from('chats')
        .select('chat_id, owner_user_id, seeker_user_id')
        .eq('owner_user_id', ownerUserId)
        .eq('seeker_user_id', seekerUserId)
        .maybeSingle();

    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> createChat({
    required String ownerUserId,
    required String seekerUserId,
  }) async {
    final row = await _client
        .from('chats')
        .insert({
          'owner_user_id': ownerUserId,
          'seeker_user_id': seekerUserId,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('chat_id, owner_user_id, seeker_user_id')
        .single();

    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>?> fetchChatById(int chatId) async {
    final row = await _client
        .from('chats')
        .select('chat_id, owner_user_id, seeker_user_id')
        .eq('chat_id', chatId)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> fetchMessagesByChatId(int chatId) async {
    final rows = await _client
        .from('chat_messages')
        .select('message_id, chat_id, sender_user_id, message_text, created_at, read_at')
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);

    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> insertMessage({
    required int chatId,
    required String senderUserId,
    required String messageText,
  }) async {
    await _client.from('chat_messages').insert({
      'chat_id': chatId,
      'sender_user_id': senderUserId,
      'message_text': messageText,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> markOtherMessagesRead({
    required int chatId,
    required String currentUserId,
  }) async {
    await _client
        .from('chat_messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('chat_id', chatId)
        .neq('sender_user_id', currentUserId)
        .isFilter('read_at', null);
  }
}
