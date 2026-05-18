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
    'Fresh Produce',
    'Meat, Seafood & Poultry',
    'Dairy, Eggs & Chilled Goods',
    'Frozen Foods',
    'Condiments, Sauces & Spices',
    'Rice, Grains & Pasta',
    'Ready-to-Eat Meals',
    'Local Delicacies',
  ];

  static const _sorts = [
    'New',
    'Popular',
    'Price: Low to High',
    'Price: High to Low',
  ];

  final _queryController = TextEditingController();
  final _sellerController = TextEditingController();
  final _sellerFocusNode = FocusNode();
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;
  String _category = 'All';
  String _sort = 'New';
  bool _appliedInitialQuery = false;

  @override
  void initState() {
    super.initState();
    _sellerController.addListener(() {
      if (mounted) setState(() {});
    });
    _sellerFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _search();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _sellerController.dispose();
    _sellerFocusNode.dispose();
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
      errorBuilder: (context, error, stackTrace) =>
          Image.asset('assets/images/burger.jpg', fit: BoxFit.cover),
    );
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
          size: 15,
          color: Colors.amber,
        );
      }),
    );
  }

  Widget _productRow(Map<String, dynamic> product) {
    final productId = product['product_id']?.toString();
    final store = product['store'];
    final seller = store is Map
        ? store['store_name']?.toString() ?? 'Seller'
        : 'Seller';
    final storeId = store is Map ? store['store_id']?.toString() : null;
    final rating = _rating(product);
    final reviewCount = _reviewCount(product);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: productId == null
            ? null
            : () async {
                await DatabaseService.trackProductClick(
                  productId: productId,
                  storeId: storeId,
                );
                if (mounted) {
                  Navigator.pushNamed(context, '/product/$productId');
                }
              },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: _image(product['main_image_url']),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DatabaseService.displayProductName(product['name']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: storeId == null
                          ? null
                          : () => Navigator.pushNamed(context, '/seller/$storeId'),
                      child: Text(
                        seller,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'PHP ${product['price']}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _stars(rating),
                        Text(
                          '($reviewCount)',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> get _sellerSuggestions {
    final query = _sellerController.text.trim().toLowerCase();
    if (!_sellerFocusNode.hasFocus || query.isEmpty) return [];
    final names = <String>{};
    for (final product in _products) {
      final store = product['store'];
      if (store is! Map) continue;
      final name = store['store_name']?.toString().trim();
      if (name == null || name.isEmpty) continue;
      if (name.toLowerCase().contains(query)) names.add(name);
    }
    final sorted = names.toList()..sort();
    return sorted.take(6).toList();
  }

  Widget _sellerSuggestionList() {
    final suggestions = _sellerSuggestions;
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.storefront),
            title: Text(suggestion, overflow: TextOverflow.ellipsis),
            onTap: () {
              _sellerController.text = suggestion;
              _sellerFocusNode.unfocus();
              _search();
            },
          );
        },
      ),
    );
  }

  Widget _filters() {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    filled: true,
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
                  initialValue: _sort,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Sort',
                    filled: true,
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
            focusNode: _sellerFocusNode,
            decoration: InputDecoration(
              labelText: 'Seller name',
              prefixIcon: const Icon(Icons.storefront),
              suffixIcon: IconButton(
                onPressed: _search,
                icon: const Icon(Icons.tune),
                tooltip: 'Apply seller filter',
              ),
              filled: true,
            ),
            onSubmitted: (_) => _search(),
          ),
          _sellerSuggestionList(),
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
        title: TextField(
          controller: _queryController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search products',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
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
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _products.length,
                        itemBuilder: (context, index) =>
                            _productRow(_products[index]),
                      ),
          ),
        ],
      ),
    );
  }
}
