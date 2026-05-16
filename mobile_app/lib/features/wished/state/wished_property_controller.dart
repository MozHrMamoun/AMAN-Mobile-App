import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/wished_property_repository.dart';
import '../../notifications/state/notification_controller.dart';

class SaveWishResult {
  const SaveWishResult._({required this.success, this.errorMessage});

  final bool success;
  final String? errorMessage;

  factory SaveWishResult.success() => const SaveWishResult._(success: true);
  factory SaveWishResult.error(String message) =>
      SaveWishResult._(success: false, errorMessage: message);
}

class WishedPropertyController {
  WishedPropertyController({
    WishedPropertyRepository? repository,
    NotificationController? notificationController,
  })  : _repository = repository ?? WishedPropertyRepository(),
        _notificationController =
            notificationController ?? NotificationController();

  final WishedPropertyRepository _repository;
  final NotificationController _notificationController;

  int? _parseCount(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return int.tryParse(value.replaceAll('+', '').trim());
  }

  double? _parsePrice(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  Future<SaveWishResult> saveWish({
    required bool isBuy,
    required String? propertyType,
    required String? city,
    required String? bedrooms,
    required String? bathrooms,
    required String priceText,
  }) async {
    final seekerId = _repository.currentUserId;
    if (seekerId == null) {
      return SaveWishResult.error('Please login first.');
    }

    if (propertyType == null || propertyType.isEmpty || city == null || city.isEmpty) {
      return SaveWishResult.error('Please select property type and city.');
    }

    final price = _parsePrice(priceText);
    if (priceText.trim().isNotEmpty && price == null) {
      return SaveWishResult.error('Price must be a valid number.');
    }

    try {
      await _repository.insertWish(
        seekerId: seekerId,
        transactionType: isBuy ? 'buy' : 'rent',
        propertyType: propertyType,
        city: city,
        bedrooms: _parseCount(bedrooms),
        bathrooms: _parseCount(bathrooms),
        price: price,
      );

      try {
        await _notificationController.runAiMatchingOnly();
      } catch (_) {
        // Ignore AI match failures to keep saving flow smooth.
      }

      return SaveWishResult.success();
    } on PostgrestException catch (e) {
      return SaveWishResult.error(
        e.message.isEmpty ? 'Failed to save wished property.' : e.message,
      );
    } catch (_) {
      return SaveWishResult.error('Unexpected error while saving wished property.');
    }
  }
}
