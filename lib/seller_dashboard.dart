import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_product_page.dart';
import '../buyer_profile_page.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'widgets/adaptive_menu_item.dart';
import 'widgets/notification_bell.dart';
import 'widgets/role_sidebar.dart';
import 'dart:async';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _productsChannel;
  Timer? _salesClockTimer;

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
  List<Map<String, dynamic>> _storeReviews = [];
  List<Map<String, dynamic>> _productReviews = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String _overviewRange = 'Day';
  String _orderStatusFilter = 'All';
  String _productCategoryFilter = 'All';
  String _productSort = 'Newest';
  int _productsPage = 0;
  int _storeReviewsPage = 0;
  int _productReviewsPage = 0;
  int _discountHistoryPage = 0;
  String _offersView = 'Product Discounts';
  int _activeDiscountsPage = 0;
  int _couponsPage = 0;
  String _salesRange = 'Month';
  DateTime _salesAnchorDate = DateTime.now();
  int _salesPage = 0;

  static const int _salesPerPage = 8;
  static const int _offersPerPage = 5;
  static const List<String> _offersViews = [
    'Product Discounts',
    'Discount History',
    'Shop Coupons',
  ];
  static const List<String> _overviewRanges = ['Day', 'Week', 'Month', 'Year'];
  static const int _productsPerPage = 10;
  static const int _reviewsPerPage = 5;
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
  static const List<String> _salesRanges = [
    'Day',
    'Week',
    'Month',
    'Year',
    'All',
  ];

  List<Map<String, dynamic>> _marketFlags = [];
  String _marketFlagFilter = 'open';
  int _marketFlagsPage = 0;

  static const int _marketFlagsPerPage = 5;
  static const List<String> _marketFlagFilters = [
    'open',
    'reviewing',
    'resolved',
    'dismissed',
    'All',
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
    _startSalesClock();
  }

  @override
  void dispose() {
    _stopSalesClock();

    final ordersChannel = _ordersChannel;
    final productsChannel = _productsChannel;
    if (ordersChannel != null) _supabase.removeChannel(ordersChannel);
    if (productsChannel != null) _supabase.removeChannel(productsChannel);
    super.dispose();
  }

  void _startSalesClock() {
    _salesClockTimer?.cancel();

    _salesClockTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (!mounted) return;

        // Only refresh visual time grouping while on Sales tab.
        // Change the index if your Sales tab is not index 3.
        if (_currentIndex == 3) {
          setState(() {});
        }
      },
    );
  }

  void _stopSalesClock() {
    _salesClockTimer?.cancel();
    _salesClockTimer = null;
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final accountId = await DatabaseService.getCurrentAccountId();
      final account = await DatabaseService.getCurrentAccount();
      final store = await DatabaseService.getCurrentSellerStore();
      final storeId = store?['store_id']?.toString();
      await _supabase.rpc('expire_product_discounts');

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
      final storeReviews = storeId == null
          ? <Map<String, dynamic>>[]
          : await DatabaseService.getStoreReviews(storeId);
      final productReviews = storeId == null
          ? <Map<String, dynamic>>[]
          : await DatabaseService.getProductReviewsForStore(storeId);
      final marketFlags = storeId == null
          ? <Map<String, dynamic>>[]
          : await DatabaseService.getSellerMarketFlags(
              status: _marketFlagFilter,
              limit: 100,
              offset: 0,
            );
      _subscribeToDashboard(accountId: accountId, storeId: storeId);

      if (mounted) {
        setState(() {
          _store = store;
          _account = account;
          _products = products;
          _orders = orders;
          _coupons = coupons;
          _productDiscounts = productDiscounts;
          _storeReviews = storeReviews;
          _productReviews = productReviews;
          _marketFlags = marketFlags;
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

  void _jumpSalesToToday() {
    setState(() {
      _salesAnchorDate = DateTime.now();
      _salesPage = 0;
    });
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

  Widget _smallPager({
    required int page,
    required int totalItems,
    required int perPage,
    required ValueChanged<int> onPageChanged,
  }) {
    final totalPages = totalItems == 0 ? 1 : (totalItems / perPage).ceil();

    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: page <= 0 ? null : () => onPageChanged(page - 1),
            child: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text('Page ${page + 1} of $totalPages'),
            ),
          ),
          OutlinedButton(
            onPressed: page >= totalPages - 1
                ? null
                : () => onPageChanged(page + 1),
            child: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _pageSlice(
    List<Map<String, dynamic>> source,
    int page,
    int perPage,
  ) {
    if (source.isEmpty) return [];

    final totalPages = (source.length / perPage).ceil();
    final safePage = page.clamp(0, totalPages - 1);
    final start = safePage * perPage;
    final end = (start + perPage) > source.length ? source.length : start + perPage;

    return source.sublist(start, end);
  }

  Widget _reviewStars(dynamic value) {
    final rating = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          size: 16,
          color: Colors.amber,
        );
      }),
    );
  }

  String _reviewBuyerName(Map<String, dynamic> review) {
    final account = review['account'] ?? review['buyer'];
    if (account is Map) {
      final first = account['firstname']?.toString().trim() ?? '';
      final last = account['surname']?.toString().trim() ?? '';
      final name = '$first $last'.trim();
      if (name.isNotEmpty) return name;

      final email = account['email']?.toString().trim() ?? '';
      if (email.isNotEmpty) return email;
    }

    return 'Buyer';
  }

  String _reviewProductName(Map<String, dynamic> review) {
    final product = review['product'];
    if (product is Map) {
      return DatabaseService.displayProductName(product['name']);
    }

    return 'Product';
  }

  Widget _reviewCard(
    Map<String, dynamic> review, {
    bool showProduct = false,
  }) {
    final comment = review['comment']?.toString().trim() ?? '';
    final buyerImagePath = _buyerImagePath(review);
    final buyerId = _buyerAccountIdFromReview(review);
    final product = _productFromReview(review);

    final imageProvider = buyerImagePath.isNotEmpty
        ? NetworkImage(DatabaseService.getProfileImageUrl(buyerImagePath))
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: InkWell(
          onTap: buyerId == null ? null : () => _openBuyerProfileFromReview(review),
          borderRadius: BorderRadius.circular(999),
          child: CircleAvatar(
            backgroundImage: imageProvider,
            child: buyerImagePath.isEmpty ? const Icon(Icons.person) : null,
          ),
        ),
        title: Text(
          showProduct ? _reviewProductName(review) : _reviewBuyerName(review),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showProduct)
              InkWell(
                onTap: buyerId == null ? null : () => _openBuyerProfileFromReview(review),
                child: Text(
                  _reviewBuyerName(review),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 4),
            _reviewStars(review['rating']),
            const SizedBox(height: 4),
            Text(comment.isEmpty ? 'No comment' : comment),
            if (showProduct && product != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openProductForm(product),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Product'),
                  ),
                ],
              ),
            ],
          ],
        ),
        onTap: buyerId == null ? null : () => _openBuyerProfileFromReview(review),
      ),
    );
  }

  Widget _offersToggle() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _offersViews.map((view) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(view),
              selected: _offersView == view,
              onSelected: (_) {
                setState(() => _offersView = view);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _openProductForm([Map<String, dynamic>? product]) async {
    final storeId = _store?['store_id']?.toString();
    final isEditing = product != null;

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

    if (!mounted) return;

    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Product updated successfully'
                : 'Product added successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );

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

  String _buyerImagePath(Map<String, dynamic> review) {
    final account = review['account'] ?? review['buyer'];
    if (account is Map) {
      return account['profile_image_url']?.toString().trim() ?? '';
    }
    return '';
  }

  String? _buyerAccountIdFromReview(Map<String, dynamic> review) {
    final account = review['account'] ?? review['buyer'];
    if (account is Map) {
      return account['account_id']?.toString();
    }

    return review['buyer_account_id']?.toString();
  }

  Map<String, dynamic>? _productFromReview(Map<String, dynamic> review) {
    final product = review['product'];
    if (product is Map) return Map<String, dynamic>.from(product);

    final productId = review['product_id']?.toString();
    if (productId == null || productId.isEmpty) return null;

    for (final item in _products) {
      if (item['product_id']?.toString() == productId) {
        return item;
      }
    }

    return null;
  }

  void _openBuyerProfileFromReview(Map<String, dynamic> review) {
    final buyerId = _buyerAccountIdFromReview(review);
    if (buyerId == null || buyerId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuyerProfilePage(
          buyerAccountId: buyerId,
          allowReport: true,
        ),
      ),
    );
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
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
          final images = product['product_image'];
          final imageCount = images is List ? images.length : 0;
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
                  if (imageCount > 0)
                    Text('$imageCount image${imageCount == 1 ? '' : 's'}'),
                  if (variantCount > 0)
                    Text('$variantCount alternate size${variantCount == 1 ? '' : 's'}'),
                  if (discountPercent > 0)
                    Text('${discountPercent.toStringAsFixed(0)}% active discount'),
                  Text(
                    active ? 'Active' : 'Hidden',
                    style: TextStyle(color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
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
            Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
          if (_marketFlags.where((flag) => flag['status'] == 'open').isNotEmpty) ...[
            const SizedBox(height: 12),
            _marketFlagsSummaryCard(),
          ],
          const SizedBox(height: 4),
          Text(
            'Sales, orders, and fulfillment history',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _metricCard(
                'Sales',
                _money(deliveredRevenue),
                Icons.payments_outlined,
                Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              _metricCard(
                'Delivered',
                '${deliveredOrders.length}',
                Icons.check_circle_outline,
                Theme.of(context).colorScheme.secondary
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
                Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(width: 10),
              _metricCard(
                'Products',
                '${_products.length}',
                Icons.inventory_2_outlined,
                Theme.of(context).colorScheme.outline,
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

  Widget _marketFlagsSummaryCard() {
    final openFlags = _marketFlags
        .where((flag) => flag['status']?.toString() == 'open')
        .toList();

    final highFlags = openFlags.where((flag) {
      final severity = flag['severity']?.toString();
      return severity == 'high' || severity == 'critical';
    }).length;

    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: highFlags > 0
          ? scheme.errorContainer
          : scheme.secondaryContainer,
      child: ListTile(
        leading: Icon(
          Icons.policy_outlined,
          color: highFlags > 0
              ? scheme.onErrorContainer
              : scheme.onSecondaryContainer,
        ),
        title: Text(
          highFlags > 0
              ? 'Market integrity issues need attention'
              : 'Marketplace notice',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: highFlags > 0
                ? scheme.onErrorContainer
                : scheme.onSecondaryContainer,
          ),
        ),
        subtitle: Text(
          '${openFlags.length} open flag${openFlags.length == 1 ? '' : 's'} found. Review pricing, discounts, cancellations, or duplicate listings.',
          style: TextStyle(
            color: highFlags > 0
                ? scheme.onErrorContainer
                : scheme.onSecondaryContainer,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => setState(() => _currentIndex = 6),
      ),
    );
  }

  String _flagTitle(String type) {
    switch (type) {
      case 'price_spike':
        return 'Price spike detected';
      case 'fake_discount_baseline':
        return 'Discount may be misleading';
      case 'high_cancellation_rate':
        return 'High cancellation rate';
      case 'duplicate_listing_spam':
        return 'Duplicate listing warning';
      default:
        return 'Market integrity flag';
    }
  }

  String _flagAdvice(String type) {
    switch (type) {
      case 'price_spike':
        return 'Review your recent price changes. Adjust the price if the increase was unintentional.';
      case 'fake_discount_baseline':
        return 'Your sale price appears higher than the recent lowest price. Lower the sale price or remove the discount.';
      case 'high_cancellation_rate':
        return 'Keep stock accurate and avoid accepting orders you cannot fulfill.';
      case 'duplicate_listing_spam':
        return 'Merge duplicate listings or hide repeated products.';
      default:
        return 'Review this issue and make sure your listing follows marketplace rules.';
    }
  }

  Color _flagColor(String severity) {
    switch (severity) {
      case 'critical':
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildMarketFlagsTab() {
    final visible = _marketFlags.where((flag) {
      if (_marketFlagFilter == 'All') return true;
      return flag['status']?.toString() == _marketFlagFilter;
    }).toList();

    final pageItems = _pageSlice(
      visible,
      _marketFlagsPage,
      _marketFlagsPerPage,
    );

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Market Integrity',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Automatic checks for pricing, discounts, cancellations, and duplicate listings.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _marketFlagFilters.map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: _marketFlagFilter == filter,
                    onSelected: (_) async {
                      setState(() {
                        _marketFlagFilter = filter;
                        _marketFlagsPage = 0;
                      });

                      final flags = await DatabaseService.getSellerMarketFlags(
                        status: filter,
                        limit: 100,
                        offset: 0,
                      );

                      if (!mounted) return;
                      setState(() => _marketFlags = flags);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 100),
              child: Center(child: Text('No market flags for this filter')),
            )
          else
            ...pageItems.map(_marketFlagCard),
          _smallPager(
            page: _marketFlagsPage,
            totalItems: visible.length,
            perPage: _marketFlagsPerPage,
            onPageChanged: (page) {
              setState(() => _marketFlagsPage = page);
            },
          ),
        ],
      ),
    );
  }

  Widget _marketFlagCard(Map<String, dynamic> flag) {
    final type = flag['flag_type']?.toString() ?? '';
    final severity = flag['severity']?.toString() ?? 'medium';
    final status = flag['status']?.toString() ?? 'open';
    final productName = flag['product_name']?.toString() ?? '';
    final reason = flag['reason']?.toString() ?? '';
    final evidence = flag['evidence'];
    final color = _flagColor(severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(35),
          child: Icon(Icons.policy_outlined, color: color),
        ),
        title: Text(
          _flagTitle(type),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (productName.isNotEmpty) Text(productName),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text(severity.toUpperCase()),
                  backgroundColor: color.withAlpha(35),
                  labelStyle: TextStyle(color: color),
                ),
                Chip(label: Text(status)),
              ],
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(reason),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _flagAdvice(type),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (evidence != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                evidence.toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _salesRangeStart() {
    final anchor = _salesAnchorDate;

    switch (_salesRange) {
      case 'Day':
        return DateTime(anchor.year, anchor.month, anchor.day);

      case 'Week':
        final day = DateTime(anchor.year, anchor.month, anchor.day);
        return day.subtract(Duration(days: day.weekday - 1));

      case 'Month':
        return DateTime(anchor.year, anchor.month);

      case 'Year':
        return DateTime(anchor.year);

      case 'All':
      default:
        return DateTime(0);
    }
  }

  DateTime _salesRangeEnd() {
    final start = _salesRangeStart();

    switch (_salesRange) {
      case 'Day':
        return start.add(const Duration(days: 1));

      case 'Week':
        return start.add(const Duration(days: 7));

      case 'Month':
        return DateTime(start.year, start.month + 1);

      case 'Year':
        return DateTime(start.year + 1);

      case 'All':
      default:
        return DateTime(9999);
    }
  }

  String _salesPeriodLabel() {
    final start = _salesRangeStart();
    final end = _salesRangeEnd().subtract(const Duration(days: 1));

    switch (_salesRange) {
      case 'Day':
        return _shortDate(start);

      case 'Week':
        return '${_shortDate(start)} → ${_shortDate(end)}';

      case 'Month':
        return '${start.year}-${start.month.toString().padLeft(2, '0')}';

      case 'Year':
        return '${start.year}';

      case 'All':
      default:
        return 'All Time';
    }
  }

  void _moveSalesPeriod(int direction) {
    setState(() {
      _salesPage = 0;

      switch (_salesRange) {
        case 'Day':
          _salesAnchorDate = _salesAnchorDate.add(Duration(days: direction));
          break;

        case 'Week':
          _salesAnchorDate = _salesAnchorDate.add(Duration(days: 7 * direction));
          break;

        case 'Month':
          _salesAnchorDate = DateTime(
            _salesAnchorDate.year,
            _salesAnchorDate.month + direction,
            1,
          );
          break;

        case 'Year':
          _salesAnchorDate = DateTime(
            _salesAnchorDate.year + direction,
            1,
            1,
          );
          break;

        case 'All':
          break;
      }
    });
  }

  Widget _salesPeriodControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _salesRanges.map((range) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(range),
                  selected: _salesRange == range,
                  onSelected: (_) {
                    setState(() {
                      _salesRange = range;
                      _salesPage = 0;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: _salesRange == 'All'
                      ? null
                      : () => _moveSalesPeriod(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _salesRange == 'All' ? null : _pickSalesDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        _salesPeriodLabel(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                if (_salesRange != 'All')
                  TextButton(
                    onPressed: _jumpSalesToToday,
                    child: const Text('Today'),
                  ),
                IconButton(
                  onPressed: _salesRange == 'All'
                      ? null
                      : () => _moveSalesPeriod(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickSalesDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _salesAnchorDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _salesAnchorDate = picked;
      _salesPage = 0;
    });
  }

  bool _orderInsideSelectedSalesRange(Map<String, dynamic> order) {
    if (_salesRange == 'All') return true;

    final date = _orderDate(order, preferDelivered: true)?.toLocal();
    if (date == null) return false;

    final start = _salesRangeStart();
    final end = _salesRangeEnd();

    return !date.isBefore(start) && date.isBefore(end);
  }

  List<Map<String, dynamic>> _selectedSalesOrders() {
    final filtered = _orders
        .where(_isDelivered)
        .where(_orderInsideSelectedSalesRange)
        .toList();

    filtered.sort((a, b) {
      final aDate = _orderDate(a, preferDelivered: true) ?? DateTime(0);
      final bDate = _orderDate(b, preferDelivered: true) ?? DateTime(0);
      return bDate.compareTo(aDate);
    });

    return filtered;
  }

  Widget _buildSalesTab() {
    final salesOrders = _selectedSalesOrders();
    final chartRows = _salesChartRows(salesOrders);

    final totalPages = salesOrders.isEmpty
        ? 1
        : (salesOrders.length / _salesPerPage).ceil();

    if (_salesPage >= totalPages) {
      _salesPage = totalPages - 1;
    }

    if (_salesPage < 0) {
      _salesPage = 0;
    }

    final visibleSales = _pageSlice(
      salesOrders,
      _salesPage,
      _salesPerPage,
    );

    final revenue = salesOrders.fold<double>(
      0,
      (sum, order) => sum + _sellerOrderValue(order),
    );

    final itemsSold = salesOrders.fold<int>(
      0,
      (sum, order) => sum + _itemCount(order),
    );

    final averageOrder = salesOrders.isEmpty ? 0 : revenue / salesOrders.length;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Sales',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'View gains by selected day, week, month, year, or all time',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 16),
          _salesPeriodControls(),

          const SizedBox(height: 16),

          Row(
            children: [
              _metricCard(
                'Revenue',
                _money(revenue),
                Icons.payments_outlined,
                Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              _metricCard(
                'Orders',
                '${salesOrders.length}',
                Icons.receipt_long_outlined,
                Theme.of(context).colorScheme.secondary,
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              _metricCard(
                'Items Sold',
                '$itemsSold',
                Icons.shopping_bag_outlined,
                Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(width: 10),
              _metricCard(
                'Avg Order',
                _money(averageOrder),
                Icons.trending_up_outlined,
                Theme.of(context).colorScheme.outline,
              ),
            ],
          ),

          const SizedBox(height: 16),

          _salesBarChart(chartRows),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Text(
                  '${_salesPeriodLabel()} Sales',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              Chip(label: Text('${salesOrders.length}')),
            ],
          ),

          const SizedBox(height: 8),

          if (visibleSales.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No delivered sales for this period')),
            )
          else
            ...visibleSales.map((order) {
              final buyerName = _buyerName(order);
              final itemCount = _itemCount(order);
              final date = _orderDate(order, preferDelivered: true);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.receipt_long_outlined),
                  ),
                  title: Text(_money(_sellerOrderValue(order))),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$buyerName | $itemCount item${itemCount == 1 ? '' : 's'} sold',
                      ),
                      if (date != null)
                        Text(
                          _readableDateTime(date.toIso8601String()),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  trailing: Text(
                    order['payment_status']?.toString() ?? 'Pending',
                  ),
                ),
              );
            }),

          _smallPager(
            page: _salesPage,
            totalItems: salesOrders.length,
            perPage: _salesPerPage,
            onPageChanged: (page) {
              setState(() => _salesPage = page);
            },
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _salesChartRows(List<Map<String, dynamic>> orders) {
    final rows = <String, Map<String, dynamic>>{};

    void addRow(String key, String label, DateTime sortDate) {
      rows.putIfAbsent(
        key,
        () => {
          'key': key,
          'label': label,
          'amount': 0.0,
          'orders': 0,
          'date': sortDate,
        },
      );
    }

    if (_salesRange == 'Day') {
      final start = _salesRangeStart();

      for (var hour = 0; hour < 24; hour++) {
        final date = DateTime(start.year, start.month, start.day, hour);
        final hourLabel = hour == 0
            ? '12 AM'
            : hour < 12
                ? '$hour AM'
                : hour == 12
                    ? '12 PM'
                    : '${hour - 12} PM';

        addRow('$hour', hourLabel, date);
      }
    } else if (_salesRange == 'Week') {
      final start = _salesRangeStart();

      const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      for (var i = 0; i < 7; i++) {
        final date = start.add(Duration(days: i));
        addRow('$i', labels[i], date);
      }
    } else if (_salesRange == 'Month') {
      final start = _salesRangeStart();
      final end = _salesRangeEnd();

      var cursor = start;
      var index = 1;

      while (cursor.isBefore(end)) {
        final weekEnd = cursor.add(const Duration(days: 6));
        addRow(
          '$index',
          'W$index',
          cursor,
        );
        cursor = weekEnd.add(const Duration(days: 1));
        index++;
      }
    } else if (_salesRange == 'Year') {
      final year = _salesAnchorDate.year;

      const labels = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      for (var month = 1; month <= 12; month++) {
        addRow(
          '$month',
          labels[month - 1],
          DateTime(year, month),
        );
      }
    } else {
      final delivered = _orders.where(_isDelivered).toList();

      for (final order in delivered) {
        final date = _orderDate(order, preferDelivered: true)?.toLocal();
        if (date == null) continue;

        addRow(
          '${date.year}',
          '${date.year}',
          DateTime(date.year),
        );
      }
    }

    for (final order in orders) {
      final date = _orderDate(order, preferDelivered: true)?.toLocal();
      if (date == null) continue;

      String key;

      if (_salesRange == 'Day') {
        key = '${date.hour}';
      } else if (_salesRange == 'Week') {
        key = '${date.weekday - 1}';
      } else if (_salesRange == 'Month') {
        final start = _salesRangeStart();
        final dayOffset = _dateOnly(date).difference(start).inDays;
        key = '${(dayOffset ~/ 7) + 1}';
      } else if (_salesRange == 'Year') {
        key = '${date.month}';
      } else {
        key = '${date.year}';
      }

      final row = rows[key];
      if (row == null) continue;

      row['amount'] = (row['amount'] as double) + _sellerOrderValue(order);
      row['orders'] = (row['orders'] as int) + 1;
    }

    final result = rows.values.toList()
      ..sort(
        (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
      );

    return result;
  }

  Widget _salesBarChart(List<Map<String, dynamic>> rows) {
    final maxAmount = rows.fold<double>(
      0,
      (max, row) {
        final value = _number(row['amount']);
        return value > max ? value : max;
      },
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales Graph',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),

            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No graph data')),
              )
            else
              ...rows.map((row) {
                final amount = _number(row['amount']);
                final orders = row['orders'] as int? ?? 0;
                final fraction = maxAmount <= 0 ? 0.0 : amount / maxAmount;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 54,
                        child: Text(
                          row['label'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 18,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: fraction.clamp(0.0, 1.0),
                              child: Container(
                                height: 18,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 86,
                        child: Text(
                          orders == 0 ? '-' : _money(amount),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Ordered products ($itemCount item${itemCount == 1 ? '' : 's'})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  if (orderItems.isEmpty)
                    Text(
                      'No product details loaded for this order.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
    final existingExpiry = DateTime.tryParse(
      coupon?['expires_at']?.toString() ?? '',
    );
    final expiryController = TextEditingController(
      text: existingExpiry == null ? '' : _formatDateTimeForInput(existingExpiry),
    );
    var type = coupon?['discount_type']?.toString() ?? 'percent';
    var active = coupon?['is_active'] != false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Text(coupon == null ? 'Add Shop Coupon' : 'Edit Shop Coupon'),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.72,
              ),
              child: SingleChildScrollView(
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
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Expires At',
                        hintText: 'Select expiry date and time',
                        prefixIcon: Icon(Icons.event_available_outlined),
                        suffixIcon: Icon(Icons.edit_calendar_outlined),
                      ),
                      onTap: () async {
                        FocusScope.of(dialogContext).unfocus();

                        final current = _parseDateTimeInput(expiryController.text) ??
                            DateTime.now().add(const Duration(days: 7));

                        Navigator.pop(dialogContext, null);

                        final picked = await _pickDateTimeValue(
                          initial: current,
                          isStart: false,
                        );

                        if (picked == null || !mounted) return;

                        expiryController.text = _formatDateTimeForInput(picked);

                        await _openCouponForm({
                          if (coupon != null) ...coupon,
                          'code': codeController.text,
                          'description': descriptionController.text,
                          'discount_type': type,
                          'discount_value': valueController.text,
                          'min_subtotal': minController.text,
                          'expires_at': picked.toIso8601String(),
                          'is_active': active,
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: active,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      onChanged: (value) => setDialogState(() => active = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true) {
      final storeId = _store?['store_id']?.toString();
      final expiryText = expiryController.text.trim();
      final expiryDate = expiryText.isEmpty ? null : _parseDateTimeInput(expiryText);

      if (expiryText.isNotEmpty && expiryDate == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select a valid coupon expiry date/time')),
          );
        }
        return;
      }

      final expiresAt = expiryDate == null
          ? null
          : _formatDateTimeForSupabase(expiryDate);

      final ok = storeId != null &&
          await DatabaseService.saveCoupon(
            code: codeController.text,
            discountType: type,
            discountValue: double.tryParse(valueController.text.trim()) ?? 0,
            minSubtotal: double.tryParse(minController.text.trim()) ?? 0,
            description: descriptionController.text,
            expiresAt: expiresAt,
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

  String _readableDateTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) return 'No date';

    final local = date.toLocal();
    final hour = local.hour > 12
        ? local.hour - 12
        : local.hour == 0
            ? 12
            : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute $period';
  }

  String _formatDateTimeForInput(DateTime dateTime) {
    final local = dateTime.toLocal();

    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTimeForSupabase(DateTime dateTime) {
    return dateTime.toUtc().toIso8601String();
  }

  DateTime? _parseDateTimeInput(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;

    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }

  Future<DateTime?> _pickDateTimeValue({
    required DateTime initial,
    required bool isStart,
  }) async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate == null || !mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (pickedTime == null || !mounted) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _pickDateTime(
    TextEditingController controller, {
    required bool isStart,
  }) async {
    final now = DateTime.now();
    final current = _parseDateTimeInput(controller.text) ??
        (isStart ? now : now.add(const Duration(days: 7)));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );

    if (pickedTime == null || !mounted) return;

    final picked = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    controller.text = _formatDateTimeForInput(picked);
  }

  Future<void> _openProductDiscountForm([
    Map<String, dynamic>? discount,
  ]) async {
    final existingStart = DateTime.tryParse(
      discount?['starts_at']?.toString() ?? '',
    );
    final existingEnd = DateTime.tryParse(
      discount?['ends_at']?.toString() ?? '',
    );

    final startsController = TextEditingController(
      text: existingStart == null ? '' : _formatDateTimeForInput(existingStart),
    );
    final endsController = TextEditingController(
      text: existingEnd == null ? '' : _formatDateTimeForInput(existingEnd),
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
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Starts At',
                      hintText: 'Select start date and time',
                      prefixIcon: Icon(Icons.event_outlined),
                      suffixIcon: Icon(Icons.edit_calendar_outlined),
                    ),
                    onTap: () => _pickDateTime(startsController, isStart: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: endsController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Ends At',
                      hintText: 'Select end date and time',
                      prefixIcon: Icon(Icons.event_available_outlined),
                      suffixIcon: Icon(Icons.edit_calendar_outlined),
                    ),
                    onTap: () => _pickDateTime(endsController, isStart: false),
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
                  Text(
                    'Anti-deceptive pricing: a discount is blocked if the current base or variant price is above the lowest recorded price in the last 30 days.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
      final startsDate = _parseDateTimeInput(startsController.text);
      final endsDate = _parseDateTimeInput(endsController.text);

      if (startsDate == null || endsDate == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select start and end date/time')),
          );
        }
        return;
      }

      if (!endsDate.isAfter(startsDate)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('End date/time must be after start date/time')),
          );
        }
        return;
      }

      final startsAt = _formatDateTimeForSupabase(startsDate);
      final endsAt = _formatDateTimeForSupabase(endsDate);

      var ok = storeId != null;
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
    final now = DateTime.now();

    final activeDiscounts = <Map<String, dynamic>>[];
    final historyDiscounts = <Map<String, dynamic>>[];

    for (final discount in _productDiscounts) {
      final endsAt = DateTime.tryParse(discount['ends_at']?.toString() ?? '');
      final expired = endsAt != null && !endsAt.isAfter(now);

      if (expired || discount['is_active'] == false) {
        historyDiscounts.add(discount);
      } else {
        activeDiscounts.add(discount);
      }
    }

    activeDiscounts.sort((a, b) {
      final aDate = DateTime.tryParse(a['starts_at']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['starts_at']?.toString() ?? '');
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return aDate.compareTo(bDate);
    });

    historyDiscounts.sort((a, b) {
      final aDate = DateTime.tryParse(a['ends_at']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['ends_at']?.toString() ?? '');
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    Widget discountTile(
      Map<String, dynamic> discount, {
      required bool history,
    }) {
      final product = discount['product'];
      final productName = product is Map
          ? DatabaseService.displayProductName(product['name'])
          : 'Product';

      final type = discount['discount_type']?.toString() == 'amount'
          ? '${DatabaseService.money(discount['discount_value'])} off'
          : '${discount['discount_value']}% off';

      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        color: history
            ? Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.45)
            : null,
        child: ListTile(
          leading: Icon(history ? Icons.history : Icons.percent),
          title: Text(productName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(type),
              if (history)
                Text('Ended ${_readableDateTime(discount['ends_at'])}')
              else
                Text(
                  '${_readableDateTime(discount['starts_at'])} → ${_readableDateTime(discount['ends_at'])}',
                ),
            ],
          ),
          trailing: history
              ? const Chip(label: Text('History'))
              : Switch(
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
          onTap: history ? null : () => _openProductDiscountForm(discount),
        ),
      );
    }

    Widget pagedDiscounts({
      required List<Map<String, dynamic>> discounts,
      required int page,
      required ValueChanged<int> onPageChanged,
      required String emptyText,
      required bool history,
    }) {
      final visible = _pageSlice(discounts, page, _offersPerPage);

      return Column(
        children: [
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text(emptyText)),
            )
          else
            ...visible.map(
              (discount) => discountTile(discount, history: history),
            ),
          _smallPager(
            page: page,
            totalItems: discounts.length,
            perPage: _offersPerPage,
            onPageChanged: onPageChanged,
          ),
        ],
      );
    }

    if (_offersView == 'Discount History') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Discount History',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          pagedDiscounts(
            discounts: historyDiscounts,
            page: _discountHistoryPage,
            emptyText: 'No expired or disabled discounts yet',
            history: true,
            onPageChanged: (page) {
              setState(() => _discountHistoryPage = page);
            },
          ),
        ],
      );
    }

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
        pagedDiscounts(
          discounts: activeDiscounts,
          page: _activeDiscountsPage,
          emptyText: 'No active product discounts',
          history: false,
          onPageChanged: (page) {
            setState(() => _activeDiscountsPage = page);
          },
        ),
      ],
    );
  }

  Widget _buildShopCouponsSection() {
    final coupons = [..._coupons];

    final visibleCoupons = _pageSlice(
      coupons,
      _couponsPage,
      _offersPerPage,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        if (visibleCoupons.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('No shop coupons yet')),
          )
        else
          ...visibleCoupons.map((coupon) {
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
                      Text('Expires ${_readableDateTime(coupon['expires_at'])}'),
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
        _smallPager(
          page: _couponsPage,
          totalItems: coupons.length,
          perPage: _offersPerPage,
          onPageChanged: (page) {
            setState(() => _couponsPage = page);
          },
        ),
      ],
    );
  }

  Widget _buildCouponsTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Offers',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage discounts, discount history, and shop coupons',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _offersToggle(),
          const SizedBox(height: 16),
          if (_offersView == 'Shop Coupons')
            _buildShopCouponsSection()
          else
            _buildProductDiscountsSection(),
        ],
      ),
    );
  }

  Widget _reviewsPanel({
    required String title,
    required int count,
    required String emptyText,
    required List<Widget> children,
    required Widget pager,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Chip(label: Text('$count')),
              ],
            ),
            const SizedBox(height: 10),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text(emptyText)),
              )
            else
              ...children,
            pager,
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsTab() {
    final storeReviews = [..._storeReviews];
    final productReviews = [..._productReviews];

    final storeTotalPages =
        storeReviews.isEmpty ? 1 : (storeReviews.length / _reviewsPerPage).ceil();

    final productTotalPages = productReviews.isEmpty
        ? 1
        : (productReviews.length / _reviewsPerPage).ceil();

    if (_storeReviewsPage >= storeTotalPages) {
      _storeReviewsPage = storeTotalPages - 1;
    }

    if (_productReviewsPage >= productTotalPages) {
      _productReviewsPage = productTotalPages - 1;
    }

    if (_storeReviewsPage < 0) _storeReviewsPage = 0;
    if (_productReviewsPage < 0) _productReviewsPage = 0;

    final visibleStoreReviews = _pageSlice(
      storeReviews,
      _storeReviewsPage,
      _reviewsPerPage,
    );

    final visibleProductReviews = _pageSlice(
      productReviews,
      _productReviewsPage,
      _reviewsPerPage,
    );

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Reviews',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Store and product feedback from buyers',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 760;

              final storePanel = _reviewsPanel(
                title: 'Store Reviews',
                count: storeReviews.length,
                emptyText: 'No store reviews yet',
                children: visibleStoreReviews
                    .map((review) => _reviewCard(review))
                    .toList(),
                pager: _smallPager(
                  page: _storeReviewsPage,
                  totalItems: storeReviews.length,
                  perPage: _reviewsPerPage,
                  onPageChanged: (page) {
                    setState(() => _storeReviewsPage = page);
                  },
                ),
              );

              final productPanel = _reviewsPanel(
                title: 'Product Reviews',
                count: productReviews.length,
                emptyText: 'No product reviews yet',
                children: visibleProductReviews
                    .map(
                      (review) => _reviewCard(
                        review,
                        showProduct: true,
                      ),
                    )
                    .toList(),
                pager: _smallPager(
                  page: _productReviewsPage,
                  totalItems: productReviews.length,
                  perPage: _reviewsPerPage,
                  onPageChanged: (page) {
                    setState(() => _productReviewsPage = page);
                  },
                ),
              );

              if (!sideBySide) {
                return Column(
                  children: [
                    storePanel,
                    const SizedBox(height: 12),
                    productPanel,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: storePanel),
                  const SizedBox(width: 12),
                  Expanded(child: productPanel),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sellerNavItem(
    int index,
    IconData icon,
    IconData selectedIcon,
    String label,
  ) {
    final selected = _currentIndex == index;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _currentIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 86,
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outline.withAlpha(70),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  fontSize: 10,
                  height: 1.0,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storeName = _store?['store_name']?.toString() ?? 'Seller Dashboard';
    final selectedTab = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : switch (_currentIndex) {
            0 => _buildOverviewTab(),
            1 => _buildProductsTab(),
            2 => _buildOrdersTab(),
            3 => _buildSalesTab(),
            4 => _buildCouponsTab(),
            5 => _buildReviewsTab(),
            _ => _buildMarketFlagsTab(),
          };

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1000;
          return Row(
            children: [
              if (isWide)
                RoleSidebar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() => _currentIndex = index);
                  },
                  destinations: const [
                    RoleSidebarDestination(
                      label: 'Overview',
                      icon: Icons.dashboard_outlined,
                      selectedIcon: Icons.dashboard,
                    ),
                    RoleSidebarDestination(
                      label: 'Products',
                      icon: Icons.inventory_2_outlined,
                      selectedIcon: Icons.inventory_2,
                    ),
                    RoleSidebarDestination(
                      label: 'Orders',
                      icon: Icons.receipt_long_outlined,
                      selectedIcon: Icons.receipt_long,
                    ),
                    RoleSidebarDestination(
                      label: 'Sales',
                      icon: Icons.bar_chart_outlined,
                      selectedIcon: Icons.bar_chart,
                    ),
                    RoleSidebarDestination(
                      label: 'Offers',
                      icon: Icons.local_offer_outlined,
                      selectedIcon: Icons.local_offer,
                    ),
                    RoleSidebarDestination(
                      label: 'Reviews',
                      icon: Icons.reviews_outlined,
                      selectedIcon: Icons.reviews,
                    ),
                    RoleSidebarDestination(
                      label: 'Flags',
                      icon: Icons.policy_outlined,
                      selectedIcon: Icons.policy,
                    ),
                  ],
                ),
              Expanded(child: selectedTab),
            ],
          );
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final width = MediaQuery.of(context).size.width;
          final isWide = width >= 1000;
          final isMobile = width < 700;
          if (isWide) return const SizedBox.shrink();

          if (!isMobile) {
            return NavigationBar(
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
                NavigationDestination(
                  icon: Icon(Icons.reviews_outlined),
                  selectedIcon: Icon(Icons.reviews),
                  label: 'Reviews',
                ),
                NavigationDestination(
                  icon: Icon(Icons.policy_outlined),
                  selectedIcon: Icon(Icons.policy),
                  label: 'Flags',
                ),
              ],
            );
          }

          return SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                children: [
                  _sellerNavItem(
                    0,
                    Icons.dashboard_outlined,
                    Icons.dashboard,
                    'Overview',
                  ),
                  _sellerNavItem(
                    1,
                    Icons.inventory_2_outlined,
                    Icons.inventory_2,
                    'Products',
                  ),
                  _sellerNavItem(
                    2,
                    Icons.receipt_long_outlined,
                    Icons.receipt_long,
                    'Orders',
                  ),
                  _sellerNavItem(
                    3,
                    Icons.bar_chart_outlined,
                    Icons.bar_chart,
                    'Sales',
                  ),
                  _sellerNavItem(
                    4,
                    Icons.local_offer_outlined,
                    Icons.local_offer,
                    'Offers',
                  ),
                  _sellerNavItem(
                    5,
                    Icons.reviews_outlined,
                    Icons.reviews,
                    'Reviews',
                  ),
                  _sellerNavItem(
                    6,
                    Icons.policy_outlined,
                    Icons.policy,
                    'Flags',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
