import 'package:flutter/material.dart';

import 'core/app_session.dart';
import 'deal_detail_page.dart';
import 'features/deals/state/deals_list_controller.dart';
import 'more_service_page.dart';
import 'owner_home_page.dart';

enum DealsFilter { active, completed }

class MyDealsPage extends StatefulWidget {
  const MyDealsPage({
    super.key,
    this.initialRole,
    this.initialFilter = DealsFilter.active,
  });

  final String? initialRole;
  final DealsFilter initialFilter;

  @override
  State<MyDealsPage> createState() => _MyDealsPageState();
}

class _MyDealsPageState extends State<MyDealsPage> {
  final DealsListController _controller = DealsListController();

  bool _isLoading = true;
  String? _errorMessage;
  String _currentRole = 'seeker';
  List<DealListItem> _allItems = const [];
  late DealsFilter _selectedFilter;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.initialRole ?? 'seeker';
    _selectedFilter = widget.initialFilter;
    if (AppSession.isGuestMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to use this feature.')),
        );
        Navigator.of(context).maybePop();
      });
      return;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _controller.loadDeals();
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage ?? 'Failed to load deals.';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _currentRole = result.currentRole ?? _currentRole;
      _allItems = result.items;
    });
  }

  void _goBack() {
    if (_currentRole == 'owner') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OwnerHomePage()),
      );
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MoreServicePage()),
    );
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final h = hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $suffix';
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1C2A4A);
    const page = Color(0xFFE9EAEC);

    final activeItems = _allItems.where((e) => !e.isCompleted).toList();
    final completedItems = _allItems.where((e) => e.isCompleted).toList();
    final visibleItems = _selectedFilter == DealsFilter.active
        ? activeItems
        : completedItems;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _goBack();
        }
      },
      child: Scaffold(
        backgroundColor: primary,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text(
                      'My Deals',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: _goBack,
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
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFF1F2430),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                                children: [
                                  _DealsSegmentedControl(
                                    selectedFilter: _selectedFilter,
                                    activeCount: activeItems.length,
                                    completedCount: completedItems.length,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedFilter = value;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  if (visibleItems.isEmpty)
                                    const _EmptyState(
                                      text: 'No deals found for this section.',
                                    )
                                  else
                                    ...visibleItems.map(
                                      (item) => Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _DealCard(
                                          item: item,
                                          timeLabel: item.isCompleted
                                              ? 'Completed ${_formatDate(item.doneAt)} ${_formatTime(item.doneAt)}'
                                              : 'Started ${_formatDate(item.createdAt)} ${_formatTime(item.createdAt)}',
                                          statusLabel: item.isCompleted
                                              ? 'Completed'
                                              : _currentRole == 'owner'
                                                  ? 'Pending your confirmation'
                                                  : 'Waiting for owner confirmation',
                                          statusColor: item.isCompleted
                                              ? const Color(0xFF2F7D32)
                                              : const Color(0xFFD68600),
                                          onTap: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => DealDetailPage(
                                                  peerName: item.otherUserName,
                                                  seekerUserId: item.seekerUserId,
                                                  ownerUserId: item.ownerUserId,
                                                  propertyId: item.propertyId,
                                                  propertySummary: item.propertySummary,
                                                ),
                                              ),
                                            );
                                            await _load();
                                          },
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DealsSegmentedControl extends StatelessWidget {
  const _DealsSegmentedControl({
    required this.selectedFilter,
    required this.activeCount,
    required this.completedCount,
    required this.onChanged,
  });

  final DealsFilter selectedFilter;
  final int activeCount;
  final int completedCount;
  final ValueChanged<DealsFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1D4D9)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DealsFilterTab(
              label: 'Active',
              count: activeCount,
              selected: selectedFilter == DealsFilter.active,
              onTap: () => onChanged(DealsFilter.active),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DealsFilterTab(
              label: 'Completed',
              count: completedCount,
              selected: selectedFilter == DealsFilter.completed,
              onTap: () => onChanged(DealsFilter.completed),
            ),
          ),
        ],
      ),
    );
  }
}

class _DealsFilterTab extends StatelessWidget {
  const _DealsFilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1C2A4A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF1F2430),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0x33FFFFFF)
                    : const Color(0xFF1C2A4A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE0E5)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF8E949F),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({
    required this.item,
    required this.timeLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
  });

  final DealListItem item;
  final String timeLabel;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final property = item.propertySummary;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDE0E5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 74,
                  height: 74,
                  child: property == null ||
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
                          errorBuilder: (_, __, ___) => Container(
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
                      property?.title ?? 'Property #${item.propertyId}',
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
                      'With: ${item.otherUserName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF4A5160),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (property != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        property.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8E949F),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8E949F),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
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
}
