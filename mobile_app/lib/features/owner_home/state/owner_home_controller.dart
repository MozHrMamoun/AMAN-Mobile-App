import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/owner_home_repository.dart';

class OwnerActivityItem {
  const OwnerActivityItem({
    required this.peerName,
    required this.lastMessageText,
    required this.lastMessageAt,
  });

  final String peerName;
  final String lastMessageText;
  final DateTime? lastMessageAt;
}

class OwnerDashboardResult {
  const OwnerDashboardResult._({
    required this.success,
    this.errorMessage,
    this.activeListings = 0,
    this.pendingDeals = 0,
    this.unreadMessages = 0,
    this.activities = const [],
  });

  final bool success;
  final String? errorMessage;
  final int activeListings;
  final int pendingDeals;
  final int unreadMessages;
  final List<OwnerActivityItem> activities;

  factory OwnerDashboardResult.success({
    required int activeListings,
    required int pendingDeals,
    required int unreadMessages,
    required List<OwnerActivityItem> activities,
  }) {
    return OwnerDashboardResult._(
      success: true,
      activeListings: activeListings,
      pendingDeals: pendingDeals,
      unreadMessages: unreadMessages,
      activities: activities,
    );
  }

  factory OwnerDashboardResult.error(String message) {
    return OwnerDashboardResult._(success: false, errorMessage: message);
  }
}

class OwnerHomeController {
  OwnerHomeController({OwnerHomeRepository? repository})
      : _repository = repository ?? OwnerHomeRepository();

  final OwnerHomeRepository _repository;

  Future<OwnerDashboardResult> loadDashboard({int activityLimit = 5}) async {
    try {
      final profile = await _repository.fetchCurrentUserProfile();
      if (profile == null) {
        return OwnerDashboardResult.error('Please login first.');
      }
      final role = (profile['role'] as String?)?.toLowerCase() ?? 'seeker';
      if (role != 'owner') {
        return OwnerDashboardResult.error('Only owners can access this page.');
      }

      final ownerId = profile['user_id']?.toString();
      if (ownerId == null || ownerId.isEmpty) {
        return OwnerDashboardResult.error('Invalid owner user.');
      }

      final activeListings = await _repository.countActiveListings(ownerId);
      final pendingDeals = await _repository.countPendingDeals(ownerId);

      final chatRows = await _repository.fetchChatsForUser(ownerId);
      final chatIds = chatRows
          .map((row) => row['chat_id'])
          .whereType<num>()
          .map((value) => value.toInt())
          .toList();
      final unreadMessages = await _repository.countUnreadMessages(
        currentUserId: ownerId,
        chatIds: chatIds,
      );

      final peerIds = <String>{};
      for (final row in chatRows) {
        final ownerUserId = row['owner_user_id']?.toString();
        final seekerUserId = row['seeker_user_id']?.toString();
        if (ownerUserId != null && ownerUserId.isNotEmpty && ownerUserId != ownerId) {
          peerIds.add(ownerUserId);
        }
        if (seekerUserId != null && seekerUserId.isNotEmpty && seekerUserId != ownerId) {
          peerIds.add(seekerUserId);
        }
      }
      final names = await _repository.fetchUserNamesByIds(peerIds.toList());

      DateTime? parseDate(dynamic value) {
        final raw = value?.toString();
        if (raw == null || raw.isEmpty) return null;
        final hasOffset = raw.endsWith('Z') || raw.contains('+') || raw.contains('-');
        final normalized = hasOffset ? raw : '${raw}Z';
        return DateTime.tryParse(normalized);
      }

      final activities = chatRows
          .where((row) => (row['last_message_text'] as String?)?.trim().isNotEmpty == true)
          .map((row) {
            final ownerUserId = row['owner_user_id']?.toString();
            final seekerUserId = row['seeker_user_id']?.toString();
            final peerId = ownerUserId == ownerId ? seekerUserId : ownerUserId;
            final safePeerId = (peerId == null || peerId.isEmpty) ? '-' : peerId;
            return OwnerActivityItem(
              peerName: names[safePeerId] ?? 'User',
              lastMessageText: (row['last_message_text'] as String?) ?? '',
              lastMessageAt: parseDate(row['last_message_at']),
            );
          })
          .take(activityLimit)
          .toList();

      return OwnerDashboardResult.success(
        activeListings: activeListings,
        pendingDeals: pendingDeals,
        unreadMessages: unreadMessages,
        activities: activities,
      );
    } on PostgrestException catch (e) {
      return OwnerDashboardResult.error(
        e.message.isEmpty ? 'Failed to load dashboard.' : e.message,
      );
    } catch (_) {
      return OwnerDashboardResult.error('Unexpected error while loading dashboard.');
    }
  }
}
