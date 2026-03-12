import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/property_repository.dart';

class SearchCriteria {
  const SearchCriteria({
    required this.transactionType,
    this.propertyType,
    this.propertyState,
    this.propertyCity,
    this.bedrooms,
    this.bedroomsAtLeast = false,
    this.bathrooms,
    this.bathroomsAtLeast = false,
    this.minPrice,
    this.maxPrice,
  });

  final String transactionType;
  final String? propertyType;
  final String? propertyState;
  final String? propertyCity;
  final int? bedrooms;
  final bool bedroomsAtLeast;
  final int? bathrooms;
  final bool bathroomsAtLeast;
  final double? minPrice;
  final double? maxPrice;
}

class SearchPropertyItem {
  const SearchPropertyItem({
    required this.propertyId,
    required this.propertyType,
    required this.bedrooms,
    required this.bathrooms,
    required this.ownerName,
    required this.imageUrl,
    required this.city,
  });

  final int propertyId;
  final String propertyType;
  final int? bedrooms;
  final int? bathrooms;
  final String ownerName;
  final String? imageUrl;
  final String city;

  factory SearchPropertyItem.fromMap(Map<String, dynamic> row) {
    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    final idRaw = row['property_id'];
    final propertyId = idRaw is int ? idRaw : (idRaw is num ? idRaw.toInt() : 0);

    return SearchPropertyItem(
      propertyId: propertyId,
      propertyType: (row['property_type'] as String?) ?? 'Property',
      bedrooms: parseInt(row['bedrooms']),
      bathrooms: parseInt(row['bathrooms']),
      ownerName: (row['owner_name'] as String?) ?? 'Unknown',
      imageUrl: row['image_url'] as String?,
      city: (row['property_city'] as String?) ?? '-',
    );
  }
}

class SearchPropertiesResult {
  const SearchPropertiesResult._({
    required this.success,
    this.errorMessage,
    this.items = const [],
  });

  final bool success;
  final String? errorMessage;
  final List<SearchPropertyItem> items;

  factory SearchPropertiesResult.success(List<SearchPropertyItem> items) {
    return SearchPropertiesResult._(success: true, items: items);
  }

  factory SearchPropertiesResult.error(String message) {
    return SearchPropertiesResult._(success: false, errorMessage: message);
  }
}

class SearchPropertiesController {
  SearchPropertiesController({PropertyRepository? repository})
      : _repository = repository ?? PropertyRepository();

  final PropertyRepository _repository;

  Future<SearchPropertiesResult> search(
    SearchCriteria criteria, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final rows = await _repository.searchProperties(
        transactionType: criteria.transactionType,
        propertyType: criteria.propertyType,
        propertyState: criteria.propertyState,
        propertyCity: criteria.propertyCity,
        bedrooms: criteria.bedrooms,
        bedroomsAtLeast: criteria.bedroomsAtLeast,
        bathrooms: criteria.bathrooms,
        bathroomsAtLeast: criteria.bathroomsAtLeast,
        minPrice: criteria.minPrice,
        maxPrice: criteria.maxPrice,
        limit: limit,
        offset: offset,
      );
      final items = rows.map(SearchPropertyItem.fromMap).toList();
      return SearchPropertiesResult.success(items);
    } on PostgrestException catch (e) {
      return SearchPropertiesResult.error(
        e.message.isEmpty ? 'Failed to search properties.' : e.message,
      );
    } catch (_) {
      return SearchPropertiesResult.error(
        'Unexpected error while searching properties.',
      );
    }
  }
}
