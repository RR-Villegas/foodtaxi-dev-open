import 'package:flutter/material.dart';

import 'services/database_service.dart';

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
      _trendingProducts =
          trending.where((item) => item['is_active'] != false).toList();
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
    final imagePath = _ownerAccount?['profile_image_url']?.toString().trim() ?? '';
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
    final parts = [
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
      (sum, review) => sum + (double.tryParse(review['rating']?.toString() ?? '') ?? 0),
    );
    return total / _reviews.length;
  }

  Future<bool> _requireLogin(String action) async {
    final accountId = await DatabaseService.getCurrentAccountId();
    if (accountId != null) return true;
    if (!mounted) return false;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Please log in to $action')),
    );
    navigator.pushNamed('/login');
    return false;
  }

  Future<void> _reviewStore() async {
    if (!await _requireLogin('review this shop')) return;
    if (!mounted) return;
    if (!_canReviewStore) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can review this shop after a delivered order')),
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
          SnackBar(content: Text(ok ? 'Shop review saved' : 'Shop review could not be saved')),
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

  int _stock(Map<String, dynamic> product) {
    return int.tryParse(product['stock_quantity']?.toString() ?? '') ?? 0;
  }

  Widget _image(dynamic imageValue) {
    final path = imageValue?.toString().trim() ?? '';
    if (path.isEmpty) {
      return Image.asset('assets/images/burger.jpg', fit: BoxFit.cover);
    }
    return Image.network(
      path.startsWith('http') ? path : DatabaseService.getProductImageUrl(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Image.asset('assets/images/burger.jpg', fit: BoxFit.cover),
    );
  }

  Widget _stars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = rating >= index + 1;
        final half = !filled && rating > index && rating < index + 1;
        return Icon(
          filled
              ? Icons.star
              : half
                  ? Icons.star_half
                  : Icons.star_border,
          size: 14,
          color: Colors.amber,
        );
      }),
    );
  }

  Widget _productTile(Map<String, dynamic> product, {bool compact = false}) {
    final productId = product['product_id']?.toString();
    final rating = _rating(product);
    final reviewCount = _reviewCount(product);
    return SizedBox(
      width: compact ? 168 : null,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: compact ? const EdgeInsets.only(right: 12) : EdgeInsets.zero,
        child: InkWell(
          onTap: productId == null
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  await DatabaseService.trackProductClick(
                    productId: productId,
                    storeId: widget.storeId,
                  );
                  if (!navigator.mounted) return;
                  navigator.pushNamed('/product/$productId');
                },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: _image(product['main_image_url']),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DatabaseService.displayProductName(product['name']),
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DatabaseService.displayProductPrice(product),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _stars(rating),
                          Text(
                            '($reviewCount)',
                            style: const TextStyle(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_stock(product)} in stock',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: FilledButton(
                          onPressed: productId == null
                              ? null
                              : () {
                                  Navigator.pushNamed(
                                    context,
                                    '/product/$productId',
                                  );
                                },
                          child: const Text('Buy'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _horizontalSection(List<Map<String, dynamic>> products) {
    return SizedBox(
      height: 292,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        itemBuilder: (context, index) => _productTile(
          products[index],
          compact: true,
        ),
      ),
    );
  }

  Widget _productRow(Map<String, dynamic> product) {
    final productId = product['product_id']?.toString();
    final rating = _rating(product);
    final reviewCount = _reviewCount(product);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: productId == null
            ? null
            : () async {
                final navigator = Navigator.of(context);
                await DatabaseService.trackProductClick(
                  productId: productId,
                  storeId: widget.storeId,
                );
                if (!navigator.mounted) return;
                navigator.pushNamed('/product/$productId');
              },
        child: SizedBox(
          height: 126,
          child: Row(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: _image(product['main_image_url']),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DatabaseService.displayProductName(product['name']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DatabaseService.displayProductPrice(product),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _stars(rating),
                          const SizedBox(width: 4),
                          Text('($reviewCount)'),
                        ],
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: productId == null
                              ? null
                              : () {
                                  Navigator.pushNamed(
                                    context,
                                    '/product/$productId',
                                  );
                                },
                          child: const Text('Buy'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
    final activeProducts =
        _products.where((item) => item['is_active'] != false).toList();
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
      appBar: AppBar(
        title: Text(storeName),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSeller,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        image: bannerUrl == null
                            ? null
                            : DecorationImage(
                                image: NetworkImage(bannerUrl),
                                fit: BoxFit.cover,
                              ),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                        decoration: BoxDecoration(
                          gradient: bannerUrl == null
                              ? null
                              : LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withAlpha(105),
                                    Colors.black.withAlpha(65),
                                    Colors.black.withAlpha(125),
                                  ],
                                ),
                        ),
                        child: DefaultTextStyle.merge(
                          style: TextStyle(
                            color: bannerUrl == null
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Colors.white,
                            shadows: bannerUrl == null
                                ? null
                                : const [
                                    Shadow(
                                      blurRadius: 6,
                                      color: Colors.black,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                          ),
                          child: IconTheme.merge(
                            data: IconThemeData(
                              color: bannerUrl == null
                                  ? Theme.of(context).colorScheme.onPrimaryContainer
                                  : Colors.white,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundImage: ownerImageUrl.isNotEmpty
                                          ? NetworkImage(ownerImageUrl)
                                          : null,
                                      child: ownerImageUrl.isEmpty
                                          ? const Icon(Icons.storefront)
                                          : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            storeName,
                                            style: const TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _ownerName(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Chip(
                                      avatar: Icon(
                                        isOpen
                                            ? Icons.check_circle_outline
                                            : Icons.pause_circle_outline,
                                      ),
                                      label: Text(isOpen ? 'Open' : 'Closed'),
                                    ),
                                  ],
                                ),
                                if (location.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.place_outlined, size: 18),
                                      const SizedBox(width: 6),
                                      Expanded(child: Text(location)),
                                    ],
                                  ),
                                ],
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(description),
                                ],
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    Chip(
                                      avatar: const Icon(Icons.inventory_2_outlined),
                                      label: Text('${activeProducts.length} products'),
                                    ),
                                    Chip(
                                      avatar: const Icon(Icons.star_border),
                                      label: Text(
                                        '${_storeRating.toStringAsFixed(1)} (${_reviews.length})',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _reviewStore,
                                      icon: const Icon(Icons.rate_review_outlined),
                                      label: Text(
                                        _myReview == null ? 'Review Shop' : 'Edit Review',
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _reportStore,
                                      icon: const Icon(Icons.flag_outlined),
                                      label: const Text('Report Shop'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
                          _sectionTitle('New Products', Icons.fiber_new_outlined),
                          _horizontalSection(newProducts),
                          if (_trendingProducts.isNotEmpty) ...[
                            _sectionTitle('Trending', Icons.trending_up_outlined),
                            _horizontalSection(_trendingProducts),
                          ],
                          _sectionTitle(
                            'Best Seller',
                            Icons.local_fire_department_outlined,
                          ),
                          _horizontalSection(bestSellerProducts),
                          _sectionTitle('All Products', Icons.storefront_outlined),
                          _allProductsPager(
                            currentPage: currentPage,
                            totalPages: totalPages,
                            totalProducts: activeProducts.length,
                          ),
                        ],
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            index == 0 ? 0 : 10,
                            16,
                            index == pagedProducts.length - 1 ? 24 : 0,
                          ),
                          child: _productRow(pagedProducts[index]),
                        ),
                        childCount: pagedProducts.length,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
