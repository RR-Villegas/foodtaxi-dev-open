import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/address_model.dart';

class DatabaseService {
  static final _supabase = Supabase.instance.client;

  // Insert address for a user
  static Future<Address?> insertAddress({
    required String accountId,
    required String province,
    required String city,
    required String barangay,
    String? street,
    String? houseNumber,
    bool isDefault = false,
  }) async {
    try {
      final response = await _supabase
          .from('address')
          .insert({
            'account_id': accountId,
            'province': province,
            'city': city,
            'barangay': barangay,
            'street': street,
            'house_number': houseNumber ?? '',
            'is_default': isDefault,
          })
          .select()
          .single();

      return Address.fromJson(response);
    } catch (e) {
      print('DB Error: Failed to insert address: $e');
      return null;
    }
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  // Insert user profile after signup
  static Future<String?> insertUserProfile({
    required String authId,
    required String firstName,
    required String surname,
    required String email,
    String? phoneNumber,
    required String accountType,
  }) async {
    try {
      final response = await _supabase
          .from('account')
          .insert({
            'auth_id': authId,
            'firstname': firstName,
            'surname': surname,
            'email': email,
            'phone_number': _blankToNull(phoneNumber),
            'account_type': accountType,
          })
          .select('account_id')
          .single();

      return response['account_id'] as String?;
    } catch (e) {
      print('DB Error: Failed to insert user profile: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentAccount() async {
    try {
      final authId = _supabase.auth.currentUser?.id;
      if (authId == null) return null;

      final response = await _supabase
          .from('account')
          .select()
          .eq('auth_id', authId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('DB Error: Failed to fetch current account: $e');
      return null;
    }
  }

  static Future<String?> getCurrentAccountId() async {
    try {
      final account = await getCurrentAccount();
      return account?['account_id'] as String?;
    } catch (e) {
      print('DB Error: Failed to fetch current account ID: $e');
      return null;
    }
  }

  // Get addresses for a user
  static Future<List<Address>> getUserAddresses(String accountId) async {
    try {
      final response = await _supabase
          .from('address')
          .select()
          .eq('account_id', accountId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((address) => Address.fromJson(address))
          .toList();
    } catch (e) {
      print('DB Error: Failed to fetch addresses: $e');
      return [];
    }
  }

  // Update address
  static Future<Address?> updateAddress({
    required String addressId,
    String? province,
    String? city,
    String? barangay,
    String? street,
    String? houseNumber,
    bool? isDefault,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (province != null) updateData['province'] = province;
      if (city != null) updateData['city'] = city;
      if (barangay != null) updateData['barangay'] = barangay;
      if (street != null) updateData['street'] = street;
      if (houseNumber != null) updateData['house_number'] = houseNumber;
      if (isDefault != null) updateData['is_default'] = isDefault;

      final response = await _supabase
          .from('address')
          .update(updateData)
          .eq('address_id', addressId)
          .select()
          .single();

      return Address.fromJson(response);
    } catch (e) {
      print('DB Error: Failed to update address: $e');
      return null;
    }
  }

  // Delete address
  static Future<void> deleteAddress(String addressId) async {
    try {
      await _supabase
          .from('address')
          .delete()
          .eq('address_id', addressId);
    } catch (e) {
      print('DB Error: Failed to delete address: $e');
    }
  }

// Set address as default
  static Future<void> setDefaultAddress(String accountId, String addressId) async {
    try {
      // Set all addresses to not default
      await _supabase
          .from('address')
          .update({'is_default': false})
          .eq('account_id', accountId);

      // Set the selected address as default
      await _supabase
          .from('address')
          .update({'is_default': true})
          .eq('address_id', addressId);
    } catch (e) {
      print('DB Error: Failed to set default address: $e');
    }
  }

  // Update user role
  static Future<bool> updateUserRole(String accountId, String newRole) async {
    try {
      await _supabase
          .from('account')
          .update({'account_type': newRole})
          .eq('account_id', accountId);
      return true;
    } catch (e) {
      print('DB Error: Failed to update role: $e');
      return false;
    }
  }

  // Insert order
  static Future<String> insertOrder({
    required String accountId,
    required String addressId,
    required double totalAmount,
    required double shippingFee,
    required String paymentMethod,
    String orderStatus = 'Processing',
  }) async {
    try {
      final response = await _supabase
          .from('orders')
          .insert({
            'buyer_account_id': accountId,
            'address_id': addressId,
            'total_amount': totalAmount,
            'shipping_fee': shippingFee,
            'payment_method': paymentMethod,
            'order_status': orderStatus,
          })
          .select('order_id')
          .single();

      return response['order_id'] as String;
    } catch (e) {
      print('DB Error: Failed to insert order: $e');
      return '';
    }
  }

  // Insert order item
  static Future<void> insertOrderItem({
    required String orderId,
    required String productId,
    required double unitPriceAtSale,
    required int quantity,
  }) async {
    try {
      await _supabase
          .from('order_items')
          .insert({
            'order_id': orderId,
            'product_id': productId,
            'quantity': quantity,
            'unit_price_at_sale': unitPriceAtSale,
            'subtotal': unitPriceAtSale * quantity,
          });
    } catch (e) {
      print('DB Error: Failed to insert order item: $e');
    }
  }

  // Fetch all products
  static Future<List<Map<String, dynamic>>> fetchProducts() async {
    try {
      final response = await _supabase
          .from('product')
          .select()
          .eq('is_active', true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('DB Error: Failed to fetch products: $e');
      return [];
    }
  }

  // Get product image URL from bucket
  static String getProductImageUrl(String fileName) {
    return _supabase.storage
        .from('product-images/main-picture')
        .getPublicUrl(fileName);
  }

  // Insert cart item
  static Future<void> insertCartItem({
    required String accountId,
    required String productId,
    required int quantity,
    required double priceAtTime,
  }) async {
    try {
      await _supabase.from('cart').insert({
        'account_id': accountId,
        'product_id': productId,
        'quantity': quantity,
        'price_at_time': priceAtTime,
      });
    } catch (e) {
      print('DB Error: Failed to insert cart item: $e');
    }
  }

  // Get cart items for user
  static Future<List<Map<String, dynamic>>> getCartItems(
      String accountId) async {
    try {
      final response = await _supabase
          .from('cart')
          .select()
          .eq('account_id', accountId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('DB Error: Failed to fetch cart items: $e');
      return [];
    }
  }

  // Update cart item quantity
  static Future<void> updateCartItem({
    required String cartId,
    required int quantity,
  }) async {
    try {
      await _supabase
          .from('cart')
          .update({'quantity': quantity}).eq('id', cartId);
    } catch (e) {
      print('DB Error: Failed to update cart item: $e');
    }
  }

  // Delete cart item
  static Future<void> deleteCartItem(String cartId) async {
    try {
      await _supabase.from('cart').delete().eq('id', cartId);
    } catch (e) {
      print('DB Error: Failed to delete cart item: $e');
    }
  }

  // Clear all cart items for user
  static Future<void> clearCart(String accountId) async {
    try {
      await _supabase.from('cart').delete().eq('account_id', accountId);
    } catch (e) {
      print('DB Error: Failed to clear cart: $e');
    }
  }

  // Insert seller application
  static Future<bool> insertSellerApplication({
    required String accountId,
    required String storeName,
    String? storeDescription,
    required String province,
    required String city,
    required String barangay,
    String? street,
    String? houseNumber,
    required String contactPhone,
  }) async {
    try {
      final businessAddress = [
        _blankToNull(houseNumber),
        _blankToNull(street),
        barangay.trim(),
        city.trim(),
        province.trim(),
      ].whereType<String>().join(', ');

      await _supabase.from('seller_application').insert({
        'account_id': accountId,
        'store_name': storeName.trim(),
        'store_description': _blankToNull(storeDescription),
        'business_address': businessAddress,
        'province': province.trim(),
        'city': city.trim(),
        'barangay': barangay.trim(),
        'street': _blankToNull(street),
        'house_number': _blankToNull(houseNumber),
        'contact_phone': contactPhone.trim(),
        'status': 'Pending Review',
      });
      return true;
    } catch (e) {
      print('DB Error: Failed to submit seller application: $e');
      return false;
    }
  }

  // Get all seller applications (for admin)
  static Future<List<Map<String, dynamic>>> getSellerApplications() async {
    try {
      final response = await _supabase
          .from('seller_application')
          .select('*, account(firstname, surname, email)');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('DB Error: Failed to fetch seller applications: $e');
      return [];
    }
  }

  // Get seller application by account_id
  static Future<Map<String, dynamic>?> getSellerApplicationByAccountId(
      String accountId) async {
    try {
      final response = await _supabase
          .from('seller_application')
          .select()
          .eq('account_id', accountId)
          .single();
      return response;
    } catch (e) {
      print('DB Error: Failed to get seller application: $e');
      return null;
    }
  }

  // Approve seller application
  static Future<bool> approveSellerApplication({
    required String applicationId,
    required String accountId,
    required String storeName,
    required String addressLine,
    required String city,
    String? contactPhone,
  }) async {
    try {
      // Update application status
      await _supabase
          .from('seller_application')
          .update({
            'status': 'Approved',
            'date_approved': DateTime.now().toIso8601String(),
          })
          .eq('application_id', applicationId);

      // Update account type to Seller
      await _supabase
          .from('account')
          .update({'account_type': 'Seller', 'is_verified': true})
          .eq('account_id', accountId);

      // Create store for the seller
      await _supabase.from('store').insert({
        'owner_account_id': accountId,
        'store_name': storeName,
        'slug': storeName.toLowerCase().replaceAll(' ', '-'),
        'address_line': addressLine,
        'city': city,
        'contact_phone': _blankToNull(contactPhone),
        'is_open': true,
      });
      return true;
    } catch (e) {
      print('DB Error: Failed to approve seller application: $e');
      return false;
    }
  }

  // Reject seller application
  static Future<void> rejectSellerApplication({
    required String applicationId,
    required String reviewNotes,
  }) async {
    try {
      await _supabase
          .from('seller_application')
          .update({
            'status': 'Rejected',
            'review_notes': reviewNotes,
          })
          .eq('application_id', applicationId);
    } catch (e) {
      print('DB Error: Failed to reject seller application: $e');
    }
  }
}

