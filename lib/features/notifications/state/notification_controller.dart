import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/notification_repository.dart';

class NotificationItem {
  const NotificationItem({
    required this.notificationId,
    required this.propertyId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });

  final int notificationId;
  final int? propertyId;
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool isRead;

  factory NotificationItem.fromMap(Map<String, dynamic> row) {
    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    DateTime? parseDate(dynamic value) {
      final raw = value?.toString();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    final notificationId = parseInt(row['notification_id']) ?? 0;

    return NotificationItem(
      notificationId: notificationId,
      propertyId: parseInt(row['property_id']),
      title: (row['title'] as String?) ?? 'Match found',
      body: (row['body'] as String?) ?? '',
      createdAt: parseDate(row['created_at']),
      isRead: row['read_at'] != null,
    );
  }
}

class NotificationResult {
  const NotificationResult._({
    required this.success,
    this.errorMessage,
    this.items = const [],
    this.unreadCount = 0,
  });

  final bool success;
  final String? errorMessage;
  final List<NotificationItem> items;
  final int unreadCount;

  factory NotificationResult.success({
    required List<NotificationItem> items,
    required int unreadCount,
  }) {
    return NotificationResult._(
      success: true,
      items: items,
      unreadCount: unreadCount,
    );
  }

  factory NotificationResult.error(String message) {
    return NotificationResult._(success: false, errorMessage: message);
  }
}

class NotificationController {
  NotificationController({NotificationRepository? repository})
      : _repository = repository ?? NotificationRepository();

  final NotificationRepository _repository;

  Future<NotificationResult> loadNotifications() async {
    try {
      final userId = _repository.currentUserId;
      if (userId == null) {
        return NotificationResult.error('Please login first.');
      }

      final rows = await _repository.fetchNotificationsForUser(userId);
      final items = rows.map(NotificationItem.fromMap).toList();
      final unreadCount = await _repository.fetchUnreadCount(userId);

      return NotificationResult.success(
        items: items,
        unreadCount: unreadCount,
      );
    } on PostgrestException catch (e) {
      return NotificationResult.error(
        e.message.isEmpty ? 'Failed to load notifications.' : e.message,
      );
    } catch (_) {
      return NotificationResult.error(
        'Unexpected error while loading notifications.',
      );
    }
  }

  Future<int> loadUnreadCount() async {
    try {
      final userId = _repository.currentUserId;
      if (userId == null) return 0;
      return await _repository.fetchUnreadCount(userId);
    } catch (_) {
      return 0;
    }
  }

  Future<void> markRead(int notificationId) async {
    await _repository.markNotificationRead(notificationId);
  }
}
