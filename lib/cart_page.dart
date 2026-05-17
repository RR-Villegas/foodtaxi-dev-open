import 'package:flutter/material.dart';
import 'cart_model.dart';
import 'services/database_service.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  static const String _fallbackImage = 'assets/images/food1.jpg';

  Widget _buildProductImage(dynamic imageValue, {double size = 80}) {
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

  @override
  Widget build(BuildContext context) {
    // Check if the cart is empty
    if (CartModel.cartItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Cart'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Your cart is empty',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Add items from dashboard to get started!'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('My Cart (${CartModel.cartItems.length} items)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              CartModel.clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: CartModel.cartItems.length,
              itemBuilder: (context, index) {
                final item = CartModel.cartItems[index];
                
                // Safe calculation for total per item
                final double price = CartModel.itemPrice(item);
                final int quantity = item['quantity'] ?? 1;
                final double itemTotal = price * quantity;
                
                final productId = item['product_id']?.toString();

                return GestureDetector(
                  onTap: productId != null
                      ? () => Navigator.pushNamed(context, '/product/$productId')
                      : null,
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Product Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildProductImage(item['main_image_url']),
                          ),
                          const SizedBox(width: 16),
                          // Item Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] ?? 'Unknown Product',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                if ((item['selected_size']?.toString() ?? '').isNotEmpty)
                                  Text('Size: ${item['selected_size']}'),
                                Text('₱${price.toStringAsFixed(2)}'),
                                Text(
                                  'Total: ₱${itemTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          // Quantity controls
                          Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                    onPressed: () {
                                      CartModel.updateQuantity(item['uniqueId'], quantity - 1);
                                      setState(() {});
                                    },
                                  ),
                                  Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                    onPressed: () {
                                      CartModel.updateQuantity(item['uniqueId'], quantity + 1);
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                onPressed: () {
                                  CartModel.removeItem(item['uniqueId']);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Total & Checkout Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green[50],
              border: Border(top: BorderSide(color: Colors.green[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  // FIXED LINE 141: Ensuring totalPrice is treated as a double
                  '₱${(CartModel.totalPrice).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22, 
                    fontWeight: FontWeight.bold, 
                    color: Color(0xFF2d8f4e),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2d8f4e),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/checkout');
                },
                child: const Text(
                  'Proceed to Checkout',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
