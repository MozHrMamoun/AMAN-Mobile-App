import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client_provider.dart';

class PropertyRepository {
  PropertyRepository({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;
  String? get currentUserId => _client.auth.currentUser?.id;

  String? _extractPathFromUrl({
    required String url,
    required String bucket,
  }) {
    final publicMarker = '/object/public/$bucket/';
    final signedMarker = '/object/sign/$bucket/';

    var idx = url.indexOf(publicMarker);
    var marker = publicMarker;
    if (idx == -1) {
      idx = url.indexOf(signedMarker);
      marker = signedMarker;
    }
    if (idx == -1) return null;

    var path = url.substring(idx + marker.length);
    final queryIndex = path.indexOf('?');
    if (queryIndex != -1) {
      path = path.substring(0, queryIndex);
    }
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    if (path.isEmpty) return null;
    return Uri.decodeComponent(path);
  }

  Future<List<Map<String, dynamic>>> fetchPropertiesByOwner(String ownerId) async {
    final rows = await _client
        .from('properties')
        .select(
          'property_id, property_type, property_state, property_city, bedrooms, bathrooms, status, price, area_sqm, location, description',
        )
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchSeekerHomeProperties() async {
    final rows = await _client
        .from('properties')
        .select(
          'property_id, owner_id, property_type, property_city, bedrooms, bathrooms, status, created_at',
        )
        .eq('status', 'active')
        .order('created_at', ascending: false);

    final properties = (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (properties.isEmpty) return const [];

    final propertyIds = properties
        .map((row) => row['property_id'])
        .whereType<int>()
        .toList();
    final ownerIds = properties
        .map((row) => row['owner_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();

    final firstImageByProperty = <int, String>{};
    if (propertyIds.isNotEmpty) {
      final imageRows = await _client
          .from('property_images')
          .select('property_id, image_url, image_id')
          .inFilter('property_id', propertyIds)
          .order('image_id', ascending: true);

      for (final rowRaw in (imageRows as List)) {
        final row = Map<String, dynamic>.from(rowRaw as Map);
        final propertyIdRaw = row['property_id'];
        final propertyId = propertyIdRaw is int
            ? propertyIdRaw
            : (propertyIdRaw is num ? propertyIdRaw.toInt() : null);
        if (propertyId == null) continue;
        final imageUrl = row['image_url'] as String?;
        if (imageUrl == null || imageUrl.isEmpty) continue;

        firstImageByProperty.putIfAbsent(propertyId, () => imageUrl);
      }
    }

    final ownerNameById = <String, String>{};
    final ownerAvgRatingById = <String, double>{};
    if (ownerIds.isNotEmpty) {
      final ownerRows = await _client
          .from('user')
          .select('user_id, full_name')
          .inFilter('user_id', ownerIds);

      for (final rowRaw in (ownerRows as List)) {
        final row = Map<String, dynamic>.from(rowRaw as Map);
        final userId = row['user_id']?.toString();
        if (userId == null || userId.isEmpty) continue;
        ownerNameById[userId] = (row['full_name'] as String?) ?? 'Unknown';
      }

      final ratingRows = await _client
          .from('ratings')
          .select('target_user_id, rating_value')
          .inFilter('target_user_id', ownerIds);

      final sumByOwner = <String, double>{};
      final countByOwner = <String, int>{};
      for (final rowRaw in (ratingRows as List)) {
        final row = Map<String, dynamic>.from(rowRaw as Map);
        final ownerId = row['target_user_id']?.toString();
        if (ownerId == null || ownerId.isEmpty) continue;

        final valueRaw = row['rating_value'];
        final value = valueRaw is num ? valueRaw.toDouble() : double.tryParse(valueRaw?.toString() ?? '');
        if (value == null) continue;

        sumByOwner[ownerId] = (sumByOwner[ownerId] ?? 0) + value;
        countByOwner[ownerId] = (countByOwner[ownerId] ?? 0) + 1;
      }

      for (final ownerId in sumByOwner.keys) {
        final count = countByOwner[ownerId] ?? 0;
        if (count > 0) {
          ownerAvgRatingById[ownerId] = sumByOwner[ownerId]! / count;
        }
      }
    }

    return properties.map((property) {
      final propertyIdRaw = property['property_id'];
      final propertyId = propertyIdRaw is int
          ? propertyIdRaw
          : (propertyIdRaw is num ? propertyIdRaw.toInt() : null);
      final ownerId = property['owner_id']?.toString();

      return {
        ...property,
        'owner_name': ownerId == null ? 'Unknown' : (ownerNameById[ownerId] ?? 'Unknown'),
        'owner_rating': ownerId == null ? null : ownerAvgRatingById[ownerId],
        'image_url': propertyId == null ? null : firstImageByProperty[propertyId],
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> searchProperties({
    String? transactionType,
    String? propertyType,
    String? propertyState,
    String? propertyCity,
    int? bedrooms,
    bool bedroomsAtLeast = false,
    int? bathrooms,
    bool bathroomsAtLeast = false,
    double? minPrice,
    double? maxPrice,
  }) async {
    dynamic query = _client.from('properties').select(
          'property_id, owner_id, property_type, property_city, bedrooms, bathrooms, status, created_at, price',
        );

    query = query.eq('status', 'active');

    if (transactionType != null && transactionType.isNotEmpty) {
      query = query.eq('transaction_type', transactionType);
    }
    if (propertyType != null && propertyType.isNotEmpty) {
      query = query.eq('property_type', propertyType);
    }
    if (propertyState != null && propertyState.isNotEmpty) {
      query = query.eq('property_state', propertyState);
    }
    if (propertyCity != null && propertyCity.isNotEmpty) {
      query = query.eq('property_city', propertyCity);
    }
    if (bedrooms != null) {
      query = bedroomsAtLeast
          ? query.gte('bedrooms', bedrooms)
          : query.eq('bedrooms', bedrooms);
    }
    if (bathrooms != null) {
      query = bathroomsAtLeast
          ? query.gte('bathrooms', bathrooms)
          : query.eq('bathrooms', bathrooms);
    }
    if (minPrice != null) {
      query = query.gte('price', minPrice);
    }
    if (maxPrice != null) {
      query = query.lte('price', maxPrice);
    }

    final rows = await query.order('created_at', ascending: false);
    final properties = (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (properties.isEmpty) return const [];

    final propertyIds = properties
        .map((row) => row['property_id'])
        .whereType<int>()
        .toList();
    final ownerIds = properties
        .map((row) => row['owner_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();

    final firstImageByProperty = <int, String>{};
    if (propertyIds.isNotEmpty) {
      final imageRows = await _client
          .from('property_images')
          .select('property_id, image_url, image_id')
          .inFilter('property_id', propertyIds)
          .order('image_id', ascending: true);

      for (final rowRaw in (imageRows as List)) {
        final row = Map<String, dynamic>.from(rowRaw as Map);
        final propertyIdRaw = row['property_id'];
        final propertyId = propertyIdRaw is int
            ? propertyIdRaw
            : (propertyIdRaw is num ? propertyIdRaw.toInt() : null);
        if (propertyId == null) continue;
        final imageUrl = row['image_url'] as String?;
        if (imageUrl == null || imageUrl.isEmpty) continue;
        firstImageByProperty.putIfAbsent(propertyId, () => imageUrl);
      }
    }

    final ownerNameById = <String, String>{};
    if (ownerIds.isNotEmpty) {
      final ownerRows = await _client
          .from('user')
          .select('user_id, full_name')
          .inFilter('user_id', ownerIds);

      for (final rowRaw in (ownerRows as List)) {
        final row = Map<String, dynamic>.from(rowRaw as Map);
        final userId = row['user_id']?.toString();
        if (userId == null || userId.isEmpty) continue;
        ownerNameById[userId] = (row['full_name'] as String?) ?? 'Unknown';
      }
    }

    return properties.map((property) {
      final propertyIdRaw = property['property_id'];
      final propertyId = propertyIdRaw is int
          ? propertyIdRaw
          : (propertyIdRaw is num ? propertyIdRaw.toInt() : null);
      final ownerId = property['owner_id']?.toString();

      return {
        ...property,
        'owner_name': ownerId == null ? 'Unknown' : (ownerNameById[ownerId] ?? 'Unknown'),
        'image_url': propertyId == null ? null : firstImageByProperty[propertyId],
      };
    }).toList();
  }

  Future<Map<String, dynamic>?> fetchPropertyDetailById(int propertyId) async {
    final row = await _client
        .from('properties')
        .select(
          'property_id, owner_id, property_type, property_state, property_city, bedrooms, bathrooms, price, area_sqm, location, description, status',
        )
        .eq('property_id', propertyId)
        .maybeSingle();

    if (row == null) return null;
    final property = Map<String, dynamic>.from(row);
    final ownerId = property['owner_id']?.toString();

    String ownerName = 'Unknown';
    if (ownerId != null && ownerId.isNotEmpty) {
      final ownerRow = await _client
          .from('user')
          .select('full_name')
          .eq('user_id', ownerId)
          .maybeSingle();
      ownerName = (ownerRow?['full_name'] as String?) ?? 'Unknown';
    }

    final imageRows = await _client
        .from('property_images')
        .select('image_url, image_id')
        .eq('property_id', propertyId)
        .order('image_id', ascending: true);
    final imageUrls = (imageRows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((row) => row['image_url'] as String?)
        .whereType<String>()
        .toList();

    return {
      ...property,
      'owner_name': ownerName,
      'image_url': imageUrls.isEmpty ? null : imageUrls.first,
      'image_urls': imageUrls,
    };
  }

  Future<Map<String, dynamic>?> fetchPropertyByIdForOwner({
    required int propertyId,
    required String ownerId,
  }) async {
    final row = await _client
        .from('properties')
        .select(
          'property_id, property_type, property_state, property_city, bedrooms, bathrooms, status, price, area_sqm, location, description',
        )
        .eq('property_id', propertyId)
        .eq('owner_id', ownerId)
        .maybeSingle();

    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<void> deleteProperty({
    required int propertyId,
    required String ownerId,
  }) async {
    final property = await _client
        .from('properties')
        .select('certificate_url')
        .eq('property_id', propertyId)
        .eq('owner_id', ownerId)
        .maybeSingle();

    final imageRows = await _client
        .from('property_images')
        .select('image_url')
        .eq('property_id', propertyId);

    final imagePaths = (imageRows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((row) => row['image_url'] as String?)
        .whereType<String>()
        .map(
          (url) => _extractPathFromUrl(
            url: url,
            bucket: 'property-images',
          ),
        )
        .whereType<String>()
        .toList();

    if (imagePaths.isNotEmpty) {
      await _client.storage.from('property-images').remove(imagePaths);
    }

    // Supabase storage has virtual folders; removing all files under this path
    // effectively removes the property-number folder as well.
    final imageFolder = 'properties/$ownerId/$propertyId';
    try {
      final leftovers = await _client.storage.from('property-images').list(path: imageFolder);
      final leftoverPaths = leftovers.map((e) => '$imageFolder/${e.name}').toList();
      if (leftoverPaths.isNotEmpty) {
        await _client.storage.from('property-images').remove(leftoverPaths);
      }
    } catch (_) {
      // Ignore cleanup-list errors; primary delete is done via exact paths from DB.
    }

    final certificateUrl = property?['certificate_url'] as String?;
    if (certificateUrl != null && certificateUrl.isNotEmpty) {
      final certificatePath = _extractPathFromUrl(
        url: certificateUrl,
        bucket: 'property-certificates',
      );
      if (certificatePath != null) {
        await _client.storage.from('property-certificates').remove([certificatePath]);
      }
    }

    await _client
        .from('properties')
        .delete()
        .eq('property_id', propertyId)
        .eq('owner_id', ownerId);
  }

  Future<int> insertProperty({
    required String ownerId,
    required String transactionType,
    required String propertyType,
    required String propertyState,
    required String propertyCity,
    required double price,
    required double areaSqm,
    int? bedrooms,
    int? bathrooms,
    String? locationUrl,
    String? certificateUrl,
    String? description,
  }) async {
    final row = await _client
        .from('properties')
        .insert({
          'owner_id': ownerId,
          'owner_role': 'owner',
          'transaction_type': transactionType,
          'property_type': propertyType,
          'property_state': propertyState,
          'property_city': propertyCity,
          'bedrooms': bedrooms,
          'bathrooms': bathrooms,
          'price': price,
          'area_sqm': areaSqm,
          'location': locationUrl,
          'certificate_url': certificateUrl,
          'description': description,
          'status': 'active',
        })
        .select('property_id')
        .single();

    final dynamic propertyId = row['property_id'];
    if (propertyId is int) return propertyId;
    if (propertyId is num) return propertyId.toInt();
    throw const FormatException('Invalid property_id type returned from database.');
  }

  Future<void> insertPropertyImages({
    required int propertyId,
    required List<String> imageUrls,
  }) async {
    if (imageUrls.isEmpty) return;

    final rows = imageUrls
        .map(
          (url) => {
            'property_id': propertyId,
            'image_url': url,
          },
        )
        .toList();

    await _client.from('property_images').insert(rows);
  }

  Future<void> updateProperty({
    required int propertyId,
    required String ownerId,
    required double price,
    required String? locationUrl,
    required String? description,
    required String status,
  }) async {
    await _client
        .from('properties')
        .update({
          'price': price,
          'location': locationUrl,
          'description': description,
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('property_id', propertyId)
        .eq('owner_id', ownerId);
  }

  Future<String> uploadPropertyImage({
    required String ownerId,
    required int propertyId,
    required XFile file,
    required int index,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'properties/$ownerId/$propertyId/$ts-$index-${file.name}';
    final bytes = await file.readAsBytes();

    await _client.storage.from('property-images').uploadBinary(path, bytes);
    return _client.storage.from('property-images').getPublicUrl(path);
  }

  Future<String> uploadCertificate({
    required String ownerId,
    required XFile file,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'certificates/$ownerId/$ts-${file.name}';
    final bytes = await file.readAsBytes();

    await _client.storage.from('property-certificates').uploadBinary(path, bytes);
    return _client.storage.from('property-certificates').getPublicUrl(path);
  }
}
