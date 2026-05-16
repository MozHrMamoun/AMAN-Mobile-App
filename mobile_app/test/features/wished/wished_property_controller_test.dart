import 'package:aman/features/notifications/data/notification_repository.dart';
import 'package:aman/features/notifications/state/notification_controller.dart';
import 'package:aman/features/wished/data/wished_property_repository.dart';
import 'package:aman/features/wished/state/wished_property_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('WishedPropertyController.saveWish', () {
    test('requires a logged in seeker', () async {
      final controller = WishedPropertyController(
        repository: FakeWishedPropertyRepository(currentUserIdValue: null),
        notificationController: FakeNotificationController(),
      );

      final result = await controller.saveWish(
        isBuy: true,
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
        repository: FakeWishedPropertyRepository(currentUserIdValue: 'seeker-1'),
        notificationController: FakeNotificationController(),
      );

      final result = await controller.saveWish(
        isBuy: false,
        propertyType: '',
        city: null,
        bedrooms: null,
        bathrooms: null,
        priceText: '',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Please select property type and city.');
    });

    test('validates numeric price input', () async {
      final controller = WishedPropertyController(
        repository: FakeWishedPropertyRepository(currentUserIdValue: 'seeker-1'),
        notificationController: FakeNotificationController(),
      );

      final result = await controller.saveWish(
        isBuy: true,
        propertyType: 'Apartment',
        city: 'Suakin',
        bedrooms: '2',
        bathrooms: '1',
        priceText: 'not-a-number',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Price must be a valid number.');
    });

    test('saves wish and ignores AI matching failure', () async {
      final repository = FakeWishedPropertyRepository(currentUserIdValue: 'seeker-9');
      final notificationController = FakeNotificationController(shouldThrow: true);
      final controller = WishedPropertyController(
        repository: repository,
        notificationController: notificationController,
      );

      final result = await controller.saveWish(
        isBuy: false,
        propertyType: 'House',
        city: 'Port Sudan',
        bedrooms: '5+',
        bathrooms: '2',
        priceText: '900000',
      );

      expect(result.success, isTrue);
      expect(repository.insertedSeekerId, 'seeker-9');
      expect(repository.insertedTransactionType, 'rent');
      expect(repository.insertedPropertyType, 'House');
      expect(repository.insertedCity, 'Port Sudan');
      expect(repository.insertedBedrooms, 5);
      expect(repository.insertedBathrooms, 2);
      expect(repository.insertedPrice, 900000);
      expect(notificationController.runCount, 1);
    });

    test('returns database error from repository', () async {
      final controller = WishedPropertyController(
        repository: FakeWishedPropertyRepository(
          currentUserIdValue: 'seeker-2',
          insertException: const PostgrestException(message: 'Insert failed'),
        ),
        notificationController: FakeNotificationController(),
      );

      final result = await controller.saveWish(
        isBuy: true,
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
    required String propertyType,
    required String city,
    int? bedrooms,
    int? bathrooms,
    double? price,
  }) async {
    if (insertException != null) throw insertException!;

    insertedSeekerId = seekerId;
    insertedTransactionType = transactionType;
    insertedPropertyType = propertyType;
    insertedCity = city;
    insertedBedrooms = bedrooms;
    insertedBathrooms = bathrooms;
    insertedPrice = price;
  }
}

class FakeNotificationController extends NotificationController {
  FakeNotificationController({this.shouldThrow = false})
      : super(repository: FakeNotificationRepository());

  final bool shouldThrow;
  int runCount = 0;

  @override
  Future<void> runAiMatchingOnly() async {
    runCount += 1;
    if (shouldThrow) {
      throw Exception('AI matching failed');
    }
  }
}

class FakeNotificationRepository implements NotificationRepository {
  @override
  String? get currentUserId => null;

  @override
  Future<List<Map<String, dynamic>>> fetchNotificationsForUser(String userId) async {
    return const [];
  }

  @override
  Future<int> fetchUnreadCount(String userId) async {
    return 0;
  }

  @override
  Future<void> markNotificationRead(int notificationId) async {}

  @override
  Future<void> runAiMatching() async {}
}
