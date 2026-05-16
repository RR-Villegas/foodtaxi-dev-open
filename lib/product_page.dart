import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cart_model.dart';
import 'services/database_service.dart';

class ProductPage extends StatefulWidget {
  final String productId;

  const ProductPage({super.key, required this.productId});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _product;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  bool _hasError = false;
  int _quantity = 1;
  Map<String, dynamic>? _selectedVariant;

  @override
  void initState() {
    super.initState();
    _fetchProduct();
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? _resolveImagePath(dynamic imageValue) {
    final path = imageValue?.toString().trim();
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http') || path.startsWith('assets/')) return path;
    return DatabaseService.getProductImageUrl(path);
  }

  Future<void> _fetchProduct() async {
    try {
      final response = await _supabase
          .from('product')
          .select('*, store(store_id, store_name), product_variant(*)')
          .eq('product_id', widget.productId)
          .maybeSingle();
      final reviews = await DatabaseService.getProductReviews(widget.productId);

      if (!mounted) return;

      setState(() {
        _product = response == null ? null : Map<String, dynamic>.from(response);
        _reviews = reviews;
        _hasError = response == null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching product: $e');
      if (!mounted) return;

      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _addToCart() {
    final product = _product;
    if (product == null) return;

    for (var i = 0; i < _quantity; i++) {
      CartModel.addItem({
        ...product,
        if (_selectedVariant != null) ...{
          'selected_variant_id': _selectedVariant!['variant_id'],
          'selected_size': _selectedVariant!['size_label'],
          'price': _selectedVariant!['price'],
          'stock_quantity': _selectedVariant!['stock_quantity'],
        },
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['name']} x$_quantity added to cart!'),
        duration: const Duration(seconds: 2),
      ),
    );

    setState(() {});
  }

  Widget _buildImage(String? imagePath) {
    if (imagePath == null) {
      return Container(
        color: Colors.grey[300],
        child: const Icon(Icons.image_not_supported, size: 64),
      );
    }

    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.image_not_supported, size: 64),
        ),
      );
    }

    return Image.network(
      imagePath,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: Colors.grey[300],
        child: const Icon(Icons.image_not_supported, size: 64),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Product Details'),
          backgroundColor: const Color(0xFF2d8f4e),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError || _product == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Product Details'),
          backgroundColor: const Color(0xFF2d8f4e),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red),
              SizedBox(height: 16),
              Text('Error loading product details'),
            ],
          ),
        ),
      );
    }

    final product = _product!;
    final imagePath = _resolveImagePath(product['main_image_url']);
    final stock = _toInt(product['stock_quantity']);
    final price = _toDouble(product['price']);
    final variants = product['product_variant'];
    final activeVariants = variants is List
        ? variants
            .whereType<Map>()
            .where((variant) => variant['is_active'] != false)
            .map((variant) => Map<String, dynamic>.from(variant))
            .toList()
        : <Map<String, dynamic>>[];
    final selectedPrice = _selectedVariant == null
        ? price
        : _toDouble(_selectedVariant!['price']);
    final selectedStock = _selectedVariant == null
        ? stock
        : _toInt(_selectedVariant!['stock_quantity']);
    final isActive = product['is_active'] != false;
    final canPurchase = isActive && selectedStock > 0;
    final description = product['description']?.toString().trim() ?? '';
    final sku = product['sku']?.toString().trim() ?? '';
    final store = product['store'];
    final sellerName = store is Map
        ? store['store_name']?.toString() ?? 'Seller'
        : 'Seller';
    final storeId = store is Map ? store['store_id']?.toString() : null;
    final avgRating = _reviews.isEmpty
        ? 0.0
        : _reviews.fold<double>(
              0,
              (sum, review) => sum + _toDouble(review['rating']),
            ) /
            _reviews.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: const Color(0xFF2d8f4e),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final imageSize = constraints.maxWidth > 640
                    ? 320.0
                    : constraints.maxWidth * 0.44;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox.square(
                      dimension: imageSize.clamp(140, 320),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ColoredBox(
                          color: Colors.grey.shade200,
                          child: _buildImage(imagePath),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name']?.toString() ?? 'Unknown Product',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: storeId == null
                                ? null
                                : () => Navigator.pushNamed(
                                      context,
                                      '/seller/$storeId',
                                    ),
                            child: Text(
                              sellerName,
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'PHP ${selectedPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Size',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: Text(
                                  'Base - PHP ${price.toStringAsFixed(2)}',
                                ),
                                selected: _selectedVariant == null,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedVariant = null;
                                    _quantity = 1;
                                  });
                                },
                              ),
                              ...activeVariants.map((variant) {
                                return ChoiceChip(
                                  label: Text(
                                    '${variant['size_label']} - PHP ${_toDouble(variant['price']).toStringAsFixed(2)}',
                                  ),
                                  selected: _selectedVariant?['variant_id'] ==
                                      variant['variant_id'],
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedVariant = variant;
                                      _quantity = 1;
                                    });
                                  },
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ...List.generate(5, (index) {
                                return Icon(
                                  index < avgRating.round()
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 18,
                                );
                              }),
                              const SizedBox(width: 6),
                              Text('(${_reviews.length} reviews)'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text(
                  'Stock: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  isActive ? '$selectedStock available' : 'Hidden from buyers',
                  style: TextStyle(
                    color: canPurchase ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (canPurchase)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Quantity',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                        ),
                        SizedBox(
                          width: 40,
                          child: Center(
                            child: Text(
                              _quantity.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _quantity < selectedStock
                              ? () => setState(() => _quantity++)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: canPurchase ? _addToCart : null,
                child: Text(
                  canPurchase
                      ? 'Buy'
                      : (isActive ? 'Out of Stock' : 'Unavailable'),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Description',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description.isEmpty ? 'No description yet.' : description,
              style: const TextStyle(height: 1.5),
            ),
            if (sku.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('SKU: $sku'),
            ],
            const SizedBox(height: 28),
            const Text(
              'Reviews',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_reviews.isEmpty)
              const Text('No reviews yet.')
            else
              ..._reviews.map((review) {
                final account = review['account'];
                final name = account is Map
                    ? '${account['firstname'] ?? 'Buyer'} ${account['surname'] ?? ''}'
                        .trim()
                    : 'Buyer';
                final rating = _toInt(review['rating']);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Row(
                      children: [
                        Expanded(child: Text(name.isEmpty ? 'Buyer' : name)),
                        ...List.generate(5, (index) {
                          return Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          );
                        }),
                      ],
                    ),
                    subtitle: Text(
                      review['comment']?.toString().trim().isEmpty ?? true
                          ? 'No comment.'
                          : review['comment'].toString(),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
