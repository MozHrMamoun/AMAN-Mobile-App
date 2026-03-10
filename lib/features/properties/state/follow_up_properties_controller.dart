import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/property_repository.dart';

class OwnerPropertyItem {
  const OwnerPropertyItem({
    required this.propertyId,
    required this.propertyType,
    required this.propertyState,
    required this.propertyCity,
    required this.bedrooms,
    required this.bathrooms,
  });

  final int propertyId;
  final String propertyType;
  final String propertyState;
  final String propertyCity;
  final int? bedrooms;
  final int? bathrooms;

  String get title => '$propertyType - $propertyState/$propertyCity';

  factory OwnerPropertyItem.fromMap(Map<String, dynamic> map) {
    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    final dynamic idRaw = map['property_id'];
    final int id =
        idRaw is int ? idRaw : (idRaw is num ? idRaw.toInt() : 0);

    return OwnerPropertyItem(
      propertyId: id,
      propertyType: (map['property_type'] as String?) ?? 'Property',
      propertyState: (map['property_state'] as String?) ?? '-',
      propertyCity: (map['property_city'] as String?) ?? '-',
      bedrooms: parseInt(map['bedrooms']),
      bathrooms: parseInt(map['bathrooms']),
    );
  }
}

class FollowUpPropertiesResult {
  const FollowUpPropertiesResult._({
    required this.success,
    this.errorMessage,
    this.items = const [],
  });

  final bool success;
  final String? errorMessage;
  final List<OwnerPropertyItem> items;

  factory FollowUpPropertiesResult.success(List<OwnerPropertyItem> items) {
    return FollowUpPropertiesResult._(success: true, items: items);
  }

  factory FollowUpPropertiesResult.error(String message) {
    return FollowUpPropertiesResult._(success: false, errorMessage: message);
  }
}

class FollowUpPropertiesController {
  FollowUpPropertiesController({PropertyRepository? repository})
      : _repository = repository ?? PropertyRepository();

  final PropertyRepository _repository;

  Future<FollowUpPropertiesResult> loadOwnerProperties() async {
    final userId = _repository.currentUserId;
    if (userId == null) {
      return FollowUpPropertiesResult.error('Please login first.');
    }

    try {
      final rows = await _repository.fetchPropertiesByOwner(userId);
      final items = rows.map(OwnerPropertyItem.fromMap).toList();
      return FollowUpPropertiesResult.success(items);
    } on PostgrestException catch (e) {
      return FollowUpPropertiesResult.error(
        e.message.isEmpty ? 'Failed to load properties.' : e.message,
      );
    } catch (_) {
      return FollowUpPropertiesResult.error(
        'Unexpected error while loading properties.',
      );
    }
  }

  Future<String?> deleteProperty(int propertyId) async {
    final userId = _repository.currentUserId;
    if (userId == null) return 'Please login first.';

    try {
      await _repository.deleteProperty(propertyId: propertyId, ownerId: userId);
      return null;
    } on PostgrestException catch (e) {
      return e.message.isEmpty ? 'Failed to delete property.' : e.message;
    } catch (_) {
      return 'Unexpected error while deleting property.';
    }
  }
}
