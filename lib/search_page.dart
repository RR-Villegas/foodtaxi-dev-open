import 'package:flutter/material.dart';

import 'services/database_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _categories = [
    'All',
    'Baking Supplies & Ingredients',
    'Coffee, Tea & Beverages',
    'Snacks & Candy',
    'Specialty Foods & International Cuisine',
    'Organic and Health Foods',
    'Meal Kits & Prepped Foods',
  ];

  static const _sorts = [
    'New',
    'Popular',
    'Price: Low to High',
    'Price: High to Low',
  ];

  final _queryController = TextEditingController();
  final _sellerController = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;
  String _category = 'All';
  String _sort = 'New';
  bool _appliedInitialQuery = false;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _sellerController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _isLoading = true);
    final products = await DatabaseService.searchProducts(
      query: _queryController.text,
      category: _category,
      sort: _sort,
      seller: _sellerController.text,
    );
    if (!mounted) return;
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  Widget _image(dynamic imageValue) {
    final path = imageValue?.toString() ?? '';
    if (path.isEmpty) {
      return Image.asset('assets/images/burger.jpg', fit: BoxFit.cover);
    }
    return Image.network(
      DatabaseService.getProductImageUrl(path),
      fit: BoxFit.cover,
      errorBuilder: (_, _, __) =>
          Image.asset('assets/images/burger.jpg', fit: BoxFit.cover),
    );
  }

  Widget _filters() {
    return Container(
      color: const Color(0xFFEAF7EF),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _categories
                      .map((item) => DropdownMenuItem(
                            value: item,
                            child: Text(item, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _category = value);
                    _search();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sort,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sort',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _sorts
                      .map((item) => DropdownMenuItem(
                            value: item,
                            child: Text(item, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sort = value);
                    _search();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sellerController,
            decoration: InputDecoration(
              labelText: 'Seller name',
              prefixIcon: const Icon(Icons.storefront),
              suffixIcon: IconButton(
                onPressed: _search,
                icon: const Icon(Icons.tune),
                tooltip: 'Apply seller filter',
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (_) => _search(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialQuery = ModalRoute.of(context)?.settings.arguments?.toString();
    if (!_appliedInitialQuery) {
      _appliedInitialQuery = true;
      if (initialQuery != null && initialQuery.isNotEmpty) {
        _queryController.text = initialQuery;
        WidgetsBinding.instance.addPostFrameCallback((_) => _search());
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2d8f4e),
        foregroundColor: Colors.white,
        title: TextField(
          controller: _queryController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search products',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
          ),
          onSubmitted: (_) => _search(),
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: _search,
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: Column(
        children: [
          _filters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(child: Text('No products found'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth > 700 ? 4 : 2;
                          return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          final productId = product['product_id']?.toString();
                          final store = product['store'];
                          final seller = store is Map
                              ? store['store_name']?.toString() ?? 'Seller'
                              : 'Seller';
                          final storeId = store is Map
                              ? store['store_id']?.toString()
                              : null;
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
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product['name']?.toString() ??
                                              'Product',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        InkWell(
                                          onTap: storeId == null
                                              ? null
                                              : () => Navigator.pushNamed(
                                                    context,
                                                    '/seller/$storeId',
                                                  ),
                                          child: Text(
                                            seller,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'PHP ${product['price']}',
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
                      );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
