import 'package:flutter/material.dart';
import 'cart_model.dart';
import 'services/database_service.dart';
import 'services/location_service.dart';
import 'models/address_model.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _couponController = TextEditingController();
  List<Address> _addresses = [];
  Address? _selectedAddress;
  String? _accountId;
  Map<String, dynamic>? _appliedCoupon;
  String _selectedPaymentMethod = 'COD';
  bool _isLoading = false;
  bool _isLoadingAddresses = true;
  bool _isCalculatingDelivery = false;
  bool _isBulkDelivery = false;
  double _deliveryFee = 50.0;
  double? _deliveryDistanceKm;
  static const String _fallbackImage = 'assets/images/food1.jpg';
  
  static const double _serviceFeeRate = 0.05;
  
  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final accountId = await DatabaseService.getCurrentAccountId();
      if (accountId == null) {
        throw Exception('Account profile not found');
      }

      final addresses = await DatabaseService.getUserAddresses(accountId);
      setState(() {
        _accountId = accountId;
        _addresses = addresses;
        _isLoadingAddresses = false;
        // Auto-select default address
        if (addresses.isNotEmpty) {
          final defaultAddr = addresses.where((a) => a.isDefault).firstOrNull;
          _selectedAddress = defaultAddr ?? addresses.first;
        }
      });
      _refreshDeliveryFee();
    } catch (e) {
      setState(() {
        _isLoadingAddresses = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading addresses: $e')),
        );
      }
    }
  }

  double get _subtotal => CartModel.totalPrice;
  double get _discountAmount {
    final value = _appliedCoupon?['discount_amount'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
  double get _commissionBase =>
      (_subtotal - _discountAmount) < 0 ? 0 : _subtotal - _discountAmount;
  double get _serviceFee => _commissionBase * _serviceFeeRate;
  double get _total => _subtotal + _deliveryFee + _serviceFee - _discountAmount;
  int get _bulkShareCount => _deliveryDistanceKm == null
      ? LocationService.bulkDeliveryMinOrders
      : LocationService.bulkDeliveryShareCount(_deliveryDistanceKm!);

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      setState(() => _appliedCoupon = null);
      return;
    }

    String? storeId;
    final firstProductId = CartModel.cartItems
        .map((item) => item['product_id']?.toString() ?? '')
        .firstWhere((id) => id.isNotEmpty, orElse: () => '');
    if (firstProductId.isNotEmpty) {
      final store = await DatabaseService.getStoreForProduct(firstProductId);
      storeId = store?['store_id']?.toString();
    }

    final coupon = await DatabaseService.validateCoupon(
      code: code,
      subtotal: _subtotal,
      storeId: storeId,
    );

    if (!mounted) return;
    setState(() => _appliedCoupon = coupon);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(coupon == null ? 'Coupon is invalid or expired' : 'Coupon applied'),
        backgroundColor: coupon == null ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _refreshDeliveryFee() async {
    final address = _selectedAddress;
    if (address == null || CartModel.cartItems.isEmpty) return;

    setState(() => _isCalculatingDelivery = true);
    try {
      final firstProductId = CartModel.cartItems
          .map((item) => item['product_id']?.toString() ?? '')
          .firstWhere((id) => id.isNotEmpty, orElse: () => '');
      if (firstProductId.isEmpty) return;

      final store = await DatabaseService.getStoreForProduct(firstProductId);
      if (store == null) return;

      final storeLat = double.tryParse(store['latitude']?.toString() ?? '');
      final storeLon = double.tryParse(store['longitude']?.toString() ?? '');
      final storePoint = storeLat != null && storeLon != null
          ? GeoPoint(latitude: storeLat, longitude: storeLon)
          : await LocationService.geocodeAddress(
              houseNumber: store['house_number']?.toString(),
              street: store['street']?.toString(),
              barangay: store['barangay']?.toString(),
              city: store['city']?.toString(),
              province: store['province']?.toString(),
              zipCode: store['zip_code']?.toString(),
            );
      final buyerPoint = address.latitude != null && address.longitude != null
          ? GeoPoint(latitude: address.latitude!, longitude: address.longitude!)
          : await LocationService.geocodeAddress(
              houseNumber: address.houseNumber,
              street: address.street,
              barangay: address.barangay,
              city: address.city,
              province: address.province,
              zipCode: address.zipCode,
            );

      if (storePoint == null || buyerPoint == null) return;

      final roadDistance =
          await LocationService.roadDistanceKm(storePoint, buyerPoint);
      final distance = roadDistance ??
          LocationService.straightLineDistanceKm(storePoint, buyerPoint);

      if (!mounted) return;
      setState(() {
        _deliveryDistanceKm = distance;
        _deliveryFee = _isBulkDelivery
            ? LocationService.bulkDeliveryFeeForDistance(distance)
            : LocationService.deliveryFeeForDistance(distance);
      });
    } finally {
      if (mounted) setState(() => _isCalculatingDelivery = false);
    }
  }

  void _setBulkDelivery(bool value) {
    setState(() {
      _isBulkDelivery = value;
      final distance = _deliveryDistanceKm;
      if (distance != null) {
        _deliveryFee = value
            ? LocationService.bulkDeliveryFeeForDistance(distance)
            : LocationService.deliveryFeeForDistance(distance);
      }
    });
  }

  Widget _buildProductImage(dynamic imageValue, {double size = 50}) {
    final path = imageValue?.toString().trim();
    if (path == null || path.isEmpty) {
      return Image.asset(_fallbackImage, width: size, height: size, fit: BoxFit.cover);
    }

    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Image.asset(_fallbackImage, width: size, height: size, fit: BoxFit.cover),
      );
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Image.asset(_fallbackImage, width: size, height: size, fit: BoxFit.cover),
      );
    }

    return Image.network(
      DatabaseService.getProductImageUrl(path),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Image.asset(_fallbackImage, width: size, height: size, fit: BoxFit.cover),
    );
  }

  String _getPaymentMethodLabel() {
    switch (_selectedPaymentMethod) {
      case 'COD':
        return 'Cash on Delivery';
      case 'Gcash':
        return 'GCash';
      default:
        return 'Unknown';
    }
  }

  Future<void> _placeOrder() async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a delivery address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to place this order?'),
            const SizedBox(height: 16),
            Text('Delivery Address:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_formatAddress(_selectedAddress!)),
            const SizedBox(height: 12),
            Text('Payment Method:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_getPaymentMethodLabel()),
            const SizedBox(height: 12),
            Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('₱${_total.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontSize: 18)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      for (final item in CartModel.cartItems) {
        final stockError = await DatabaseService.checkoutStockError(item);
        if (stockError != null) throw Exception(stockError);
      }

      String? sellerAccountId;
      for (final item in CartModel.cartItems) {
        final productId = item['product_id']?.toString();
        if (productId == null || productId.isEmpty) continue;
        sellerAccountId =
            await DatabaseService.getSellerAccountIdForProduct(productId);
        if (sellerAccountId != null) break;
      }

      final orderItems = <Map<String, dynamic>>[];

      for (final item in CartModel.cartItems) {
        final productId = item['product_id']?.toString();

        if (productId == null || productId.isEmpty) {
          throw Exception('Cart item is missing product ID');
        }

        final variantId = item['selected_variant_id']?.toString();
        final quantity = item['quantity'] ?? 1;

        final freshProduct = await DatabaseService.getProductForCheckout(productId);

        if (freshProduct == null) {
          throw Exception('A product in your cart is no longer available');
        }

        final discount = DatabaseService.activeProductDiscount(freshProduct);

        double basePrice = double.tryParse(
              freshProduct['price']?.toString() ?? '',
            ) ??
            0;

        if (variantId != null && variantId.isNotEmpty) {
          final variants = freshProduct['product_variant'];

          if (variants is List) {
            final selectedVariant = variants.whereType<Map>().firstWhere(
                  (variant) => variant['variant_id']?.toString() == variantId,
                  orElse: () => {},
                );

            if (selectedVariant.isNotEmpty) {
              basePrice = double.tryParse(
                    selectedVariant['price']?.toString() ?? '',
                  ) ??
                  basePrice;
            }
          }
        }

        final price = DatabaseService.discountedPrice(basePrice, discount);

        orderItems.add({
          'product_id': productId,
          'product_variant_id':
              variantId == null || variantId.isEmpty ? null : variantId,
          'quantity': quantity,
          'unit_price_at_sale': price,
        });
      }

      final freshSubtotal = orderItems.fold<double>(
      0,
      (sum, item) {
        final price = double.tryParse(item['unit_price_at_sale'].toString()) ?? 0;
        final quantity = int.tryParse(item['quantity'].toString()) ?? 1;
        return sum + (price * quantity);
      },
    );

    final freshCommissionBase =
        (freshSubtotal - _discountAmount) < 0 ? 0 : freshSubtotal - _discountAmount;

    final freshServiceFee = freshCommissionBase * _serviceFeeRate;

    final freshTotal =
        freshSubtotal + _deliveryFee + freshServiceFee - _discountAmount;

      final orderId = await DatabaseService.placeOrderWithItems(
        accountId: _accountId!,
        addressId: _selectedAddress!.addressId!,
        totalAmount: freshTotal,
        shippingFee: _deliveryFee,
        deliveryDistanceKm: _deliveryDistanceKm,
        serviceFee: freshServiceFee,
        discountAmount: _discountAmount,
        deliveryMode: _isBulkDelivery ? 'bulk' : 'standard',
        bulkDeliveryMinOrders:
            _isBulkDelivery ? LocationService.bulkDeliveryMinOrders : 1,
        bulkDeliveryMaxOrders: _isBulkDelivery ? _bulkShareCount : 1,
        discountCode: _appliedCoupon?['code']?.toString(),
        paymentMethod: _selectedPaymentMethod,
        sellerAccountId: sellerAccountId,
        items: orderItems,
      );

      if (orderId.isEmpty) {
        throw Exception('Failed to create order');
      }

      final couponCode = _appliedCoupon?['code']?.toString();
      if (couponCode != null && couponCode.isNotEmpty) {
        await DatabaseService.incrementCouponUsage(couponCode);
      }

      // Clear cart after successful order
      CartModel.clear();

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 8),
                Text('Order Placed!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Your order has been successfully placed.'),
                const SizedBox(height: 12),
                Text('Order ID: $orderId', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('You will receive a confirmation shortly.'),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pushNamedAndRemoveUntil('/buyer-dashboard', (route) => false); // Go to buyer dashboard
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error placing order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatAddress(Address address) {
    List<String> parts = [];
    if (address.houseNumber != null && address.houseNumber!.isNotEmpty) {
      parts.add(address.houseNumber!);
    }
    if (address.street != null && address.street!.isNotEmpty) {
      parts.add(address.street!);
    }
    parts.add(address.barangay);
    parts.add(address.city);
    parts.add(address.province);
    return parts.join(', ');
  }

  void _showAddAddressDialog() {
    Navigator.pushNamed(context, '/addresses').then((_) => _loadAddresses());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Summary Section
                  _buildSectionTitle('Order Summary'),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          ...CartModel.cartItems.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _buildProductImage(item['main_image_url']),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] ?? 'Unknown',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      if ((item['selected_size']?.toString() ?? '').isNotEmpty)
                                        Text('Size: ${item['selected_size']}'),
                                      Text(
                                        'Qty: ${item['quantity'] ?? 1} × ₱${item['price']}',
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₱${(CartModel.itemPrice(item) * (item['quantity'] ?? 1)).toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal'),
                              Text('₱${_subtotal.toStringAsFixed(2)}'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _deliveryDistanceKm == null
                                    ? 'Delivery Fee'
                                    : 'Delivery Fee (${_deliveryDistanceKm!.toStringAsFixed(1)} km)',
                              ),
                              Text(
                                _isCalculatingDelivery
                                    ? 'Calculating...'
                                    : '₱${_deliveryFee.toStringAsFixed(2)}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _isBulkDelivery,
                            onChanged: _setBulkDelivery,
                            title: const Text('Bulk delivery'),
                            subtitle: Text(
                              'Pool pickup with ${LocationService.bulkDeliveryMinOrders}-$_bulkShareCount orders for a lower rider fee.',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Service Fee'),
                              Text('₱${_serviceFee.toStringAsFixed(2)}'),
                            ],
                          ),
                          if (_discountAmount > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Discount (${_appliedCoupon?['code']})'),
                                Text(
                                  '-PHP ${_discountAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.green),
                                ),
                              ],
                            ),
                          ],
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              Text(
                                '₱${_total.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildSectionTitle('Discount Coupon'),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _couponController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Coupon code',
                                prefixIcon: Icon(Icons.local_offer_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _applyCoupon,
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Delivery Address Section
                  _buildSectionTitle('Delivery Address'),
                  const SizedBox(height: 8),
                  if (_isLoadingAddresses)
                    const Center(child: CircularProgressIndicator())
                  else if (_addresses.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Icon(Icons.location_off, size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            const Text('No addresses saved'),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _showAddAddressDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Address'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    RadioGroup<Address>(
                      groupValue: _selectedAddress,
                      onChanged: (value) {
                        if (value != null) {
                            setState(() => _selectedAddress = value);
                            _refreshDeliveryFee();
                        }
                      },
                      child: Column(
                        children: [
                          ..._addresses.map((address) => RadioListTile<Address>(
                            value: address,
                            title: Text(
                              _formatAddress(address),
                              style: TextStyle(
                                fontWeight: address.isDefault
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: address.isDefault
                                ? Text(
                                    'Default',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  )
                                : null,
                            secondary: const Icon(Icons.location_on),
                            selected: _selectedAddress == address,
                          )),
                          TextButton.icon(
                            onPressed: _showAddAddressDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add New Address'),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Payment Method Section
                  // Payment Method Section
                  _buildSectionTitle('Payment Method'),
                  const SizedBox(height: 8),
                  Card(
                    child: RadioGroup<String>(
                      groupValue: _selectedPaymentMethod,
                      onChanged: (value) {
                        if (value != null && value != 'Gcash') {
                          setState(() => _selectedPaymentMethod = value);
                        }
                      },
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            value: 'COD',
                            title: Row(
                              children: [
                                Icon(
                                  Icons.money,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text('Cash on Delivery'),
                              ],
                            ),
                          ),
                          Tooltip(
                            message: 'Service unavailable',
                            waitDuration: const Duration(milliseconds: 300),
                            child: Opacity(
                              opacity: 0.45,
                              child: RadioListTile<String>(
                                value: 'Gcash',
                                enabled: false,
                                title: Row(
                                  children: [
                                    const Icon(Icons.phone_android, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'GCash',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'Service unavailable',
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: const Text(
                                  'GCash payments are temporarily unavailable.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Place Order Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _placeOrder,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        'Place Order - ₱${_total.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
