import 'package:flutter/foundation.dart';

class CartModel {
  static List<Map<String, dynamic>> cartItems = [];
  static final ValueNotifier<int> itemCountNotifier = ValueNotifier<int>(0);
  
  static int get length => totalQuantity;

  static int get totalQuantity {
    return cartItems.fold(
      0,
      (sum, item) =>
          sum + (int.tryParse(item['quantity']?.toString() ?? '') ?? 0),
    );
  }

  static void _notifyChanged() {
    itemCountNotifier.value = totalQuantity;
  }
  
  static void addItem(Map<String, dynamic> item) {
    final productId = item['product_id']?.toString() ?? item['name'].toString();
    final variantId = item['selected_variant_id']?.toString() ?? 'base';
    final uniqueId = '$productId::$variantId';
    
    final index = cartItems.indexWhere((cartItem) => cartItem['uniqueId'] == uniqueId);
    if (index != -1) {
      cartItems[index]['quantity'] = (cartItems[index]['quantity'] ?? 0) + 1;
    } else {
      cartItems.add({
        ...item,
        'quantity': 1,
        'uniqueId': uniqueId,
      });
    }
    _notifyChanged();
  }

  static double itemPrice(Map<String, dynamic> item) {
    final value = item['price'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
  
  static void removeItem(String identifier) {
    cartItems.removeWhere((item) => item['uniqueId'] == identifier);
    _notifyChanged();
  }
  
  static void updateQuantity(String identifier, int quantity) {
    final index = cartItems.indexWhere((item) => item['uniqueId'] == identifier);
    if (index != -1 && quantity > 0) {
      cartItems[index]['quantity'] = quantity;
      _notifyChanged();
    } else if (quantity <= 0) {
      removeItem(identifier);
    }
  }
  
  static double get totalPrice {
    return cartItems.fold(
      0.0,
      (sum, item) => sum + (itemPrice(item) * (item['quantity'] ?? 1)),
    );
  }
  
  static void clear() {
    cartItems.clear();
    _notifyChanged();
  }
}
