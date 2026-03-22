import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/fair_price_repository.dart';

class FairPriceResult {
  const FairPriceResult._({
    required this.success,
    this.errorMessage,
    this.averagePrice,
    this.sampleCount = 0,
  });

  final bool success;
  final String? errorMessage;
  final double? averagePrice;
  final int sampleCount;

  factory FairPriceResult.success({
    required double? averagePrice,
    required int sampleCount,
  }) {
    return FairPriceResult._(
      success: true,
      averagePrice: averagePrice,
      sampleCount: sampleCount,
    );
  }

  factory FairPriceResult.error(String message) {
    return FairPriceResult._(success: false, errorMessage: message);
  }
}

class FairPriceController {
  FairPriceController({FairPriceRepository? repository})
      : _repository = repository ?? FairPriceRepository();

  final FairPriceRepository _repository;

  Future<FairPriceResult> fetchAverage({
    required String monthStart,
    required String transactionType,
    required String propertyType,
    required String propertyCity,
    required int bedrooms,
  }) async {
    try {
      final row = await _repository.fetchAverage(
        monthStart: monthStart,
        transactionType: transactionType,
        propertyType: propertyType,
        propertyCity: propertyCity,
        bedrooms: bedrooms,
      );
      if (row == null) {
        return FairPriceResult.success(averagePrice: null, sampleCount: 0);
      }
      final avgRaw = row['avg_price'];
      final countRaw = row['sample_count'];
      final avg = avgRaw is num ? avgRaw.toDouble() : null;
      final count = countRaw is int
          ? countRaw
          : (countRaw is num ? countRaw.toInt() : 0);
      return FairPriceResult.success(averagePrice: avg, sampleCount: count);
    } on PostgrestException catch (e) {
      return FairPriceResult.error(
        e.message.isEmpty ? 'Failed to load fair price.' : e.message,
      );
    } catch (_) {
      return FairPriceResult.error('Unexpected error while loading fair price.');
    }
  }
}
