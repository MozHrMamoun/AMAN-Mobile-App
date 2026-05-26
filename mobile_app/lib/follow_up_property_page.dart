import 'package:flutter/material.dart';

import 'features/properties/state/follow_up_properties_controller.dart';
import 'owner_home_page.dart';
import 'property_detail_page.dart';
import 'update_property_page.dart';

enum ListingFilter { active, inactive }

class FollowUpPropertyPage extends StatefulWidget {
  const FollowUpPropertyPage({
    super.key,
    this.initialFilter = ListingFilter.active,
  });

  final ListingFilter initialFilter;

  @override
  State<FollowUpPropertyPage> createState() => _FollowUpPropertyPageState();
}

class _FollowUpPropertyPageState extends State<FollowUpPropertyPage> {
  final FollowUpPropertiesController _controller =
      FollowUpPropertiesController();
  final TextEditingController _searchController = TextEditingController();
  late Future<FollowUpPropertiesResult> _future;
  int? _deletingPropertyId;
  late ListingFilter _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _future = _controller.loadOwnerProperties();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeQuery(String value) {
    return value.trim().toLowerCase();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _controller.loadOwnerProperties();
    });
    await _future;
  }

  Future<void> _deleteProperty(int propertyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete property?'),
          content: const Text(
            'This will permanently delete the property and its images. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C2A4A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _deletingPropertyId = propertyId;
    });

    final error = await _controller.deleteProperty(propertyId);

    if (!mounted) return;
    setState(() {
      _deletingPropertyId = null;
    });

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Property deleted successfully.')),
    );
    await _refresh();
  }

  Future<void> _togglePropertyStatus(OwnerPropertyItem item) async {
    final nextStatus = item.status == 'active' ? 'inactive' : 'active';
    final error = await _controller.updatePropertyStatus(
      propertyId: item.propertyId,
      status: nextStatus,
    );

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextStatus == 'active'
              ? 'Property activated successfully.'
              : 'Property moved to inactive.',
        ),
      ),
    );
    await _refresh();
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
                  const Text(
                    'Manage Listings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 37 / 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OwnerHomePage(),
                          ),
                        );
                      },
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
                child: FutureBuilder<FollowUpPropertiesResult>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Failed to load properties.',
                            style: const TextStyle(
                              color: Color(0xFF1F2430),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final result = snapshot.data;
                    if (result == null || !result.success) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            result?.errorMessage ??
                                'Failed to load properties.',
                            style: const TextStyle(
                              color: Color(0xFF1F2430),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final filteredItems =
                        result.items.where((item) {
                          if (_selectedFilter == ListingFilter.active) {
                            return item.status == 'active';
                          }
                          return item.status != 'active';
                        }).toList();
                    final searchQuery = _normalizeQuery(_searchController.text);
                    final visibleItems =
                        searchQuery.isEmpty
                            ? filteredItems
                            : filteredItems.where((item) {
                              final haystack = _normalizeQuery(
                                '${item.propertyType} ${item.propertyState} ${item.propertyCity} ${item.title}',
                              );
                              return haystack.contains(searchQuery);
                            }).toList();

                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                        children: [
                          _ListingSegmentedControl(
                            selectedFilter: _selectedFilter,
                            onChanged: (value) {
                              setState(() {
                                _selectedFilter = value;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          _SearchFilterField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 20),
                          if (filteredItems.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 56),
                              child: _OwnerEmptyState(
                                title: _selectedFilter == ListingFilter.active
                                    ? 'No active properties found.'
                                    : 'No inactive properties found.',
                                description: _selectedFilter == ListingFilter.active
                                    ? 'Add a new listing or reactivate one of your inactive properties.'
                                    : 'Inactive listings will appear here when you hide them from the market.',
                                actionLabel: _selectedFilter == ListingFilter.active
                                    ? 'Back to Home'
                                    : 'Show active listings',
                                onTap: () {
                                  if (_selectedFilter == ListingFilter.active) {
                                    Navigator.of(context).pop();
                                  } else {
                                    setState(() {
                                      _selectedFilter = ListingFilter.active;
                                    });
                                  }
                                },
                              ),
                            )
                          else if (visibleItems.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 56),
                              child: _OwnerEmptyState(
                                title: 'No properties match your search.',
                                description:
                                    'Try another city, property type, or clear the search to see more listings.',
                                actionLabel: 'Clear search',
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              ),
                            )
                          else
                            ...List.generate(visibleItems.length, (index) {
                              final item = visibleItems[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      index == visibleItems.length - 1 ? 0 : 24,
                                ),
                                child: _FollowUpCard(
                                  item: item,
                                  isDeleting:
                                      _deletingPropertyId == item.propertyId,
                                  onView: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => PropertyDetailPage(
                                              propertyId: item.propertyId,
                                            ),
                                      ),
                                    );
                                  },
                                  onUpdate: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => UpdatePropertyPage(
                                              propertyId: item.propertyId,
                                            ),
                                      ),
                                    );
                                    await _refresh();
                                  },
                                  onToggleStatus: () => _togglePropertyStatus(item),
                                  onDelete:
                                      () => _deleteProperty(item.propertyId),
                                ),
                              );
                            }),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchFilterField extends StatelessWidget {
  const _SearchFilterField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1D4D9)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          hintText: 'Search by type, state, or city',
          hintStyle: const TextStyle(
            color: Color(0xFF98A2B3),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF1C2A4A),
          ),
          suffixIcon:
              controller.text.isEmpty
                  ? null
                  : IconButton(
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF667085),
                    ),
                  ),
        ),
      ),
    );
  }
}

class _ListingSegmentedControl extends StatelessWidget {
  const _ListingSegmentedControl({
    required this.selectedFilter,
    required this.onChanged,
  });

  final ListingFilter selectedFilter;
  final ValueChanged<ListingFilter> onChanged;

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
            child: _ListingFilterTab(
              label: 'Active',
              selected: selectedFilter == ListingFilter.active,
              onTap: () => onChanged(ListingFilter.active),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ListingFilterTab(
              label: 'Inactive',
              selected: selectedFilter == ListingFilter.inactive,
              onTap: () => onChanged(ListingFilter.inactive),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingFilterTab extends StatelessWidget {
  const _ListingFilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1C2A4A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF1F2430),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard({
    required this.item,
    required this.isDeleting,
    required this.onView,
    required this.onUpdate,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final OwnerPropertyItem item;
  final bool isDeleting;
  final VoidCallback onView;
  final VoidCallback onUpdate;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isActive = item.status == 'active';
    final transactionLabel =
        item.transactionType == 'rent'
            ? item.rentType == 'monthly'
                ? 'Rent - Monthly'
                : item.rentType == 'yearly'
                    ? 'Rent - Yearly'
                    : 'Rent'
            : 'Buy';

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1D4D9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            offset: Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 92,
                    child:
                        item.imageUrl == null || item.imageUrl!.trim().isEmpty
                            ? Container(
                                color: const Color(0xFFEDEFF2),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.home_work_outlined,
                                  color: Color(0xFF8E949F),
                                  size: 30,
                                ),
                              )
                            : Image.network(
                                item.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) => Container(
                                      color: const Color(0xFFEDEFF2),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.broken_image_outlined,
                                        color: Color(0xFF8E949F),
                                        size: 30,
                                      ),
                                    ),
                              ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Color(0xFF1F2430),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ListingBadge(
                          label: isActive ? 'Active' : 'Inactive',
                          color: isActive
                              ? const Color(0xFF2F7D32)
                              : const Color(0xFF7A6F8F),
                          backgroundColor: isActive
                              ? const Color(0xFFE4F3E8)
                              : const Color(0xFFF0EAF7),
                        ),
                        _ListingBadge(
                          label: transactionLabel,
                          color: const Color(0xFF355C7D),
                          backgroundColor: const Color(0xFFEAF0F6),
                        ),
                        _ListingBadge(
                          label: 'Price ${item.priceLabel}',
                          color: const Color(0xFF1C2A4A),
                          backgroundColor: const Color(0xFFEDF1F8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _InfoRow(
                  icon: Icons.bed_rounded,
                  label: 'Bedrooms',
                  value: item.bedrooms,
                ),
              ),
              Expanded(
                child: _InfoRow(
                  icon: Icons.bathtub_rounded,
                  label: 'Bathrooms',
                  value: item.bathrooms,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionRow(
                label: 'View',
                icon: Icons.visibility_rounded,
                accentColor: const Color(0xFF1C2A4A),
                backgroundColor: const Color(0xFFEDF1F8),
                borderColor: const Color(0xFFD7E0F0),
                onTap: onView,
              ),
              _ActionRow(
                label: 'Update',
                icon: Icons.edit_note_rounded,
                accentColor: const Color(0xFF355C7D),
                backgroundColor: const Color(0xFFEAF0F6),
                borderColor: const Color(0xFFD4DFEA),
                onTap: onUpdate,
              ),
              _ActionRow(
                label: isActive ? 'Deactivate' : 'Activate',
                icon: isActive
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded,
                accentColor: isActive
                    ? const Color(0xFF7A6F8F)
                    : const Color(0xFF2F7D32),
                backgroundColor: isActive
                    ? const Color(0xFFF0EAF7)
                    : const Color(0xFFE4F3E8),
                borderColor: isActive
                    ? const Color(0xFFE1D5F2)
                    : const Color(0xFFCFE8D6),
                onTap: onToggleStatus,
              ),
              _ActionRow(
                label: isDeleting ? 'Deleting' : 'Delete',
                icon: Icons.delete_rounded,
                accentColor: const Color(0xFF9A4B5A),
                backgroundColor: const Color(0xFFF8EDEF),
                borderColor: const Color(0xFFE8CDD4),
                onTap: isDeleting ? null : onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListingBadge extends StatelessWidget {
  const _ListingBadge({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OwnerEmptyState extends StatelessWidget {
  const _OwnerEmptyState({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE0E5)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_rounded,
            color: Color(0xFF8E949F),
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1F2430),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8E949F),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C2A4A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1C2A4A), size: 24),
        const SizedBox(width: 10),
        Text(
          '$label: ${value ?? '-'}',
          style: const TextStyle(
            color: Color(0xFF1F2430),
            fontSize: 34 / 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
    required this.borderColor,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final resolvedAccent = isEnabled ? accentColor : const Color(0xFF98A2B3);
    final resolvedBackground =
        isEnabled ? backgroundColor : const Color(0xFFF2F4F7);
    final resolvedBorder = isEnabled ? borderColor : const Color(0xFFDDE3EA);

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: resolvedBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: resolvedBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: resolvedAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: resolvedAccent,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
