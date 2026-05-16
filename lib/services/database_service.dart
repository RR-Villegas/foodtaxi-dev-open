import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/address_model.dart';
import 'location_service.dart';

class DatabaseService {
  static final _supabase = Supabase.instance.client;

  static void _logDbError(String message, Object error) {
    debugPrint('DB Error: $message: $error');
  }

  // Insert address for a user
  static Future<Address?> insertAddress({
    required String accountId,
    String? province,
    String? city,
    String? barangay,
    String? street,
    String? houseNumber,
    String? zipCode,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    try {
      final response = await _supabase
          .from('address')
          .insert({
            'account_id': accountId,
            'province': _blankToNull(province),
            'city': _blankToNull(city),
            'barangay': _blankToNull(barangay),
            'street': _blankToNull(street),
            'house_number': _blankToNull(houseNumber),
            'zip_code': _blankToNull(zipCode),
            'latitude': latitude,
            'longitude': longitude,
            'is_default': isDefault,
          })
          .select()
          .single();

      return Address.fromJson(response);
    } catch (e) {
      _logDbError('Failed to insert address', e);
      return null;
    }
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static num _toNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) => _toNum(value).toDouble();

  static int _toInt(dynamic value) => _toNum(value).toInt();

  static String _randomCode([int length = 6]) {
    final random = Random.secure();
    return List.generate(length, (_) => random.nextInt(10).toString()).join();
  }

  static String _extensionFor(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) return 'bin';
    return parts.last.toLowerCase();
  }

  static String _contentTypeFor(String fileName, [String? fallback]) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    return fallback ?? 'application/octet-stream';
  }

  static String _storageSafeSegment(String? value, {String fallback = 'document'}) {
    final sanitized = (value ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return sanitized.isEmpty ? fallback : sanitized;
  }

  static String? normalizePhilippinePhone(String? phone) {
    final digits = phone?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.isEmpty) return null;
    if (digits.startsWith('9') && digits.length == 10) {
      return '+63$digits';
    }
    if (digits.startsWith('09') && digits.length == 11) {
      return '+63${digits.substring(1)}';
    }
    if (digits.startsWith('639') && digits.length == 12) {
      return '+$digits';
    }
    return phone?.trim();
  }

  // Insert user profile after signup
  // Returns existing account_id if already exists, creates new if not
  static Future<String?> insertUserProfile({
    required String authId,
    required String firstName,
    required String surname,
    required String email,
    String? phoneNumber,
    required String accountType,
  }) async {
    try {
      // First, check if account already exists
      final existingAccount = await _supabase
          .from('account')
          .select('account_id')
          .eq('auth_id', authId)
          .maybeSingle();

      if (existingAccount != null) {
        debugPrint('Account already exists for auth_id: $authId');
        await _supabase
            .from('account')
            .update({
              'firstname': firstName,
              'surname': surname,
              'email': email,
              'phone_number': _blankToNull(normalizePhilippinePhone(phoneNumber)),
              'account_type': accountType,
            })
            .eq('auth_id', authId);
        return existingAccount['account_id'] as String?;
      }

      // Account doesn't exist, create it
      final response = await _supabase
          .from('account')
          .insert({
            'auth_id': authId,
            'firstname': firstName,
            'surname': surname,
            'email': email,
            'phone_number': _blankToNull(normalizePhilippinePhone(phoneNumber)),
            'account_type': accountType,
          })
          .select('account_id')
          .single();

      return response['account_id'] as String?;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        try {
          final existingByEmail = await _supabase
              .from('account')
              .select('account_id')
              .eq('email', email)
              .maybeSingle();

          final accountId = existingByEmail?['account_id'] as String?;
          if (accountId != null) {
            await _supabase
                .from('account')
                .update({
                  'auth_id': authId,
                  'firstname': firstName,
                  'surname': surname,
                  'phone_number': _blankToNull(normalizePhilippinePhone(phoneNumber)),
                  'account_type': accountType,
                })
                .eq('account_id', accountId);
            return accountId;
          }
        } catch (recoveryError) {
          _logDbError('Failed to recover duplicate account insert',
              recoveryError);
        }
      }
      debugPrint('=== PostgreSQL Error ===');
      debugPrint('Error Code: ${e.code}');
      debugPrint('Error Message: ${e.message}');
      debugPrint('Error Details: ${e.details}');
      debugPrint('Full Error: $e');
      _logDbError('Failed to insert user profile', e);
      return null;
    } catch (e) {
      debugPrint('=== Generic Error ===');
      debugPrint('Error Type: ${e.runtimeType}');
      debugPrint('Error: $e');
      _logDbError('Failed to insert user profile', e);
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
      _logDbError('Failed to fetch current account', e);
      return null;
    }
  }

  static Future<String?> getCurrentAccountId() async {
    try {
      final account = await getCurrentAccount();
      return account?['account_id'] as String?;
    } catch (e) {
      _logDbError('Failed to fetch current account ID', e);
      return null;
    }
  }

  static Future<String?> getCurrentAccountType() async {
    try {
      final account = await getCurrentAccount();
      return account?['account_type'] as String?;
    } catch (e) {
      _logDbError('Failed to fetch current account type', e);
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
      _logDbError('Failed to fetch addresses', e);
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
    String? zipCode,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (province != null) updateData['province'] = _blankToNull(province);
      if (city != null) updateData['city'] = _blankToNull(city);
      if (barangay != null) updateData['barangay'] = _blankToNull(barangay);
      if (street != null) updateData['street'] = _blankToNull(street);
      if (houseNumber != null)
        updateData['house_number'] = _blankToNull(houseNumber);
      if (zipCode != null) updateData['zip_code'] = _blankToNull(zipCode);
      if (latitude != null) updateData['latitude'] = latitude;
      if (longitude != null) updateData['longitude'] = longitude;
      if (isDefault != null) updateData['is_default'] = isDefault;

      final response = await _supabase
          .from('address')
          .update(updateData)
          .eq('address_id', addressId)
          .select()
          .single();

      return Address.fromJson(response);
    } catch (e) {
      _logDbError('Failed to update address', e);
      return null;
    }
  }

  // Delete address
  static Future<void> deleteAddress(String addressId) async {
    try {
      await _supabase.from('address').delete().eq('address_id', addressId);
    } catch (e) {
      _logDbError('Failed to delete address', e);
    }
  }

  // Set address as default
  static Future<void> setDefaultAddress(
    String accountId,
    String addressId,
  ) async {
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
      _logDbError('Failed to set default address', e);
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
      _logDbError('Failed to update role', e);
      return false;
    }
  }

  // Insert order
  static Future<String> insertOrder({
    required String accountId,
    required String addressId,
    required double totalAmount,
    required double shippingFee,
    double serviceFee = 0,
    double discountAmount = 0,
    double? deliveryDistanceKm,
    required String paymentMethod,
    String? discountCode,
    String? sellerAccountId,
    String orderStatus = 'Processing',
  }) async {
    try {
      final sellerPayout = totalAmount - shippingFee - serviceFee;
      final orderData = {
        'buyer_account_id': accountId,
        'seller_account_id': sellerAccountId,
        'address_id': addressId,
        'total_amount': totalAmount,
        'shipping_fee': shippingFee,
        'delivery_distance_km': deliveryDistanceKm,
        'pickup_code': _randomCode(),
        'service_fee': serviceFee,
        'admin_commission': serviceFee,
        'rider_fee': shippingFee,
        'seller_payout': sellerPayout < 0 ? 0 : sellerPayout,
        'payment_method': paymentMethod,
        'order_status': orderStatus,
      };

      if (discountAmount > 0 || _blankToNull(discountCode) != null) {
        orderData['discount_amount'] = discountAmount;
        orderData['discount_code'] = _blankToNull(discountCode);
      }

      final response = await _supabase
          .from('orders')
          .insert(orderData)
          .select('order_id')
          .single();

      return response['order_id'] as String;
    } catch (e) {
      _logDbError('Failed to insert order', e);
      return '';
    }
  }

  // Insert order item
  static Future<bool> insertOrderItem({
    required String orderId,
    required String productId,
    required double unitPriceAtSale,
    required int quantity,
    String? productVariantId,
  }) async {
    try {
      await _supabase.from('order_items').insert({
        'order_id': orderId,
        'product_id': productId,
        'product_variant_id': _blankToNull(productVariantId),
        'quantity': quantity,
        'unit_price_at_sale': unitPriceAtSale,
        'subtotal': unitPriceAtSale * quantity,
      });
      return true;
    } catch (e) {
      _logDbError('Failed to insert order item', e);
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentSellerStore() async {
    try {
      final accountId = await getCurrentAccountId();
      if (accountId == null) return null;

      final response = await _supabase
          .from('store')
          .select()
          .eq('owner_account_id', accountId)
          .maybeSingle();

      return response;
    } catch (e) {
      _logDbError('Failed to fetch current seller store', e);
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getStoreById(String storeId) async {
    try {
      final response = await _supabase
          .from('store')
          .select(
            '*, account!store_owner_account_id_fkey(firstname, surname, profile_image_url)',
          )
          .eq('store_id', storeId)
          .maybeSingle();

      return response == null ? null : Map<String, dynamic>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch store', e);
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getSellerProducts(
    String storeId,
  ) async {
    try {
      final response = await _supabase
          .from('product')
          .select('*, product_variant(*)')
          .eq('store_id', storeId)
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch seller products', e);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getProductsForStore(
    String storeId,
  ) {
    return getSellerProducts(storeId);
  }

  static Future<bool> insertProduct({
    required String storeId,
    required String name,
    required double price,
    required int stockQuantity,
    String? category,
    String? description,
    String? sku,
    String? mainImageUrl,
    bool isActive = true,
    List<Map<String, dynamic>> variants = const [],
  }) async {
    try {
      final response = await _supabase
          .from('product')
          .insert({
            'store_id': storeId,
            'category': _blankToNull(category),
            'name': name.trim(),
            'description': _blankToNull(description),
            'price': price,
            'stock_quantity': stockQuantity,
            'sku': _blankToNull(sku),
            'main_image_url': _blankToNull(mainImageUrl),
            'is_active': isActive,
          })
          .select('product_id')
          .single();

      await _replaceProductVariants(response['product_id'].toString(), variants);
      return true;
    } catch (e) {
      _logDbError('Failed to insert product', e);
      return false;
    }
  }

  static Future<bool> updateProduct({
    required String productId,
    required String name,
    required double price,
    required int stockQuantity,
    String? category,
    String? description,
    String? sku,
    String? mainImageUrl,
    required bool isActive,
    List<Map<String, dynamic>> variants = const [],
  }) async {
    try {
      await _supabase
          .from('product')
          .update({
            'category': _blankToNull(category),
            'name': name.trim(),
            'description': _blankToNull(description),
            'price': price,
            'stock_quantity': stockQuantity,
            'sku': _blankToNull(sku),
            'main_image_url': _blankToNull(mainImageUrl),
            'is_active': isActive,
          })
          .eq('product_id', productId);
      await _replaceProductVariants(productId, variants);
      return true;
    } catch (e) {
      _logDbError('Failed to update product', e);
      return false;
    }
  }

  static Future<bool> deleteProduct(String productId) async {
    try {
      await _supabase
          .from('product')
          .update({'is_active': false})
          .eq('product_id', productId);
      return true;
    } catch (e) {
      _logDbError('Failed to delete product', e);
      return false;
    }
  }

  static Future<bool> updateCurrentAccountProfile({
    required String firstName,
    required String surname,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    try {
      final accountId = await getCurrentAccountId();
      if (accountId == null) return false;

      final updateData = {
        'firstname': firstName.trim(),
        'surname': surname.trim(),
        'phone_number': _blankToNull(normalizePhilippinePhone(phoneNumber)),
      };

      if (profileImageUrl != null) {
        updateData['profile_image_url'] = _blankToNull(profileImageUrl);
      }

      await _supabase
          .from('account')
          .update(updateData)
          .eq('account_id', accountId);
      return true;
    } catch (e) {
      _logDbError('Failed to update current account profile', e);
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getCurrentNotifications({
    int? limit,
    String? type,
    Duration? age,
  }) async {
    try {
      final accountId = await getCurrentAccountId();
      if (accountId == null) return [];

      var query = _supabase
          .from('notification')
          .select()
          .eq('account_id', accountId);

      if (type != null && type != 'All') {
        query = query.eq('notification_type', type);
      }

      if (age != null) {
        query = query.gte(
          'created_at',
          DateTime.now().subtract(age).toIso8601String(),
        );
      }

      final orderedQuery = query.order('created_at', ascending: false);
      final response =
          limit == null ? await orderedQuery : await orderedQuery.limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch notifications', e);
      return [];
    }
  }

  static Future<void> markNotificationRead(String notificationId) async {
    try {
      await _supabase
          .from('notification')
          .update({'is_read': true})
          .eq('notification_id', notificationId);
    } catch (e) {
      _logDbError('Failed to mark notification read', e);
    }
  }

  static Future<void> _replaceProductVariants(
    String productId,
    List<Map<String, dynamic>> variants,
  ) async {
    await _supabase.from('product_variant').delete().eq('product_id', productId);

    final rows = variants
        .map(
          (variant) => {
            'product_id': productId,
            'size_label': variant['size_label']?.toString().trim(),
            'price': _toDouble(variant['price']),
            'stock_quantity': _toInt(variant['stock_quantity']),
            'is_active': variant['is_active'] != false,
          },
        )
        .where(
          (variant) =>
              variant['size_label'] != null &&
              variant['size_label'].toString().isNotEmpty,
        )
        .toList();

    if (rows.isNotEmpty) {
      await _supabase.from('product_variant').insert(rows);
    }
  }

  static Future<String?> uploadProductImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final extension = fileName.split('.').last.toLowerCase();
      final safeExtension = extension == fileName ? 'jpg' : extension;
      final path =
          'seller-products/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

      await _supabase.storage
          .from('product-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: false),
          );

      return path;
    } catch (e) {
      _logDbError('Failed to upload product image', e);
      return null;
    }
  }

  static Future<String?> getSellerAccountIdForProduct(String productId) async {
    try {
      final response = await _supabase
          .from('product')
          .select('store(owner_account_id)')
          .eq('product_id', productId)
          .maybeSingle();

      return response?['store']?['owner_account_id'] as String?;
    } catch (e) {
      _logDbError('Failed to fetch seller for product', e);
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getStoreForProduct(String productId) async {
    try {
      final response = await _supabase
          .from('product')
          .select('store(*)')
          .eq('product_id', productId)
          .maybeSingle();

      final store = response?['store'];
      return store is Map ? Map<String, dynamic>.from(store) : null;
    } catch (e) {
      _logDbError('Failed to fetch store for product', e);
      return null;
    }
  }

  static Future<bool> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    try {
      final updateData = <String, dynamic>{'order_status': status};
      if (status == 'Delivered') {
        updateData['delivered_at'] = DateTime.now().toIso8601String();
      }
      await _supabase
          .from('orders')
          .update(updateData)
          .eq('order_id', orderId);
      return true;
    } catch (e) {
      _logDbError('Failed to update order status', e);
      return false;
    }
  }

  static Future<bool> sellerUpdateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    if (!['Processing', 'Ready for Pickup', 'Cancelled'].contains(status)) {
      return false;
    }
    final order = await _supabase
        .from('orders')
        .select('order_status')
        .eq('order_id', orderId)
        .maybeSingle();
    final currentStatus = order?['order_status']?.toString() ?? 'Processing';
    if (!['Processing', 'Ready for Pickup'].contains(currentStatus)) {
      return false;
    }
    return updateOrderStatus(orderId: orderId, status: status);
  }

  static Future<List<Map<String, dynamic>>> getSellerOrders(
    String sellerAccountId,
  ) async {
    try {
      final response = await _supabase
          .from('orders')
          .select(
            '*, account!orders_buyer_account_id_fkey(firstname, surname, email, phone_number), order_items(*, product(name, main_image_url), product_variant(size_label))',
          )
          .eq('seller_account_id', sellerAccountId)
          .order('order_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch seller orders', e);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getCurrentBuyerOrders() async {
    try {
      final accountId = await getCurrentAccountId();
      if (accountId == null) return [];

      var response = await _supabase
          .from('orders')
          .select(
            '*, address(*), order_items(*, product(name, main_image_url), product_variant(size_label), product_review(review_id, rating, comment))',
          )
          .eq('buyer_account_id', accountId)
          .order('order_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      try {
        final accountId = await getCurrentAccountId();
        if (accountId == null) return [];
        final response = await _supabase
            .from('orders')
            .select(
              '*, address(*), order_items(*, product(name, main_image_url), product_variant(size_label))',
            )
            .eq('buyer_account_id', accountId)
            .order('order_date', ascending: false);
        return List<Map<String, dynamic>>.from(response);
      } catch (fallbackError) {
        _logDbError('Failed to fetch buyer orders', fallbackError);
        return [];
      }
    }
  }

  static Future<List<Map<String, dynamic>>> getAvailableDeliveryOrders() async {
    try {
      final response = await _supabase
          .from('orders')
          .select(
            '*, address(*), account!orders_buyer_account_id_fkey(firstname, surname, phone_number), order_items(*, product(name), product_variant(size_label))',
          )
          .order('order_date', ascending: false);

      return List<Map<String, dynamic>>.from(response).where((order) {
        final status = order['order_status']?.toString();
        return status == 'Ready for Pickup' || status == 'In Transit';
      }).toList();
    } catch (e) {
      _logDbError('Failed to fetch delivery orders', e);
      return [];
    }
  }

  static Future<bool> assignOrderToCurrentRider(String orderId) async {
    try {
      final riderAccountId = await getCurrentAccountId();
      if (riderAccountId == null) return false;

      await _supabase
          .from('orders')
          .update({
            'rider_account_id': riderAccountId,
            'order_status': 'In Transit',
          })
          .eq('order_id', orderId);
      return true;
    } catch (e) {
      _logDbError('Failed to assign rider order', e);
      return false;
    }
  }

  static Future<bool> markOrderInTransitWithPickupCode({
    required String orderId,
    required String pickupCode,
  }) async {
    try {
      final riderAccountId = await getCurrentAccountId();
      if (riderAccountId == null) return false;

      final order = await _supabase
          .from('orders')
          .select('pickup_code, order_status')
          .eq('order_id', orderId)
          .maybeSingle();

      if (order == null ||
          order['order_status']?.toString() != 'Ready for Pickup' ||
          order['pickup_code']?.toString() != pickupCode.trim()) {
        return false;
      }

      await _supabase
          .from('orders')
          .update({
            'rider_account_id': riderAccountId,
            'order_status': 'In Transit',
            'picked_up_at': DateTime.now().toIso8601String(),
          })
          .eq('order_id', orderId);
      return true;
    } catch (e) {
      _logDbError('Failed to mark order in transit', e);
      return false;
    }
  }

  static Future<bool> markOrderDelivered({
    required String orderId,
    String? proofOfDeliveryUrl,
    String? proofNote,
  }) async {
    try {
      await _supabase
          .from('orders')
          .update({
            'order_status': 'Delivered',
            'payment_status': 'Paid',
            'proof_of_delivery_url': _blankToNull(proofOfDeliveryUrl),
            'delivery_proof_note': _blankToNull(proofNote),
            'delivered_at': DateTime.now().toIso8601String(),
          })
          .eq('order_id', orderId);
      return true;
    } catch (e) {
      _logDbError('Failed to mark order delivered', e);
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getProductReviews(
    String productId,
  ) async {
    try {
      final response = await _supabase
          .from('product_review')
          .select(
            '*, account!product_review_buyer_account_id_fkey(firstname, surname)',
          )
          .eq('product_id', productId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch product reviews', e);
      return [];
    }
  }

  static Future<bool> saveProductReview({
    required String orderItemId,
    required String productId,
    required int rating,
    String? comment,
  }) async {
    try {
      final accountId = await getCurrentAccountId();
      if (accountId == null) return false;

      await _supabase.from('product_review').upsert({
        'order_item_id': orderItemId,
        'product_id': productId,
        'buyer_account_id': accountId,
        'rating': rating,
        'comment': _blankToNull(comment),
      }, onConflict: 'order_item_id');
      return true;
    } catch (e) {
      _logDbError('Failed to save product review', e);
      return false;
    }
  }

  static Future<Map<String, dynamic>?> validateCoupon({
    required String code,
    required double subtotal,
  }) async {
    try {
      final coupon = await _supabase
          .from('discount_coupon')
          .select()
          .eq('code', code.trim().toUpperCase())
          .eq('is_active', true)
          .maybeSingle();

      if (coupon == null) return null;

      final now = DateTime.now();
      final startsAt = DateTime.tryParse(coupon['starts_at']?.toString() ?? '');
      final expiresAt = DateTime.tryParse(coupon['expires_at']?.toString() ?? '');
      final minSubtotal = _toDouble(coupon['min_subtotal']);
      final usageLimit = coupon['usage_limit'];
      final timesUsed = _toInt(coupon['times_used']);

      if (startsAt != null && now.isBefore(startsAt)) return null;
      if (expiresAt != null && now.isAfter(expiresAt)) return null;
      if (subtotal < minSubtotal) return null;
      if (usageLimit is num && timesUsed >= usageLimit.toInt()) return null;

      final type = coupon['discount_type']?.toString() ?? 'percent';
      final value = _toDouble(coupon['discount_value']);
      final amount = type == 'amount' ? value : subtotal * (value / 100);

      return {
        ...Map<String, dynamic>.from(coupon),
        'discount_amount': amount.clamp(0, subtotal).toDouble(),
      };
    } catch (e) {
      _logDbError('Failed to validate coupon', e);
      return null;
    }
  }

  static Future<void> incrementCouponUsage(String code) async {
    try {
      final coupon = await _supabase
          .from('discount_coupon')
          .select('times_used')
          .eq('code', code.trim().toUpperCase())
          .maybeSingle();
      if (coupon == null) return;

      await _supabase
          .from('discount_coupon')
          .update({'times_used': _toInt(coupon['times_used']) + 1})
          .eq('code', code.trim().toUpperCase());
    } catch (e) {
      _logDbError('Failed to increment coupon usage', e);
    }
  }

  static Future<List<Map<String, dynamic>>> getCoupons() async {
    try {
      final response = await _supabase
          .from('discount_coupon')
          .select()
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch coupons', e);
      return [];
    }
  }

  static Future<bool> saveCoupon({
    required String code,
    required String discountType,
    required double discountValue,
    double minSubtotal = 0,
    String? description,
    String? expiresAt,
    bool isActive = true,
  }) async {
    try {
      await _supabase.from('discount_coupon').upsert({
        'code': code.trim().toUpperCase(),
        'description': _blankToNull(description),
        'discount_type': discountType,
        'discount_value': discountValue,
        'min_subtotal': minSubtotal,
        'expires_at': _blankToNull(expiresAt),
        'is_active': isActive,
      }, onConflict: 'code');
      return true;
    } catch (e) {
      _logDbError('Failed to save coupon', e);
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getAdminOrders() async {
    try {
      final response = await _supabase
          .from('orders')
          .select(
            '*, account!orders_buyer_account_id_fkey(firstname, surname, email), order_items(quantity, subtotal, product(name))',
          )
          .order('order_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch admin orders', e);
      return [];
    }
  }

  static Map<String, dynamic> summarizeSales(
    List<Map<String, dynamic>> orders,
  ) {
    var revenue = 0.0;
    var itemsSold = 0;

    for (final order in orders) {
      revenue += _toDouble(order['total_amount']);
      final items = order['order_items'];
      if (items is List) {
        for (final item in items) {
          itemsSold += _toInt(item['quantity']);
        }
      }
    }

    return {
      'orders': orders.length,
      'revenue': revenue,
      'itemsSold': itemsSold,
    };
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
      _logDbError('Failed to fetch products', e);
      return [];
    }
  }

  // Get product image URL from bucket
  static String getProductImageUrl(String fileName) {
    final normalized = fileName.contains('/') ? fileName : 'main-picture/$fileName';
    return _supabase.storage.from('product-images').getPublicUrl(normalized);
  }

  static Future<List<Map<String, dynamic>>> searchProducts({
    String query = '',
    String? category,
    String sort = 'New',
    String seller = '',
  }) async {
    try {
      var request = _supabase
          .from('product')
          .select('*, store(store_id, store_name)')
          .eq('is_active', true);

      final trimmedQuery = query.trim();
      if (trimmedQuery.isNotEmpty) {
        request = request.ilike('name', '%$trimmedQuery%');
      }

      if (category != null && category != 'All') {
        request = request.eq('category', category);
      }

      final response = sort == 'Price: Low to High'
          ? await request.order('price', ascending: true)
          : sort == 'Price: High to Low'
              ? await request.order('price', ascending: false)
              : await request.order('product_id', ascending: false);

      final products = List<Map<String, dynamic>>.from(response);
      final sellerQuery = seller.trim().toLowerCase();
      if (sellerQuery.isEmpty) return products;

      return products.where((product) {
        final store = product['store'];
        if (store is! Map) return false;
        return (store['store_name']?.toString().toLowerCase() ?? '')
            .contains(sellerQuery);
      }).toList();
    } catch (e) {
      _logDbError('Failed to search products', e);
      return [];
    }
  }

  static String getProfileImageUrl(String fileName) {
    return _supabase.storage.from('profile-images').getPublicUrl(fileName);
  }

  static Future<String?> uploadProfileImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final extension = fileName.split('.').last.toLowerCase();
      final safeExtension = extension == fileName ? 'jpg' : extension;
      final path =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

      await _supabase.storage
          .from('profile-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: false),
          );

      return path;
    } catch (e) {
      _logDbError('Failed to upload profile image', e);
      return null;
    }
  }

  static Future<Map<String, dynamic>?> uploadApplicationDocument({
    required Uint8List bytes,
    required String fileName,
    required String label,
    String? applicationType,
    String? documentType,
    String? accountId,
    String? contentType,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      final userFolder = user.id;
      final extension = _extensionFor(fileName);
      final role = _storageSafeSegment(applicationType, fallback: 'application');
      final document = _storageSafeSegment(
        documentType ?? label,
        fallback: 'document',
      );
      final owner = _storageSafeSegment(accountId ?? user.id, fallback: 'account');
      final storedFileName =
          '${role}_${document}_${owner}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final path = '$userFolder/applications/$storedFileName';
      final mimeType = _contentTypeFor(fileName, contentType);

      await _supabase.storage.from('application-documents').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: false,
              contentType: mimeType,
            ),
          );

      return {
        'label': label,
        'file_name': fileName,
        'stored_file_name': storedFileName,
        'path': path,
        'bucket': 'application-documents',
        'content_type': mimeType,
        'size': bytes.lengthInBytes,
      };
    } catch (e) {
      _logDbError('Failed to upload application document', e);
      return null;
    }
  }

  static Future<String?> uploadDeliveryProof({
    required Uint8List bytes,
    required String fileName,
    required String orderId,
    String? contentType,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      final extension = _extensionFor(fileName);
      final path =
          '$orderId/${user.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';
      final mimeType = _contentTypeFor(fileName, contentType);

      await _supabase.storage.from('delivery-proofs').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: false,
              contentType: mimeType,
            ),
          );

      return path;
    } catch (e) {
      _logDbError('Failed to upload delivery proof', e);
      return null;
    }
  }

  static Future<String?> createSignedStorageUrl({
    required String bucket,
    required String path,
    int expiresIn = 3600,
  }) async {
    try {
      return await _supabase.storage.from(bucket).createSignedUrl(
            path,
            expiresIn,
          );
    } catch (e) {
      _logDbError('Failed to create signed storage URL', e);
      return null;
    }
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
      _logDbError('Failed to insert cart item', e);
    }
  }

  // Get cart items for user
  static Future<List<Map<String, dynamic>>> getCartItems(
    String accountId,
  ) async {
    try {
      final response = await _supabase
          .from('cart')
          .select()
          .eq('account_id', accountId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch cart items', e);
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
          .update({'quantity': quantity})
          .eq('id', cartId);
    } catch (e) {
      _logDbError('Failed to update cart item', e);
    }
  }

  // Delete cart item
  static Future<void> deleteCartItem(String cartId) async {
    try {
      await _supabase.from('cart').delete().eq('id', cartId);
    } catch (e) {
      _logDbError('Failed to delete cart item', e);
    }
  }

  // Clear all cart items for user
  static Future<void> clearCart(String accountId) async {
    try {
      await _supabase.from('cart').delete().eq('account_id', accountId);
    } catch (e) {
      _logDbError('Failed to clear cart', e);
    }
  }

  // Insert seller application
  static Future<bool> insertSellerApplication({
    required String accountId,
    required String storeName,
    String? storeDescription,
    String? province,
    required String city,
    String? barangay,
    String? street,
    String? houseNumber,
    String? zipCode,
    required String contactPhone,
    List<Map<String, dynamic>> documents = const [],
  }) async {
    try {
      await _supabase.from('seller_application').insert({
        'account_id': accountId,
        'store_name': storeName.trim(),
        'store_description': _blankToNull(storeDescription),
        'province': _blankToNull(province),
        'city': city.trim(),
        'barangay': _blankToNull(barangay),
        'street': _blankToNull(street),
        'house_number': _blankToNull(houseNumber),
        'zip_code': _blankToNull(zipCode),
        'contact_phone': normalizePhilippinePhone(contactPhone),
        'documents_path': documents.isEmpty ? null : {'files': documents},
        'status': 'Pending Review',
      });
      return true;
    } on PostgrestException catch (e) {
      debugPrint('=== Seller Application PostgreSQL Error ===');
      debugPrint('Error Code: ${e.code}');
      debugPrint('Error Message: ${e.message}');
      debugPrint('Error Details: ${e.details}');
      debugPrint('Full Error: $e');
      _logDbError('Failed to submit seller application', e);
      return false;
    } catch (e) {
      debugPrint('=== Seller Application Generic Error ===');
      debugPrint('Error Type: ${e.runtimeType}');
      debugPrint('Error: $e');
      _logDbError('Failed to submit seller application', e);
      return false;
    }
  }

  // Get all seller applications (for admin)
  static Future<List<Map<String, dynamic>>> getSellerApplications() async {
    try {
      final response = await _supabase
          .from('seller_application')
          .select('''
            application_id,
            account_id,
            store_name,
            store_description,
            city,
            province,
            barangay,
            street,
            house_number,
            zip_code,
            contact_phone,
            status,
            submission_date,
            review_notes,
            date_approved,
            documents_path,
            account (
              firstname,
              surname,
              email,
              phone_number
            )
          ''')
          .order('submission_date', ascending: false);

      debugPrint('Seller Applications Response: $response');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('=== GET SELLER APPLICATIONS ERROR ===');
      debugPrint(e.toString());
      _logDbError('Failed to fetch seller applications', e);
      return [];
    }
  }

  // Get seller application by account_id
  static Future<Map<String, dynamic>?> getSellerApplicationByAccountId(
    String accountId,
  ) async {
    try {
      final response = await _supabase
          .from('seller_application')
          .select()
          .eq('account_id', accountId)
          .maybeSingle();
      return response;
    } catch (e) {
      _logDbError('Failed to get seller application', e);
      return null;
    }
  }

  static Future<bool> saveSellerApplication({
    required String accountId,
    required String storeName,
    String? storeDescription,
    String? province,
    required String city,
    String? barangay,
    String? street,
    String? houseNumber,
    String? zipCode,
    required String contactPhone,
    List<Map<String, dynamic>> documents = const [],
  }) async {
    final existing = await getSellerApplicationByAccountId(accountId);
    if (existing == null) {
      return insertSellerApplication(
        accountId: accountId,
        storeName: storeName,
        storeDescription: storeDescription,
        province: province,
        city: city,
        barangay: barangay,
        street: street,
        houseNumber: houseNumber,
        zipCode: zipCode,
        contactPhone: contactPhone,
        documents: documents,
      );
    }

    if (existing['status'] != 'Rejected') return true;

    try {
      await _supabase
          .from('seller_application')
          .update({
            'store_name': storeName.trim(),
            'store_description': _blankToNull(storeDescription),
            'province': _blankToNull(province),
            'city': city.trim(),
            'barangay': _blankToNull(barangay),
            'street': _blankToNull(street),
            'house_number': _blankToNull(houseNumber),
            'zip_code': _blankToNull(zipCode),
            'contact_phone': normalizePhilippinePhone(contactPhone),
            'documents_path': documents.isEmpty ? null : {'files': documents},
            'status': 'Pending Review',
            'review_notes': null,
            'date_approved': null,
            'submission_date': DateTime.now().toIso8601String(),
          })
          .eq('account_id', accountId);
      return true;
    } catch (e) {
      _logDbError('Failed to resubmit seller application', e);
      return false;
    }
  }

  static Future<bool> insertRiderApplication({
    required String accountId,
    required String licenseNumber,
    required String vehicleType,
    required String plateNumber,
    String? province,
    String? city,
    String? barangay,
    String? street,
    String? houseNumber,
    String? zipCode,
    double? latitude,
    double? longitude,
    String? documentNotes,
    List<Map<String, dynamic>> documents = const [],
  }) async {
    try {
      await _supabase.from('rider_application').insert({
        'account_id': accountId,
        'license_number': licenseNumber.trim(),
        'vehicle_type': vehicleType.trim(),
        'plate_number': plateNumber.trim(),
        'province': _blankToNull(province),
        'city': _blankToNull(city),
        'barangay': _blankToNull(barangay),
        'street': _blankToNull(street),
        'house_number': _blankToNull(houseNumber),
        'zip_code': _blankToNull(zipCode),
        'latitude': latitude,
        'longitude': longitude,
        'documents_path': {
          if (_blankToNull(documentNotes) != null) 'notes': documentNotes!.trim(),
          if (documents.isNotEmpty) 'files': documents,
        },
        'status': 'Pending Review',
      });
      return true;
    } catch (e) {
      _logDbError('Failed to submit rider application', e);
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getRiderApplicationByAccountId(
    String accountId,
  ) async {
    try {
      final response = await _supabase
          .from('rider_application')
          .select()
          .eq('account_id', accountId)
          .maybeSingle();
      return response;
    } catch (e) {
      _logDbError('Failed to get rider application', e);
      return null;
    }
  }

  static Future<bool> saveRiderApplication({
    required String accountId,
    required String licenseNumber,
    required String vehicleType,
    required String plateNumber,
    String? province,
    String? city,
    String? barangay,
    String? street,
    String? houseNumber,
    String? zipCode,
    double? latitude,
    double? longitude,
    String? documentNotes,
    List<Map<String, dynamic>> documents = const [],
  }) async {
    final existing = await getRiderApplicationByAccountId(accountId);
    if (existing == null) {
      return insertRiderApplication(
        accountId: accountId,
        licenseNumber: licenseNumber,
        vehicleType: vehicleType,
        plateNumber: plateNumber,
        province: province,
        city: city,
        barangay: barangay,
        street: street,
        houseNumber: houseNumber,
        zipCode: zipCode,
        latitude: latitude,
        longitude: longitude,
        documentNotes: documentNotes,
        documents: documents,
      );
    }

    if (existing['status'] != 'Rejected') return true;

    try {
      await _supabase
          .from('rider_application')
          .update({
            'license_number': licenseNumber.trim(),
            'vehicle_type': vehicleType.trim(),
            'plate_number': plateNumber.trim(),
            'province': _blankToNull(province),
            'city': _blankToNull(city),
            'barangay': _blankToNull(barangay),
            'street': _blankToNull(street),
            'house_number': _blankToNull(houseNumber),
            'zip_code': _blankToNull(zipCode),
            'latitude': latitude,
            'longitude': longitude,
            'documents_path': {
              if (_blankToNull(documentNotes) != null)
                'notes': documentNotes!.trim(),
              if (documents.isNotEmpty) 'files': documents,
            },
            'status': 'Pending Review',
            'review_notes': null,
            'date_approved': null,
            'application_date': DateTime.now().toIso8601String(),
          })
          .eq('account_id', accountId);
      return true;
    } catch (e) {
      _logDbError('Failed to resubmit rider application', e);
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getRiderApplications() async {
    try {
      final response = await _supabase
          .from('rider_application')
          .select('''
            rider_app_id,
            account_id,
            license_number,
            vehicle_type,
            plate_number,
            city,
            province,
            barangay,
            street,
            house_number,
            zip_code,
            latitude,
            longitude,
            documents_path,
            status,
            application_date,
            review_notes,
            date_approved,
            account (
              firstname,
              surname,
              email,
              phone_number
            )
          ''')
          .order('application_date', ascending: false);

      debugPrint('Rider Applications Response: $response');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('=== GET RIDER APPLICATIONS ERROR ===');
      debugPrint(e.toString());
      _logDbError('Failed to fetch rider applications', e);
      return [];
    }
  }

  static Future<bool> approveRiderApplication({
    required String applicationId,
    required String accountId,
  }) async {
    try {
      final application = await _supabase
          .from('rider_application')
          .select('province, city, barangay, street, house_number, zip_code, latitude, longitude')
          .eq('rider_app_id', applicationId)
          .maybeSingle();
      final hasAddress = _blankToNull(application?['city']?.toString()) != null &&
          _blankToNull(application?['barangay']?.toString()) != null;
      final point = !hasAddress
          ? null
          : await LocationService.geocodeAddress(
              houseNumber: application!['house_number']?.toString(),
              street: application['street']?.toString(),
              barangay: application['barangay']?.toString(),
              city: application['city']?.toString(),
              province: application['province']?.toString(),
            );
      final resolvedZipCode = point?.postalCode?.trim().isNotEmpty == true
          ? point!.postalCode!.trim()
          : application?['zip_code']?.toString();

      await _supabase
          .from('rider_application')
          .update({
            'status': 'Approved',
            'date_approved': DateTime.now().toIso8601String(),
            'zip_code': _blankToNull(resolvedZipCode),
            'latitude': point?.latitude ?? _toDouble(application?['latitude']),
            'longitude': point?.longitude ?? _toDouble(application?['longitude']),
          })
          .eq('rider_app_id', applicationId);

      await _supabase
          .from('account')
          .update({'account_type': 'Rider', 'is_verified': true})
          .eq('account_id', accountId);
      if (application != null) {
        await saveRegistrationAddress(
          accountId: accountId,
          province: application['province']?.toString(),
          city: application['city']?.toString(),
          barangay: application['barangay']?.toString(),
          street: application['street']?.toString(),
          houseNumber: application['house_number']?.toString(),
          zipCode: resolvedZipCode,
          latitude: point?.latitude ?? _toDouble(application['latitude']),
          longitude: point?.longitude ?? _toDouble(application['longitude']),
        );
      }
      return true;
    } catch (e) {
      _logDbError('Failed to approve rider application', e);
      return false;
    }
  }

  static Future<void> rejectRiderApplication({
    required String applicationId,
    required String reviewNotes,
  }) async {
    try {
      await _supabase
          .from('rider_application')
          .update({'status': 'Rejected', 'review_notes': reviewNotes})
          .eq('rider_app_id', applicationId);
    } catch (e) {
      _logDbError('Failed to reject rider application', e);
    }
  }

  static Future<void> saveRegistrationAddress({
    required String accountId,
    String? province,
    String? city,
    String? barangay,
    String? street,
    String? houseNumber,
    String? zipCode,
    double? latitude,
    double? longitude,
  }) async {
    if (_blankToNull(city) == null || _blankToNull(barangay) == null) return;

    final existingAddresses = await _supabase
        .from('address')
        .select('address_id, is_default')
        .eq('account_id', accountId);
    final addresses = List<Map<String, dynamic>>.from(existingAddresses);
    final shouldBeDefault =
        !addresses.any((address) => address['is_default'] == true);

    final existingMatch = await _supabase
        .from('address')
        .select('address_id')
        .eq('account_id', accountId)
        .eq('city', _blankToNull(city)!)
        .eq('barangay', _blankToNull(barangay)!)
        .maybeSingle();

    final addressData = {
      'province': _blankToNull(province),
      'city': _blankToNull(city),
      'barangay': _blankToNull(barangay),
      'street': _blankToNull(street),
      'house_number': _blankToNull(houseNumber),
      'zip_code': _blankToNull(zipCode),
      'latitude': latitude,
      'longitude': longitude,
      'is_default': shouldBeDefault,
    };

    if (existingMatch == null) {
      await _supabase.from('address').insert({
        'account_id': accountId,
        ...addressData,
      });
    } else {
      await _supabase
          .from('address')
          .update(addressData..remove('is_default'))
          .eq('address_id', existingMatch['address_id']);
    }
  }

  // Approve seller application
  static Future<bool> approveSellerApplication({
    required String applicationId,
    required String accountId,
    required String storeName,
    String? storeDescription,
    String? province,
    required String city,
    String? barangay,
    String? street,
    String? houseNumber,
    String? zipCode,
    String? contactPhone,
  }) async {
    try {
      final point = await LocationService.geocodeAddress(
        houseNumber: houseNumber,
        street: street,
        barangay: barangay,
        city: city,
        province: province,
      );
      final resolvedZipCode = point?.postalCode?.trim().isNotEmpty == true
          ? point!.postalCode!.trim()
          : zipCode;

      // Update application status
      await _supabase
          .from('seller_application')
          .update({
            'status': 'Approved',
            'date_approved': DateTime.now().toIso8601String(),
            'zip_code': _blankToNull(resolvedZipCode),
          })
          .eq('application_id', applicationId);

      // Update account type to Seller
      await _supabase
          .from('account')
          .update({'account_type': 'Seller', 'is_verified': true})
          .eq('account_id', accountId);

      final existingStore = await _supabase
          .from('store')
          .select('store_id')
          .eq('owner_account_id', accountId)
          .maybeSingle();

      final storeData = {
        'owner_account_id': accountId,
        'store_name': storeName,
        'slug': storeName.toLowerCase().replaceAll(' ', '-'),
        'description': _blankToNull(storeDescription),
        'province': _blankToNull(province),
        'city': city,
        'barangay': _blankToNull(barangay),
        'street': _blankToNull(street),
        'house_number': _blankToNull(houseNumber),
        'zip_code': _blankToNull(resolvedZipCode),
        'latitude': point?.latitude,
        'longitude': point?.longitude,
        'contact_phone': _blankToNull(normalizePhilippinePhone(contactPhone)),
        'is_open': true,
      };

      if (existingStore == null) {
        await _supabase.from('store').insert(storeData);
      } else {
        await _supabase
            .from('store')
            .update(storeData)
            .eq('store_id', existingStore['store_id']);
      }

      await saveRegistrationAddress(
        accountId: accountId,
        province: province,
        city: city,
        barangay: barangay,
        street: street,
        houseNumber: houseNumber,
        zipCode: resolvedZipCode,
        latitude: point?.latitude,
        longitude: point?.longitude,
      );
      return true;
    } catch (e) {
      _logDbError('Failed to approve seller application', e);
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
          .update({'status': 'Rejected', 'review_notes': reviewNotes})
          .eq('application_id', applicationId);
    } catch (e) {
      _logDbError('Failed to reject seller application', e);
    }
  }
}
