import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
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
  RealtimeChannel? _priceHistoryChannel;
  Timer? _discountCountdownTimer;

  Map<String, dynamic>? _product;
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _priceHistory = [];
  List<Map<String, dynamic>> _discountPriceHistory = [];
  List<Map<String, dynamic>> _productImages = [];
  Map<String, List<Map<String, dynamic>>> _variantImages = {};
  int _selectedImageIndex = 0;
  bool _isLoading = true;
  bool _hasError = false;
  int _quantity = 1;
  Map<String, dynamic>? _selectedVariant;

  @override
  void initState() {
    super.initState();
    _fetchProduct();
    _subscribeToPriceHistory();
    _startDiscountCountdownTimer();
  }
  
  @override
  void dispose() {
    _discountCountdownTimer?.cancel();

    final channel = _priceHistoryChannel;
    if (channel != null) {
      _supabase.removeChannel(channel);
    }

    super.dispose();
  }

  void _startDiscountCountdownTimer() {
    _discountCountdownTimer?.cancel();

    _discountCountdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        final product = _product;
        if (product == null) return;

        final discount = DatabaseService.activeProductDiscount(product);
        if (discount == null) return;

        setState(() {});
      },
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _readableDateTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'unknown time';

    final local = date.toLocal();
    final hour = local.hour > 12
        ? local.hour - 12
        : local.hour == 0
            ? 12
            : local.hour;

    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute $period';
  }

  String _discountRemainingText(Map<String, dynamic> discount) {
    final endsAt = DateTime.tryParse(discount['ends_at']?.toString() ?? '');

    if (endsAt == null) return 'Until unknown';

    final now = DateTime.now();
    final remaining = endsAt.difference(now);

    if (remaining.isNegative || remaining.inSeconds <= 0) {
      return 'Ended';
    }

    if (remaining.inDays >= 1) {
      return 'Until ${_readableDateTime(endsAt.toIso8601String())}, ${remaining.inDays} day${remaining.inDays == 1 ? '' : 's'} left';
    }

    final hours = remaining.inHours.toString().padLeft(2, '0');
    final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');

    return 'Until ${_readableDateTime(endsAt.toIso8601String())}, $hours:$minutes:$seconds left';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _availableStockForOption(
    Map<String, dynamic> product,
    Map<String, dynamic>? variant,
  ) {
    final stock = _toInt(product['stock_quantity']);
    final stockMode = product['stock_mode']?.toString() == 'shared'
        ? 'shared'
        : 'independent';
    if (stockMode == 'shared') {
      final unitQuantity = variant == null
          ? _toInt(product['base_unit_quantity'])
          : _toInt(variant['stock_unit_quantity']);
      final safeUnitQuantity = unitQuantity < 1 ? 1 : unitQuantity;
      return stock ~/ safeUnitQuantity;
    }
    return variant == null ? stock : _toInt(variant['stock_quantity']);
  }

  Map<String, dynamic>? _firstAvailableVariant(Map<String, dynamic> product) {
    if (_availableStockForOption(product, null) > 0) return null;
    final variants = product['product_variant'];
    if (variants is! List) return null;
    for (final variant in variants.whereType<Map>()) {
      if (variant['is_active'] == false) continue;
      final normalized = Map<String, dynamic>.from(variant);
      if (_availableStockForOption(product, normalized) > 0) return normalized;
    }
    return null;
  }

  String? _resolveImagePath(dynamic imageValue) {
    final path = imageValue?.toString().trim();
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http') || path.startsWith('assets/')) return path;
    return DatabaseService.getProductImageUrl(path);
  }

    Future<void> _refreshPriceHistory() async {
    try {
      final priceHistory =
          await DatabaseService.getProductPriceHistory(widget.productId);

      if (!mounted) return;

      setState(() {
        _priceHistory = priceHistory;
      });
    } catch (e) {
      debugPrint('Error refreshing price history: $e');
    }
  }

  Future<void> _fetchProduct() async {
    try {
      final response = await _supabase
          .from('product')
          .select(
            '*, store(store_id, store_name), product_variant(*), product_discount(*)',
          )
          .eq('product_id', widget.productId)
          .maybeSingle();
      final reviews = await DatabaseService.getProductReviews(widget.productId);
      final priceHistory =
          await DatabaseService.getProductPriceHistory(widget.productId);
      final discountPriceHistory =
          await DatabaseService.getProductDiscountPriceHistory(widget.productId);
      final productImages = response == null
          ? <Map<String, dynamic>>[]
          : await DatabaseService.getProductImages(widget.productId);

      final variantImageMap = <String, List<Map<String, dynamic>>>{};

      if (response != null) {
        final variants = response['product_variant'];

        if (variants is List) {
          for (final variant in variants.whereType<Map>()) {
            final variantId = variant['variant_id']?.toString();

            if (variantId == null || variantId.isEmpty) continue;

            variantImageMap[variantId] =
                await DatabaseService.getVariantImages(variantId);
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _product = response == null ? null : Map<String, dynamic>.from(response);
        if (_product != null) {
          _selectedVariant = _firstAvailableVariant(_product!);
        }
        _reviews = reviews;
        _priceHistory = priceHistory;
        _discountPriceHistory = discountPriceHistory;
        _productImages = productImages;
        _variantImages = variantImageMap;
        _selectedImageIndex = 0;
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

  Future<void> _refreshDiscountPriceHistory() async {
    try {
      final discountPriceHistory =
          await DatabaseService.getProductDiscountPriceHistory(widget.productId);

      if (!mounted) return;

      setState(() {
        _discountPriceHistory = discountPriceHistory;
      });
    } catch (e) {
      debugPrint('Error refreshing discount price history: $e');
    }
  }

  void _subscribeToPriceHistory() {
    if (_priceHistoryChannel != null) return;

    _priceHistoryChannel = _supabase
        .channel('product-price-history-${widget.productId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'product_price_history',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'product_id',
            value: widget.productId,
          ),
          callback: (_) => _refreshPriceHistory(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'product_discount',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'product_id',
            value: widget.productId,
          ),
          callback: (_) => _fetchProduct(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'product_discount_price_history',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'product_id',
            value: widget.productId,
          ),
          callback: (_) => _refreshDiscountPriceHistory(),
        )
        .subscribe();
  }

  void _addToCart() {
    final product = _product;
    if (product == null) return;

    if (Supabase.instance.client.auth.currentUser == null) {
      Navigator.pushNamed(context, '/login');
      return;
    }

    final selectedStock = _availableStockForOption(product, _selectedVariant);
    final discount = DatabaseService.activeProductDiscount(product);

    final originalPrice = _selectedVariant == null
        ? _toDouble(product['price'])
        : _toDouble(_selectedVariant!['price']);

    final cartPrice = DatabaseService.discountedPrice(
      originalPrice,
      discount,
    );

    var added = 0;

    for (var i = 0; i < _quantity; i++) {
      final didAdd = CartModel.addItem({
        ...product,
        'price': cartPrice,
        'original_price': originalPrice,
        'discount_id': discount?['discount_id'],
        'discount_type': discount?['discount_type'],
        'discount_value': discount?['discount_value'],
        'max_quantity': selectedStock,
        if (_selectedVariant == null) ...{
          'selected_size': product['base_size_label'],
          'selected_sku': product['sku'],
        } else ...{
          'selected_variant_id': _selectedVariant!['variant_id'],
          'selected_size': _selectedVariant!['size_label'],
          'selected_sku': _selectedVariant!['sku'],
          'stock_quantity': _selectedVariant!['stock_quantity'],
        },
      });

      if (!didAdd) break;
      added++;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added > 0
              ? '${DatabaseService.displayProductName(product['name'])} x$added added to cart!'
              : 'Cart already has all available stock for this item.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    setState(() {});
  }

  Future<void> _reportProduct() async {
    final product = _product;
    if (product == null) return;
    if (Supabase.instance.client.auth.currentUser == null) {
      Navigator.pushNamed(context, '/login');
      return;
    }

    final reasonController = TextEditingController();
    final detailsController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Product'),
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
    );

    if (saved == true) {
      final store = product['store'];
      final ok = reasonController.text.trim().isNotEmpty &&
          await DatabaseService.reportProduct(
            productId: widget.productId,
            storeId: store is Map ? store['store_id']?.toString() : null,
            reason: reasonController.text,
            details: detailsController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'Product report submitted' : 'Product report could not be submitted',
            ),
          ),
        );
      }
    }

    reasonController.dispose();
    detailsController.dispose();
  }

  Widget _buildPriceHistorySection() {
    final selectedVariantId = _selectedVariant?['variant_id']?.toString();

    final relevantHistory = _priceHistory.where((row) {
      final variantId = row['variant_id']?.toString();

      if (selectedVariantId == null || selectedVariantId.isEmpty) {
        return variantId == null || variantId.isEmpty || variantId == 'null';
      }

      return variantId == selectedVariantId;
    }).toList()
      ..sort(
        (a, b) {
          final aDate = DateTime.tryParse(a['recorded_at']?.toString() ?? '') ??
              DateTime(0);
          final bDate = DateTime.tryParse(b['recorded_at']?.toString() ?? '') ??
              DateTime(0);
          return aDate.compareTo(bDate);
        },
      );

    final rowsWithCurrent = [...relevantHistory];

    final currentPrice = _selectedVariant == null
        ? _toDouble(_product!['price'])
        : _toDouble(_selectedVariant!['price']);

    rowsWithCurrent.add({
      'price': currentPrice,
      'recorded_at': DateTime.now().toIso8601String(),
      'variant_id': selectedVariantId,
      'is_live': true,
    });

    final rows = rowsWithCurrent.length > 24
        ? rowsWithCurrent.sublist(rowsWithCurrent.length - 24)
        : rowsWithCurrent;

    if (rows.isEmpty) {
      return Text(
        selectedVariantId == null
            ? 'No base price history yet.'
            : 'No price history for this size yet.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    double graphPrice(Map<String, dynamic> row) {
    return _toDouble(row['price']);
  }

    final prices = rows.map(graphPrice).toList();
    final low = prices.reduce((a, b) => a < b ? a : b);
    final high = prices.reduce((a, b) => a > b ? a : b);
    final latest = prices.last;
    final previous = prices.length >= 2 ? prices[prices.length - 2] : latest;
    final spread = high - low;
    final scheme = Theme.of(context).colorScheme;

    String readableTime(dynamic value) {
      final date = DateTime.tryParse(value?.toString() ?? '');
      if (date == null) return 'Unknown time';

      final local = date.toLocal();
      final hour = local.hour > 12
          ? local.hour - 12
          : local.hour == 0
              ? 12
              : local.hour;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = local.hour >= 12 ? 'PM' : 'AM';

      return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute $period';
    }

    Color barColor(double price) {
      if (price <= low) return scheme.tertiary;
      if (price >= high && high != low) return scheme.secondary;
      return scheme.primary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.trending_down_outlined),
              label: Text('Low ${DatabaseService.money(low)}'),
            ),
            Chip(
              avatar: const Icon(Icons.trending_up_outlined),
              label: Text('High ${DatabaseService.money(high)}'),
            ),
            Chip(
              avatar: Icon(
                latest <= previous
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
              ),
              label: Text('Latest ${DatabaseService.money(latest)}'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: rows.map((row) {
              final price = graphPrice(row);
              final height =
                  spread <= 0 ? 64.0 : 32 + ((price - low) / spread) * 92;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Tooltip(
                    message:
                        '${DatabaseService.money(price)}\n${readableTime(row['recorded_at'])}',
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: height,
                        decoration: BoxDecoration(
                          color: barColor(price),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Showing ${rows.length} recorded price${rows.length == 1 ? '' : 's'}'
          '${selectedVariantId == null ? ' for base item' : ' for selected size'}',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountPriceHistorySection() {
    final selectedVariantId = _selectedVariant?['variant_id']?.toString();

    final relevantHistory = _discountPriceHistory.where((row) {
      final variantId = row['variant_id']?.toString();

      if (selectedVariantId == null || selectedVariantId.isEmpty) {
        return variantId == null || variantId.isEmpty || variantId == 'null';
      }

      return variantId == selectedVariantId;
    }).toList()
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a['recorded_at']?.toString() ?? '') ??
            DateTime(0);
        final bDate = DateTime.tryParse(b['recorded_at']?.toString() ?? '') ??
            DateTime(0);
        return aDate.compareTo(bDate);
      });

    final rows = relevantHistory.length > 24
        ? relevantHistory.sublist(relevantHistory.length - 24)
        : relevantHistory;

    if (rows.isEmpty) {
      return Text(
        'No sale price history yet.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    double graphPrice(Map<String, dynamic> row) {
      return _toDouble(row['discounted_price']);
    }

    final prices = rows.map(graphPrice).toList();
    final low = prices.reduce((a, b) => a < b ? a : b);
    final high = prices.reduce((a, b) => a > b ? a : b);
    final latest = prices.last;
    final spread = high - low;
    final scheme = Theme.of(context).colorScheme;

    String readableTime(dynamic value) {
      final date = DateTime.tryParse(value?.toString() ?? '');
      if (date == null) return 'Unknown time';

      final local = date.toLocal();
      final hour = local.hour > 12
          ? local.hour - 12
          : local.hour == 0
              ? 12
              : local.hour;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = local.hour >= 12 ? 'PM' : 'AM';

      return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute $period';
    }

    Color barColor(double price) {
      if (price <= low) return scheme.tertiary;
      if (price >= high && high != low) return scheme.secondary;
      return scheme.primary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.local_offer_outlined),
              label: Text('Sale low ${DatabaseService.money(low)}'),
            ),
            Chip(
              avatar: const Icon(Icons.sell_outlined),
              label: Text('Sale high ${DatabaseService.money(high)}'),
            ),
            Chip(
              avatar: const Icon(Icons.history),
              label: Text('Latest ${DatabaseService.money(latest)}'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: rows.map((row) {
              final price = graphPrice(row);
              final height =
                  spread <= 0 ? 64.0 : 32 + ((price - low) / spread) * 82;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Tooltip(
                    message:
                        '${DatabaseService.money(price)}\nBase: ${DatabaseService.money(row['base_price'])}\n${readableTime(row['recorded_at'])}',
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: height,
                        decoration: BoxDecoration(
                          color: barColor(price),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Showing ${rows.length} recorded sale price${rows.length == 1 ? '' : 's'}',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  List<String> _activeGalleryImages() {
    final product = _product;
    if (product == null) return [];

    final selectedVariantId = _selectedVariant?['variant_id']?.toString();

    if (selectedVariantId != null && selectedVariantId.isNotEmpty) {
      final variantRows = _variantImages[selectedVariantId] ?? [];

      final variantUrls = variantRows
          .map((row) => row['image_url']?.toString().trim() ?? '')
          .where((url) => url.isNotEmpty)
          .toList();

      if (variantUrls.isNotEmpty) {
        return variantUrls;
      }
    }

    final productUrls = _productImages
        .map((row) => row['image_url']?.toString().trim() ?? '')
        .where((url) => url.isNotEmpty)
        .toList();

    if (productUrls.isNotEmpty) {
      return productUrls;
    }

    final fallback = product['main_image_url']?.toString().trim() ?? '';
    if (fallback.isNotEmpty) return [fallback];

    return [];
  }

  String? _activeGalleryImage() {
    final images = _activeGalleryImages();

    if (images.isEmpty) return null;

    final safeIndex = _selectedImageIndex.clamp(0, images.length - 1);
    return _resolveImagePath(images[safeIndex]);
  }

  Widget _buildProductGallery() {
    final scheme = Theme.of(context).colorScheme;
    final images = _activeGalleryImages();

    final activeImage = _activeGalleryImage();

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildImage(activeImage),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, index) {
                final resolved = _resolveImagePath(images[index]);
                final selected = index == _selectedImageIndex;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedImageIndex = index);
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? scheme.primary : scheme.outline,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: _buildImage(resolved),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
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
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError || _product == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Product Details'),
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
    final price = _toDouble(product['price']);
    final baseSizeLabel =
        product['base_size_label']?.toString().trim().isNotEmpty == true
            ? product['base_size_label'].toString()
            : 'Default';
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
    final activeDiscount = DatabaseService.activeProductDiscount(product);
    final displayedSelectedPrice =
        DatabaseService.discountedPrice(selectedPrice, activeDiscount);
    final selectedStock = _availableStockForOption(product, _selectedVariant);
    final isActive = product['is_active'] != false;
    final canPurchase = isActive && selectedStock > 0;
    final description = product['description']?.toString().trim() ?? '';
    final sku = _selectedVariant == null
        ? product['sku']?.toString().trim() ?? ''
        : _selectedVariant!['sku']?.toString().trim() ?? '';
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
        actions: [
          IconButton(
            tooltip: 'Report product',
            onPressed: _reportProduct,
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
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
                    SizedBox(
                      width: imageSize.clamp(160, 320),
                      child: _buildProductGallery(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DatabaseService.displayProductName(product['name']),
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
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'PHP ${displayedSelectedPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          if (activeDiscount != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              activeDiscount['discount_type']?.toString() == 'amount'
                                  ? '${DatabaseService.money(activeDiscount['discount_value'])} scheduled shop discount'
                                  : '${activeDiscount['discount_value']}% scheduled shop discount',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _discountRemainingText(activeDiscount),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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
                                  '$baseSizeLabel - ${DatabaseService.money(DatabaseService.discountedPrice(price, activeDiscount))}${_availableStockForOption(product, null) <= 0 ? ' (out)' : ''}',
                                ),
                                selected: _selectedVariant == null,
                                onSelected: _availableStockForOption(product, null) <= 0
                                    ? null
                                    : (_) {
                                        setState(() {
                                          _selectedVariant = null;
                                          _quantity = 1;
                                        });
                                      },
                              ),
                              ...activeVariants.map((variant) {
                                final variantStock =
                                    _availableStockForOption(product, variant);
                                return ChoiceChip(
                                  label: Text(
                                    '${variant['size_label']} - ${DatabaseService.money(DatabaseService.discountedPrice(_toDouble(variant['price']), activeDiscount))}${variantStock <= 0 ? ' (out)' : ''}',
                                  ),
                                  selected: _selectedVariant?['variant_id'] ==
                                      variant['variant_id'],
                                  onSelected: variantStock <= 0
                                      ? null
                                      : (_) {
                                          setState(() {
                                            _selectedVariant = variant;
                                            _selectedImageIndex = 0;
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
            TextButton.icon(
              onPressed: _reportProduct,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Report Product'),
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
              'Base Price History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildPriceHistorySection(),
            const SizedBox(height: 28),
            const Text(
              'Sale Price History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildDiscountPriceHistorySection(),
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
