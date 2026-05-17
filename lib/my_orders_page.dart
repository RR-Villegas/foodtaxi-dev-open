import 'package:flutter/material.dart';

import 'services/database_service.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _statusFilter = 'All';
  static const List<String> _statusFilters = [
    'All',
    'Processing',
    'Ready for Pickup',
    'In Transit',
    'Delivered',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final orders = await DatabaseService.getCurrentBuyerOrders();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  String _money(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return 'PHP ${amount.toStringAsFixed(2)}';
  }

  List<Map<String, dynamic>> get _visibleOrders {
    if (_statusFilter == 'All') return _orders;
    return _orders
        .where((order) => order['order_status']?.toString() == _statusFilter)
        .toList();
  }

  Widget _statusSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusFilters
            .map(
              (status) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(status),
                  selected: _statusFilter == status,
                  onSelected: (_) => setState(() => _statusFilter = status),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _reviewItem(Map item) async {
    var rating = 5;
    final commentController = TextEditingController(
      text: _existingReview(item)?['comment']?.toString() ?? '',
    );
    final existingRating = _existingReview(item)?['rating'];
    if (existingRating is num) rating = existingRating.toInt();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Review Product'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final value = index + 1;
                  return IconButton(
                    onPressed: () => setDialogState(() => rating = value),
                    icon: Icon(
                      value <= rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                  );
                }),
              ),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Comment',
                  alignLabelWithHint: true,
                ),
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      commentController.dispose();
      return;
    }

    final ok = await DatabaseService.saveProductReview(
      orderItemId: item['order_item_id'].toString(),
      productId: item['product_id'].toString(),
      rating: rating,
      comment: commentController.text,
    );
    commentController.dispose();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Review saved' : 'Review could not be saved')),
    );
    if (ok) _loadOrders();
  }

  Map<String, dynamic>? _existingReview(Map item) {
    final review = item['product_review'];
    if (review is List && review.isNotEmpty && review.first is Map) {
      return Map<String, dynamic>.from(review.first as Map);
    }
    if (review is Map) return Map<String, dynamic>.from(review);
    return null;
  }

  String _formatAddress(dynamic value) {
    if (value is! Map) return 'No delivery address linked';
    final parts = [
      value['house_number'],
      value['street'],
      value['barangay'],
      value['city'],
      value['province'],
      value['zip_code'],
    ]
        .map((part) => part?.toString().trim() ?? '')
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? 'No delivery address linked' : parts.join(', ');
  }

  int _statusIndex(String status) {
    const states = [
      'Processing',
      'Ready for Pickup',
      'In Transit',
      'Delivered',
    ];
    final index = states.indexWhere(
      (item) => item.toLowerCase() == status.toLowerCase(),
    );
    return index < 0 ? 0 : index;
  }

  Widget _statusFlow(String status) {
    final current = _statusIndex(status);
    const labels = [
      'Processing',
      'Ready for Pickup',
      'In Transit',
      'Delivered',
    ];
    const icons = [
      Icons.inventory_2_outlined,
      Icons.storefront_outlined,
      Icons.local_shipping_outlined,
      Icons.verified_outlined,
    ];

    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= current && status != 'Cancelled';
        return Expanded(
          child: Column(
            children: [
              Icon(
                icons[index],
                color: active ? const Color(0xFF2d8f4e) : Colors.grey,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                labels[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: active ? Colors.black87 : Colors.black45,
                  fontWeight: active ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _openOrderStatus(Map<String, dynamic> order) {
    final status = order['order_status']?.toString() ?? 'Processing';
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order ${_shortId(order['order_id'])}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Chip(label: Text(status)),
            const SizedBox(height: 18),
            _statusFlow(status),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/order-receipt',
                        arguments: order,
                      );
                    },
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Receipt'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final items = order['order_items'];
    final orderItems = items is List ? items.whereType<Map>().toList() : [];
    final status = order['order_status']?.toString() ?? 'Processing';
    final canReview = status == 'Delivered';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openOrderStatus(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Order ${_shortId(order['order_id'])}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Chip(label: Text(status)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_formatAddress(order['address']))),
                ],
              ),
              const Divider(),
              ...orderItems.map((item) {
                final product = item['product'];
                final variant = item['product_variant'];
                final productName = product is Map
                    ? product['name']?.toString() ?? 'Product'
                    : 'Product';
                final size = variant is Map
                    ? variant['size_label']?.toString() ?? ''
                    : '';
                final reviewed = _existingReview(item) != null;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(productName),
                  subtitle: Text(
                    '${item['quantity'] ?? 1} item${size.isEmpty ? '' : ' | $size'}',
                  ),
                  trailing: canReview
                      ? TextButton.icon(
                          onPressed: () => _reviewItem(item),
                          icon: Icon(reviewed ? Icons.edit : Icons.rate_review),
                          label: Text(reviewed ? 'Edit' : 'Review'),
                        )
                      : null,
                );
              }),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total'),
                  Text(
                    _money(order['total_amount']),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _statusFlow(status)),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Receipt',
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/order-receipt',
                      arguments: order,
                    ),
                    icon: const Icon(Icons.receipt_long_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: const Color(0xFF2d8f4e),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: _orders.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 180),
                        Center(child: Text('No orders yet')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _visibleOrders.isEmpty
                          ? 2
                          : _visibleOrders.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _statusSelector(),
                          );
                        }
                        if (_visibleOrders.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 120),
                            child: Center(child: Text('No orders in this state')),
                          );
                        }
                        return _orderCard(_visibleOrders[index - 1]);
                      },
                    ),
            ),
    );
  }

  String _shortId(dynamic value) {
    final id = value?.toString() ?? '';
    if (id.length <= 8) return id;
    return id.substring(0, 8);
  }
}
