import 'package:flutter/material.dart';

import 'features/properties/state/follow_up_properties_controller.dart';
import 'owner_home_page.dart';
import 'update_property_page.dart';

class FollowUpPropertyPage extends StatefulWidget {
  const FollowUpPropertyPage({super.key});

  @override
  State<FollowUpPropertyPage> createState() => _FollowUpPropertyPageState();
}

class _FollowUpPropertyPageState extends State<FollowUpPropertyPage> {
  final FollowUpPropertiesController _controller = FollowUpPropertiesController();
  late Future<FollowUpPropertiesResult> _future;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _future = _controller.loadOwnerProperties();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _controller.loadOwnerProperties();
    });
    await _future;
  }

  Future<void> _deleteProperty(int propertyId) async {
    setState(() {
      _isDeleting = true;
    });

    final error = await _controller.deleteProperty(propertyId);

    if (!mounted) return;
    setState(() {
      _isDeleting = false;
    });

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
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
                            result?.errorMessage ?? 'Failed to load properties.',
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

                    if (result.items.isEmpty) {
                      return const Center(
                        child: Text(
                          'No properties found.',
                          style: TextStyle(
                            color: Color(0xFF1F2430),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                        itemCount: result.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 24),
                        itemBuilder: (context, index) {
                          final item = result.items[index];
                          return _FollowUpCard(
                            item: item,
                            isDeleting: _isDeleting,
                            onUpdate: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      UpdatePropertyPage(propertyId: item.propertyId),
                                ),
                              );
                              await _refresh();
                            },
                            onDelete: () => _deleteProperty(item.propertyId),
                          );
                        },
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
  const _InfoRow({required this.icon, required this.label, required this.value});

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
  const _ActionRow({required this.label, required this.icon, this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1F2430),
                  fontSize: 34 / 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: const Color(0xFF1C2A4A), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
