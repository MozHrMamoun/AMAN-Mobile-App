import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/property_repository.dart';

class AddPropertyResult {
  const AddPropertyResult._({
    required this.success,
    this.errorMessage,
  });

  final bool success;
  final String? errorMessage;

  factory AddPropertyResult.success() {
    return const AddPropertyResult._(success: true);
  }

  factory AddPropertyResult.error(String message) {
    return AddPropertyResult._(success: false, errorMessage: message);
  }
}

class AddPropertyController {
  AddPropertyController({PropertyRepository? repository})
      : _repository = repository ?? PropertyRepository();

  final PropertyRepository _repository;

  int? _parseRoomCount(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.replaceAll('+', '');
    return int.tryParse(normalized);
  }

  Future<AddPropertyResult> submit({
    required bool isBuy,
    required String? propertyType,
    required String? propertyState,
    required String? propertyCity,
    required String? bedrooms,
    required String? bathrooms,
    required String priceText,
    required String areaText,
    required String locationUrl,
    required String description,
    required List<XFile> propertyImages,
    required XFile? certificateFile,
  }) async {
    final userId = _repository.currentUserId;
    if (userId == null) {
      return AddPropertyResult.error('Please login first.');
    }

    if (propertyType == null || propertyState == null || propertyCity == null) {
      return AddPropertyResult.error('Please complete property type/state/city.');
    }

    if (bedrooms == null || bathrooms == null) {
      return AddPropertyResult.error('Bedrooms and bathrooms are required.');
    }

    final trimmedPrice = priceText.trim();
    final trimmedArea = areaText.trim();
    if (trimmedPrice.isEmpty || trimmedArea.isEmpty) {
      return AddPropertyResult.error('Price and area are required.');
    }

    final price = double.tryParse(trimmedPrice);
    final area = double.tryParse(trimmedArea);
    if (price == null || area == null) {
      return AddPropertyResult.error('Price and area must be valid numbers.');
    }

    if (propertyImages.isEmpty) {
      return AddPropertyResult.error('Please attach at least one property image.');
    }

    if (locationUrl.trim().isEmpty) {
      return AddPropertyResult.error('Location URL is required.');
    }

    if (description.trim().isEmpty) {
      return AddPropertyResult.error('Description is required.');
    }

    if (certificateFile == null) {
      return AddPropertyResult.error('Certificate image is required.');
    }

    try {
      String? certificateUrl;
      certificateUrl = await _repository.uploadCertificate(
        ownerId: userId,
        file: certificateFile,
      );

      final propertyId = await _repository.insertProperty(
        ownerId: userId,
        transactionType: isBuy ? 'buy' : 'rent',
        propertyType: propertyType,
        propertyState: propertyState,
        propertyCity: propertyCity,
        bedrooms: _parseRoomCount(bedrooms),
        bathrooms: _parseRoomCount(bathrooms),
        price: price,
        areaSqm: area,
        locationUrl: locationUrl.trim(),
        certificateUrl: certificateUrl,
        description: description.trim(),
      );

      final imageUrls = <String>[];
      for (var i = 0; i < propertyImages.length; i++) {
        final imageUrl = await _repository.uploadPropertyImage(
          ownerId: userId,
          propertyId: propertyId,
          file: propertyImages[i],
          index: i,
        );
        imageUrls.add(imageUrl);
      }

      await _repository.insertPropertyImages(
        propertyId: propertyId,
        imageUrls: imageUrls,
      );

      return AddPropertyResult.success();
    } on StorageException catch (e) {
      return AddPropertyResult.error('Storage error: ${e.message}');
    } on PostgrestException catch (e) {
      return AddPropertyResult.error('Database error: ${e.message}');
    } catch (_) {
      return AddPropertyResult.error('Unexpected error while adding property.');
    }
  }
}
