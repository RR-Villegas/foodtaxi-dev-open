import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _productsChannel;

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
  List<Map<String, dynamic>> _productDiscounts = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String _overviewRange = 'Day';
  String _orderStatusFilter = 'All';
  String _productCategoryFilter = 'All';
  String _productSort = 'Newest';
  int _productsPage = 0;

  static const List<String> _overviewRanges = ['Day', 'Week', 'Month', 'Year'];
  static const int _productsPerPage = 10;
  static const List<String> _productSortOptions = [
    'Newest',
    'Oldest',
    'A-Z',
    'Z-A',
    'Price: Low to High',
    'Price: High to Low',
    'Discount: High to Low',
    'Discount: Low to High',
  ];
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

  @override
  void dispose() {
    final ordersChannel = _ordersChannel;
    final productsChannel = _productsChannel;
    if (ordersChannel != null) _supabase.removeChannel(ordersChannel);
    if (productsChannel != null) _supabase.removeChannel(productsChannel);
    super.dispose();
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
      final productDiscounts = storeId == null
          ? <Map<String, dynamic>>[]
          : await DatabaseService.getProductDiscountsForStore(storeId);
      _subscribeToDashboard(accountId: accountId, storeId: storeId);

      if (mounted) {
        setState(() {
          _store = store;
          _account = account;
          _products = products;
          _orders = orders;
          _coupons = coupons;
          _productDiscounts = productDiscounts;
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

  DateTime _productDate(Map<String, dynamic> product) {
    return DateTime.tryParse(
          product['created_at']?.toString() ??
              product['updated_at']?.toString() ??
              '',
        ) ??
        DateTime(0);
  }

  double _productLowestPrice(Map<String, dynamic> product) {
    final prices = <double>[_number(product['price'])];
    final variants = product['product_variant'];
    if (variants is List) {
      for (final variant in variants.whereType<Map>()) {
        if (variant['is_active'] == false) continue;
        prices.add(_number(variant['price']));
      }
    }
    final discount = DatabaseService.activeProductDiscount(product);
    final discounted = prices
        .map((price) => DatabaseService.discountedPrice(price, discount))
        .where((price) => price >= 0)
        .toList();
    if (discounted.isEmpty) return 0;
    discounted.sort();
    return discounted.first;
  }

  double _productDiscountPercent(Map<String, dynamic> product) {
    final discount = DatabaseService.activeProductDiscount(product);
    if (discount == null) return 0;
    final value = _number(discount['discount_value']);
    if (discount['discount_type']?.toString() == 'percent') return value;
    final basePrices = <double>[_number(product['price'])];
    final variants = product['product_variant'];
    if (variants is List) {
      for (final variant in variants.whereType<Map>()) {
        if (variant['is_active'] == false) continue;
        basePrices.add(_number(variant['price']));
      }
    }
    basePrices.sort();
    final base = basePrices.isEmpty ? 0 : basePrices.first;
    return base <= 0 ? 0 : (value / base) * 100;
  }

  List<Map<String, dynamic>> _filteredProducts() {
    final availableCategories = _products
        .map((product) => product['category']?.toString() ?? '')
        .where((category) => category.isNotEmpty)
        .toSet();
    final categoryFilter = availableCategories.contains(_productCategoryFilter)
        ? _productCategoryFilter
        : 'All';
    final filtered = _products.where((product) {
      if (categoryFilter == 'All') return true;
      return product['category']?.toString() == categoryFilter;
    }).toList();

    filtered.sort((a, b) {
      switch (_productSort) {
        case 'Oldest':
          return _productDate(a).compareTo(_productDate(b));
        case 'A-Z':
          return DatabaseService.displayProductName(a['name'])
              .toLowerCase()
              .compareTo(DatabaseService.displayProductName(b['name']).toLowerCase());
        case 'Z-A':
          return DatabaseService.displayProductName(b['name'])
              .toLowerCase()
              .compareTo(DatabaseService.displayProductName(a['name']).toLowerCase());
        case 'Price: Low to High':
          return _productLowestPrice(a).compareTo(_productLowestPrice(b));
        case 'Price: High to Low':
          return _productLowestPrice(b).compareTo(_productLowestPrice(a));
        case 'Discount: Low to High':
          return _productDiscountPercent(a).compareTo(_productDiscountPercent(b));
        case 'Discount: High to Low':
          return _productDiscountPercent(b).compareTo(_productDiscountPercent(a));
        case 'Newest':
        default:
          return _productDate(b).compareTo(_productDate(a));
      }
    });
    return filtered;
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
            backgroundImage: imageUrl.isNotEmpty
                ? NetworkImage(DatabaseService.getProfileImageUrl(imageUrl))
                : null,
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

  Map<dynamic, dynamic>? _buyerFor(Map<String, dynamic> order) {
    final account = order['account'];
    if (account is Map) return account;
    final buyer = order['buyer'];
    if (buyer is Map) return buyer;
    return null;
  }

  String _buyerName(Map<String, dynamic> order) {
    final buyer = _buyerFor(order);
    final firstName = buyer?['firstname']?.toString().trim() ?? '';
    final surname = buyer?['surname']?.toString().trim() ?? '';
    final fullName = '$firstName $surname'.trim();
    if (fullName.isNotEmpty) return fullName;

    final email = buyer?['email']?.toString().trim() ?? '';
    if (email.isNotEmpty) return email;

    final phone = buyer?['phone_number']?.toString().trim() ?? '';
    if (phone.isNotEmpty) return phone;

    final buyerId = order['buyer_account_id']?.toString() ?? '';
    if (buyerId.length >= 8) return 'Buyer ${buyerId.substring(0, 8)}';
    return 'Unknown Buyer';
  }

  String _buyerPhone(Map<String, dynamic> order) {
    return _buyerFor(order)?['phone_number']?.toString().trim() ?? '';
  }

  String _buyerContactLine(Map<String, dynamic> order) {
    final buyer = _buyerFor(order);
    final email = buyer?['email']?.toString().trim() ?? '';
    final phone = buyer?['phone_number']?.toString().trim() ?? '';
    return [
      if (email.isNotEmpty) email,
      if (phone.isNotEmpty) phone,
    ].join(' | ');
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

  void _subscribeToDashboard({String? accountId, String? storeId}) {
    if (accountId != null && _ordersChannel == null) {
      _ordersChannel = _supabase
          .channel('seller-orders-$accountId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'seller_account_id',
              value: accountId,
            ),
            callback: (_) => _loadDashboard(),
          )
          .subscribe();
    }

    if (storeId != null && _productsChannel == null) {
      _productsChannel = _supabase
          .channel('seller-products-$storeId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'product',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'store_id',
              value: storeId,
            ),
            callback: (_) => _loadDashboard(),
          )
          .subscribe();
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

  Widget _buildProductFilters(int visibleCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: () => _openProductForm(),
            icon: const Icon(Icons.add),
            label: const Text('Add Product'),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final categories = <String>{
              'All',
              ..._categories,
              ..._products
                  .map((product) => product['category']?.toString() ?? '')
                  .where((category) => category.isNotEmpty),
            }.toList();
            final selectedCategory = categories.contains(_productCategoryFilter)
                ? _productCategoryFilter
                : 'All';
            final categoryField = DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _productCategoryFilter = value;
                  _productsPage = 0;
                });
              },
            );
            final sortField = DropdownButtonFormField<String>(
              initialValue: _productSort,
              decoration: const InputDecoration(
                labelText: 'Sort',
                border: OutlineInputBorder(),
              ),
              items: _productSortOptions
                  .map(
                    (sort) => DropdownMenuItem(
                      value: sort,
                      child: Text(sort),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _productSort = value;
                  _productsPage = 0;
                });
              },
            );

            if (compact) {
              return Column(
                children: [
                  categoryField,
                  const SizedBox(height: 10),
                  sortField,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: categoryField),
                const SizedBox(width: 10),
                Expanded(child: sortField),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          '$visibleCount product${visibleCount == 1 ? '' : 's'} shown',
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildProductsPager(int totalPages) {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _productsPage <= 0
                ? null
                : () => setState(() => _productsPage--),
            icon: const Icon(Icons.chevron_left),
            label: const Text('Previous'),
          ),
          Expanded(
            child: Center(
              child: Text('Page ${_productsPage + 1} of $totalPages'),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _productsPage >= totalPages - 1
                ? null
                : () => setState(() => _productsPage++),
            icon: const Icon(Icons.chevron_right),
            label: const Text('Next'),
          ),
        ],
      ),
    );
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

    final visibleProducts = _filteredProducts();
    final totalPages = visibleProducts.isEmpty
        ? 1
        : (visibleProducts.length / _productsPerPage).ceil();
    if (_productsPage >= totalPages) _productsPage = totalPages - 1;
    if (_productsPage < 0) _productsPage = 0;
    final start = _productsPage * _productsPerPage;
    final requestedEnd = start + _productsPerPage;
    final end =
        requestedEnd > visibleProducts.length ? visibleProducts.length : requestedEnd;
    final pageProducts = visibleProducts.sublist(start, end);

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pageProducts.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildProductFilters(visibleProducts.length),
            );
          }

          if (index == 1 && pageProducts.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: Text('No products match these filters')),
            );
          }

          if (index == pageProducts.length + 1) {
            return _buildProductsPager(totalPages);
          }

          index -= 1;
          final product = pageProducts[index];
          final active = product['is_active'] != false;
          final variants = product['product_variant'];
          final variantCount = variants is List ? variants.length : 0;
          final category = product['category']?.toString() ?? '';
          final discountPercent = _productDiscountPercent(product);

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
                  Text(DatabaseService.displayProductPrice(product)),
                  if (category.isNotEmpty) Text(category),
                  Text('Stock: ${_stock(product['stock_quantity'])}'),
                  if (variantCount > 0)
                    Text('$variantCount alternate size${variantCount == 1 ? '' : 's'}'),
                  if (discountPercent > 0)
                    Text('${discountPercent.toStringAsFixed(0)}% active discount'),
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
    final processingOrders =
        _orders.where((order) => _status(order) == 'Processing').toList();
    final readyOrders =
        _orders.where((order) => _status(order) == 'Ready for Pickup').toList();
    final inTransitOrders =
        _orders.where((order) => _status(order) == 'In Transit').toList();
    final activeOrders = _orders.where((order) {
      final status = _status(order);
      return status == 'Processing' ||
          status == 'Ready for Pickup' ||
          status == 'In Transit';
    }).toList();
    final lowStockProducts = _products
        .where((product) =>
            product['is_active'] != false && _stock(product['stock_quantity']) <= 5)
        .toList();
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('${processingOrders.length} processing')),
                      Chip(label: Text('${readyOrders.length} ready')),
                      Chip(label: Text('${inTransitOrders.length} in transit')),
                      Chip(label: Text('${lowStockProducts.length} low stock')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => setState(() => _currentIndex = 2),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('Manage Orders'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _currentIndex = 1),
                          icon: const Icon(Icons.inventory_2_outlined),
                          label: const Text('Products'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
    final deliveredOrders = _orders.where(_isDelivered).toList();

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
          if (deliveredOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No delivered sales yet')),
            )
          else
            ...deliveredOrders.map((order) {
              final buyerName = _buyerName(order);
              final itemCount = _itemCount(order);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.receipt_long_outlined),
                  ),
                  title: Text(_money(order['total_amount'])),
                  subtitle: Text(
                    '$buyerName | $itemCount item${itemCount == 1 ? '' : 's'} sold',
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
          final buyerName = _buyerName(order);
          final buyerContact = _buyerContactLine(order);
          final buyerPhone = _buyerPhone(order);
          final items = order['order_items'];
          final orderItems = items is List ? items : const [];
          final status = order['order_status']?.toString() ?? 'Processing';
          final itemCount = _itemCount(order);

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
                          buyerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(_money(order['total_amount'])),
                    ],
                  ),
                  if (buyerContact.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      buyerContact,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Ordered products ($itemCount item${itemCount == 1 ? '' : 's'})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  if (orderItems.isEmpty)
                    const Text(
                      'No product details loaded for this order.',
                      style: TextStyle(color: Colors.black54),
                    )
                  else
                    ...orderItems.map((item) {
                      if (item is! Map) return const SizedBox.shrink();
                      final product = item['product'];
                      final variant = item['product_variant'];
                      final productName = product is Map
                          ? DatabaseService.displayProductName(product['name'])
                          : 'Product';
                      final image = product is Map ? product['main_image_url'] : null;
                      final size = variant is Map
                          ? variant['size_label']?.toString() ?? ''
                          : '';
                      final quantity = _stock(item['quantity']);
                      final unitPrice = _number(item['unit_price_at_sale']);
                      final subtotal = item.containsKey('subtotal')
                          ? _number(item['subtotal'])
                          : unitPrice * quantity;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: _buildProductImage(image, size: 42),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    productName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    [
                                      if (size.isNotEmpty) size,
                                      'Qty $quantity',
                                      _money(unitPrice),
                                    ].join(' | '),
                                    style: const TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _money(subtotal),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
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
                  initialValue: type,
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

  Future<void> _openProductDiscountForm([
    Map<String, dynamic>? discount,
  ]) async {
    final startsController = TextEditingController(
      text: discount?['starts_at']?.toString() ?? '',
    );
    final endsController = TextEditingController(
      text: discount?['ends_at']?.toString() ?? '',
    );
    final defaultValueController = TextEditingController(
      text: discount?['discount_value']?.toString() ?? '',
    );
    var type = discount?['discount_type']?.toString() ?? 'percent';
    var active = discount?['is_active'] != false;
    final activeProducts =
        _products.where((product) => product['is_active'] != false).toList();
    final selected = <String, bool>{};
    final valueControllers = <String, TextEditingController>{};
    final existingProductId = discount?['product_id']?.toString();

    for (final product in activeProducts) {
      final productId = product['product_id']?.toString() ?? '';
      if (productId.isEmpty) continue;
      final existingValue = discount?['discount_value']?.toString() ?? '';
      selected[productId] = existingProductId == productId;
      valueControllers[productId] = TextEditingController(
        text: existingValue,
      );
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            discount == null ? 'Schedule Product Discounts' : 'Edit Discount',
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
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
                    controller: startsController,
                    decoration: const InputDecoration(
                      labelText: 'Starts At',
                      hintText: '2026-05-19T00:00:00Z',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: endsController,
                    decoration: const InputDecoration(
                      labelText: 'Ends At',
                      hintText: '2026-05-24T23:59:59Z',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: active,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    onChanged: (value) => setDialogState(() => active = value),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: defaultValueController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                type == 'amount' ? 'Default PHP off' : 'Default % off',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          final value = defaultValueController.text.trim();
                          if (value.isEmpty) return;
                          setDialogState(() {
                            for (final entry in selected.entries) {
                              if (entry.value || discount == null) {
                                valueControllers[entry.key]?.text = value;
                                selected[entry.key] = true;
                              }
                            }
                          });
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (activeProducts.isEmpty)
                    const Text('Add active products before scheduling discounts.')
                  else
                    ...activeProducts.map((product) {
                      final productId = product['product_id']?.toString() ?? '';
                      final controller = valueControllers[productId]!;
                      return CheckboxListTile(
                        value: selected[productId] ?? false,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          DatabaseService.displayProductName(product['name']),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(DatabaseService.displayProductPrice(product)),
                        secondary: SizedBox(
                          width: 96,
                          child: TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: type == 'amount' ? 'PHP' : '%',
                            ),
                          ),
                        ),
                        onChanged: discount == null || existingProductId == productId
                            ? (value) => setDialogState(
                                  () => selected[productId] = value ?? false,
                                )
                            : null,
                      );
                    }),
                  const SizedBox(height: 8),
                  const Text(
                    'Anti-deceptive pricing: a discount is blocked if the current base or variant price is above the lowest recorded price in the last 30 days.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
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
      final startsAt = startsController.text.trim();
      final endsAt = endsController.text.trim();
      var ok = storeId != null && startsAt.isNotEmpty && endsAt.isNotEmpty;
      var savedCount = 0;
      if (ok) {
        for (final entry in selected.entries) {
          if (!entry.value) continue;
          final value = double.tryParse(valueControllers[entry.key]!.text.trim());
          if (value == null || value <= 0) {
            ok = false;
            continue;
          }
          String? discountId;
          if (existingProductId == entry.key && discount != null) {
            discountId = discount['discount_id']?.toString();
          }
          final savedDiscount = await DatabaseService.saveProductDiscount(
            discountId: discountId,
            storeId: storeId,
            productId: entry.key,
            discountType: type,
            discountValue: value,
            startsAt: startsAt,
            endsAt: endsAt,
            isActive: active,
          );
          ok = ok && savedDiscount;
          if (savedDiscount) savedCount++;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok && savedCount > 0
                  ? 'Product discount saved'
                  : 'Product discount could not be saved',
            ),
          ),
        );
      }
      if (ok && savedCount > 0) _loadDashboard();
    }

    startsController.dispose();
    endsController.dispose();
    defaultValueController.dispose();
    for (final controller in valueControllers.values) {
      controller.dispose();
    }
  }

  Widget _buildProductDiscountsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Product Discounts',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _openProductDiscountForm(),
              icon: const Icon(Icons.percent),
              label: const Text('Schedule'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_productDiscounts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('No scheduled product discounts yet')),
          )
        else
          ..._productDiscounts.map((discount) {
            final product = discount['product'];
            final productName = product is Map
                ? DatabaseService.displayProductName(product['name'])
                : 'Product';
            final type = discount['discount_type']?.toString() == 'amount'
                ? '${DatabaseService.money(discount['discount_value'])} off'
                : '${discount['discount_value']}% off';
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.percent),
                title: Text(productName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type),
                    Text('${discount['starts_at']} to ${discount['ends_at']}'),
                  ],
                ),
                trailing: Switch(
                  value: discount['is_active'] != false,
                  onChanged: (value) async {
                    await DatabaseService.saveProductDiscount(
                      discountId: discount['discount_id']?.toString(),
                      storeId: discount['store_id'].toString(),
                      productId: discount['product_id'].toString(),
                      discountType:
                          discount['discount_type']?.toString() ?? 'percent',
                      discountValue: _number(discount['discount_value']),
                      startsAt: discount['starts_at'].toString(),
                      endsAt: discount['ends_at'].toString(),
                      isActive: value,
                    );
                    _loadDashboard();
                  },
                ),
                onTap: () => _openProductDiscountForm(discount),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCouponsTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProductDiscountsSection(),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Shop Coupons',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openCouponForm(),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_coupons.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('No shop coupons yet')),
            )
          else
            ..._coupons.map((coupon) {
              final type = coupon['discount_type']?.toString() == 'amount'
                  ? 'PHP ${coupon['discount_value']} off'
                  : '${coupon['discount_value']}% off';
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.local_offer_outlined),
                  title: Text(coupon['code']?.toString() ?? 'COUPON'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type),
                      Text('Used ${coupon['times_used'] ?? 0} time(s)'),
                      if ((coupon['expires_at']?.toString() ?? '').isNotEmpty)
                        Text('Expires ${coupon['expires_at']}'),
                    ],
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
            label: 'Offers',
          ),
        ],
      ),
    );
  }
}
