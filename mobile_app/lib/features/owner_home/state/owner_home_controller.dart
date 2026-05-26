import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/owner_home_repository.dart';

enum OwnerActivityKind { chat, dealPending, dealCompleted, listingInactive }

class OwnerActivityItem {
  const OwnerActivityItem({
    required this.kind,
    required this.chatId,
    required this.dealId,
    required this.seekerUserId,
    required this.ownerUserId,
    required this.peerName,
    required this.title,
    required this.lastMessageText,
    required this.lastMessageAt,
    required this.propertyId,
    required this.statusLabel,
  });

  final OwnerActivityKind kind;
  final int chatId;
  final int? dealId;
  final String? seekerUserId;
  final String? ownerUserId;
  final String peerName;
  final String title;
  final String lastMessageText;
  final DateTime? lastMessageAt;
  final int? propertyId;
  final String statusLabel;
}

class OwnerDashboardResult {
  const OwnerDashboardResult._({
    required this.success,
    this.errorMessage,
    this.activeListings = 0,
    this.inactiveListings = 0,
    this.pendingDeals = 0,
    this.unreadMessages = 0,
    this.activities = const [],
  });

  final bool success;
  final String? errorMessage;
  final int activeListings;
  final int inactiveListings;
  final int pendingDeals;
  final int unreadMessages;
  final List<OwnerActivityItem> activities;

  factory OwnerDashboardResult.success({
    required int activeListings,
    required int inactiveListings,
    required int pendingDeals,
    required int unreadMessages,
    required List<OwnerActivityItem> activities,
  }) {
    return OwnerDashboardResult._(
      success: true,
      activeListings: activeListings,
      inactiveListings: inactiveListings,
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
      final inactiveListings = await _repository.countInactiveListings(ownerId);
      final pendingDeals = await _repository.countPendingDeals(ownerId);

      final chatRows = await _repository.fetchChatsForUser(ownerId);
      final dealRows = await _repository.fetchDealsForOwner(ownerId);
      final propertyRows = await _repository.fetchPropertiesForOwner(ownerId);
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

      int? parseInt(dynamic value) {
        if (value is int) return value;
        if (value is num) return value.toInt();
        return int.tryParse(value?.toString() ?? '');
      }

      final chatActivities = chatRows
          .where((row) => (row['last_message_text'] as String?)?.trim().isNotEmpty == true)
          .map((row) {
            final ownerUserId = row['owner_user_id']?.toString();
            final seekerUserId = row['seeker_user_id']?.toString();
            final peerId = ownerUserId == ownerId ? seekerUserId : ownerUserId;
            final safePeerId = (peerId == null || peerId.isEmpty) ? '-' : peerId;
            final chatIdRaw = row['chat_id'];
            return OwnerActivityItem(
              kind: OwnerActivityKind.chat,
              chatId:
                  chatIdRaw is int
                      ? chatIdRaw
                      : (chatIdRaw is num ? chatIdRaw.toInt() : 0),
              dealId: null,
              seekerUserId: seekerUserId,
              ownerUserId: ownerUserId,
              peerName: names[safePeerId] ?? 'User',
              title: 'New message',
              lastMessageText: (row['last_message_text'] as String?) ?? '',
              lastMessageAt: parseDate(row['last_message_at']),
              propertyId: null,
              statusLabel: 'Chat',
            );
          })
          .where((item) => item.chatId > 0);

      final dealActivities = dealRows.map((row) {
        final seekerId = row['seeker_id']?.toString() ?? '';
        final dealId = parseInt(row['deal_id']);
        final propertyId = parseInt(row['property_id']);
        final isCompleted = row['done_at'] != null;
        return OwnerActivityItem(
          kind: isCompleted ? OwnerActivityKind.dealCompleted : OwnerActivityKind.dealPending,
          chatId: 0,
          dealId: dealId,
          seekerUserId: seekerId,
          ownerUserId: row['owner_id']?.toString(),
          peerName: names[seekerId] ?? 'Seeker',
          title: isCompleted ? 'Deal completed' : 'Deal requested',
          lastMessageText: isCompleted
              ? 'This property deal was completed successfully.'
              : 'A seeker is waiting for your confirmation.',
          lastMessageAt: parseDate(row['done_at']) ?? parseDate(row['created_at']),
          propertyId: propertyId,
          statusLabel: isCompleted ? 'Completed' : 'Deal',
        );
      });

      final propertyActivities = propertyRows
          .where((row) => ((row['status'] as String?) ?? '').toLowerCase() != 'active')
          .map((row) {
            final type = (row['property_type'] as String?) ?? 'Property';
            final state = (row['property_state'] as String?) ?? '-';
            final city = (row['property_city'] as String?) ?? '-';
            return OwnerActivityItem(
              kind: OwnerActivityKind.listingInactive,
              chatId: 0,
              dealId: null,
              seekerUserId: null,
              ownerUserId: ownerId,
              peerName: type,
              title: 'Listing inactive',
              lastMessageText: '$type in $state / $city is currently hidden.',
              lastMessageAt: parseDate(row['updated_at']),
              propertyId: parseInt(row['property_id']),
              statusLabel: 'Listing',
            );
          });

      final activities = [
        ...chatActivities,
        ...dealActivities,
        ...propertyActivities,
      ]
          .toList()
        ..sort((a, b) {
          final aTime = a.lastMessageAt?.millisecondsSinceEpoch ?? 0;
          final bTime = b.lastMessageAt?.millisecondsSinceEpoch ?? 0;
          return bTime.compareTo(aTime);
        });

      final trimmedActivities = activities
          .take(activityLimit)
          .toList();

      return OwnerDashboardResult.success(
        activeListings: activeListings,
        inactiveListings: inactiveListings,
        pendingDeals: pendingDeals,
        unreadMessages: unreadMessages,
        activities: trimmedActivities,
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
