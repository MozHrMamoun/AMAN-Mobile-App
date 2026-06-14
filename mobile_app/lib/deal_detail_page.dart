import 'package:flutter/material.dart';

import 'features/chat/state/chat_list_controller.dart';
import 'features/deals/state/deal_controller.dart';
import 'features/ratings/state/rating_controller.dart';
import 'property_detail_page.dart';

class DealDetailPage extends StatefulWidget {
  const DealDetailPage({
    super.key,
    required this.peerName,
    required this.seekerUserId,
    required this.ownerUserId,
    required this.propertyId,
    this.propertySummary,
  });

  final String peerName;
  final String seekerUserId;
  final String ownerUserId;
  final int propertyId;
  final ChatPropertySummary? propertySummary;

  @override
  State<DealDetailPage> createState() => _DealDetailPageState();
}

class _DealDetailPageState extends State<DealDetailPage> {
  final DealController _dealController = DealController();
  final RatingController _ratingController = RatingController();

  bool _isLoading = true;
  bool _isActionLoading = false;
  bool _isDealPending = false;
  bool _isDealCompleted = false;
  bool _isDealRejected = false;
  bool _hasRated = false;
  String _currentRole = 'seeker';
  int? _dealId;
  double? _peerAverageRating;
  int _peerRatingCount = 0;
  bool _isRatingSummaryLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _targetUserId =>
      _currentRole == 'owner' ? widget.seekerUserId : widget.ownerUserId;

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });

    final status = await _dealController.loadStatus(
      seekerId: widget.seekerUserId,
      ownerId: widget.ownerUserId,
      propertyId: widget.propertyId,
    );

    if (!mounted) return;

    if (!status.success) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status.errorMessage ?? 'Failed to load deal.')),
      );
      return;
    }

    setState(() {
      _currentRole = status.currentRole ?? 'seeker';
      _isDealPending =
          status.isPending && !status.isCompleted && !status.isRejected;
      _isDealCompleted = status.isCompleted;
      _isDealRejected = status.isRejected;
      _dealId = status.dealId;
      _isLoading = false;
      _hasRated = false;
    });

    await _loadPeerRatingSummary();

    if (_isDealCompleted && _dealId != null) {
      await _loadRatingStatus(_dealId!);
    }
  }

  Future<void> _loadRatingStatus(int dealId) async {
    final result = await _ratingController.checkHasRated(dealId: dealId);
    if (!mounted || !result.success) return;

    setState(() {
      _hasRated = result.hasRated;
    });
  }

  Future<void> _loadPeerRatingSummary() async {
    setState(() {
      _isRatingSummaryLoading = true;
    });

    final result = await _ratingController.fetchUserRatingSummary(
      targetUserId: _targetUserId,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isRatingSummaryLoading = false;
        _peerAverageRating = null;
        _peerRatingCount = 0;
      });
      return;
    }

    setState(() {
      _isRatingSummaryLoading = false;
      _peerAverageRating = result.averageRating;
      _peerRatingCount = result.ratingCount;
    });
  }

  Future<void> _requestDeal() async {
    setState(() {
      _isActionLoading = true;
    });

    final result = await _dealController.requestDeal(
      seekerId: widget.seekerUserId,
      ownerId: widget.ownerUserId,
      propertyId: widget.propertyId,
    );

    if (!mounted) return;

    setState(() {
      _isActionLoading = false;
    });

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Failed to request deal.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deal request sent to owner.')),
    );
    await _load();
  }

  Future<void> _confirmDeal() async {
    final dealId = _dealId;
    if (dealId == null) return;

    setState(() {
      _isActionLoading = true;
    });

    final result = await _dealController.confirmDeal(
      dealId: dealId,
      propertyId: widget.propertyId,
    );

    if (!mounted) return;

    setState(() {
      _isActionLoading = false;
    });

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Failed to confirm deal.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deal confirmed. Property is now inactive.'),
      ),
    );
    await _load();
  }

  Future<void> _rejectDeal() async {
    final dealId = _dealId;
    if (dealId == null) return;

    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject deal?'),
          content: const Text(
            'This will mark the deal as rejected for both you and the seeker.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC65D5D),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (shouldReject != true) return;

    setState(() {
      _isActionLoading = true;
    });

    final result = await _dealController.rejectDeal(dealId: dealId);

    if (!mounted) return;

    setState(() {
      _isActionLoading = false;
    });

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Failed to reject deal.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Deal rejected.')));
    await _load();
  }

  Future<void> _showRatingDialog() async {
    final dealId = _dealId;
    if (dealId == null) return;

    double rating = 5.0;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rate this user'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Rating: ${rating.toStringAsFixed(1)}'),
                  Slider(
                    value: rating,
                    min: 1,
                    max: 5,
                    divisions: 40,
                    label: rating.toStringAsFixed(1),
                    onChanged: (value) {
                      setDialogState(() {
                        rating = value;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    setState(() {
      _isActionLoading = true;
    });

    final submit = await _ratingController.submitRating(
      dealId: dealId,
      targetUserId: _targetUserId,
      ratingValue: double.parse(rating.toStringAsFixed(1)),
    );

    if (!mounted) return;

    setState(() {
      _isActionLoading = false;
    });

    if (!submit.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(submit.errorMessage ?? 'Failed to submit rating.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Thank you for your rating.')));
    await _load();
  }

  Widget _buildRatingSummary() {
    if (_isRatingSummaryLoading) {
      return const Text(
        'Loading rating...',
        style: TextStyle(
          color: Color(0xFF6E7583),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (_peerAverageRating == null || _peerRatingCount == 0) {
      return const Text(
        'No ratings yet',
        style: TextStyle(
          color: Color(0xFF6E7583),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: Color(0xFFF4C542), size: 16),
        const SizedBox(width: 4),
        Text(
          '${_peerAverageRating!.toStringAsFixed(1)} ($_peerRatingCount)',
          style: const TextStyle(
            color: Color(0xFF6E7583),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyCard() {
    final property = widget.propertySummary;
    if (property == null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => PropertyDetailPage(propertyId: property.propertyId),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDE0E5)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child:
                      property.imageUrl == null ||
                              property.imageUrl!.trim().isEmpty
                          ? Container(
                            color: const Color(0xFFF2F2F3),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.home_work_outlined,
                              color: Color(0xFF8E949F),
                            ),
                          )
                          : Image.network(
                            property.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => Container(
                                  color: const Color(0xFFF2F2F3),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    color: Color(0xFF8E949F),
                                  ),
                                ),
                          ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2430),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      property.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6E7583),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bedrooms: ${property.bedrooms ?? '-'}   Bathrooms: ${property.bathrooms ?? '-'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6E7583),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Price: ${property.price}',
                      style: const TextStyle(
                        color: Color(0xFF1F2430),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Color(0xFF1C2A4A),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    String title;
    String description;
    Color tone;

    if (_isDealCompleted) {
      title = 'Completed';
      description =
          'The owner confirmed this deal. The property is inactive now.';
      tone = const Color(0xFF2F7D32);
    } else if (_isDealRejected) {
      title = 'Rejected';
      description =
          _currentRole == 'owner'
              ? 'You rejected this deal request.'
              : 'The owner rejected this deal request.';
      tone = const Color(0xFFC65D5D);
    } else if (_isDealPending) {
      title = 'Pending Confirmation';
      description =
          _currentRole == 'owner'
              ? 'The seeker requested completion. Confirm it here when the deal is really done.'
              : 'You requested completion. The owner still needs to confirm it.';
      tone = const Color(0xFFD68600);
    } else {
      title = 'No Completion Request Yet';
      description =
          _currentRole == 'seeker'
              ? 'When the deal is finished, request completion here.'
              : 'Wait for the seeker to request completion before confirming.';
      tone = const Color(0xFF6E7583);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE0E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: tone, size: 12),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: tone,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF4A5160),
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionArea() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isDealCompleted) {
      if (_dealId != null && !_hasRated) {
        return SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: _isActionLoading ? null : _showRatingDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C2A4A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child:
                _isActionLoading
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Text(
                      'Rate User',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
          ),
        );
      }

      return const Center(
        child: Text(
          'Deal completed and rating handled.',
          style: TextStyle(
            color: Color(0xFF2F7D32),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (_isDealRejected) {
      return Center(
        child: Text(
          _currentRole == 'owner'
              ? 'You rejected this deal.'
              : 'This deal was rejected by the owner.',
          style: const TextStyle(
            color: Color(0xFFC65D5D),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (_isDealPending) {
      if (_currentRole == 'owner') {
        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: _isActionLoading ? null : _rejectDeal,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC65D5D),
                    side: const BorderSide(color: Color(0xFFE4B5B5)),
                    backgroundColor: const Color(0xFFFFF5F5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _isActionLoading ? null : _confirmDeal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C2A4A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child:
                      _isActionLoading
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text(
                            'Confirm',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                ),
              ),
            ),
          ],
        );
      }

      return const Center(
        child: Text(
          'Waiting for owner confirmation.',
          style: TextStyle(
            color: Color(0xFF8E949F),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (_currentRole == 'seeker') {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: _isActionLoading ? null : _requestDeal,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1C2A4A),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child:
              _isActionLoading
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : const Text(
                    'Request Completion',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
        ),
      );
    }

    return const Center(
      child: Text(
        'No action needed yet.',
        style: TextStyle(
          color: Color(0xFF8E949F),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1C2A4A);
    const page = Color(0xFFE9EAEC);

    return Scaffold(
      backgroundColor: primary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Deal Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.peerName,
                        style: const TextStyle(
                          color: Color(0xFFD1D4D9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildRatingSummary(),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: page,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    children: [
                      _buildPropertyCard(),
                      if (widget.propertySummary != null)
                        const SizedBox(height: 14),
                      _buildStatusCard(),
                      const SizedBox(height: 16),
                      _buildActionArea(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
