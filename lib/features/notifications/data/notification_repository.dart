import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client_provider.dart';

class NotificationRepository {
  NotificationRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> fetchNotificationsForUser(
    String userId,
  ) async {
    final rows = await _client
        .from('notifications')
        .select(
          'notification_id, seeker_id, wish_id, property_id, title, body, created_at, read_at',
        )
        .eq('seeker_id', userId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<int> fetchUnreadCount(String userId) async {
    final rows = await _client
        .from('notifications')
        .select('notification_id')
        .eq('seeker_id', userId)
        .isFilter('read_at', null);

    return (rows as List).length;
  }

  Future<void> markNotificationRead(int notificationId) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('notification_id', notificationId);
  }
}
