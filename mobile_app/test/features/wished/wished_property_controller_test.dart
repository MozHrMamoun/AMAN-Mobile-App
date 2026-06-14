import 'package:aman/features/wished/data/wished_property_repository.dart';
import 'package:aman/features/wished/state/wished_property_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('WishedPropertyController.saveWish', () {
    test('requires a logged in seeker', () async {
      final controller = WishedPropertyController(
        repository: FakeWishedPropertyRepository(currentUserIdValue: null),
      );

      final result = await controller.saveWish(
        isBuy: true,
        rentType: null,
        propertyType: 'House',
        city: 'Khartoum',
        bedrooms: '3',
        bathrooms: '2',
        priceText: '250000',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Please login first.');
    });

    test('validates required property type and city', () async {
      final controller = WishedPropertyController(
        repository: FakeWishedPropertyRepository(
          currentUserIdValue: 'seeker-1',
        ),
      );

      final result = await controller.saveWish(
        isBuy: false,
        rentType: null,
        propertyType: '',
        city: null,
        bedrooms: null,
        bathrooms: null,
        priceText: '',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Please select property type and city.');
    });

    test('requires rent type for rent wishes', () async {
      final controller = WishedPropertyController(
        repository: FakeWishedPropertyRepository(
          currentUserIdValue: 'seeker-1',
        ),
      );

      final result = await controller.saveWish(
        isBuy: false,
        rentType: null,
        propertyType: 'Apartment',
        city: 'Khartoum',
        bedrooms: '2',
        bathrooms: '1',
        priceText: '450000',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Please select type of rent.');
    });

    test('validates numeric price input', () async {
      final controller = WishedPropertyController(
        repository: FakeWishedPropertyRepository(
          currentUserIdValue: 'seeker-1',
        ),
      );

      final result = await controller.saveWish(
        isBuy: true,
        rentType: null,
        propertyType: 'Apartment',
        city: 'Suakin',
        bedrooms: '2',
        bathrooms: '1',
        priceText: 'not-a-number',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Price must be a valid number.');
    });

    test('saves wish successfully', () async {
      final repository = FakeWishedPropertyRepository(
        currentUserIdValue: 'seeker-9',
      );
      final controller = WishedPropertyController(repository: repository);

      final result = await controller.saveWish(
        isBuy: false,
        rentType: 'Monthly',
        propertyType: 'House',
        city: 'Port Sudan',
        bedrooms: '5+',
        bathrooms: '2',
        priceText: '900000',
      );

      expect(result.success, isTrue);
      expect(repository.insertedSeekerId, 'seeker-9');
      expect(repository.insertedTransactionType, 'rent');
      expect(repository.insertedRentType, 'monthly');
      expect(repository.insertedPropertyType, 'House');
      expect(repository.insertedCity, 'Port Sudan');
      expect(repository.insertedBedrooms, 5);
      expect(repository.insertedBathrooms, 2);
      expect(repository.insertedPrice, 900000);
    });

    test('returns database error from repository', () async {
      final controller = WishedPropertyController(
        repository: FakeWishedPropertyRepository(
          currentUserIdValue: 'seeker-2',
          insertException: const PostgrestException(message: 'Insert failed'),
        ),
      );

      final result = await controller.saveWish(
        isBuy: true,
        rentType: null,
        propertyType: 'Land',
        city: 'Nyala',
        bedrooms: null,
        bathrooms: null,
        priceText: '500000',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Insert failed');
    });
  });
}

class FakeWishedPropertyRepository implements WishedPropertyRepository {
  FakeWishedPropertyRepository({
    required this.currentUserIdValue,
    this.insertException,
  });

  final String? currentUserIdValue;
  final Exception? insertException;

  String? insertedSeekerId;
  String? insertedTransactionType;
  String? insertedRentType;
  String? insertedPropertyType;
  String? insertedCity;
  int? insertedBedrooms;
  int? insertedBathrooms;
  double? insertedPrice;

  @override
  String? get currentUserId => currentUserIdValue;

  @override
  Future<void> insertWish({
    required String seekerId,
    required String transactionType,
    required String? rentType,
    required String propertyType,
    required String city,
    int? bedrooms,
    int? bathrooms,
    double? price,
  }) async {
    if (insertException != null) throw insertException!;

    insertedSeekerId = seekerId;
    insertedTransactionType = transactionType;
    insertedRentType = rentType;
    insertedPropertyType = propertyType;
    insertedCity = city;
    insertedBedrooms = bedrooms;
    insertedBathrooms = bathrooms;
    insertedPrice = price;
  }
}
