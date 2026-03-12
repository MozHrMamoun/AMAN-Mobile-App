import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/rating_repository.dart';

class RatingStatusResult {
  const RatingStatusResult._({
    required this.success,
    this.errorMessage,
    this.hasRated = false,
  });

  final bool success;
  final String? errorMessage;
  final bool hasRated;

  factory RatingStatusResult.success({required bool hasRated}) {
    return RatingStatusResult._(success: true, hasRated: hasRated);
  }

  factory RatingStatusResult.error(String message) {
    return RatingStatusResult._(success: false, errorMessage: message);
  }
}

class RatingActionResult {
  const RatingActionResult._({required this.success, this.errorMessage});

  final bool success;
  final String? errorMessage;

  factory RatingActionResult.success() {
    return const RatingActionResult._(success: true);
  }

  factory RatingActionResult.error(String message) {
    return RatingActionResult._(success: false, errorMessage: message);
  }
}

class RatingController {
  RatingController({RatingRepository? repository})
      : _repository = repository ?? RatingRepository();

  final RatingRepository _repository;

  Future<RatingStatusResult> checkHasRated({
    required int dealId,
  }) async {
    try {
      final raterId = _repository.currentUserId;
      if (raterId == null) {
        return RatingStatusResult.error('Please login first.');
      }

      final rating = await _repository.findRating(
        dealId: dealId,
        raterUserId: raterId,
      );
      return RatingStatusResult.success(hasRated: rating != null);
    } on PostgrestException catch (e) {
      return RatingStatusResult.error(
        e.message.isEmpty ? 'Failed to check rating.' : e.message,
      );
    } catch (_) {
      return RatingStatusResult.error('Unexpected error while checking rating.');
    }
  }

  Future<RatingActionResult> submitRating({
    required int dealId,
    required String targetUserId,
    required double ratingValue,
  }) async {
    try {
      final raterId = _repository.currentUserId;
      if (raterId == null) {
        return RatingActionResult.error('Please login first.');
      }

      if (ratingValue < 1 || ratingValue > 5) {
        return RatingActionResult.error('Rating must be between 1 and 5.');
      }

      await _repository.insertRating(
        dealId: dealId,
        raterUserId: raterId,
        targetUserId: targetUserId,
        ratingValue: ratingValue,
      );
      return RatingActionResult.success();
    } on PostgrestException catch (e) {
      return RatingActionResult.error(
        e.message.isEmpty ? 'Failed to submit rating.' : e.message,
      );
    } catch (_) {
      return RatingActionResult.error('Unexpected error while submitting rating.');
    }
  }
}
