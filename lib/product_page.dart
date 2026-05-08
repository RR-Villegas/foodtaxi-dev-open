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
  bool _isLoading = true;
  bool _hasError = false;
  int _quantity = 1;

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
          .select()
          .eq('product_id', widget.productId)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _product = response == null ? null : Map<String, dynamic>.from(response);
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
      CartModel.addItem(product);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['name']} x$_quantity added to cart!'),
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.pop(context);
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
    final isActive = product['is_active'] != false;
    final canPurchase = isActive && stock > 0;
    final description = product['description']?.toString().trim() ?? '';
    final sku = product['sku']?.toString().trim() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: const Color(0xFF2d8f4e),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 300,
              color: Colors.grey[200],
              child: _buildImage(imagePath),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name']?.toString() ?? 'Unknown Product',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PHP ${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (product['category'] != null)
                    Chip(
                      label: Text(product['category'].toString()),
                      backgroundColor: Colors.green[100],
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Stock: ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        isActive ? '$stock available' : 'Hidden from buyers',
                        style: TextStyle(
                          color: canPurchase ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (description.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  if (sku.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        children: [
                          const Text(
                            'SKU: ',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(sku),
                        ],
                      ),
                    ),
                  if (canPurchase)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Quantity:',
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _quantity.toString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: _quantity < stock
                                    ? () => setState(() => _quantity++)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canPurchase ? Colors.green : Colors.grey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: canPurchase ? _addToCart : null,
                      child: Text(
                        canPurchase
                            ? 'Add to Cart'
                            : (isActive ? 'Out of Stock' : 'Unavailable'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
