import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client_provider.dart';

class DealRepository {
  DealRepository({SupabaseClient? client})
    : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<Map<String, dynamic>?> fetchCurrentUserProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;

    final row =
        await _client
            .from('user')
            .select('user_id, role')
            .eq('user_id', userId)
            .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>?> findLatestDeal({
    required String seekerId,
    required String ownerId,
    required int propertyId,
  }) async {
    final rows = await _client
        .from('deals')
        .select(
          'deal_id, seeker_id, owner_id, property_id, done_at, rejected_at',
        )
        .eq('seeker_id', seekerId)
        .eq('owner_id', ownerId)
        .eq('property_id', propertyId)
        .order('created_at', ascending: false)
        .limit(1);

    final list = (rows as List);
    if (list.isEmpty) return null;
    return Map<String, dynamic>.from(list.first as Map);
  }

  Future<Map<String, dynamic>?> findLatestDealByUsers({
    required String seekerId,
    required String ownerId,
  }) async {
    final rows = await _client
        .from('deals')
        .select(
          'deal_id, seeker_id, owner_id, property_id, done_at, rejected_at',
        )
        .eq('seeker_id', seekerId)
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false)
        .limit(1);

    final list = (rows as List);
    if (list.isEmpty) return null;
    return Map<String, dynamic>.from(list.first as Map);
  }

  Future<Map<String, dynamic>?> findPendingDeal({
    required String seekerId,
    required String ownerId,
    required int propertyId,
  }) async {
    final row =
        await _client
            .from('deals')
            .select(
              'deal_id, seeker_id, owner_id, property_id, done_at, rejected_at',
            )
            .eq('seeker_id', seekerId)
            .eq('owner_id', ownerId)
            .eq('property_id', propertyId)
            .isFilter('done_at', null)
            .isFilter('rejected_at', null)
            .maybeSingle();

    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> createPendingDeal({
    required String seekerId,
    required String ownerId,
    required int propertyId,
  }) async {
    final row =
        await _client
            .from('deals')
            .insert({
              'seeker_id': seekerId,
              'owner_id': ownerId,
              'property_id': propertyId,
              'done_at': null,
              'rejected_at': null,
            })
            .select(
              'deal_id, seeker_id, owner_id, property_id, done_at, rejected_at',
            )
            .single();

    return Map<String, dynamic>.from(row);
  }

  Future<void> confirmDeal({required int dealId}) async {
    await _client
        .from('deals')
        .update({
          'done_at': DateTime.now().toIso8601String(),
          'rejected_at': null,
        })
        .eq('deal_id', dealId);
  }

  Future<void> rejectDeal({required int dealId}) async {
    await _client
        .from('deals')
        .update({
          'rejected_at': DateTime.now().toIso8601String(),
          'done_at': null,
        })
        .eq('deal_id', dealId);
  }

  Future<List<Map<String, dynamic>>> fetchDealsForUser({
    required String role,
  }) async {
    final userId = currentUserId;
    if (userId == null) return const [];

    final query = _client
        .from('deals')
        .select(
          'deal_id, seeker_id, owner_id, property_id, done_at, rejected_at, created_at',
        )
        .eq(role == 'owner' ? 'owner_id' : 'seeker_id', userId)
        .order('created_at', ascending: false);

    final rows = await query;
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

  Future<Map<int, Map<String, dynamic>>> fetchPropertySummariesByIds(
    List<int> propertyIds,
  ) async {
    if (propertyIds.isEmpty) return const {};

    final propertyRows = await _client
        .from('properties')
        .select(
          'property_id, property_type, property_state, property_city, bedrooms, bathrooms, price',
        )
        .inFilter('property_id', propertyIds);

    final imageRows = await _client
        .from('property_images')
        .select('property_id, image_id, image_url')
        .inFilter('property_id', propertyIds)
        .order('image_id', ascending: true);

    final firstImageByPropertyId = <int, String>{};
    for (final raw in (imageRows as List)) {
      final row = Map<String, dynamic>.from(raw as Map);
      final propertyIdRaw = row['property_id'];
      final propertyId =
          propertyIdRaw is int
              ? propertyIdRaw
              : (propertyIdRaw is num ? propertyIdRaw.toInt() : null);
      if (propertyId == null ||
          firstImageByPropertyId.containsKey(propertyId)) {
        continue;
      }
      final imageUrl = row['image_url']?.toString();
      if (imageUrl != null && imageUrl.trim().isNotEmpty) {
        firstImageByPropertyId[propertyId] = imageUrl;
      }
    }

    final result = <int, Map<String, dynamic>>{};
    for (final raw in (propertyRows as List)) {
      final row = Map<String, dynamic>.from(raw as Map);
      final propertyIdRaw = row['property_id'];
      final propertyId =
          propertyIdRaw is int
              ? propertyIdRaw
              : (propertyIdRaw is num ? propertyIdRaw.toInt() : null);
      if (propertyId == null) continue;

      result[propertyId] = {
        ...row,
        'image_url': firstImageByPropertyId[propertyId],
      };
    }

    return result;
  }
}
