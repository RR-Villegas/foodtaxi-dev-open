import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/database_service.dart';
import 'cart_model.dart';

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

  Future<void> _fetchProduct() async {
    try {
      final response = await _supabase
          .from('product')
          .select()
          .eq('product_id', widget.productId)
          .single();

      setState(() {
        _product = response as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching product: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _addToCart() {
    if (_product == null) return;

    // Add product to cart with quantity
    for (int i = 0; i < _quantity; i++) {
      CartModel.addItem(_product!);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_product!['name']} x${_quantity} added to cart!'),
        duration: const Duration(seconds: 2),
      ),
    );

    // Navigate back to previous page
    Navigator.pop(context);
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
    final imageUrl = DatabaseService.getProductImageUrl(product['main_image_url'] ?? '');
    final stock = product['stock_quantity'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: const Color(0xFF2d8f4e),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product Image
            Container(
              height: 300,
              color: Colors.grey[200],
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported, size: 64),
                ),
              ),
            ),
            
            // Product Details
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    product['name'] ?? 'Unknown Product',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Price
                  Text(
                    '₱${(product['price'] ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Category
                  if (product['category'] != null)
                    Chip(
                      label: Text(product['category']),
                      backgroundColor: Colors.green[100],
                    ),
                  const SizedBox(height: 16),

                  // Stock Status
                  Row(
                    children: [
                      const Text('Stock: ', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '$stock available',
                        style: TextStyle(
                          color: stock > 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Description
                  if (product['description'] != null)
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
                          product['description'],
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),

                  // SKU
                  if (product['sku'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        children: [
                          const Text('SKU: ', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(product['sku']),
                        ],
                      ),
                    ),

                  // Quantity Selector
                  if (stock > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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

                  // Add to Cart Button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: stock > 0 ? Colors.green : Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: stock > 0 ? _addToCart : null,
                      child: Text(
                        stock > 0 ? 'Add to Cart' : 'Out of Stock',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
