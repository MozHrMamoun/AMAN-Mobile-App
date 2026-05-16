import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client_provider.dart';

class OwnerHomeRepository {
  OwnerHomeRepository({SupabaseClient? client})
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

  Future<int> countActiveListings(String ownerId) async {
    final rows = await _client
        .from('properties')
        .select('property_id')
        .eq('owner_id', ownerId)
        .eq('status', 'active');
    return (rows as List).length;
  }

  Future<int> countPendingDeals(String ownerId) async {
    final rows = await _client
        .from('deals')
        .select('deal_id')
        .eq('owner_id', ownerId)
        .isFilter('done_at', null);
    return (rows as List).length;
  }

  Future<List<Map<String, dynamic>>> fetchChatsForUser(String userId) async {
    final rows = await _client
        .from('chats')
        .select(
          'chat_id, owner_user_id, seeker_user_id, last_message_text, last_message_at',
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

  Future<int> countUnreadMessages({
    required String currentUserId,
    required List<int> chatIds,
  }) async {
    if (chatIds.isEmpty) return 0;
    final rows = await _client
        .from('chat_messages')
        .select('message_id')
        .inFilter('chat_id', chatIds)
        .isFilter('read_at', null)
        .neq('sender_user_id', currentUserId);
    return (rows as List).length;
  }
}
