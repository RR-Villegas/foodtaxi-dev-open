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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSeller();
  }

  Future<void> _loadSeller() async {
    final store = await DatabaseService.getStoreById(widget.storeId);
    final products = await DatabaseService.getProductsForStore(widget.storeId);
    if (!mounted) return;
    setState(() {
      _store = store;
      _products = products.where((item) => item['is_active'] != false).toList();
      _isLoading = false;
    });
  }

  String _money(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return 'PHP ${amount.toStringAsFixed(2)}';
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

  @override
  Widget build(BuildContext context) {
    final storeName = _store?['store_name']?.toString() ?? 'Seller';
    final city = _store?['city']?.toString() ?? '';
    final description = _store?['description']?.toString() ?? '';

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
                      padding: const EdgeInsets.all(20),
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
                        ],
                      ),
                    ),
                  ),
                  if (_products.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('No active products yet')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(12),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                          final product = _products[index];
                          final productId = product['product_id']?.toString();
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: productId == null
                                  ? null
                                  : () => Navigator.pushNamed(
                                        context,
                                        '/product/$productId',
                                      ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product['name']?.toString() ??
                                              'Product',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _money(product['price']),
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                          childCount: _products.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
