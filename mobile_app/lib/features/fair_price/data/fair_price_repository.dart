import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client_provider.dart';

class FairPriceRepository {
  FairPriceRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchAverage({
    required String monthStart,
    required String transactionType,
    required String propertyType,
    required String propertyCity,
    required int bedrooms,
  }) async {
    final row = await _client
        .from('fair_price_averages')
        .select('avg_price, sample_count')
        .eq('month_start', monthStart)
        .ilike('transaction_type', transactionType)
        .ilike('property_type', propertyType)
        .ilike('property_city', propertyCity)
        .eq('bedrooms', bedrooms)
        .maybeSingle();
    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }
}
