import 'package:flutter/material.dart';
import 'edit_product_page.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'widgets/adaptive_menu_item.dart';
import 'widgets/notification_bell.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  static const List<String> _categories = [
    'Baking Supplies & Ingredients',
    'Coffee, Tea & Beverages',
    'Snacks & Candy',
    'Specialty Foods & International Cuisine',
    'Organic and Health Foods',
    'Meal Kits & Prepped Foods',
    'Fresh Produce',
    'Meat, Seafood & Poultry',
    'Dairy, Eggs & Chilled Goods',
    'Frozen Foods',
    'Condiments, Sauces & Spices',
    'Rice, Grains & Pasta',
    'Ready-to-Eat Meals',
    'Local Delicacies',
  ];

  Map<String, dynamic>? _store;
  Map<String, dynamic>? _account;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _coupons = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String _overviewRange = 'Day';
  String _orderStatusFilter = 'All';

  static const List<String> _overviewRanges = ['Day', 'Week', 'Month', 'Year'];
  static const List<String> _orderStatusFilters = [
    'All',
    'Processing',
    'Ready for Pickup',
    'In Transit',
    'Delivered',
    'Cancelled',
  ];

  Future<void> _logout() async {
    await AuthService.clearLoginSession();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _handleMenu(String value) {
    switch (value) {
      case 'profile':
        Navigator.pushNamed(context, '/profile');
        break;
      case 'settings':
        Navigator.pushNamed(context, '/settings');
        break;
      case 'location':
        Navigator.pushNamed(context, '/addresses');
        break;
      case 'logout':
        _logout();
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final accountId = await DatabaseService.getCurrentAccountId();
      final account = await DatabaseService.getCurrentAccount();
      final store = await DatabaseService.getCurrentSellerStore();
      final storeId = store?['store_id']?.toString();

      final products = storeId == null
          ? <Map<String, dynamic>>[]
          : await DatabaseService.getSellerProducts(storeId);
      final orders = accountId == null
          ? <Map<String, dynamic>>[]
          : await DatabaseService.getSellerOrders(accountId);
      final coupons = storeId == null
          ? <Map<String, dynamic>>[]
          : await DatabaseService.getCouponsForStore(storeId);

      if (mounted) {
        setState(() {
          _store = store;
          _account = account;
          _products = products;
          _orders = orders;
          _coupons = coupons;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load seller dashboard: $e')),
        );
      }
    }
  }

  String _money(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return 'PHP ${amount.toStringAsFixed(2)}';
  }

  int _stock(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _profileMenuHeader() {
    final account = _account;
    if (account == null) return const Text('Profile');
    final imageUrl = account['profile_image_url']?.toString() ?? '';
    final first = account['firstname']?.toString() ?? '';
    final last = account['surname']?.toString() ?? '';
    final name = '$first $last'.trim();
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            child: imageUrl.isEmpty ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Seller' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  account['email']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _status(Map<String, dynamic> order) {
    return order['order_status']?.toString() ?? 'Processing';
  }

  bool _isCancelled(Map<String, dynamic> order) {
    final status = _status(order).toLowerCase();
    return status == 'cancelled' || status == 'canceled';
  }

  bool _isDelivered(Map<String, dynamic> order) {
    return _status(order).toLowerCase() == 'delivered';
  }

  DateTime? _orderDate(Map<String, dynamic> order, {bool preferDelivered = false}) {
    final value = preferDelivered
        ? order['delivered_at'] ?? order['order_date']
        : order['order_date'];
    return DateTime.tryParse(value?.toString() ?? '');
  }

  int _itemCount(Map<String, dynamic> order) {
    final items = order['order_items'];
    if (items is! List) return 0;
    return items.fold<int>(0, (sum, item) {
      if (item is! Map) return sum;
      return sum + _stock(item['quantity']);
    });
  }

  double _sellerOrderValue(Map<String, dynamic> order) {
    return order.containsKey('seller_payout')
        ? _number(order['seller_payout'])
        : _number(order['total_amount']);
  }

  String _periodKey(DateTime date, String range) {
    if (range == 'Year') return '${date.year}';
    if (range == 'Month') {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    }
    if (range == 'Week') {
      final start = DateTime(date.year, date.month, date.day)
          .subtract(Duration(days: date.weekday - 1));
      return 'Week of ${_shortDate(start)}';
    }
    return _shortDate(date);
  }

  String _shortDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _periodStats({
    required Iterable<Map<String, dynamic>> orders,
    required String range,
    bool deliveredOnly = false,
  }) {
    final stats = <String, Map<String, dynamic>>{};
    for (final order in orders) {
      if (_isCancelled(order)) continue;
      if (deliveredOnly && !_isDelivered(order)) continue;
      final date = _orderDate(order, preferDelivered: deliveredOnly);
      if (date == null) continue;
      final key = _periodKey(date, range);
      final row = stats.putIfAbsent(
        key,
        () => {
          'period': key,
          'orders': 0,
          'items': 0,
          'amount': 0.0,
          'date': date,
        },
      );
      row['orders'] = (row['orders'] as int) + 1;
      row['items'] = (row['items'] as int) + _itemCount(order);
      row['amount'] = (row['amount'] as double) + _sellerOrderValue(order);
      final currentDate = row['date'] as DateTime;
      if (date.isAfter(currentDate)) row['date'] = date;
    }

    final rows = stats.values.toList()
      ..sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return rows.take(8).toList();
  }

  List<Map<String, dynamic>> _filteredOrders() {
    if (_orderStatusFilter == 'All') return _orders;
    return _orders
        .where((order) => _status(order) == _orderStatusFilter)
        .toList();
  }

  Widget _buildProductImage(dynamic imageValue, {double size = 56}) {
    final path = imageValue?.toString().trim();
    if (path == null || path.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_outlined),
      );
    }

    final imageUrl = path.startsWith('http')
        ? path
        : DatabaseService.getProductImageUrl(path);

    return Image.network(
      imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        width: size,
        height: size,
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }

  Future<void> _openProductForm([Map<String, dynamic>? product]) async {
    final storeId = _store?['store_id']?.toString();
    if (storeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller store not found')),
      );
      return;
    }

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductPage(
          storeId: storeId,
          product: product,
          categories: _categories,
        ),
      ),
    );

    if (saved == true) {
      await _loadDashboard();
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Hide ${DatabaseService.displayProductName(product['name'])} from buyers?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hide'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok =
        await DatabaseService.deleteProduct(product['product_id'].toString());
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Product hidden' : 'Product could not be hidden')),
    );
    if (ok) _loadDashboard();
  }

  Widget _buildProductsTab() {
    if (_store == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.store_mall_directory_outlined, size: 56),
              const SizedBox(height: 12),
              const Text(
                'No seller store found',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your seller application must be approved before you can manage products.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadDashboard,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 56),
            const SizedBox(height: 12),
            const Text('No products yet'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openProductForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => _openProductForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Product'),
                ),
              ),
            );
          }

          index -= 1;
          final product = _products[index];
          final active = product['is_active'] != false;
          final variants = product['product_variant'];
          final variantCount = variants is List ? variants.length : 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildProductImage(product['main_image_url']),
              ),
              title: Text(DatabaseService.displayProductName(product['name'])),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_money(product['price'])),
                  Text('Stock: ${_stock(product['stock_quantity'])}'),
                  if (variantCount > 0)
                    Text('$variantCount alternate size${variantCount == 1 ? '' : 's'}'),
                  Text(
                    active ? 'Active' : 'Hidden',
                    style: TextStyle(color: active ? Colors.green : Colors.grey),
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _openProductForm(product);
                  if (value == 'delete') _deleteProduct(product);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Edit'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                    ),
                  ),
                ],
              ),
              onTap: () => _openProductForm(product),
            ),
          );
        },
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodSelector() {
    return Wrap(
      spacing: 8,
      children: _overviewRanges
          .map(
            (range) => ChoiceChip(
              label: Text(range),
              selected: _overviewRange == range,
              onSelected: (_) => setState(() => _overviewRange = range),
            ),
          )
          .toList(),
    );
  }

  Widget _orderStatusSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB7E4C7)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _orderStatusFilters
            .map(
              (status) => ChoiceChip(
                label: Text(status),
                selected: _orderStatusFilter == status,
                onSelected: (_) => setState(() => _orderStatusFilter = status),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final deliveredOrders = _orders.where(_isDelivered).toList();
    final activeOrders = _orders.where((order) {
      final status = _status(order);
      return status == 'Processing' ||
          status == 'Ready for Pickup' ||
          status == 'In Transit';
    }).toList();
    final deliveredRevenue = deliveredOrders.fold<double>(
      0,
      (sum, order) => sum + _sellerOrderValue(order),
    );
    final periodRows = _periodStats(
      orders: _orders,
      range: _overviewRange,
    );

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _store?['store_name']?.toString() ?? 'Seller Overview',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sales, orders, and fulfillment history',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _metricCard(
                'Sales',
                _money(deliveredRevenue),
                Icons.payments_outlined,
                Colors.green,
              ),
              const SizedBox(width: 10),
              _metricCard(
                'Delivered',
                '${deliveredOrders.length}',
                Icons.check_circle_outline,
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _metricCard(
                'Active Orders',
                '${activeOrders.length}',
                Icons.local_shipping_outlined,
                Colors.orange,
              ),
              const SizedBox(width: 10),
              _metricCard(
                'Products',
                '${_products.length}',
                Icons.inventory_2_outlined,
                Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'History',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          _periodSelector(),
          const SizedBox(height: 10),
          if (periodRows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No order history yet')),
            )
          else
            ...periodRows.map(
              (row) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.timeline_outlined),
                  ),
                  title: Text(row['period'].toString()),
                  subtitle: Text(
                    '${row['orders']} order${row['orders'] == 1 ? '' : 's'} | ${row['items']} item${row['items'] == 1 ? '' : 's'}',
                  ),
                  trailing: Text(
                    _money(row['amount']),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSalesTab() {
    final summary = DatabaseService.summarizeSales(_orders);

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _metricCard(
                'Revenue',
                _money(summary['revenue']),
                Icons.payments_outlined,
                Colors.green,
              ),
              const SizedBox(width: 10),
              _metricCard(
                'Orders',
                '${summary['orders']}',
                Icons.receipt_long_outlined,
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _metricCard(
                'Items Sold',
                '${summary['itemsSold']}',
                Icons.shopping_bag_outlined,
                Colors.orange,
              ),
              const SizedBox(width: 10),
              _metricCard(
                'Products',
                '${_products.length}',
                Icons.inventory_2_outlined,
                Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Recent Sales',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          if (_orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No sales yet')),
            )
          else
            ..._orders.map((order) {
              final buyer = order['account'];
              final buyerName = buyer is Map
                  ? '${buyer['firstname'] ?? 'Buyer'} ${buyer['surname'] ?? ''}'
                      .trim()
                  : 'Buyer';
              final items = order['order_items'];
              final itemCount = items is List ? items.length : 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.receipt_long_outlined),
                  ),
                  title: Text(_money(order['total_amount'])),
                  subtitle: Text(
                    '$buyerName | $itemCount item${itemCount == 1 ? '' : 's'} | ${order['order_status'] ?? 'Processing'}',
                  ),
                  trailing: Text(
                    order['payment_status']?.toString() ?? 'Pending',
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _updateOrderStatus(
    Map<String, dynamic> order,
    String status,
  ) async {
    final ok = await DatabaseService.sellerUpdateOrderStatus(
      orderId: order['order_id'].toString(),
      status: status,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Order updated' : 'Order could not be updated')),
    );
    if (ok) _loadDashboard();
  }

  Future<void> _showDeliveryProof(Map<String, dynamic> order) async {
    final path = order['proof_of_delivery_url']?.toString();
    if (path == null || path.isEmpty) return;
    final url = await DatabaseService.createSignedStorageUrl(
      bucket: 'delivery-proofs',
      path: path,
    );
    if (!mounted || url == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delivery Proof'),
        content: SizedBox(
          width: 520,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => SelectableText(url),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    final visibleOrders = _filteredOrders();
    if (_orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          children: const [
            SizedBox(height: 160),
            Center(child: Text('No orders to process')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: visibleOrders.isEmpty ? 2 : visibleOrders.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _orderStatusSelector(),
            );
          }

          if (visibleOrders.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: Text('No orders in this state')),
            );
          }

          final order = visibleOrders[index - 1];
          final buyer = order['account'];
          final buyerName = buyer is Map
              ? '${buyer['firstname'] ?? 'Buyer'} ${buyer['surname'] ?? ''}'.trim()
              : 'Buyer';
          final buyerPhone =
              buyer is Map ? buyer['phone_number']?.toString() ?? '' : '';
          final items = order['order_items'];
          final orderItems = items is List ? items : const [];
          final status = order['order_status']?.toString() ?? 'Processing';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          buyerName.isEmpty ? 'Buyer' : buyerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(_money(order['total_amount'])),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...orderItems.map((item) {
                    if (item is! Map) return const SizedBox.shrink();
                    final product = item['product'];
                    final variant = item['product_variant'];
                    final productName = product is Map
                        ? DatabaseService.displayProductName(product['name'])
                        : 'Product';
                    final size = variant is Map
                        ? variant['size_label']?.toString() ?? ''
                        : '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${item['quantity'] ?? 1}x $productName${size.isEmpty ? '' : ' ($size)'}',
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  _orderStateActions(order, status),
                  if (status == 'Ready for Pickup' &&
                      (order['pickup_code']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SelectableText(
                      'Pickup code: ${order['pickup_code']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                  if (buyerPhone.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Customer phone: $buyerPhone')),
                        );
                      },
                      icon: const Icon(Icons.phone),
                      label: const Text('Call Customer'),
                    ),
                  ],
                  if ((order['proof_of_delivery_url']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showDeliveryProof(order),
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Show Delivery Proof'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _orderStateActions(Map<String, dynamic> order, String status) {
    final sellerCanChange = status == 'Processing' || status == 'Ready for Pickup';
    if (!sellerCanChange) {
      return Chip(
        avatar: const Icon(Icons.lock_outline, size: 18),
        label: Text(status),
      );
    }

    final nextStatus =
        status == 'Processing' ? 'Ready for Pickup' : 'Processing';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Chip(label: Text(status)),
        FilledButton.icon(
          onPressed: () => _updateOrderStatus(order, nextStatus),
          icon: Icon(
            status == 'Processing'
                ? Icons.inventory_2_outlined
                : Icons.settings_backup_restore,
          ),
          label: Text(
            status == 'Processing'
                ? 'Ready for Pickup'
                : 'Back to Processing',
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _updateOrderStatus(order, 'Cancelled'),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _openCouponForm([Map<String, dynamic>? coupon]) async {
    final codeController =
        TextEditingController(text: coupon?['code']?.toString() ?? '');
    final descriptionController = TextEditingController(
      text: coupon?['description']?.toString() ?? '',
    );
    final valueController = TextEditingController(
      text: coupon?['discount_value']?.toString() ?? '',
    );
    final minController = TextEditingController(
      text: coupon?['min_subtotal']?.toString() ?? '0',
    );
    final expiryController = TextEditingController(
      text: coupon?['expires_at']?.toString() ?? '',
    );
    var type = coupon?['discount_type']?.toString() ?? 'percent';
    var active = coupon?['is_active'] != false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(coupon == null ? 'Add Shop Coupon' : 'Edit Shop Coupon'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Code'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Discount Type'),
                  items: const [
                    DropdownMenuItem(value: 'percent', child: Text('Percent')),
                    DropdownMenuItem(value: 'amount', child: Text('Amount')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => type = value);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: valueController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Discount Value'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: minController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Minimum Subtotal'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: expiryController,
                  decoration: const InputDecoration(
                    labelText: 'Expires At',
                    hintText: '2026-12-31T23:59:59Z',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                SwitchListTile(
                  value: active,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  onChanged: (value) => setDialogState(() => active = value),
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

    if (saved == true) {
      final storeId = _store?['store_id']?.toString();
      final ok = storeId != null &&
          await DatabaseService.saveCoupon(
            code: codeController.text,
            discountType: type,
            discountValue: double.tryParse(valueController.text.trim()) ?? 0,
            minSubtotal: double.tryParse(minController.text.trim()) ?? 0,
            description: descriptionController.text,
            expiresAt: expiryController.text,
            isActive: active,
            storeId: storeId,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Coupon saved' : 'Coupon could not be saved')),
        );
      }
      if (ok) _loadDashboard();
    }

    codeController.dispose();
    descriptionController.dispose();
    valueController.dispose();
    minController.dispose();
    expiryController.dispose();
  }

  Widget _buildCouponsTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => _openCouponForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add Shop Coupon'),
            ),
          ),
          const SizedBox(height: 12),
          if (_coupons.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: Text('No shop coupons yet')),
            )
          else
            ..._coupons.map((coupon) {
              final type = coupon['discount_type']?.toString() == 'amount'
                  ? 'PHP ${coupon['discount_value']} off'
                  : '${coupon['discount_value']}% off';
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.local_offer_outlined),
                  title: Text(coupon['code']?.toString() ?? 'COUPON'),
                  subtitle: Text(
                    '$type | Used ${coupon['times_used'] ?? 0} time(s)',
                  ),
                  trailing: Switch(
                    value: coupon['is_active'] != false,
                    onChanged: (value) async {
                      await DatabaseService.saveCoupon(
                        code: coupon['code'].toString(),
                        discountType:
                            coupon['discount_type']?.toString() ?? 'percent',
                        discountValue: _number(coupon['discount_value']),
                        minSubtotal: _number(coupon['min_subtotal']),
                        description: coupon['description']?.toString(),
                        expiresAt: coupon['expires_at']?.toString(),
                        isActive: value,
                        storeId: _store?['store_id']?.toString(),
                      );
                      _loadDashboard();
                    },
                  ),
                  onTap: () => _openCouponForm(coupon),
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storeName = _store?['store_name']?.toString() ?? 'Seller Dashboard';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(storeName),
        backgroundColor: const Color(0xFF2d8f4e),
        actions: [
          const NotificationBell(),
          IconButton(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: _handleMenu,
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: _profileMenuHeader(),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'profile',
                child: const AdaptiveMenuItem(icon: Icons.person, title: 'Profile'),
              ),
              PopupMenuItem(
                value: 'location',
                child: const AdaptiveMenuItem(
                  icon: Icons.location_on,
                  title: 'Shop Location',
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: const AdaptiveMenuItem(icon: Icons.settings, title: 'Settings'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: const AdaptiveMenuItem(icon: Icons.logout, title: 'Logout'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentIndex == 0
              ? _buildOverviewTab()
              : _currentIndex == 1
                  ? _buildProductsTab()
                  : _currentIndex == 2
                      ? _buildOrdersTab()
                      : _currentIndex == 3
                          ? _buildSalesTab()
                          : _buildCouponsTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer),
            label: 'Coupons',
          ),
        ],
      ),
    );
  }
}
