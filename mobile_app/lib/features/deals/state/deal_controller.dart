import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/deal_repository.dart';
import '../../properties/data/property_repository.dart';

class DealStatusResult {
  const DealStatusResult._({
    required this.success,
    this.errorMessage,
    this.pendingDealId,
    this.dealId,
    this.isPending = false,
    this.isCompleted = false,
    this.currentRole,
    this.propertyId,
  });

  final bool success;
  final String? errorMessage;
  final int? pendingDealId;
  final int? dealId;
  final bool isPending;
  final bool isCompleted;
  final String? currentRole;
  final int? propertyId;

  factory DealStatusResult.pending({
    required int dealId,
    required String role,
    required int? propertyId,
  }) {
    return DealStatusResult._(
      success: true,
      pendingDealId: dealId,
      dealId: dealId,
      isPending: true,
      currentRole: role,
      propertyId: propertyId,
    );
  }

  factory DealStatusResult.completed({
    required String role,
    required int dealId,
    required int? propertyId,
  }) {
    return DealStatusResult._(
      success: true,
      isCompleted: true,
      dealId: dealId,
      currentRole: role,
      propertyId: propertyId,
    );
  }

  factory DealStatusResult.none({required String role}) {
    return DealStatusResult._(
      success: true,
      currentRole: role,
    );
  }

  factory DealStatusResult.error(String message) {
    return DealStatusResult._(success: false, errorMessage: message);
  }
}

class DealActionResult {
  const DealActionResult._({
    required this.success,
    this.errorMessage,
    this.dealId,
    this.propertyId,
  });

  final bool success;
  final String? errorMessage;
  final int? dealId;
  final int? propertyId;

  factory DealActionResult.success({int? dealId, int? propertyId}) {
    return DealActionResult._(
      success: true,
      dealId: dealId,
      propertyId: propertyId,
    );
  }

  factory DealActionResult.error(String message) {
    return DealActionResult._(success: false, errorMessage: message);
  }
}

class DealController {
  DealController({DealRepository? repository})
      : _repository = repository ?? DealRepository();

  final DealRepository _repository;
  final PropertyRepository _propertyRepository = PropertyRepository();

  Future<DealStatusResult> loadStatus({
    required String seekerId,
    required String ownerId,
    required int propertyId,
  }) async {
    try {
      final profile = await _repository.fetchCurrentUserProfile();
      if (profile == null) {
        return DealStatusResult.error('Please login first.');
      }
      final role = (profile['role'] as String?)?.toLowerCase() ?? 'seeker';

      final latest = await _repository.findLatestDeal(
        seekerId: seekerId,
        ownerId: ownerId,
        propertyId: propertyId,
      );

      if (latest == null) {
        return DealStatusResult.none(role: role);
      }

      final dealIdRaw = latest['deal_id'];
      final dealId = dealIdRaw is int
          ? dealIdRaw
          : (dealIdRaw is num ? dealIdRaw.toInt() : null);
      if (dealId == null) {
        return DealStatusResult.error('Invalid deal id.');
      }

      final doneAt = latest['done_at'];
      if (doneAt != null) {
        return DealStatusResult.completed(
          role: role,
          dealId: dealId,
          propertyId: propertyId,
        );
      }

      return DealStatusResult.pending(
        dealId: dealId,
        role: role,
        propertyId: propertyId,
      );
    } on PostgrestException catch (e) {
      return DealStatusResult.error(
        e.message.isEmpty ? 'Failed to load deal status.' : e.message,
      );
    } catch (_) {
      return DealStatusResult.error('Unexpected error while loading deal status.');
    }
  }

  Future<DealStatusResult> loadLatestByUsers({
    required String seekerId,
    required String ownerId,
  }) async {
    try {
      final profile = await _repository.fetchCurrentUserProfile();
      if (profile == null) {
        return DealStatusResult.error('Please login first.');
      }
      final role = (profile['role'] as String?)?.toLowerCase() ?? 'seeker';

      final latest = await _repository.findLatestDealByUsers(
        seekerId: seekerId,
        ownerId: ownerId,
      );
      if (latest == null) {
        return DealStatusResult.none(role: role);
      }

      final dealIdRaw = latest['deal_id'];
      final dealId = dealIdRaw is int
          ? dealIdRaw
          : (dealIdRaw is num ? dealIdRaw.toInt() : null);
      if (dealId == null) {
        return DealStatusResult.error('Invalid deal id.');
      }

      final propertyIdRaw = latest['property_id'];
      final propertyId = propertyIdRaw is int
          ? propertyIdRaw
          : (propertyIdRaw is num ? propertyIdRaw.toInt() : null);

      final doneAt = latest['done_at'];
      if (doneAt != null) {
        return DealStatusResult.completed(
          role: role,
          dealId: dealId,
          propertyId: propertyId,
        );
      }

      return DealStatusResult.pending(
        dealId: dealId,
        role: role,
        propertyId: propertyId,
      );
    } on PostgrestException catch (e) {
      return DealStatusResult.error(
        e.message.isEmpty ? 'Failed to load deal status.' : e.message,
      );
    } catch (_) {
      return DealStatusResult.error('Unexpected error while loading deal status.');
    }
  }

  Future<DealActionResult> requestDeal({
    required String seekerId,
    required String ownerId,
    required int propertyId,
  }) async {
    try {
      final profile = await _repository.fetchCurrentUserProfile();
      if (profile == null) {
        return DealActionResult.error('Please login first.');
      }
      final role = (profile['role'] as String?)?.toLowerCase() ?? 'seeker';
      if (role != 'seeker') {
        return DealActionResult.error('Only seekers can request a deal.');
      }

      final latest = await _repository.findLatestDeal(
        seekerId: seekerId,
        ownerId: ownerId,
        propertyId: propertyId,
      );
      if (latest != null) {
        final doneAt = latest['done_at'];
        if (doneAt != null) {
          return DealActionResult.error('Deal already completed.');
        }
        final dealIdRaw = latest['deal_id'];
        final dealId = dealIdRaw is int
            ? dealIdRaw
            : (dealIdRaw is num ? dealIdRaw.toInt() : null);
        return DealActionResult.success(dealId: dealId);
      }

      final created = await _repository.createPendingDeal(
        seekerId: seekerId,
        ownerId: ownerId,
        propertyId: propertyId,
      );
      final dealIdRaw = created['deal_id'];
      final dealId = dealIdRaw is int
          ? dealIdRaw
          : (dealIdRaw is num ? dealIdRaw.toInt() : null);
      if (dealId == null) {
        return DealActionResult.error('Invalid deal id.');
      }

      return DealActionResult.success(dealId: dealId);
    } on PostgrestException catch (e) {
      return DealActionResult.error(
        e.message.isEmpty ? 'Failed to request deal.' : e.message,
      );
    } catch (_) {
      return DealActionResult.error('Unexpected error while requesting deal.');
    }
  }

  Future<DealActionResult> confirmDeal({
    required int dealId,
    required int propertyId,
  }) async {
    try {
      final profile = await _repository.fetchCurrentUserProfile();
      if (profile == null) {
        return DealActionResult.error('Please login first.');
      }
      final role = (profile['role'] as String?)?.toLowerCase() ?? 'seeker';
      if (role != 'owner') {
        return DealActionResult.error('Only owners can confirm a deal.');
      }

      await _repository.confirmDeal(dealId: dealId);
      await _propertyRepository.markPropertyInactive(propertyId: propertyId);
      return DealActionResult.success(
        dealId: dealId,
        propertyId: propertyId,
      );
    } on PostgrestException catch (e) {
      return DealActionResult.error(
        e.message.isEmpty ? 'Failed to confirm deal.' : e.message,
      );
    } catch (_) {
      return DealActionResult.error('Unexpected error while confirming deal.');
    }
  }
}
