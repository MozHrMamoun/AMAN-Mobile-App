import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client_provider.dart';

class RatingRepository {
  RatingRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<Map<String, dynamic>?> findRating({
    required int dealId,
    required String raterUserId,
  }) async {
    final row = await _client
        .from('ratings')
        .select('rating_id, rating_value')
        .eq('deal_id', dealId)
        .eq('rater_user_id', raterUserId)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<void> insertRating({
    required int dealId,
    required String raterUserId,
    required String targetUserId,
    required double ratingValue,
  }) async {
    await _client.from('ratings').insert({
      'deal_id': dealId,
      'rater_user_id': raterUserId,
      'target_user_id': targetUserId,
      'rating_value': ratingValue,
      'rated_at': DateTime.now().toIso8601String(),
    });
  }
}
