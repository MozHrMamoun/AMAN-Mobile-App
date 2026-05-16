import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client_provider.dart';

class WishedPropertyRepository {
  WishedPropertyRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<void> insertWish({
    required String seekerId,
    required String transactionType,
    required String propertyType,
    required String city,
    int? bedrooms,
    int? bathrooms,
    double? price,
  }) async {
    await _client.from('wished_property').insert({
      'seeker_id': seekerId,
      'transaction_type': transactionType,
      'property_type': propertyType,
      'city': city,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'price': price,
    });
  }
}
