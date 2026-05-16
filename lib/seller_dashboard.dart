import 'package:flutter/material.dart';
import 'edit_product_page.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
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
  ];

  Map<String, dynamic>? _store;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _orders = [];
  int _currentIndex = 0;
  bool _isLoading = true;

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
      final store = await DatabaseService.getCurrentSellerStore();
      final storeId = store?['store_id']?.toString();

      final products = storeId == null
          ? <Map<String, dynamic>>[]
          : await DatabaseService.getSellerProducts(storeId);
      final orders = accountId == null
          ? <Map<String, dynamic>>[]
          : await DatabaseService.getSellerOrders(accountId);

      if (mounted) {
        setState(() {
          _store = store;
          _products = products;
          _orders = orders;
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
        content: Text('Hide ${product['name'] ?? 'this product'} from buyers?'),
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
              title: Text(product['name']?.toString() ?? 'Product'),
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
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
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
                        ? product['name']?.toString() ?? 'Product'
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
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Profile'),
                ),
              ),
              PopupMenuItem(
                value: 'location',
                child: ListTile(
                  leading: Icon(Icons.location_on),
                  title: Text('Shop Location'),
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentIndex == 0
              ? _buildProductsTab()
              : _currentIndex == 1
                  ? _buildOrdersTab()
                  : _buildSalesTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
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
        ],
      ),
    );
  }
}
