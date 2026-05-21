import 'package:flutter/material.dart';

import 'services/database_service.dart';

class BuyerProfilePage extends StatefulWidget {
  final String buyerAccountId;
  final String? orderId;
  final bool allowReport;

  const BuyerProfilePage({
    super.key,
    required this.buyerAccountId,
    this.orderId,
    this.allowReport = false,
  });

  @override
  State<BuyerProfilePage> createState() => _BuyerProfilePageState();
}

class _BuyerProfilePageState extends State<BuyerProfilePage> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await DatabaseService.getBuyerPublicProfile(
      widget.buyerAccountId,
    );

    if (!mounted) return;

    setState(() {
      _profile = profile;
      _loading = false;
    });
  }

  String _name() {
    final first = _profile?['firstname']?.toString() ?? '';
    final last = _profile?['surname']?.toString() ?? '';
    final name = '$first $last'.trim();
    return name.isEmpty ? 'Buyer' : name;
  }

  List<Map<String, dynamic>> _list(String key) {
    final value = _profile?[key];
    if (value is List) {
      return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    return [];
  }

  Future<void> _reportBuyer() async {
    String reason = 'Problematic order behavior';
    final detailsController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Report Buyer'),
              content: SizedBox(
                width: 420,
                height: 270,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: reason,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Problematic order behavior',
                          child: Text('Problematic order behavior'),
                        ),
                        DropdownMenuItem(
                          value: 'Fake or abusive review',
                          child: Text('Fake or abusive review'),
                        ),
                        DropdownMenuItem(
                          value: 'Harassment or inappropriate messages',
                          child: Text('Harassment or inappropriate messages'),
                        ),
                        DropdownMenuItem(
                          value: 'Suspicious account activity',
                          child: Text('Suspicious account activity'),
                        ),
                        DropdownMenuItem(
                          value: 'Other',
                          child: Text('Other'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => reason = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TextField(
                        controller: detailsController,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          labelText: 'Details',
                          hintText: 'Explain what happened.',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      detailsController.dispose();
      return;
    }

    final details = detailsController.text.trim();

    if (details.length < 10) {
      detailsController.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least 10 characters of details.'),
        ),
      );
      return;
    }

    final ok = await DatabaseService.reportBuyer(
      buyerAccountId: widget.buyerAccountId,
      orderId: widget.orderId,
      reason: reason,
      details: details,
    );

    detailsController.dispose();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Buyer report submitted for admin review'
              : 'Buyer report could not be submitted',
        ),
      ),
    );
  }

  Widget _stars(dynamic value) {
    final rating = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

  Widget _reviewCard(Map<String, dynamic> review, {required bool product}) {
    final title = product
        ? review['product_name']?.toString() ?? 'Product'
        : review['store_name']?.toString() ?? 'Store';

    final comment = review['comment']?.toString().trim() ?? '';

    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.reviews_outlined),
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stars(review['rating']),
            const SizedBox(height: 4),
            Text(comment.isEmpty ? 'No comment' : comment),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Buyer Profile')),
        body: const Center(child: Text('Buyer profile not found')),
      );
    }

    final imagePath = _profile?['profile_image_url']?.toString() ?? '';
    final productReviews = _list('product_reviews');
    final storeReviews = _list('store_reviews');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buyer Profile'),
        actions: [
          if (widget.allowReport)
            IconButton(
              tooltip: 'Report Buyer',
              onPressed: _reportBuyer,
              icon: const Icon(Icons.flag_outlined),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundImage: imagePath.isNotEmpty
                          ? NetworkImage(
                              DatabaseService.getProfileImageUrl(imagePath),
                            )
                          : null,
                      child: imagePath.isEmpty
                          ? const Icon(Icons.person, size: 42)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_profile?['delivered_orders'] ?? 0} delivered order(s)',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.allowReport) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _reportBuyer,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Report Buyer'),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Product Reviews',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            if (productReviews.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('No product reviews yet'),
                ),
              )
            else
              ...productReviews.map(
                (review) => _reviewCard(review, product: true),
              ),
            const SizedBox(height: 20),
            const Text(
              'Store Reviews',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            if (storeReviews.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('No store reviews yet'),
                ),
              )
            else
              ...storeReviews.map(
                (review) => _reviewCard(review, product: false),
              ),
          ],
        ),
      ),
    );
  }
}