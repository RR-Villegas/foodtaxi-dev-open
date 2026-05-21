import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/database_service.dart';
import 'rider_profile_page.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _ordersChannel;
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
    _subscribeToOrders();
  }

  @override
  void dispose() {
    final channel = _ordersChannel;
    if (channel != null) _supabase.removeChannel(channel);
    super.dispose();
  }

  Future<void> _subscribeToOrders() async {
    final accountId = await DatabaseService.getCurrentAccountId();
    if (!mounted || accountId == null || _ordersChannel != null) return;
    _ordersChannel = _supabase
        .channel('buyer-orders-$accountId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'buyer_account_id',
            value: accountId,
          ),
          callback: (_) => _loadOrders(),
        )
        .subscribe();
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
    final scheme = Theme.of(context).colorScheme;

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
                  selectedColor: scheme.primaryContainer,
                  checkmarkColor: scheme.onPrimaryContainer,
                  labelStyle: TextStyle(
                    color: _statusFilter == status
                        ? scheme.onPrimaryContainer
                        : scheme.onSurface,
                  ),
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
          content: SizedBox(
            width: 420,
            height: 210,
            child: Column(
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
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: commentController,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      labelText: 'Comment',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
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
      SnackBar(
        content: Text(ok ? 'Review saved' : 'Review could not be saved'),
      ),
    );

    if (ok) _loadOrders();
  }

  Map<String, dynamic>? _existingRiderReview(Map<String, dynamic> order) {
    final review = order['rider_review'];

    if (review is List && review.isNotEmpty && review.first is Map) {
      return Map<String, dynamic>.from(review.first as Map);
    }

    if (review is Map) return Map<String, dynamic>.from(review);

    return null;
  }

  Future<void> _reviewRider(Map<String, dynamic> order) async {
    final rider = order['rider'];
    if (rider is! Map) return;

    final riderId = rider['account_id']?.toString();
    final orderId = order['order_id']?.toString();
    if (riderId == null || orderId == null) return;

    var rating = 5;
    final existing = _existingRiderReview(order);

    if (existing?['rating'] is num) {
      rating = (existing!['rating'] as num).toInt();
    }

    final commentController = TextEditingController(
      text: existing?['comment']?.toString() ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Review Rider'),
          content: SizedBox(
            width: 420,
            height: 210,
            child: Column(
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
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: commentController,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      labelText: 'Comment',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
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

    final ok = await DatabaseService.saveRiderReview(
      orderId: orderId,
      riderAccountId: riderId,
      rating: rating,
      comment: commentController.text,
    );

    commentController.dispose();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Rider review saved' : 'Rider review could not be saved'),
      ),
    );

    if (ok) _loadOrders();
  }

  Map<String, dynamic>? _existingReview(Map item) {
    final review = item['product_review'];

    if (review is List && review.isNotEmpty) {
      for (final entry in review) {
        if (entry is Map) {
          return Map<String, dynamic>.from(entry);
        }
      }
    }

    if (review is Map) {
      return Map<String, dynamic>.from(review);
    }

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
    final scheme = Theme.of(context).colorScheme;
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
                color: active
                    ? scheme.primary
                    : scheme.onSurface.withAlpha(120),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                labels[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: active
                      ? scheme.onSurface
                      : scheme.onSurface.withAlpha(140),
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _openOrderStatus(Map<String, dynamic> order) {
    final scheme = Theme.of(context).colorScheme;
    final status = order['order_status']?.toString() ?? 'Processing';

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order ${_shortId(order['order_id'])}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Chip(
              label: Text(status),
              backgroundColor: scheme.secondaryContainer,
              labelStyle: TextStyle(color: scheme.onSecondaryContainer),
            ),
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

  Widget _riderTile(Map<String, dynamic> order) {
    final scheme = Theme.of(context).colorScheme;
    final rider = order['rider'];

    if (rider is! Map) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withAlpha(90),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.delivery_dining, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(
              'No rider assigned yet',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final riderId = rider['account_id']?.toString();
    final first = rider['firstname']?.toString() ?? '';
    final last = rider['surname']?.toString() ?? '';
    final name = '$first $last'.trim().isEmpty ? 'Rider' : '$first $last'.trim();
    final imagePath = rider['profile_image_url']?.toString() ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: riderId == null || riderId.isEmpty
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RiderProfilePage(
                    riderAccountId: riderId,
                  ),
                ),
              ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withAlpha(90),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.primary.withAlpha(70)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: imagePath.isNotEmpty
                  ? NetworkImage(DatabaseService.getProfileImageUrl(imagePath))
                  : null,
              child: imagePath.isEmpty ? const Icon(Icons.delivery_dining) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    riderId == null || riderId.isEmpty
                        ? 'Rider profile unavailable'
                        : 'Tap to view rider profile',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (riderId != null && riderId.isNotEmpty)
              Icon(Icons.chevron_right, color: scheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final scheme = Theme.of(context).colorScheme;
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(status),
                    backgroundColor: scheme.secondaryContainer,
                    labelStyle: TextStyle(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _formatAddress(order['address']),
                      style: TextStyle(color: scheme.onSurface),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              _riderTile(order),

              if (status == 'Delivered' && order['rider'] is Map) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _reviewRider(order),
                    icon: Icon(
                      _existingRiderReview(order) == null
                          ? Icons.star_border
                          : Icons.edit,
                    ),
                    label: Text(
                      _existingRiderReview(order) == null
                          ? 'Review Rider'
                          : 'Edit Rider Review',
                    ),
                  ),
                ),
              ],

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
                  title: Text(
                    productName,
                    style: TextStyle(color: scheme.onSurface),
                  ),
                  subtitle: Text(
                    '${item['quantity'] ?? 1} item${size.isEmpty ? '' : ' | $size'}',
                    style: TextStyle(
                      color: scheme.onSurface.withAlpha(170),
                    ),
                  ),
                  trailing: canReview
                      ? TextButton.icon(
                          onPressed: () => _reviewItem(item),
                          icon: Icon(
                            reviewed ? Icons.edit : Icons.rate_review,
                          ),
                          label: Text(reviewed ? 'Edit' : 'Review'),
                        )
                      : null,
                );
              }),

              const Divider(),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(color: scheme.onSurface),
                  ),
                  Text(
                    _money(order['total_amount']),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
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
                    icon: Icon(
                      Icons.receipt_long_outlined,
                      color: scheme.primary,
                    ),
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: scheme.primary,
              onRefresh: _loadOrders,
              child: _orders.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 180),
                        Center(
                          child: Text(
                            'No orders yet',
                            style: TextStyle(color: scheme.onSurface),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount:
                          _visibleOrders.isEmpty ? 2 : _visibleOrders.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _statusSelector(),
                          );
                        }

                        if (_visibleOrders.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 120),
                            child: Center(
                              child: Text(
                                'No orders in this state',
                                style: TextStyle(color: scheme.onSurface),
                              ),
                            ),
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
