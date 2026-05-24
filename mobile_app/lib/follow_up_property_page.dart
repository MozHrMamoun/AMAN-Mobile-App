import 'package:flutter/material.dart';

import 'features/properties/state/follow_up_properties_controller.dart';
import 'owner_home_page.dart';
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
  bool _isDeleting = false;
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
      _isDeleting = true;
    });

    final error = await _controller.deleteProperty(propertyId);

    if (!mounted) return;
    setState(() {
      _isDeleting = false;
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
                    'Follow-up Property',
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
                              child: Text(
                                _selectedFilter == ListingFilter.active
                                    ? 'No active properties found.'
                                    : 'No inactive properties found.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF1F2430),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else if (visibleItems.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 56),
                              child: Text(
                                'No properties match your search.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF1F2430),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
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
                                  isDeleting: _isDeleting,
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
    required this.onUpdate,
    required this.onDelete,
  });

  final OwnerPropertyItem item;
  final bool isDeleting;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
        children: [
          Text(
            item.title,
            style: const TextStyle(
              color: Color(0xFF1F2430),
              fontSize: 36 / 2,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 26),
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
                child: _ActionRow(
                  label: 'Update',
                  icon: Icons.edit_note_rounded,
                  accentColor: const Color(0xFF355C7D),
                  backgroundColor: const Color(0xFFEAF0F6),
                  borderColor: const Color(0xFFD4DFEA),
                  onTap: onUpdate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _InfoRow(
                  icon: Icons.bathtub_rounded,
                  label: 'Bathrooms',
                  value: item.bathrooms,
                ),
              ),
              Expanded(
                child: _ActionRow(
                  label: isDeleting ? 'Deleting' : 'Delete',
                  icon: Icons.delete_rounded,
                  accentColor: const Color(0xFF9A4B5A),
                  backgroundColor: const Color(0xFFF8EDEF),
                  borderColor: const Color(0xFFE8CDD4),
                  onTap: isDeleting ? null : onDelete,
                ),
              ),
            ],
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
