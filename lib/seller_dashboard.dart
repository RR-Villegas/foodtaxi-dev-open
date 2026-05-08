import 'package:flutter/material.dart';
import 'services/database_service.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  static const List<String> _categories = [
    'Baking Supplies & Ingredients',
    'Coffee, Tea & Beverages',
    'Snacks & Candy',
    'Specialty Foods & International Cuisine',
    'Organic and Health Foods',
    'Meal Kits & Prepped Foods',
  ];

  Map<String, dynamic>? _store;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _orders = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final accountId = await DatabaseService.getCurrentAccountId();
      final store = await DatabaseService.getCurrentSellerStore();
      final storeId = store?['store_id']?.toString();

      final products = storeId == null
          ? <Map<String, dynamic>>[]
          : await DatabaseService.getSellerProducts(storeId);
      final orders = accountId == null
          ? <Map<String, dynamic>>[]
          : await DatabaseService.getSellerOrders(accountId);

      if (mounted) {
        setState(() {
          _store = store;
          _products = products;
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load seller dashboard: $e')),
        );
      }
    }
  }

  String _money(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return 'PHP ${amount.toStringAsFixed(2)}';
  }

  int _stock(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _buildProductImage(dynamic imageValue, {double size = 56}) {
    final path = imageValue?.toString().trim();
    if (path == null || path.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_outlined),
      );
    }

    final imageUrl = path.startsWith('http')
        ? path
        : DatabaseService.getProductImageUrl(path);

    return Image.network(
      imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        width: size,
        height: size,
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }

  Future<void> _openProductForm([Map<String, dynamic>? product]) async {
    final formKey = GlobalKey<FormState>();
    final nameController =
        TextEditingController(text: product?['name']?.toString() ?? '');
    final priceController =
        TextEditingController(text: product?['price']?.toString() ?? '');
    final stockController = TextEditingController(
      text: product?['stock_quantity']?.toString() ?? '0',
    );
    final descriptionController = TextEditingController(
      text: product?['description']?.toString() ?? '',
    );
    final skuController =
        TextEditingController(text: product?['sku']?.toString() ?? '');
    final imageController = TextEditingController(
      text: product?['main_image_url']?.toString() ?? '',
    );
    var category = product?['category']?.toString();
    var isActive = product?['is_active'] != false;
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(product == null ? 'Add Product' : 'Edit Product'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Product Name *'),
                      validator: (value) =>
                          (value?.trim().isEmpty ?? true) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ))
                          .toList(),
                      onChanged: (value) => setDialogState(() => category = value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Price *'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final parsed = double.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed < 0) return 'Enter a valid price';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: stockController,
                      decoration: const InputDecoration(labelText: 'Stock Quantity *'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final parsed = int.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed < 0) return 'Enter a valid stock';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: skuController,
                      decoration: const InputDecoration(labelText: 'SKU'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: imageController,
                      decoration: const InputDecoration(
                        labelText: 'Image filename or URL',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                    ),
                    SwitchListTile(
                      value: isActive,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        final storeId = _store?['store_id']?.toString();
                        if (storeId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Seller store not found')),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);
                        final ok = product == null
                            ? await DatabaseService.insertProduct(
                                storeId: storeId,
                                name: nameController.text,
                                category: category,
                                price: double.parse(priceController.text.trim()),
                                stockQuantity:
                                    int.parse(stockController.text.trim()),
                                sku: skuController.text,
                                mainImageUrl: imageController.text,
                                description: descriptionController.text,
                                isActive: isActive,
                              )
                            : await DatabaseService.updateProduct(
                                productId: product['product_id'].toString(),
                                name: nameController.text,
                                category: category,
                                price: double.parse(priceController.text.trim()),
                                stockQuantity:
                                    int.parse(stockController.text.trim()),
                                sku: skuController.text,
                                mainImageUrl: imageController.text,
                                description: descriptionController.text,
                                isActive: isActive,
                              );

                        if (!mounted || !dialogContext.mounted) return;
                        if (ok) {
                          Navigator.of(dialogContext).pop();
                          await _loadDashboard();
                        } else {
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Product could not be saved')),
                          );
                        }
                      },
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(isSaving ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        );
      },
    );

    nameController.dispose();
    priceController.dispose();
    stockController.dispose();
    descriptionController.dispose();
    skuController.dispose();
    imageController.dispose();
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Hide ${product['name'] ?? 'this product'} from buyers?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hide'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok =
        await DatabaseService.deleteProduct(product['product_id'].toString());
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Product hidden' : 'Product could not be hidden')),
    );
    if (ok) _loadDashboard();
  }

  Widget _buildProductsTab() {
    if (_store == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.store_mall_directory_outlined, size: 56),
              const SizedBox(height: 12),
              const Text(
                'No seller store found',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your seller application must be approved before you can manage products.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadDashboard,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 56),
            const SizedBox(height: 12),
            const Text('No products yet'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openProductForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          final active = product['is_active'] != false;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildProductImage(product['main_image_url']),
              ),
              title: Text(product['name']?.toString() ?? 'Product'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_money(product['price'])),
                  Text('Stock: ${_stock(product['stock_quantity'])}'),
                  Text(
                    active ? 'Active' : 'Hidden',
                    style: TextStyle(color: active ? Colors.green : Colors.grey),
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _openProductForm(product);
                  if (value == 'delete') _deleteProduct(product);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Edit'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                    ),
                  ),
                ],
              ),
              onTap: () => _openProductForm(product),
            ),
          );
        },
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesTab() {
    final summary = DatabaseService.summarizeSales(_orders);

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _metricCard(
                'Revenue',
                _money(summary['revenue']),
                Icons.payments_outlined,
                Colors.green,
              ),
              const SizedBox(width: 10),
              _metricCard(
                'Orders',
                '${summary['orders']}',
                Icons.receipt_long_outlined,
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _metricCard(
                'Items Sold',
                '${summary['itemsSold']}',
                Icons.shopping_bag_outlined,
                Colors.orange,
              ),
              const SizedBox(width: 10),
              _metricCard(
                'Products',
                '${_products.length}',
                Icons.inventory_2_outlined,
                Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Recent Sales',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          if (_orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No sales yet')),
            )
          else
            ..._orders.map((order) {
              final buyer = order['account'];
              final buyerName = buyer is Map
                  ? '${buyer['firstname'] ?? 'Buyer'} ${buyer['surname'] ?? ''}'
                      .trim()
                  : 'Buyer';
              final items = order['order_items'];
              final itemCount = items is List ? items.length : 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.receipt_long_outlined),
                  ),
                  title: Text(_money(order['total_amount'])),
                  subtitle: Text(
                    '$buyerName | $itemCount item${itemCount == 1 ? '' : 's'} | ${order['order_status'] ?? 'Processing'}',
                  ),
                  trailing: Text(
                    order['payment_status']?.toString() ?? 'Pending',
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storeName = _store?['store_name']?.toString() ?? 'Seller Dashboard';

    return Scaffold(
      appBar: AppBar(
        title: Text(storeName),
        backgroundColor: const Color(0xFF2d8f4e),
        actions: [
          IconButton(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentIndex == 0
              ? _buildProductsTab()
              : _buildSalesTab(),
      floatingActionButton: _currentIndex == 0 && _store != null
          ? FloatingActionButton.extended(
              onPressed: () => _openProductForm(),
              backgroundColor: const Color(0xFF2d8f4e),
              icon: const Icon(Icons.add),
              label: const Text('Product'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Sales',
          ),
        ],
      ),
    );
  }
}
