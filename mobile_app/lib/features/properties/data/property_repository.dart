import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client_provider.dart';

class PropertyRepository {
  PropertyRepository({SupabaseClient? client})
    : _client = client ?? SupabaseClientProvider.client;

  final SupabaseClient _client;
  String? get currentUserId => _client.auth.currentUser?.id;

  int? _parsePropertyId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Future<List<Map<String, dynamic>>> _attachFirstImageUrls(
    List<Map<String, dynamic>> rows, {
    bool includeStorageFallback = true,
  }) async {
    if (rows.isEmpty) return rows;

    final missingImagePropertyIds =
        rows
            .where(
              (row) =>
                  (row['image_url']?.toString().trim().isEmpty ?? true) &&
                  _parsePropertyId(row['property_id']) != null,
            )
            .map((row) => _parsePropertyId(row['property_id'])!)
            .toSet()
            .toList();

    if (missingImagePropertyIds.isEmpty) return rows;

    final imageRows = await _client
        .from('property_images')
        .select('property_id, image_id, image_url')
        .inFilter('property_id', missingImagePropertyIds)
        .order('image_id', ascending: true);

    final firstImageByPropertyId = <int, String>{};
    for (final raw in (imageRows as List)) {
      final row = Map<String, dynamic>.from(raw as Map);
      final propertyId = _parsePropertyId(row['property_id']);
      if (propertyId == null || firstImageByPropertyId.containsKey(propertyId)) {
        continue;
      }
      final imageUrl = _normalizePropertyImageUrl(
        row['image_url']?.toString(),
      );
      if (imageUrl != null && imageUrl.isNotEmpty) {
        firstImageByPropertyId[propertyId] = imageUrl;
      }
    }

    if (includeStorageFallback) {
      final storageFallbackRows =
          rows
              .where((row) {
                final propertyId = _parsePropertyId(row['property_id']);
                return propertyId != null &&
                    !firstImageByPropertyId.containsKey(propertyId) &&
                    (row['owner_id']?.toString().trim().isNotEmpty ?? false);
              })
              .toList();

      final fallbackResults = await Future.wait(
        storageFallbackRows.map((row) async {
          final propertyId = _parsePropertyId(row['property_id']);
          final ownerId = row['owner_id']?.toString().trim();
          if (propertyId == null || ownerId == null || ownerId.isEmpty) {
            return null;
          }

          final imageFolder = 'properties/$ownerId/$propertyId';
          try {
            final files = await _client.storage
                .from('property-images')
                .list(path: imageFolder);
            if (files.isEmpty) return null;

            files.sort((a, b) => a.name.compareTo(b.name));
            final firstPath = '$imageFolder/${files.first.name}';
            final imageUrl = _client.storage
                .from('property-images')
                .getPublicUrl(firstPath);
            return MapEntry(propertyId, imageUrl);
          } catch (_) {
            // Ignore storage listing errors and keep the placeholder.
            return null;
          }
        }),
      );

      for (final result in fallbackResults.whereType<MapEntry<int, String>>()) {
        firstImageByPropertyId[result.key] = result.value;
      }
    }

    return rows.map((row) {
      final existingImageUrl = row['image_url']?.toString().trim();
      if (existingImageUrl != null && existingImageUrl.isNotEmpty) {
        return row;
      }

      final propertyId = _parsePropertyId(row['property_id']);
      return {
        ...row,
        'image_url':
            propertyId == null ? null : firstImageByPropertyId[propertyId],
      };
    }).toList();
  }

  String? _extractPathFromUrl({required String url, required String bucket}) {
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

  String? _normalizePropertyImageUrl(String? rawUrl) {
    final trimmed = rawUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final path = _extractPathFromUrl(
      url: trimmed,
      bucket: 'property-images',
    );
    if (path == null || path.isEmpty) return trimmed;

    return _client.storage.from('property-images').getPublicUrl(path);
  }

  Future<List<String>> _listStorageImageUrls({
    required int propertyId,
    String? ownerId,
  }) async {
    var resolvedOwnerId = ownerId?.trim();
    if (resolvedOwnerId == null || resolvedOwnerId.isEmpty) {
      final row = await _client
          .from('properties')
          .select('owner_id')
          .eq('property_id', propertyId)
          .maybeSingle();
      resolvedOwnerId = row?['owner_id']?.toString().trim();
    }

    if (resolvedOwnerId == null || resolvedOwnerId.isEmpty) return const [];

    final imageFolder = 'properties/$resolvedOwnerId/$propertyId';
    final files = await _client.storage.from('property-images').list(
      path: imageFolder,
    );
    if (files.isEmpty) return const [];

    files.sort((a, b) => a.name.compareTo(b.name));
    return files
        .map(
          (file) => _client.storage
              .from('property-images')
              .getPublicUrl('$imageFolder/${file.name}'),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchPropertiesByOwner(
    String ownerId,
  ) async {
    final rows = await _client
        .from('properties')
        .select(
          'property_id, owner_id, property_type, transaction_type, rent_type, property_state, property_city, bedrooms, bathrooms, status, price, area_sqm, location, description',
        )
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);

    final properties =
        (rows as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    return _attachFirstImageUrls(properties);
  }

  Future<List<Map<String, dynamic>>> fetchSeekerHomeProperties({
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await _client.rpc(
      'fetch_seeker_home_properties',
      params: {'p_limit': limit, 'p_offset': offset},
    );

    final mapped =
        (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return _attachFirstImageUrls(mapped);
  }

  Future<List<Map<String, dynamic>>> searchProperties({
    String? transactionType,
    String? rentType,
    String? propertyType,
    String? propertyState,
    String? propertyCity,
    int? bedrooms,
    bool bedroomsAtLeast = false,
    int? bathrooms,
    bool bathroomsAtLeast = false,
    double? minPrice,
    double? maxPrice,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'p_transaction_type': transactionType,
      'p_property_type': propertyType,
      'p_property_state': propertyState,
      'p_property_city': propertyCity,
      'p_bedrooms': bedrooms,
      'p_bedrooms_at_least': bedroomsAtLeast,
      'p_bathrooms': bathrooms,
      'p_bathrooms_at_least': bathroomsAtLeast,
      'p_min_price': minPrice,
      'p_max_price': maxPrice,
      'p_limit': limit,
      'p_offset': offset,
    };
    if (rentType != null && rentType.trim().isNotEmpty) {
      params['p_rent_type'] = rentType;
    }

    final rows = await _client.rpc('search_properties_rpc', params: params);

    final mapped =
        (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return _attachFirstImageUrls(mapped);
  }

  Future<Map<String, dynamic>?> fetchPropertyDetailById(int propertyId) async {
    final row =
        await _client
            .from('properties')
            .select(
              'property_id, owner_id, transaction_type, rent_type, property_type, property_state, property_city, bedrooms, bathrooms, price, area_sqm, location, description, status',
            )
            .eq('property_id', propertyId)
            .maybeSingle();

    if (row == null) return null;
    final property = Map<String, dynamic>.from(row);
    final ownerId = property['owner_id']?.toString();

    String ownerName = 'Unknown';
    if (ownerId != null && ownerId.isNotEmpty) {
      final ownerRow =
          await _client
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
    var imageUrls =
        (imageRows as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .map(
              (row) => _normalizePropertyImageUrl(row['image_url'] as String?),
            )
            .whereType<String>()
            .toList();

    if (imageUrls.isEmpty) {
      imageUrls = await _listStorageImageUrls(
        propertyId: propertyId,
        ownerId: ownerId,
      );
    }

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
    final row =
        await _client
            .from('properties')
            .select(
              'property_id, transaction_type, rent_type, property_type, property_state, property_city, bedrooms, bathrooms, status, price, area_sqm, location, description',
            )
            .eq('property_id', propertyId)
            .eq('owner_id', ownerId)
            .maybeSingle();

    if (row == null) return null;
    return Map<String, dynamic>.from(row);
  }

  Future<List<String>> fetchPropertyImageUrls(int propertyId) async {
    final rows = await _client
        .from('property_images')
        .select('image_url, image_id')
        .eq('property_id', propertyId)
        .order('image_id', ascending: true);

    final imageUrls =
        (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(
          (row) => _normalizePropertyImageUrl(row['image_url'] as String?),
        )
        .whereType<String>()
        .toList();

    if (imageUrls.isNotEmpty) return imageUrls;
    return _listStorageImageUrls(propertyId: propertyId);
  }

  Future<void> deleteProperty({
    required int propertyId,
    required String ownerId,
  }) async {
    final property =
        await _client
            .from('properties')
            .select('certificate_url')
            .eq('property_id', propertyId)
            .eq('owner_id', ownerId)
            .maybeSingle();

    final imageRows = await _client
        .from('property_images')
        .select('image_url')
        .eq('property_id', propertyId);

    final imagePaths =
        (imageRows as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .map((row) => row['image_url'] as String?)
            .whereType<String>()
            .map(
              (url) => _extractPathFromUrl(url: url, bucket: 'property-images'),
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
      final leftovers = await _client.storage
          .from('property-images')
          .list(path: imageFolder);
      final leftoverPaths =
          leftovers.map((e) => '$imageFolder/${e.name}').toList();
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
        await _client.storage.from('property-certificates').remove([
          certificatePath,
        ]);
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
    required String? rentType,
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
    final row =
        await _client
            .from('properties')
            .insert({
              'owner_id': ownerId,
              'owner_role': 'owner',
              'transaction_type': transactionType,
              'rent_type': rentType,
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
    throw const FormatException(
      'Invalid property_id type returned from database.',
    );
  }

  Future<void> insertPropertyImages({
    required int propertyId,
    required List<String> imageUrls,
  }) async {
    if (imageUrls.isEmpty) return;

    final rows =
        imageUrls
            .map((url) => {'property_id': propertyId, 'image_url': url})
            .toList();

    await _client.from('property_images').insert(rows);
  }

  Future<void> replacePropertyImages({
    required int propertyId,
    required String ownerId,
    required List<String> imageUrls,
  }) async {
    final existingRows = await _client
        .from('property_images')
        .select('image_url')
        .eq('property_id', propertyId);

    final existingPaths =
        (existingRows as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .map((row) => row['image_url'] as String?)
            .whereType<String>()
            .map(
              (url) => _extractPathFromUrl(url: url, bucket: 'property-images'),
            )
            .whereType<String>()
            .toList();

    if (existingPaths.isNotEmpty) {
      await _client.storage.from('property-images').remove(existingPaths);
    }

    final newImagePaths =
        imageUrls
            .map(
              (url) => _extractPathFromUrl(url: url, bucket: 'property-images'),
            )
            .whereType<String>()
            .toSet();

    final imageFolder = 'properties/$ownerId/$propertyId';
    try {
      final leftovers = await _client.storage
          .from('property-images')
          .list(path: imageFolder);
      final leftoverPaths =
          leftovers
              .map((e) => '$imageFolder/${e.name}')
              .where((path) => !newImagePaths.contains(path))
              .toList();
      if (leftoverPaths.isNotEmpty) {
        await _client.storage.from('property-images').remove(leftoverPaths);
      }
    } catch (_) {
      // Ignore cleanup-list errors; exact path deletion above is primary.
    }

    await _client.from('property_images').delete().eq('property_id', propertyId);

    if (imageUrls.isNotEmpty) {
      await insertPropertyImages(propertyId: propertyId, imageUrls: imageUrls);
    }
  }

  Future<List<String>> replacePropertyImagesFromFiles({
    required int propertyId,
    required String ownerId,
    required List<XFile> files,
  }) async {
    final existingRows = await _client
        .from('property_images')
        .select('image_url')
        .eq('property_id', propertyId);

    final existingPaths =
        (existingRows as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .map((row) => row['image_url'] as String?)
            .whereType<String>()
            .map(
              (url) => _extractPathFromUrl(url: url, bucket: 'property-images'),
            )
            .whereType<String>()
            .toList();

    if (existingPaths.isNotEmpty) {
      await _client.storage.from('property-images').remove(existingPaths);
    }

    final imageFolder = 'properties/$ownerId/$propertyId';
    try {
      final leftovers = await _client.storage
          .from('property-images')
          .list(path: imageFolder);
      final leftoverPaths = leftovers.map((e) => '$imageFolder/${e.name}').toList();
      if (leftoverPaths.isNotEmpty) {
        await _client.storage.from('property-images').remove(leftoverPaths);
      }
    } catch (_) {
      // Ignore cleanup-list errors; exact path deletion above is primary.
    }

    await _client.from('property_images').delete().eq('property_id', propertyId);

    if (files.isEmpty) return const [];

    final imageUrls = <String>[];
    for (var i = 0; i < files.length; i++) {
      final imageUrl = await uploadPropertyImage(
        ownerId: ownerId,
        propertyId: propertyId,
        file: files[i],
        index: i,
      );
      imageUrls.add(imageUrl);
    }

    await insertPropertyImages(propertyId: propertyId, imageUrls: imageUrls);
    return imageUrls;
  }

  Future<void> updateProperty({
    required int propertyId,
    required String ownerId,
    required double price,
    required String? rentType,
    required String? locationUrl,
    required String? description,
    required String status,
  }) async {
    await _client
        .from('properties')
        .update({
          'price': price,
          'rent_type': rentType,
          'location': locationUrl,
          'description': description,
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('property_id', propertyId)
        .eq('owner_id', ownerId);
  }

  Future<void> markPropertyInactive({required int propertyId}) async {
    await updatePropertyStatus(propertyId: propertyId, status: 'inactive');
  }

  Future<void> updatePropertyStatus({
    required int propertyId,
    required String status,
  }) async {
    await _client
        .from('properties')
        .update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('property_id', propertyId);
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

    await _client.storage
        .from('property-certificates')
        .uploadBinary(path, bytes);
    return _client.storage.from('property-certificates').getPublicUrl(path);
  }
}
