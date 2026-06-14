import 'package:supabase_flutter/supabase_flutter.dart';

import '../../chat/state/chat_list_controller.dart';
import '../data/deal_repository.dart';

class DealListItem {
  const DealListItem({
    required this.dealId,
    required this.seekerUserId,
    required this.ownerUserId,
    required this.propertyId,
    required this.isCompleted,
    required this.isRejected,
    required this.otherUserName,
    required this.createdAt,
    this.doneAt,
    this.rejectedAt,
    this.propertySummary,
  });

  final int dealId;
  final String seekerUserId;
  final String ownerUserId;
  final int propertyId;
  final bool isCompleted;
  final bool isRejected;
  final String otherUserName;
  final DateTime? createdAt;
  final DateTime? doneAt;
  final DateTime? rejectedAt;
  final ChatPropertySummary? propertySummary;
}

class DealsListResult {
  const DealsListResult._({
    required this.success,
    this.errorMessage,
    this.items = const [],
    this.currentRole,
  });

  final bool success;
  final String? errorMessage;
  final List<DealListItem> items;
  final String? currentRole;

  factory DealsListResult.success({
    required List<DealListItem> items,
    required String currentRole,
  }) {
    return DealsListResult._(
      success: true,
      items: items,
      currentRole: currentRole,
    );
  }

  factory DealsListResult.error(String message) {
    return DealsListResult._(success: false, errorMessage: message);
  }
}

class DealsListController {
  DealsListController({DealRepository? repository})
    : _repository = repository ?? DealRepository();

  final DealRepository _repository;

  Future<DealsListResult> loadDeals() async {
    try {
      final profile = await _repository.fetchCurrentUserProfile();
      if (profile == null) {
        return DealsListResult.error('Please login first.');
      }

      final currentUserId = profile['user_id']?.toString();
      final currentRole =
          (profile['role'] as String?)?.toLowerCase() ?? 'seeker';
      if (currentUserId == null || currentUserId.isEmpty) {
        return DealsListResult.error('Invalid current user.');
      }

      final rows = await _repository.fetchDealsForUser(role: currentRole);

      final otherUserIds = <String>{};
      final propertyIds = <int>{};
      for (final row in rows) {
        final seekerId = row['seeker_id']?.toString() ?? '';
        final ownerId = row['owner_id']?.toString() ?? '';
        final otherId = currentRole == 'owner' ? seekerId : ownerId;
        if (otherId.isNotEmpty) {
          otherUserIds.add(otherId);
        }
        final propertyIdRaw = row['property_id'];
        final propertyId =
            propertyIdRaw is int
                ? propertyIdRaw
                : (propertyIdRaw is num ? propertyIdRaw.toInt() : null);
        if (propertyId != null) {
          propertyIds.add(propertyId);
        }
      }

      final namesById = await _repository.fetchUserNamesByIds(
        otherUserIds.toList(),
      );
      final propertySummaries = await _repository.fetchPropertySummariesByIds(
        propertyIds.toList(),
      );

      DateTime? parseDate(dynamic value) {
        final raw = value?.toString();
        if (raw == null || raw.isEmpty) return null;
        final normalized =
            raw.endsWith('Z') || raw.contains('+') ? raw : '${raw}Z';
        return DateTime.tryParse(normalized);
      }

      int parseInt(dynamic value) {
        if (value is int) return value;
        if (value is num) return value.toInt();
        return int.tryParse(value?.toString() ?? '') ?? 0;
      }

      final items =
          rows.map((row) {
            final dealId = parseInt(row['deal_id']);
            final seekerId = row['seeker_id']?.toString() ?? '';
            final ownerId = row['owner_id']?.toString() ?? '';
            final propertyId = parseInt(row['property_id']);
            final otherId = currentRole == 'owner' ? seekerId : ownerId;
            final propertySummaryRow = propertySummaries[propertyId];

            return DealListItem(
              dealId: dealId,
              seekerUserId: seekerId,
              ownerUserId: ownerId,
              propertyId: propertyId,
              isCompleted: row['done_at'] != null,
              isRejected: row['rejected_at'] != null,
              otherUserName: namesById[otherId] ?? 'User',
              createdAt: parseDate(row['created_at']),
              doneAt: parseDate(row['done_at']),
              rejectedAt: parseDate(row['rejected_at']),
              propertySummary:
                  propertySummaryRow == null
                      ? null
                      : ChatPropertySummary.fromMap(propertySummaryRow),
            );
          }).toList();

      return DealsListResult.success(items: items, currentRole: currentRole);
    } on PostgrestException catch (e) {
      return DealsListResult.error(
        e.message.isEmpty ? 'Failed to load deals.' : e.message,
      );
    } catch (_) {
      return DealsListResult.error('Unexpected error while loading deals.');
    }
  }
}
