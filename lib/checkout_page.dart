import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cart_model.dart';
import 'services/database_service.dart';
import 'models/address_model.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _supabase = Supabase.instance.client;

  List<Address> _addresses = [];
  Address? _selectedAddress;

  String _paymentMethod = 'cash_on_delivery';

  bool _isLoadingAddresses = true;
  bool _isPlacingOrder = false;

  static const double _deliveryFee = 50.0;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  // 📍 LOAD ADDRESSES
  Future<void> _loadAddresses() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final addresses =
          await DatabaseService.getUserAddresses(userId);

      setState(() {
        _addresses = addresses;
        _isLoadingAddresses = false;

        if (addresses.isNotEmpty) {
          _selectedAddress = addresses.firstWhere(
            (a) => a.isDefault,
            orElse: () => addresses.first,
          );
        }
      });
    } catch (e) {
      setState(() => _isLoadingAddresses = false);
    }
  }

  // 💰 TOTALS
  double get _subtotal => CartModel.totalPrice;
  double get _total => _subtotal + _deliveryFee;

  String _formatAddress(Address a) {
    return [
      if (a.houseNumber != null) a.houseNumber,
      if (a.street != null) a.street,
      a.barangay,
      a.city,
      a.province,
    ].whereType<String>().join(', ');
  }

  // 🚀 PLACE ORDER
  Future<void> _placeOrder() async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an address")),
      );
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("No user found");

      final orderId = await _supabase.from('orders').insert({
        'account_id': userId,
        'address_id': _selectedAddress!.addressId,
        'payment_method': _paymentMethod,
        'subtotal': _subtotal,
        'delivery_fee': _deliveryFee,
        'total': _total,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      // insert order items
      for (var item in CartModel.cartItems) {
        await _supabase.from('order_items').insert({
          'order_id': orderId['id'],
          'product_name': item['name'],
          'price': item['price'],
          'quantity': item['quantity'],
          'image': item['main_image_url'],
        });
      }

      CartModel.cartItems.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order placed successfully!")),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => _isPlacingOrder = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Checkout"),
        backgroundColor: const Color(0xFF2d8f4e),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// 🧾 ORDER SUMMARY
            const Text(
              "Order Summary",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ...CartModel.cartItems.map((item) {
                      final total =
                          (item['price'] ?? 0) * (item['quantity'] ?? 1);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item['main_image_url'] ?? '',
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.fastfood),
                              ),
                            ),
                            const SizedBox(width: 10),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['name'] ?? ''),
                                  Text("Qty: ${item['quantity']}"),
                                ],
                              ),
                            ),

                            Text("₱${total.toStringAsFixed(2)}"),
                          ],
                        ),
                      );
                    }),

                    const Divider(),

                    _row("Subtotal", _subtotal),
                    _row("Delivery Fee", _deliveryFee),

                    const Divider(),

                    _row("Total", _total, bold: true, color: Colors.green),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            /// 📍 ADDRESS
            const Text(
              "Delivery Address",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (_isLoadingAddresses)
              const Center(child: CircularProgressIndicator())
            else if (_addresses.isEmpty)
              const Text("No address found")
            else
              Column(
                children: _addresses.map((address) {
                  final selected = _selectedAddress == address;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedAddress = address);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF2d8f4e)
                              : Colors.grey.shade300,
                          width: selected ? 2 : 1,
                        ),
                        color: selected
                            ? const Color(0xFF2d8f4e).withOpacity(0.05)
                            : Colors.white,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: const Color(0xFF2d8f4e),
                          ),
                          const SizedBox(width: 10),

                          Expanded(
                            child: Text(_formatAddress(address)),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 20),

            /// 💳 PAYMENT
            const Text(
              "Payment Method",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            RadioListTile(
              value: 'cash_on_delivery',
              groupValue: _paymentMethod,
              onChanged: (v) =>
                  setState(() => _paymentMethod = v.toString()),
              title: const Text("Cash on Delivery"),
            ),

            RadioListTile(
              value: 'gcash',
              groupValue: _paymentMethod,
              onChanged: (v) =>
                  setState(() => _paymentMethod = v.toString()),
              title: const Text("GCash"),
            ),

            const SizedBox(height: 20),

            /// 🚀 PLACE ORDER BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isPlacingOrder ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2d8f4e),
                ),
                child: _isPlacingOrder
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("Place Order - ₱${_total.toStringAsFixed(2)}"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double value,
      {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          "₱${value.toStringAsFixed(2)}",
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}