import 'package:flutter/material.dart';

import 'services/database_service.dart';
import 'widgets/product_card.dart';

class SellerPage extends StatefulWidget {
  final String storeId;

  const SellerPage({super.key, required this.storeId});

  @override
  State<SellerPage> createState() => _SellerPageState();
}

class _SellerPageState extends State<SellerPage> {
  Map<String, dynamic>? _store;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _trendingProducts = [];
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic>? _myReview;
  bool _canReviewStore = false;
  bool _isLoading = true;
  static const int _allProductsPageSize = 20;
  int _allProductsPage = 0;

  @override
  void initState() {
    super.initState();
    _loadSeller();
  }

  Future<void> _loadSeller() async {
    final store = await DatabaseService.getStoreById(widget.storeId);
    final products = await DatabaseService.getProductsForStore(widget.storeId);
    final trending = await DatabaseService.getTrendingProducts(
      storeId: widget.storeId,
    );
    final reviews = await DatabaseService.getStoreReviews(widget.storeId);
    final canReview = await DatabaseService.buyerHasDeliveredOrderFromStore(
      widget.storeId,
    );
    final myReview = await DatabaseService.getCurrentBuyerStoreReview(
      widget.storeId,
    );
    if (!mounted) return;
    setState(() {
      _store = store;
      _products = products.where((item) => item['is_active'] != false).toList();
      _trendingProducts = trending
          .where((item) => item['is_active'] != false)
          .toList();
      _reviews = reviews;
      _canReviewStore = canReview;
      _myReview = myReview;
      _isLoading = false;
      _allProductsPage = 0;
    });
  }

  double _rating(Map<String, dynamic> product) {
    final value = product['average_rating'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _reviewCount(Map<String, dynamic> product) {
    final value = product['review_count'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic>? get _ownerAccount {
    final account = _store?['account'];
    return account is Map<String, dynamic> ? account : null;
  }

  String _ownerName() {
    final account = _ownerAccount;
    if (account == null) return 'Seller';
    final first = account['firstname']?.toString() ?? '';
    final last = account['surname']?.toString() ?? '';
    final name = '$first $last'.trim();
    return name.isEmpty ? 'Seller' : name;
  }

  String _ownerImageUrl() {
    final imagePath =
        _ownerAccount?['profile_image_url']?.toString().trim() ?? '';
    if (imagePath.isEmpty) return '';
    return DatabaseService.getProfileImageUrl(imagePath);
  }

  String? _storeBannerUrl() {
    final path = _store?['banner_image_url']?.toString().trim() ?? '';
    if (path.isEmpty) return null;
    return DatabaseService.getStoreBannerImageUrl(path);
  }

  String _storeLocation() {
    final store = _store;
    if (store == null) return '';
    final parts =
        [
              store['house_number'],
              store['street'],
              store['barangay'],
              store['city'],
              store['province'],
              store['zip_code'],
            ]
            .map((part) => part?.toString().trim() ?? '')
            .where((part) => part.isNotEmpty)
            .toList();
    return parts.join(', ');
  }

  double get _storeRating {
    if (_reviews.isEmpty) return 0;
    final total = _reviews.fold<double>(
      0,
      (sum, review) =>
          sum + (double.tryParse(review['rating']?.toString() ?? '') ?? 0),
    );
    return total / _reviews.length;
  }

  Future<bool> _requireLogin(String action) async {
    final accountId = await DatabaseService.getCurrentAccountId();
    if (accountId != null) return true;
    if (!mounted) return false;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Please log in to $action')));
    navigator.pushNamed('/login');
    return false;
  }

  Future<void> _reviewStore() async {
    if (!await _requireLogin('review this shop')) return;
    if (!mounted) return;
    if (!_canReviewStore) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can review this shop after a delivered order'),
        ),
      );
      return;
    }

    var rating = int.tryParse(_myReview?['rating']?.toString() ?? '') ?? 5;
    final commentController = TextEditingController(
      text: _myReview?['comment']?.toString() ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Review Shop'),
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
                decoration: const InputDecoration(labelText: 'Comment'),
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

    if (saved == true) {
      final ok = await DatabaseService.saveStoreReview(
        storeId: widget.storeId,
        rating: rating,
        comment: commentController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'Shop review saved' : 'Shop review could not be saved',
            ),
          ),
        );
      }
      if (ok) _loadSeller();
    }
    commentController.dispose();
  }

  Future<void> _reportStore() async {
    if (!await _requireLogin('report this shop')) return;
    if (!mounted) return;

    String reason = 'Misleading shop information';
    var isOrderRelated = false;
    final detailsController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report Shop'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Misleading shop information',
                      child: Text('Misleading shop information'),
                    ),
                    DropdownMenuItem(
                      value: 'Fake or deceptive discounts',
                      child: Text('Fake or deceptive discounts'),
                    ),
                    DropdownMenuItem(
                      value: 'Suspicious pricing behavior',
                      child: Text('Suspicious pricing behavior'),
                    ),
                    DropdownMenuItem(
                      value: 'Seller is not fulfilling orders properly',
                      child: Text('Seller is not fulfilling orders properly'),
                    ),
                    DropdownMenuItem(
                      value: 'Offensive or inappropriate shop content',
                      child: Text('Offensive or inappropriate shop content'),
                    ),
                    DropdownMenuItem(
                      value: 'Spam or duplicate shop',
                      child: Text('Spam or duplicate shop'),
                    ),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => reason = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  decoration: const InputDecoration(
                    labelText: 'Details',
                    hintText: 'Explain what admin should check.',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 3,
                  maxLines: 5,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: isOrderRelated,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Related to my order'),
                  subtitle: !_canReviewStore
                      ? const Text(
                          'Only available after you receive an order from this shop',
                        )
                      : null,
                  onChanged: !_canReviewStore
                      ? null
                      : (value) {
                          setDialogState(() {
                            isOrderRelated = value ?? false;
                          });
                        },
                ),
                Text(
                  'Reports are reviewed by admin. False or abusive reports may be ignored.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              label: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final details = detailsController.text.trim();

      if (details.length < 10) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please add at least 10 characters of details.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        detailsController.dispose();
        return;
      }

      final ok = await DatabaseService.reportStore(
        storeId: widget.storeId,
        reason: reason,
        details: details,
        isOrderRelated: isOrderRelated,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Shop report submitted for admin review'
                  : 'Shop report could not be submitted',
            ),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );
      }
    }

    detailsController.dispose();
  }

  Widget _productTile(Map<String, dynamic> product, {bool compact = false}) {
    final productId = product['product_id']?.toString();
    Future<void> openProduct() async {
      if (productId == null) return;
      await DatabaseService.trackProductClick(
        productId: productId,
        storeId: widget.storeId,
      );
      if (!mounted) return;
      Navigator.pushNamed(context, '/product/$productId');
    }

    return SizedBox(
      width: compact ? 174 : null,
      height: 294,
      child: ProductCard(
        product: product,
        onTap: productId == null ? null : openProduct,
        onAction: productId == null ? null : openProduct,
        actionLabel: 'View item',
        showStock: !compact,
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Icon(icon, color: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }

  Widget _horizontalSection(List<Map<String, dynamic>> products) {
    return SizedBox(
      height: 310,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: products.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 14, bottom: 12),
          child: _productTile(products[index], compact: true),
        ),
      ),
    );
  }

  Widget _storeHeader({
    required String storeName,
    required String description,
    required String ownerImageUrl,
    required String? bannerUrl,
    required String location,
    required bool isOpen,
    required int productCount,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: SizedBox(
              height: 230,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: scheme.primaryContainer,
                    child: bannerUrl == null
                        ? null
                        : Image.network(
                            bannerUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha(20),
                          Colors.black.withAlpha(45),
                          Colors.black.withAlpha(205),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: isOpen
                            ? const Color(0xFFE2F6E8)
                            : scheme.surface,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 9,
                              color: isOpen
                                  ? const Color(0xFF21814A)
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              isOpen ? 'Open now' : 'Currently closed',
                              style: TextStyle(
                                color: isOpen
                                    ? const Color(0xFF176B3A)
                                    : scheme.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: scheme.surface,
                          backgroundImage: ownerImageUrl.isNotEmpty
                              ? NetworkImage(ownerImageUrl)
                              : null,
                          child: ownerImageUrl.isEmpty
                              ? Icon(Icons.storefront, color: scheme.primary)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                storeName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'by ${_ownerName()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF2A900),
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _reviews.isEmpty
                              ? 'New shop'
                              : '${_storeRating.toStringAsFixed(1)} (${_reviews.length} reviews)',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          color: scheme.onSurfaceVariant,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text('$productCount items'),
                      ],
                    ),
                  ],
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: scheme.onSurfaceVariant,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _reviewStore,
                      icon: const Icon(Icons.rate_review_outlined, size: 18),
                      label: Text(
                        _myReview == null ? 'Review shop' : 'Edit review',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _reportStore,
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      label: const Text('Report'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _allProductsGrid(List<Map<String, dynamic>> products) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _productTile(products[index]),
          childCount: products.length,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          mainAxisExtent: 294,
        ),
      ),
    );
  }

  Widget _allProductsPager({
    required int currentPage,
    required int totalPages,
    required int totalProducts,
  }) {
    if (totalProducts <= _allProductsPageSize) return const SizedBox.shrink();
    final start = currentPage * _allProductsPageSize + 1;
    final end = (start + _allProductsPageSize - 1).clamp(1, totalProducts);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Showing $start-$end of $totalProducts',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          IconButton(
            onPressed: currentPage == 0
                ? null
                : () => setState(() => _allProductsPage = currentPage - 1),
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous page',
          ),
          Text('${currentPage + 1} / $totalPages'),
          IconButton(
            onPressed: currentPage >= totalPages - 1
                ? null
                : () => setState(() => _allProductsPage = currentPage + 1),
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storeName = _store?['store_name']?.toString() ?? 'Seller';
    final description = _store?['description']?.toString() ?? '';
    final ownerImageUrl = _ownerImageUrl();
    final bannerUrl = _storeBannerUrl();
    final location = _storeLocation();
    final isOpen = _store?['is_open'] != false;
    final activeProducts = _products
        .where((item) => item['is_active'] != false)
        .toList();
    final newProducts = activeProducts.take(8).toList();
    final bestSellers = [...activeProducts]
      ..sort((a, b) {
        final reviews = _reviewCount(b).compareTo(_reviewCount(a));
        if (reviews != 0) return reviews;
        return _rating(b).compareTo(_rating(a));
      });
    final bestSellerProducts = bestSellers.take(8).toList();
    final totalPages = activeProducts.isEmpty
        ? 1
        : (activeProducts.length + _allProductsPageSize - 1) ~/
              _allProductsPageSize;
    final currentPage = _allProductsPage < 0
        ? 0
        : _allProductsPage >= totalPages
        ? totalPages - 1
        : _allProductsPage;
    final pagedProducts = activeProducts
        .skip(currentPage * _allProductsPageSize)
        .take(_allProductsPageSize)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Shop')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSeller,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _storeHeader(
                      storeName: storeName,
                      description: description,
                      ownerImageUrl: ownerImageUrl,
                      bannerUrl: bannerUrl,
                      location: location,
                      isOpen: isOpen,
                      productCount: activeProducts.length,
                    ),
                  ),
                  if (activeProducts.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('No active products yet')),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(
                            'New Products',
                            Icons.fiber_new_outlined,
                          ),
                          _horizontalSection(newProducts),
                          if (_trendingProducts.isNotEmpty) ...[
                            _sectionTitle(
                              'Trending',
                              Icons.trending_up_outlined,
                            ),
                            _horizontalSection(_trendingProducts),
                          ],
                          _sectionTitle(
                            'Best Seller',
                            Icons.local_fire_department_outlined,
                          ),
                          _horizontalSection(bestSellerProducts),
                          _sectionTitle(
                            'All Products',
                            Icons.storefront_outlined,
                          ),
                          _allProductsPager(
                            currentPage: currentPage,
                            totalPages: totalPages,
                            totalProducts: activeProducts.length,
                          ),
                        ],
                      ),
                    ),
                    _allProductsGrid(pagedProducts),
                  ],
                ],
              ),
            ),
    );
  }
}
