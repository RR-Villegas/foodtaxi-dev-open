import 'package:flutter/material.dart';
import 'cart_model.dart';
import 'services/database_service.dart';
import 'models/address_model.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  List<Address> _addresses = [];
  Address? _selectedAddress;
  String? _accountId;
  String _selectedPaymentMethod = 'COD';
  bool _isLoading = false;
  bool _isLoadingAddresses = true;
  static const String _fallbackImage = 'assets/images/food1.jpg';
  
  // Delivery fee in PHP
  static const double _deliveryFee = 50.0;
  
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
  double get _total => _subtotal + _deliveryFee;

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
      String? sellerAccountId;
      for (final item in CartModel.cartItems) {
        final productId = item['product_id']?.toString();
        if (productId == null || productId.isEmpty) continue;
        sellerAccountId =
            await DatabaseService.getSellerAccountIdForProduct(productId);
        if (sellerAccountId != null) break;
      }

      // Create order in database
      final orderId = await DatabaseService.insertOrder(
        accountId: _accountId!,
        addressId: _selectedAddress!.addressId!,
        totalAmount: _total,
        shippingFee: _deliveryFee,
        paymentMethod: _selectedPaymentMethod,
        sellerAccountId: sellerAccountId,
      );

      if (orderId.isEmpty) {
        throw Exception('Failed to create order');
      }

      // Add order items
      for (var item in CartModel.cartItems) {
        final productId = item['product_id']?.toString();
        if (productId == null || productId.isEmpty) {
          throw Exception('Cart item is missing product ID');
        }

        final quantity = item['quantity'] ?? 1;
        final price = (item['price'] as num).toDouble();

        await DatabaseService.insertOrderItem(
          orderId: orderId,
          productId: productId,
          unitPriceAtSale: price,
          quantity: quantity,
        );
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
    final provinceController = TextEditingController();
    final cityController = TextEditingController();
    final barangayController = TextEditingController();
    final streetController = TextEditingController();
    final houseNumberController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Address'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: houseNumberController,
                decoration: const InputDecoration(labelText: 'House Number', hintText: 'e.g., 123'),
              ),
              TextField(
                controller: streetController,
                decoration: const InputDecoration(labelText: 'Street', hintText: 'e.g., Main Street'),
              ),
              TextField(
                controller: barangayController,
                decoration: const InputDecoration(labelText: 'Barangay *', hintText: 'e.g., Poblacion'),
              ),
              TextField(
                controller: cityController,
                decoration: const InputDecoration(labelText: 'City/Municipality *', hintText: 'e.g., Manila'),
              ),
              TextField(
                controller: provinceController,
                decoration: const InputDecoration(labelText: 'Province *', hintText: 'e.g., Metro Manila'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (barangayController.text.isEmpty || cityController.text.isEmpty || provinceController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in required fields')),
                );
                return;
              }

              try {
                await DatabaseService.insertAddress(
                  accountId: _accountId!,
                  province: provinceController.text.isNotEmpty ? provinceController.text : null,
                  city: cityController.text.isNotEmpty ? cityController.text : null,
                  barangay: barangayController.text.isNotEmpty ? barangayController.text : null,
                  street: streetController.text.isNotEmpty ? streetController.text : null,
                  houseNumber: houseNumberController.text.isNotEmpty ? houseNumberController.text : null,
                  zipCode: null,
                  isDefault: _addresses.isEmpty,
                );
                Navigator.pop(context);
                _loadAddresses(); // Refresh addresses
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error adding address: $e')),
                );
              }
            },
            child: const Text('Add Address'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: const Color(0xFF2d8f4e),
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
                                      Text(
                                        'Qty: ${item['quantity'] ?? 1} × ₱${item['price']}',
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₱${(item['price'] * (item['quantity'] ?? 1)).toStringAsFixed(2)}',
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
                              const Text('Delivery Fee'),
                              Text('₱${_deliveryFee.toStringAsFixed(2)}'),
                            ],
                          ),
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
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        ..._addresses.map((address) => RadioListTile<Address>(
                          value: address,
                          groupValue: _selectedAddress,
                          onChanged: (value) => setState(() => _selectedAddress = value),
                          title: Text(
                            _formatAddress(address),
                            style: TextStyle(
                              fontWeight: address.isDefault ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: address.isDefault 
                              ? const Text('Default', style: TextStyle(color: Colors.green))
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

                  const SizedBox(height: 24),

                  // Payment Method Section
                  _buildSectionTitle('Payment Method'),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          value: 'COD',
                          groupValue: _selectedPaymentMethod,
                          onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                          title: const Row(
                            children: [
                              Icon(Icons.money, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Cash on Delivery'),
                            ],
                          ),
                        ),
                        RadioListTile<String>(
                          value: 'Gcash',
                          groupValue: _selectedPaymentMethod,
                          onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                          title: const Row(
                            children: [
                              Icon(Icons.phone_android, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('GCash'),
                            ],
                          ),
                        ),
                      ],
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
                        backgroundColor: const Color(0xFF2d8f4e),
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
