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

  Future<List<Map<String, dynamic>>> fetchSeekerHomeProperties({
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await _client.rpc(
      'fetch_seeker_home_properties',
      params: {
        'p_limit': limit,
        'p_offset': offset,
      },
    );

    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
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
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await _client.rpc(
      'search_properties_rpc',
      params: {
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
      },
    );

    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
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

  Future<void> markPropertyInactive({
    required int propertyId,
  }) async {
    await _client
        .from('properties')
        .update({
          'status': 'inactive',
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

    await _client.storage.from('property-certificates').uploadBinary(path, bytes);
    return _client.storage.from('property-certificates').getPublicUrl(path);
  }
}
