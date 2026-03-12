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

    final row = await _client
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
        .select('deal_id, seeker_id, owner_id, property_id, done_at')
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
        .select('deal_id, seeker_id, owner_id, property_id, done_at')
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
    final row = await _client
        .from('deals')
        .select('deal_id, seeker_id, owner_id, property_id, done_at')
        .eq('seeker_id', seekerId)
        .eq('owner_id', ownerId)
        .eq('property_id', propertyId)
        .isFilter('done_at', null)
        .maybeSingle();

    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> createPendingDeal({
    required String seekerId,
    required String ownerId,
    required int propertyId,
  }) async {
    final row = await _client
        .from('deals')
        .insert({
          'seeker_id': seekerId,
          'owner_id': ownerId,
          'property_id': propertyId,
          'done_at': null,
        })
        .select('deal_id, seeker_id, owner_id, property_id, done_at')
        .single();

    return Map<String, dynamic>.from(row);
  }

  Future<void> confirmDeal({
    required int dealId,
  }) async {
    await _client
        .from('deals')
        .update({'done_at': DateTime.now().toIso8601String()})
        .eq('deal_id', dealId);
  }
}
