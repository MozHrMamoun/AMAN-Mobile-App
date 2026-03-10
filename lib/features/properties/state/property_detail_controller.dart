import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/property_repository.dart';

class PropertyDetailItem {
  const PropertyDetailItem({
    required this.propertyId,
    required this.ownerUserId,
    required this.propertyType,
    required this.propertyState,
    required this.propertyCity,
    required this.bedrooms,
    required this.bathrooms,
    required this.price,
    required this.areaSqm,
    required this.location,
    required this.description,
    required this.ownerName,
    required this.imageUrl,
    required this.imageUrls,
  });

  final int propertyId;
  final String ownerUserId;
  final String propertyType;
  final String propertyState;
  final String propertyCity;
  final int? bedrooms;
  final int? bathrooms;
  final String price;
  final String areaSqm;
  final String location;
  final String description;
  final String ownerName;
  final String? imageUrl;
  final List<String> imageUrls;

  factory PropertyDetailItem.fromMap(Map<String, dynamic> row) {
    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    String parseText(dynamic value, {String fallback = '-'}) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? fallback : text;
    }

    final idRaw = row['property_id'];
    final propertyId = idRaw is int ? idRaw : (idRaw is num ? idRaw.toInt() : 0);

    return PropertyDetailItem(
      propertyId: propertyId,
      ownerUserId: (row['owner_id']?.toString() ?? ''),
      propertyType: parseText(row['property_type']),
      propertyState: parseText(row['property_state']),
      propertyCity: parseText(row['property_city']),
      bedrooms: parseInt(row['bedrooms']),
      bathrooms: parseInt(row['bathrooms']),
      price: parseText(row['price']),
      areaSqm: parseText(row['area_sqm']),
      location: parseText(row['location']),
      description: parseText(
        row['description'],
        fallback: 'No description available.',
      ),
      ownerName: parseText(row['owner_name'], fallback: 'Unknown'),
      imageUrl: row['image_url'] as String?,
      imageUrls: (row['image_urls'] as List?)
              ?.whereType<String>()
              .where((e) => e.trim().isNotEmpty)
              .toList() ??
          const [],
    );
  }
}

class PropertyDetailResult {
  const PropertyDetailResult._({
    required this.success,
    this.errorMessage,
    this.item,
  });

  final bool success;
  final String? errorMessage;
  final PropertyDetailItem? item;

  factory PropertyDetailResult.success(PropertyDetailItem item) {
    return PropertyDetailResult._(success: true, item: item);
  }

  factory PropertyDetailResult.error(String message) {
    return PropertyDetailResult._(success: false, errorMessage: message);
  }
}

class PropertyDetailController {
  PropertyDetailController({PropertyRepository? repository})
      : _repository = repository ?? PropertyRepository();

  final PropertyRepository _repository;

  Future<PropertyDetailResult> loadPropertyDetail(int propertyId) async {
    try {
      final row = await _repository.fetchPropertyDetailById(propertyId);
      if (row == null) {
        return PropertyDetailResult.error('Property not found.');
      }
      return PropertyDetailResult.success(PropertyDetailItem.fromMap(row));
    } on PostgrestException catch (e) {
      return PropertyDetailResult.error(
        e.message.isEmpty ? 'Failed to load property detail.' : e.message,
      );
    } catch (_) {
      return PropertyDetailResult.error(
        'Unexpected error while loading property detail.',
      );
    }
  }
}
