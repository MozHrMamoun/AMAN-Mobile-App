import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/property_repository.dart';

class UpdatePropertyData {
  const UpdatePropertyData({
    required this.price,
    required this.transactionType,
    required this.rentType,
    required this.description,
    required this.isActive,
    required this.imageUrls,
  });

  final String price;
  final String transactionType;
  final String? rentType;
  final String description;
  final bool isActive;
  final List<String> imageUrls;
}

class UpdatePropertyResult {
  const UpdatePropertyResult._({
    required this.success,
    this.errorMessage,
    this.data,
  });

  final bool success;
  final String? errorMessage;
  final UpdatePropertyData? data;

  factory UpdatePropertyResult.success({UpdatePropertyData? data}) {
    return UpdatePropertyResult._(success: true, data: data);
  }

  factory UpdatePropertyResult.error(String message) {
    return UpdatePropertyResult._(success: false, errorMessage: message);
  }
}

class UpdatePropertyController {
  UpdatePropertyController({PropertyRepository? repository})
    : _repository = repository ?? PropertyRepository();

  final PropertyRepository _repository;

  Future<UpdatePropertyResult> loadProperty(int propertyId) async {
    final userId = _repository.currentUserId;
    if (userId == null) {
      return UpdatePropertyResult.error('Please login first.');
    }

    try {
      final row = await _repository.fetchPropertyByIdForOwner(
        propertyId: propertyId,
        ownerId: userId,
      );
      if (row == null) {
        return UpdatePropertyResult.error('Property not found.');
      }

      final imageUrls = await _repository.fetchPropertyImageUrls(propertyId);

      final dynamic priceRaw = row['price'];
      final transactionType =
          (row['transaction_type']?.toString().trim().toLowerCase() ?? '');
      final rentTypeRaw = row['rent_type']?.toString().trim().toLowerCase();
      final dynamic descriptionRaw = row['description'];
      final dynamic statusRaw = row['status'];

      final priceText = priceRaw == null ? '' : priceRaw.toString();
      final isActive =
          (statusRaw?.toString().toLowerCase() ?? 'active') == 'active';

      return UpdatePropertyResult.success(
        data: UpdatePropertyData(
          price: priceText,
          transactionType: transactionType,
          rentType:
              rentTypeRaw == null || rentTypeRaw.isEmpty ? null : rentTypeRaw,
          description: descriptionRaw?.toString() ?? '',
          isActive: isActive,
          imageUrls: imageUrls,
        ),
      );
    } on PostgrestException catch (e) {
      return UpdatePropertyResult.error(
        e.message.isEmpty ? 'Failed to load property.' : e.message,
      );
    } catch (_) {
      return UpdatePropertyResult.error(
        'Unexpected error while loading property.',
      );
    }
  }

  Future<UpdatePropertyResult> updateProperty({
    required int propertyId,
    required String priceText,
    required String transactionType,
    required String? rentType,
    required String description,
    required bool isActive,
    required List<XFile> newImages,
  }) async {
    final userId = _repository.currentUserId;
    if (userId == null) {
      return UpdatePropertyResult.error('Please login first.');
    }

    final trimmedPrice = priceText.trim();
    if (trimmedPrice.isEmpty) {
      return UpdatePropertyResult.error('Price is required.');
    }

    final price = double.tryParse(trimmedPrice);
    if (price == null) {
      return UpdatePropertyResult.error('Price must be a valid number.');
    }

    final normalizedTransactionType = transactionType.trim().toLowerCase();
    final normalizedRentType = rentType?.trim().toLowerCase();
    if (normalizedTransactionType == 'rent' &&
        (normalizedRentType == null || normalizedRentType.isEmpty)) {
      return UpdatePropertyResult.error('Type of rent is required.');
    }

    try {
      await _repository.updateProperty(
        propertyId: propertyId,
        ownerId: userId,
        price: price,
        rentType:
            normalizedTransactionType == 'rent' ? normalizedRentType : null,
        locationUrl: null,
        description: description.trim().isEmpty ? null : description.trim(),
        status: isActive ? 'active' : 'inactive',
      );

      if (newImages.isNotEmpty) {
        final urls = <String>[];
        for (var i = 0; i < newImages.length; i++) {
          final url = await _repository.uploadPropertyImage(
            ownerId: userId,
            propertyId: propertyId,
            file: newImages[i],
            index: i,
          );
          urls.add(url);
        }
        await _repository.replacePropertyImages(
          propertyId: propertyId,
          ownerId: userId,
          imageUrls: urls,
        );
      }

      return UpdatePropertyResult.success();
    } on StorageException catch (e) {
      return UpdatePropertyResult.error('Storage error: ${e.message}');
    } on PostgrestException catch (e) {
      return UpdatePropertyResult.error(
        e.message.isEmpty ? 'Failed to update property.' : e.message,
      );
    } catch (_) {
      return UpdatePropertyResult.error(
        'Unexpected error while updating property.',
      );
    }
  }
}
