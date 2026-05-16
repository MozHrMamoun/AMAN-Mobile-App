import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/property_repository.dart';

class SeekerHomePropertyItem {
  const SeekerHomePropertyItem({
    required this.propertyId,
    required this.ownerUserId,
    required this.propertyType,
    required this.propertyCity,
    required this.bedrooms,
    required this.bathrooms,
    required this.ownerName,
    required this.ownerRating,
    required this.imageUrl,
  });

  final int propertyId;
  final String ownerUserId;
  final String propertyType;
  final String propertyCity;
  final int? bedrooms;
  final int? bathrooms;
  final String ownerName;
  final double? ownerRating;
  final String? imageUrl;

  factory SeekerHomePropertyItem.fromMap(Map<String, dynamic> row) {
    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    final idRaw = row['property_id'];
    final propertyId = idRaw is int ? idRaw : (idRaw is num ? idRaw.toInt() : 0);

    return SeekerHomePropertyItem(
      propertyId: propertyId,
      ownerUserId: (row['owner_id']?.toString() ?? ''),
      propertyType: (row['property_type'] as String?) ?? 'Property',
      propertyCity: (row['property_city'] as String?) ?? '-',
      bedrooms: parseInt(row['bedrooms']),
      bathrooms: parseInt(row['bathrooms']),
      ownerName: (row['owner_name'] as String?) ?? 'Unknown',
      ownerRating: (row['owner_rating'] as num?)?.toDouble(),
      imageUrl: row['image_url'] as String?,
    );
  }
}

class SeekerHomeResult {
  const SeekerHomeResult._({
    required this.success,
    this.errorMessage,
    this.items = const [],
  });

  final bool success;
  final String? errorMessage;
  final List<SeekerHomePropertyItem> items;

  factory SeekerHomeResult.success(List<SeekerHomePropertyItem> items) {
    return SeekerHomeResult._(success: true, items: items);
  }

  factory SeekerHomeResult.error(String message) {
    return SeekerHomeResult._(success: false, errorMessage: message);
  }
}

class SeekerHomeController {
  SeekerHomeController({PropertyRepository? repository})
      : _repository = repository ?? PropertyRepository();

  final PropertyRepository _repository;

  Future<SeekerHomeResult> loadProperties({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final rows = await _repository.fetchSeekerHomeProperties(
        limit: limit,
        offset: offset,
      );
      final items = rows.map(SeekerHomePropertyItem.fromMap).toList();
      return SeekerHomeResult.success(items);
    } on PostgrestException catch (e) {
      return SeekerHomeResult.error(
        e.message.isEmpty ? 'Failed to load properties.' : e.message,
      );
    } catch (_) {
      return SeekerHomeResult.error('Unexpected error while loading properties.');
    }
  }
}
