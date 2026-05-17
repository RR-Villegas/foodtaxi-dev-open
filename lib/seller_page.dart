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
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic>? _myReview;
  bool _canReviewStore = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSeller();
  }

  Future<void> _loadSeller() async {
    final store = await DatabaseService.getStoreById(widget.storeId);
    final products = await DatabaseService.getProductsForStore(widget.storeId);
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
      _reviews = reviews;
      _canReviewStore = canReview;
      _myReview = myReview;
      _isLoading = false;
    });
  }

  String _money(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return 'PHP ${amount.toStringAsFixed(2)}';
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

  double get _storeRating {
    if (_reviews.isEmpty) return 0;
    final total = _reviews.fold<double>(
      0,
      (sum, review) => sum + (double.tryParse(review['rating']?.toString() ?? '') ?? 0),
    );
    return total / _reviews.length;
  }

  Future<void> _reviewStore() async {
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
    var isOrderRelated = false;
    final reasonController = TextEditingController();
    final detailsController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report Shop'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detailsController,
                decoration: const InputDecoration(labelText: 'Details'),
                minLines: 2,
                maxLines: 4,
              ),
              CheckboxListTile(
                value: isOrderRelated,
                contentPadding: EdgeInsets.zero,
                title: const Text('Related to a delivered order'),
                subtitle: !_canReviewStore
                    ? const Text('Available after you receive an order from this shop')
                    : null,
                onChanged: !_canReviewStore
                    ? null
                    : (value) => setDialogState(() => isOrderRelated = value ?? false),
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
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final ok = reasonController.text.trim().isNotEmpty &&
          await DatabaseService.reportStore(
            storeId: widget.storeId,
            reason: reasonController.text,
            details: detailsController.text,
            isOrderRelated: isOrderRelated,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Shop report submitted' : 'Shop report could not be submitted')),
        );
      }
    }
    reasonController.dispose();
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
      errorBuilder: (_, _, __) =>
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
              : () => Navigator.pushNamed(context, '/product/$productId'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: _image(product['main_image_url']),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name']?.toString() ?? 'Product',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _money(product['price']),
                      style: const TextStyle(
                        color: Colors.green,
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
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${_stock(product)} in stock',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ],
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
          Icon(icon, color: const Color(0xFF2d8f4e)),
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
      height: 258,
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

  @override
  Widget build(BuildContext context) {
    final storeName = _store?['store_name']?.toString() ?? 'Seller';
    final city = _store?['city']?.toString() ?? '';
    final description = _store?['description']?.toString() ?? '';
    final activeProducts = _products.where((item) => item['is_active'] != false).toList();
    final newProducts = activeProducts.take(8).toList();
    final bestSellers = [...activeProducts]
      ..sort((a, b) {
        final reviews = _reviewCount(b).compareTo(_reviewCount(a));
        if (reviews != 0) return reviews;
        return _rating(b).compareTo(_rating(a));
      });
    final bestSellerProducts = bestSellers.take(8).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(storeName),
        backgroundColor: const Color(0xFF2d8f4e),
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
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                      color: const Color(0xFFEAF7EF),
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
                          if (city.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.place_outlined, size: 18),
                                const SizedBox(width: 4),
                                Text(city),
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
                                label: Text(_myReview == null ? 'Review Shop' : 'Edit Review'),
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
                          _sectionTitle('Best Seller', Icons.local_fire_department_outlined),
                          _horizontalSection(bestSellerProducts),
                          _sectionTitle('All Products', Icons.storefront_outlined),
                        ],
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.68,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _productTile(activeProducts[index]),
                          childCount: activeProducts.length,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
