import 'package:flutter/material.dart';
import 'cart_model.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {

  /// 🔥 Smart Image Loader (FIXES YOUR ERROR)
  Widget buildImage(dynamic imageValue) {
    String fallback = 'assets/images/food1.jpg';

    if (imageValue == null || imageValue.toString().isEmpty) {
      return Image.asset(fallback, width: 80, height: 80, fit: BoxFit.cover);
    }

    String path = imageValue.toString();

    // ✅ If full URL (Supabase / internet)
    if (path.startsWith('http')) {
      return Image.network(
        path,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          return Image.asset(fallback, width: 80, height: 80, fit: BoxFit.cover);
        },
      );
    }

    // ✅ If already correct asset path
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          return Image.asset(fallback, width: 80, height: 80, fit: BoxFit.cover);
        },
      );
    }

    // ✅ If only filename (MOST COMMON FIX)
    return Image.asset(
      'assets/images/$path',
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        return Image.asset(fallback, width: 80, height: 80, fit: BoxFit.cover);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (CartModel.cartItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Cart'),
          backgroundColor: const Color(0xFF2d8f4e),
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
        title: Text('My Cart (${CartModel.length} items)'),
        backgroundColor: const Color(0xFF2d8f4e),
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
                final total =
                    (item['price'] ?? 0) * (item['quantity'] ?? 1);

                return Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        /// ✅ FIXED IMAGE HERE
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: buildImage(item['main_image_url']),
                        ),

                        const SizedBox(width: 16),

                        /// DETAILS
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text('₱${item['price']}'),
                              Text(
                                'Total: ₱${total.toStringAsFixed(2)}',
                              ),
                            ],
                          ),
                        ),

                        /// QUANTITY CONTROLS
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, color: Colors.red),
                              onPressed: () {
                                CartModel.updateQuantity(
                                  item['uniqueId'],
                                  (item['quantity'] ?? 1) - 1,
                                );
                                setState(() {});
                              },
                            ),
                            Text('${item['quantity'] ?? 1}'),
                            IconButton(
                              icon: const Icon(Icons.add, color: Colors.green),
                              onPressed: () {
                                CartModel.updateQuantity(
                                  item['uniqueId'],
                                  (item['quantity'] ?? 1) + 1,
                                );
                                setState(() {});
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
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
                );
              },
            ),
          ),

          /// TOTAL SECTION
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green[50],
              border: Border(
                top: BorderSide(color: Colors.green[200]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '₱${CartModel.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),

          /// CHECKOUT BUTTON
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2d8f4e),
                  foregroundColor: Colors.white,
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