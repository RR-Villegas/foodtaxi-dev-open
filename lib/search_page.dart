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
    return ExpansionTile(
      title: const Text('Filters'),
      leading: const Icon(Icons.filter_list),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        DropdownButtonFormField<String>(
          value: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: _categories
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _category = value);
            _search();
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _sort,
          decoration: const InputDecoration(labelText: 'Sort'),
          items: _sorts
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _sort = value);
            _search();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _sellerController,
          decoration: const InputDecoration(
            labelText: 'Seller name',
            prefixIcon: Icon(Icons.storefront),
          ),
          onSubmitted: (_) => _search(),
        ),
      ],
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
        title: TextField(
          controller: _queryController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search products',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search),
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
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
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
                          return Card(
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
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8),
                                      ),
                                      child: _image(product['main_image_url']),
                                    ),
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
                                        Text(
                                          seller,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                      ),
          ),
        ],
      ),
    );
  }
}
