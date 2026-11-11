import 'dart:async';
import 'package:flutter/material.dart';

import 'services/database_service.dart';
import 'widgets/product_card.dart';

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
    'Condiments, Sauces & Spices',
    'Dairy, Eggs & Chilled Goods',
    'Fresh Produce',
    'Frozen Foods',
    'Local Delicacies',
    'Meal Kits & Prepped Foods',
    'Meat, Seafood & Poultry',
    'Organic and Health Foods',
    'Ready-to-Eat Meals',
    'Rice, Grains & Pasta',
    'Snacks & Candy',
    'Specialty Foods & International Cuisine',
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
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();

    _sellerController.addListener(() {
      if (mounted) setState(() {});
    });

    _sellerFocusNode.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;

      if (args is Map) {
        final initialQuery = args['query']?.toString().trim() ?? '';
        final showFilters = args['showFilters'] == true;

        if (initialQuery.isNotEmpty) {
          _queryController.text = initialQuery;
        }

        if (showFilters) {
          _sellerFocusNode.requestFocus();
        }
      } else {
        final initialQuery = args?.toString().trim() ?? '';
        if (initialQuery.isNotEmpty) {
          _queryController.text = initialQuery;
        }
      }

      _search();
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _sellerController.dispose();
    _sellerFocusNode.dispose();
    _searchDebounce?.cancel();
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

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Widget _productRow(Map<String, dynamic> product) {
    final productId = product['product_id']?.toString();
    final store = product['store'];
    final seller = store is Map
        ? store['store_name']?.toString() ?? 'Seller'
        : 'Seller';
    final storeId = store is Map ? store['store_id']?.toString() : null;
    return ProductCard(
      product: product,
      layout: ProductCardLayout.list,
      storeName: seller,
      onTap: productId == null
          ? null
          : () async {
              await DatabaseService.trackProductClick(
                productId: productId,
                storeId: storeId,
              );
              if (!mounted) return;
              Navigator.pushNamed(context, '/product/$productId');
            },
      onStoreTap: storeId == null
          ? null
          : () => Navigator.pushNamed(context, '/seller/$storeId'),
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
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item, overflow: TextOverflow.ellipsis),
                        ),
                      )
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
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item, overflow: TextOverflow.ellipsis),
                        ),
                      )
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
          onChanged: (_) => _scheduleSearch(),
        ),
        actions: [
          IconButton(
            tooltip: 'Apply search',
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
                    cacheExtent: 720,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
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
