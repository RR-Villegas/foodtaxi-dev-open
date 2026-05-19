import 'dart:convert';
import 'dart:math' show Random;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/address_model.dart';
import 'input_validator.dart';
import 'location_service.dart';

class DatabaseService {
  static final _supabase = Supabase.instance.client;
  static String? _cachedPublicIpHash;
  static const List<String> allowedApplicationDocumentExtensions = [
    'pdf',
    'png',
    'jpg',
    'webp',
  ];
  static const List<String> allowedImageExtensions = ['png', 'jpg', 'webp'];

  static void _logDbError(String message, Object error) {
    debugPrint('DB Error: $message: $error');
  }

  static String displayProductName(dynamic value) {
    return InputValidator.cleanProductTitle(value?.toString());
  }

  static String money(dynamic value) {
    final amount = _toDouble(value);
    return 'PHP ${amount.toStringAsFixed(2)}';
  }

  static Map<String, dynamic>? activeProductDiscount(
    Map<String, dynamic> product,
  ) {
    final discounts = product['product_discount'];
    if (discounts is! List || discounts.isEmpty) return null;
    final now = DateTime.now();
    final active = discounts.whereType<Map>().where((discount) {
      if (discount['is_active'] == false) return false;
      final startsAt = DateTime.tryParse(discount['starts_at']?.toString() ?? '');
      final endsAt = DateTime.tryParse(discount['ends_at']?.toString() ?? '');
      if (startsAt == null || endsAt == null) return false;
      return !now.isBefore(startsAt) && now.isBefore(endsAt);
    }).toList()
      ..sort((a, b) {
        final aStart = DateTime.tryParse(a['starts_at']?.toString() ?? '');
        final bStart = DateTime.tryParse(b['starts_at']?.toString() ?? '');
        return (bStart ?? DateTime(0)).compareTo(aStart ?? DateTime(0));
      });
    return active.isEmpty ? null : Map<String, dynamic>.from(active.first);
  }

  static double discountedPrice(double price, Map<String, dynamic>? discount) {
    if (discount == null) return price;
    final value = _toDouble(discount['discount_value']);
    final discounted = discount['discount_type']?.toString() == 'amount'
        ? price - value
        : price * (1 - (value / 100));
    return discounted < 0 ? 0 : discounted;
  }

  static List<double> _productOptionPrices(Map<String, dynamic> product) {
    final prices = <double>[_toDouble(product['price'])];
    final variants = product['product_variant'];
    if (variants is List) {
      for (final variant in variants.whereType<Map>()) {
        if (variant['is_active'] == false) continue;
        prices.add(_toDouble(variant['price']));
      }
    }
    return prices.where((price) => price >= 0).toList();
  }

  static String displayProductPrice(Map<String, dynamic> product) {
    final prices = _productOptionPrices(product);
    if (prices.isEmpty) return money(0);
    final discount = activeProductDiscount(product);
    final basePrice = discountedPrice(_toDouble(product['price']), discount);
    final variants = product['product_variant'];
    final hasVariants = variants is List &&
        variants.whereType<Map>().any((variant) => variant['is_active'] != false);
    return hasVariants ? '${money(basePrice)}*' : money(basePrice);
  }

  static String _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static Future<String?> _publicIpHash() async {
    if (_cachedPublicIpHash != null) return _cachedPublicIpHash;
    try {
      final response = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      final ip = data is Map ? data['ip']?.toString().trim() : null;
      if (ip == null || ip.isEmpty) return null;
      _cachedPublicIpHash = _stableHash(ip);
      return _cachedPublicIpHash;
    } catch (e) {
      _logDbError('Failed to fetch public IP for click tracking', e);
      return null;
    }
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

  static bool _isSuccessfulOrder(Map<String, dynamic> order) {
    final status = order['order_status']?.toString().toLowerCase() ?? '';
    return status == 'delivered';
  }

  static String generateSku(String productName, String? sizeLabel) {
    final parts = [
      productName,
      sizeLabel,
    ]
        .map((part) => part?.toString().trim() ?? '')
        .where((part) => part.isNotEmpty)
        .join('-');
    final slug = parts
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return slug.isEmpty ? 'PRODUCT' : slug;
  }

  static String _slugFor(String value) {
    final slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return slug.isEmpty ? 'store' : slug;
  }

  static String _randomCode([int length = 6]) {
    final random = Random.secure();
    return List.generate(length, (_) => random.nextInt(10).toString()).join();
  }

  static String _extensionFor(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) return 'bin';
    return parts.last.toLowerCase();
  }

  static bool isAllowedApplicationDocumentName(String fileName) {
    return allowedApplicationDocumentExtensions.contains(_extensionFor(fileName));
  }

  static bool isAllowedImageName(String fileName) {
    return allowedImageExtensions.contains(_extensionFor(fileName));
  }

  static String? applicationDocumentContentTypeFor(String fileName) {
    final extension = _extensionFor(fileName);
    if (!allowedApplicationDocumentExtensions.contains(extension)) return null;
    return _contentTypeForExtension(extension);
  }

  static String? imageContentTypeFor(String fileName) {
    final extension = _extensionFor(fileName);
    if (!allowedImageExtensions.contains(extension)) return null;
    return _contentTypeForExtension(extension);
  }

  static String _contentTypeForExtension(String extension) {
    if (extension == 'pdf') return 'application/pdf';
    if (extension == 'png') return 'image/png';
    if (extension == 'jpg') return 'image/jpeg';
    if (extension == 'webp') return 'image/webp';
    return 'application/octet-stream';
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
      if (houseNumber != null) {
        updateData['house_number'] = _blankToNull(houseNumber);
      }
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
    String deliveryMode = 'standard',
    int bulkDeliveryMinOrders = 1,
    int bulkDeliveryMaxOrders = 1,
    required String paymentMethod,
    String? discountCode,
    String? sellerAccountId,
    String orderStatus = 'Processing',
  }) async {
    try {
      final address = await _supabase
          .from('address')
          .select('address_id')
          .eq('address_id', addressId)
          .eq('account_id', accountId)
          .maybeSingle();
      if (address == null) {
        throw Exception('Selected address does not belong to this buyer');
      }

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
        'delivery_mode': deliveryMode,
        'bulk_delivery_min_orders': bulkDeliveryMinOrders,
        'bulk_delivery_max_orders': bulkDeliveryMaxOrders,
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

  static Future<String> placeOrderWithItems({
    required String accountId,
    required String addressId,
    required double totalAmount,
    required double shippingFee,
    double serviceFee = 0,
    double discountAmount = 0,
    double? deliveryDistanceKm,
    String deliveryMode = 'standard',
    int bulkDeliveryMinOrders = 1,
    int bulkDeliveryMaxOrders = 1,
    required String paymentMethod,
    String? discountCode,
    String? sellerAccountId,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final response = await _supabase.rpc(
        'place_order_with_items',
        params: {
          'p_account_id': accountId,
          'p_address_id': addressId,
          'p_total_amount': totalAmount,
          'p_shipping_fee': shippingFee,
          'p_service_fee': serviceFee,
          'p_discount_amount': discountAmount,
          'p_delivery_distance_km': deliveryDistanceKm,
          'p_delivery_mode': deliveryMode,
          'p_bulk_delivery_min_orders': bulkDeliveryMinOrders,
          'p_bulk_delivery_max_orders': bulkDeliveryMaxOrders,
          'p_payment_method': paymentMethod,
          'p_discount_code': _blankToNull(discountCode),
          'p_seller_account_id': _blankToNull(sellerAccountId),
          'p_items': items,
        },
      );
      return response?.toString() ?? '';
    } catch (e) {
      _logDbError('Failed to place order with items', e);
      rethrow;
    }
  }

  static Future<String?> checkoutStockError(Map<String, dynamic> item) async {
    try {
      final productId = item['product_id']?.toString();
      if (productId == null || productId.isEmpty) {
        return 'Cart item is missing product ID';
      }

      final quantity = _toInt(item['quantity']);
      if (quantity <= 0) return 'Invalid cart quantity';

      final product = await _supabase
          .from('product')
          .select('product_id, name, stock_quantity, stock_mode, base_unit_quantity')
          .eq('product_id', productId)
          .maybeSingle();
      if (product == null) return 'Product is no longer available';

      final name = displayProductName(product['name'] ?? item['name']);
      final stockMode = product['stock_mode']?.toString() == 'shared'
          ? 'shared'
          : 'independent';
      final variantId = _blankToNull(item['selected_variant_id']?.toString());

      if (variantId != null) {
        final variant = await _supabase
            .from('product_variant')
            .select('variant_id, size_label, stock_quantity, stock_unit_quantity')
            .eq('variant_id', variantId)
            .eq('product_id', productId)
            .maybeSingle();
        if (variant == null) return '$name size is no longer available';

        final size = variant['size_label']?.toString() ?? 'selected size';
        final unitQuantity = _toInt(variant['stock_unit_quantity']) < 1
            ? 1
            : _toInt(variant['stock_unit_quantity']);
        final available = stockMode == 'shared'
            ? _toInt(product['stock_quantity']) ~/ unitQuantity
            : _toInt(variant['stock_quantity']);
        if (quantity > available) {
          return 'Cart has $quantity of $name ($size), but only $available available.';
        }
        return null;
      }

      final unitQuantity = _toInt(product['base_unit_quantity']) < 1
          ? 1
          : _toInt(product['base_unit_quantity']);
      final available = stockMode == 'shared'
          ? _toInt(product['stock_quantity']) ~/ unitQuantity
          : _toInt(product['stock_quantity']);
      if (quantity > available) {
        return 'Cart has $quantity of $name, but only $available available. Update the cart quantity.';
      }
      return null;
    } catch (e) {
      _logDbError('Failed to check checkout stock', e);
      return 'Could not verify cart stock. Please try again.';
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
          .select('*, product_variant(*), product_discount(*)')
          .eq('store_id', storeId)
          .order('product_id', ascending: false);

      return _withProductRatings(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      _logDbError('Failed to fetch seller products', e);
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getProductForCheckout(
    String productId,
  ) async {
    try {
      final response = await _supabase
          .from('product')
          .select('''
            *,
            product_variant(*),
            product_discount(*)
          ''')
          .eq('product_id', productId)
          .eq('is_active', true)
          .maybeSingle();

      return response == null ? null : Map<String, dynamic>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch product for checkout', e);
      return null;
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
    String stockMode = 'independent',
    String baseSizeLabel = 'Default',
    int baseUnitQuantity = 1,
    String? category,
    String? description,
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
            'stock_mode': stockMode,
            'base_size_label': _blankToNull(baseSizeLabel) ?? 'Default',
            'base_unit_quantity': baseUnitQuantity < 1 ? 1 : baseUnitQuantity,
            'sku': generateSku(name, baseSizeLabel),
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
    String stockMode = 'independent',
    String baseSizeLabel = 'Default',
    int baseUnitQuantity = 1,
    String? category,
    String? description,
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
            'stock_mode': stockMode,
            'base_size_label': _blankToNull(baseSizeLabel) ?? 'Default',
            'base_unit_quantity': baseUnitQuantity < 1 ? 1 : baseUnitQuantity,
            'sku': generateSku(name, baseSizeLabel),
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
    bool unreadOnly = false,
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

      if (unreadOnly) {
        query = query.eq('is_read', false);
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

  static Future<void> markNotificationUnread(String notificationId) async {
    try {
      await _supabase
          .from('notification')
          .update({'is_read': false})
          .eq('notification_id', notificationId);
    } catch (e) {
      _logDbError('Failed to mark notification unread', e);
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
            'stock_unit_quantity': _toInt(variant['stock_unit_quantity']) < 1
                ? 1
                : _toInt(variant['stock_unit_quantity']),
            'sku': generateSku(
              variant['product_name']?.toString() ?? '',
              variant['size_label']?.toString(),
            ),
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
      if (!isAllowedImageName(fileName)) return null;
      final extension = _extensionFor(fileName);
      final path =
          'seller-products/${DateTime.now().millisecondsSinceEpoch}.$extension';
      final mimeType = imageContentTypeFor(fileName)!;

      await _supabase.storage
          .from('product-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: false,
              contentType: mimeType,
            ),
          );

      return path;
    } catch (e) {
      _logDbError('Failed to upload product image', e);
      return null;
    }
  }

  static Future<String?> uploadStoreBannerImage({
    required String storeId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      if (!isAllowedImageName(fileName)) return null;

      final extension = _extensionFor(fileName);
      final path =
          '$storeId/banner_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final mimeType = imageContentTypeFor(fileName)!;

      await _supabase.storage.from('store-banners').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: mimeType,
            ),
          );

      return path;
    } catch (e) {
      _logDbError('Failed to upload store banner image', e);
      return null;
    }
  }

  static String getStoreBannerImageUrl(String path) {
    if (path.startsWith('http')) return path;
    return _supabase.storage.from('store-banners').getPublicUrl(path);
  }

  static Future<bool> updateStoreBannerImage({
    required String storeId,
    required String bannerImageUrl,
  }) async {
    try {
      await _supabase.from('store').update({
        'banner_image_url': _blankToNull(bannerImageUrl),
      }).eq('store_id', storeId);

      return true;
    } catch (e) {
      _logDbError('Failed to update store banner image', e);
      return false;
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

  static Future<void> trackProductClick({
    required String productId,
    String? storeId,
  }) async {
    try {
      final ipHash = await _publicIpHash();
      await _supabase.rpc('track_product_click', params: {
        'p_product_id': productId,
        'p_store_id': _blankToNull(storeId),
        'p_ip_hash': ipHash,
      });
    } catch (e) {
      _logDbError('Failed to track product click', e);
    }
  }

  static Future<List<Map<String, dynamic>>> getTrendingProducts({
    String? storeId,
    int limit = 12,
  }) async {
    try {
      final clicks = await _supabase.rpc(
        'get_trending_product_clicks',
        params: {
          'p_store_id': _blankToNull(storeId),
          'p_limit': limit,
        },
      );
      final counts = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(clicks)) {
        final productId = row['product_id']?.toString();
        if (productId == null || productId.isEmpty) continue;
        counts[productId] = _toInt(row['click_count']);
      }

      if (counts.isEmpty) return [];

      final orderedIds = counts.keys.toList()
        ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
      final selectedIds = orderedIds.take(limit).toList();

      var productRequest = _supabase
          .from('product')
          .select('*, product_variant(*), product_discount(*)')
          .inFilter('product_id', selectedIds)
          .eq('is_active', true);
      if (_blankToNull(storeId) != null) {
        productRequest = productRequest.eq('store_id', storeId!);
      }

      final response = await productRequest;
      final products = await _withProductRatings(
        List<Map<String, dynamic>>.from(response),
      );
      products.sort((a, b) {
        final aId = a['product_id']?.toString() ?? '';
        final bId = b['product_id']?.toString() ?? '';
        return (counts[bId] ?? 0).compareTo(counts[aId] ?? 0);
      });
      return products;
    } catch (e) {
      _logDbError('Failed to fetch trending products', e);
      return [];
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
      final response = await _supabase.rpc(
        'get_seller_orders',
        params: {'p_seller_account_id': sellerAccountId},
      );
      final orders = List<Map<String, dynamic>>.from(response);
      final orderIds = orders
          .map((order) => order['order_id']?.toString() ?? '')
          .where((orderId) => orderId.isNotEmpty)
          .toList();

      if (orderIds.isEmpty) {
        return orders.map((order) {
          return {
            ...order,
            'buyer': order['account'],
            'order_items': <Map<String, dynamic>>[],
          };
        }).toList();
      }

      final itemResponse = await _supabase.rpc(
        'get_seller_order_items',
        params: {'p_seller_account_id': sellerAccountId},
      );

      final itemsByOrderId = <String, List<Map<String, dynamic>>>{};

      for (final item in List<Map<String, dynamic>>.from(itemResponse)) {
        final orderId = item['order_id']?.toString();
        if (orderId == null || orderId.isEmpty) continue;

        itemsByOrderId.putIfAbsent(orderId, () => []).add({
          'order_item_id': item['order_item_id'],
          'order_id': item['order_id'],
          'product_id': item['product_id'],
          'product_variant_id': item['product_variant_id'],
          'quantity': item['quantity'],
          'unit_price_at_sale': item['unit_price_at_sale'],
          'subtotal': item['subtotal'],
          'product': {
            'product_id': item['product_id'],
            'name': item['product_name'],
            'main_image_url': item['main_image_url'],
          },
          'product_variant': item['product_variant_id'] == null
              ? null
              : {
                  'variant_id': item['product_variant_id'],
                  'size_label': item['size_label'],
                },
        });
      }

      return orders.map((order) {
        final orderId = order['order_id']?.toString();

        return {
          ...order,
          'buyer': order['account'],
          'order_items': orderId == null
              ? <Map<String, dynamic>>[]
              : itemsByOrderId[orderId] ?? <Map<String, dynamic>>[],
        };
      }).toList();
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
      final riderAccountId = await getCurrentAccountId();
      if (riderAccountId == null) return [];

      final response = await _supabase.rpc(
        'get_rider_orders',
        params: {
          'p_rider_account_id': riderAccountId,
          'p_assigned_only': false,
        },
      );

      return _withOrderItems(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      _logDbError('Failed to fetch delivery orders', e);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getCurrentRiderOrders() async {
    try {
      final riderAccountId = await getCurrentAccountId();
      if (riderAccountId == null) return [];

      final response = await _supabase.rpc(
        'get_rider_orders',
        params: {
          'p_rider_account_id': riderAccountId,
          'p_assigned_only': true,
        },
      );

      return _withOrderItems(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      _logDbError('Failed to fetch rider orders', e);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _withOrderItems(
    List<Map<String, dynamic>> orders,
  ) async {
    final orderIds = orders
        .map((order) => order['order_id']?.toString() ?? '')
        .where((orderId) => orderId.isNotEmpty)
        .toList();
    if (orderIds.isEmpty) return orders;

    final response = await _supabase
        .from('order_items')
        .select(
          '*, product:product!order_items_product_id_fkey(product_id, name, main_image_url), product_variant:product_variant!order_items_product_variant_id_fkey(variant_id, size_label)',
        )
        .inFilter('order_id', orderIds)
        .order('order_item_id');

    final itemsByOrderId = <String, List<Map<String, dynamic>>>{};
    for (final item in List<Map<String, dynamic>>.from(response)) {
      final orderId = item['order_id']?.toString();
      if (orderId == null || orderId.isEmpty) continue;
      itemsByOrderId.putIfAbsent(orderId, () => []).add(item);
    }

    return orders.map((order) {
      final orderId = order['order_id']?.toString();
      return {
        ...order,
        'order_items': orderId == null
            ? <Map<String, dynamic>>[]
            : itemsByOrderId[orderId] ?? <Map<String, dynamic>>[],
      };
    }).toList();
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
          .select('''
            review_id,
            product_id,
            buyer_account_id,
            rating,
            comment,
            created_at,
            account:product_review_buyer_account_id_fkey (
              firstname,
              surname,
              email,
              profile_image_url
            )
          ''')
          .eq('product_id', productId)
          .order('created_at', ascending: false);

      debugPrint('Product Reviews: $response');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch product reviews', e);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getProductReviewsForStore(
    String storeId,
  ) async {
    try {
      final products = await _supabase
          .from('product')
          .select('product_id')
          .eq('store_id', storeId);

      final productIds = List<Map<String, dynamic>>.from(products)
          .map((item) => item['product_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      if (productIds.isEmpty) return [];

      final response = await _supabase
          .from('product_review')
          .select('''
            review_id,
            product_id,
            buyer_account_id,
            rating,
            comment,
            created_at,
            product:product_review_product_id_fkey (
              product_id,
              name
            ),
            account:product_review_buyer_account_id_fkey (
              firstname,
              surname,
              email,
              profile_image_url
            )
          ''')
          .inFilter('product_id', productIds)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch store product reviews', e);
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
    String? storeId,
  }) async {
    try {
      final coupons = await _supabase
          .from('discount_coupon')
          .select()
          .eq('code', code.trim().toUpperCase())
          .eq('is_active', true);

      Map<String, dynamic>? coupon;
      for (final item in List<Map<String, dynamic>>.from(coupons)) {
        final couponStoreId = item['store_id']?.toString();
        if (storeId != null && couponStoreId == storeId) {
          coupon = item;
          break;
        }
        if (couponStoreId == null || couponStoreId.isEmpty) {
          coupon ??= item;
        }
      }
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

  static Future<List<Map<String, dynamic>>> getCouponsForStore(
    String storeId,
  ) async {
    try {
      final response = await _supabase
          .from('discount_coupon')
          .select()
          .eq('store_id', storeId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch store coupons', e);
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
    String? storeId,
  }) async {
    try {
      await _supabase.from('discount_coupon').upsert({
        'code': code.trim().toUpperCase(),
        'store_id': _blankToNull(storeId),
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

  static Future<List<Map<String, dynamic>>> getProductDiscountsForStore(
    String storeId,
  ) async {
    try {
      final response = await _supabase
          .from('product_discount')
          .select('*, product(name, price, product_variant(*))')
          .eq('store_id', storeId)
          .order('starts_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch product discounts', e);
      return [];
    }
  }

  static Future<bool> saveProductDiscount({
    String? discountId,
    required String storeId,
    required String productId,
    required String discountType,
    required double discountValue,
    required String startsAt,
    required String endsAt,
    bool isActive = true,
  }) async {
    try {
      final accountId = await getCurrentAccountId();
      final data = {
        if (_blankToNull(discountId) != null) 'discount_id': discountId,
        'store_id': storeId,
        'product_id': productId,
        'discount_type': discountType,
        'discount_value': discountValue,
        'starts_at': startsAt,
        'ends_at': endsAt,
        'is_active': isActive,
        'created_by': accountId,
      };
      await _supabase.from('product_discount').upsert(data);
      return true;
    } catch (e) {
      _logDbError('Failed to save product discount', e);
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getProductDiscountPriceHistory(
    String productId,
  ) async {
    try {
      final response = await _supabase
          .from('product_discount_price_history')
          .select('*')
          .eq('product_id', productId)
          .order('recorded_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch product discount price history', e);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getProductPriceHistory(
    String productId,
  ) async {
    try {
      final response = await _supabase
          .from('product_price_history')
          .select()
          .eq('product_id', productId)
          .order('recorded_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch product price history', e);
      return [];
    }
  }

  static Future<bool> buyerHasDeliveredOrderFromStore(String storeId) async {
    try {
      final accountId = await getCurrentAccountId();
      if (accountId == null) return false;
      final store = await _supabase
          .from('store')
          .select('owner_account_id')
          .eq('store_id', storeId)
          .maybeSingle();
      final sellerAccountId = store?['owner_account_id']?.toString();
      if (sellerAccountId == null) return false;

      final delivered = await _supabase
          .from('orders')
          .select('order_id')
          .eq('buyer_account_id', accountId)
          .eq('seller_account_id', sellerAccountId)
          .eq('order_status', 'Delivered')
          .limit(1);
      return delivered.isNotEmpty;
    } catch (e) {
      _logDbError('Failed to check delivered store order', e);
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getStoreReviews(
    String storeId,
  ) async {
    try {
      final response = await _supabase
          .from('store_review')
          .select(
            '*, account!store_review_buyer_account_id_fkey(firstname, surname)',
          )
          .eq('store_id', storeId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch store reviews', e);
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getCurrentBuyerStoreReview(
    String storeId,
  ) async {
    try {
      final accountId = await getCurrentAccountId();
      if (accountId == null) return null;
      final response = await _supabase
          .from('store_review')
          .select()
          .eq('store_id', storeId)
          .eq('buyer_account_id', accountId)
          .maybeSingle();
      return response == null ? null : Map<String, dynamic>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch own store review', e);
      return null;
    }
  }

  static Future<bool> saveStoreReview({
    required String storeId,
    required int rating,
    String? comment,
  }) async {
    try {
      final accountId = await getCurrentAccountId();
      if (accountId == null) return false;

      await _supabase.from('store_review').upsert({
        'store_id': storeId,
        'buyer_account_id': accountId,
        'rating': rating,
        'comment': _blankToNull(comment),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'store_id,buyer_account_id');
      return true;
    } catch (e) {
      _logDbError('Failed to save store review', e);
      return false;
    }
  }

  static Future<bool> reportStore({
    required String storeId,
    required String reason,
    String? details,
    bool isOrderRelated = false,
  }) async {
    try {
      final accountId = await getCurrentAccountId();
      if (accountId == null) return false;
      await _supabase.from('store_report').insert({
        'store_id': storeId,
        'reporter_account_id': accountId,
        'reason': reason.trim(),
        'details': _blankToNull(details),
        'is_order_related': isOrderRelated,
      });
      return true;
    } catch (e) {
      _logDbError('Failed to report store', e);
      return false;
    }
  }

  static Future<bool> reportProduct({
    required String productId,
    String? storeId,
    required String reason,
    String? details,
  }) async {
    try {
      final accountId = await getCurrentAccountId();
      if (accountId == null) return false;
      await _supabase.from('product_report').insert({
        'product_id': productId,
        'store_id': _blankToNull(storeId),
        'reporter_account_id': accountId,
        'reason': reason.trim(),
        'details': _blankToNull(details),
      });
      return true;
    } catch (e) {
      _logDbError('Failed to report product', e);
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getAdminStoreReports() async {
    try {
      final response = await _supabase
          .from('store_report')
          .select(
            '*, store(store_id, store_name), account!store_report_reporter_account_id_fkey(account_id, firstname, surname, email)',
          )
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch store reports', e);
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAdminProductReports() async {
    try {
      final response = await _supabase
          .from('product_report')
          .select(
            '*, product(product_id, name), store(store_id, store_name), account!product_report_reporter_account_id_fkey(account_id, firstname, surname, email)',
          )
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logDbError('Failed to fetch product reports', e);
      return [];
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
    var successfulOrders = 0;

    for (final order in orders) {
      if (!_isSuccessfulOrder(order)) continue;
      successfulOrders++;
      revenue += order.containsKey('seller_payout')
          ? _toDouble(order['seller_payout'])
          : _toDouble(order['total_amount']);
      final items = order['order_items'];
      if (items is List) {
        for (final item in items) {
          itemsSold += _toInt(item['quantity']);
        }
      }
    }

    return {
      'orders': successfulOrders,
      'revenue': revenue,
      'itemsSold': itemsSold,
    };
  }

  static Future<List<Map<String, dynamic>>> _withProductRatings(
    List<Map<String, dynamic>> products,
  ) async {
    if (products.isEmpty) return products;
    try {
      final productIds = products
          .map((product) => product['product_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      if (productIds.isEmpty) return products;

      final reviews = await _supabase
          .from('product_review')
          .select('product_id, rating')
          .inFilter('product_id', productIds);
      final discounts = await _supabase
          .from('product_discount')
          .select()
          .inFilter('product_id', productIds)
          .order('starts_at', ascending: false);

      final totals = <String, double>{};
      final counts = <String, int>{};
      for (final review in List<Map<String, dynamic>>.from(reviews)) {
        final productId = review['product_id']?.toString();
        if (productId == null || productId.isEmpty) continue;
        totals[productId] = (totals[productId] ?? 0) + _toDouble(review['rating']);
        counts[productId] = (counts[productId] ?? 0) + 1;
      }
      final discountsByProduct = <String, List<Map<String, dynamic>>>{};
      for (final discount in List<Map<String, dynamic>>.from(discounts)) {
        final productId = discount['product_id']?.toString();
        if (productId == null || productId.isEmpty) continue;
        discountsByProduct.putIfAbsent(productId, () => []).add(discount);
      }

      return products.map((product) {
        final productId = product['product_id']?.toString() ?? '';
        final count = counts[productId] ?? 0;
        return {
          ...product,
          'average_rating': count == 0 ? 0.0 : (totals[productId] ?? 0) / count,
          'review_count': count,
          'product_discount': discountsByProduct[productId] ??
              product['product_discount'] ??
              <Map<String, dynamic>>[],
        };
      }).toList();
    } catch (e) {
      _logDbError('Failed to attach product ratings', e);
      return products
          .map((product) => {
                ...product,
                'average_rating': 0.0,
                'review_count': 0,
              })
          .toList();
    }
  }

  // Fetch all products
  static Future<List<Map<String, dynamic>>> fetchProducts() async {
    try {
      final response = await _supabase
          .from('product')
          .select('''
            *,
            product_variant(*),
            product_discount(*)
          ''')
          .eq('is_active', true)
          .order('product_id', ascending: false);

      return _withProductRatings(List<Map<String, dynamic>>.from(response));
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
          .select('*, store(store_id, store_name), product_variant(*)')
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

      var products = await _withProductRatings(List<Map<String, dynamic>>.from(response));
      if (sort == 'Popular') {
        products.sort((a, b) {
          final byCount = _toInt(b['review_count']).compareTo(
            _toInt(a['review_count']),
          );
          if (byCount != 0) return byCount;
          return _toDouble(b['average_rating']).compareTo(
            _toDouble(a['average_rating']),
          );
        });
      }
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
    final value = fileName.trim();
    if (value.startsWith('http')) return value;
    return _supabase.storage.from('profile-images').getPublicUrl(value);
  }

  static Future<String?> uploadProfileImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      if (!isAllowedImageName(fileName)) return null;
      final extension = _extensionFor(fileName);
      final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';
      final mimeType = imageContentTypeFor(fileName)!;

      await _supabase.storage
          .from('profile-images')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: false,
              contentType: mimeType,
            ),
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
      if (!isAllowedApplicationDocumentName(fileName)) return null;
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
      final mimeType = applicationDocumentContentTypeFor(fileName)!;

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
      if (!isAllowedImageName(fileName)) return null;
      final extension = _extensionFor(fileName);
      final path =
          '$orderId/${user.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';
      final mimeType = imageContentTypeFor(fileName)!;

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
            account:seller_application_account_id_fkey (
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
            account:rider_application_account_id_fkey (
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
    String? reviewNotes,
  }) async {
    try {
      final approvedAt = DateTime.now().toIso8601String();
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
          .from('account')
          .update({
            'account_type': 'Rider',
            'is_verified': true,
            'date_verified': approvedAt,
          })
          .eq('account_id', accountId);
      if (application != null) {
        try {
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
        } catch (addressError) {
          _logDbError('Failed to save approved rider address', addressError);
        }
      }
      await _supabase
          .from('rider_application')
          .update({
            'status': 'Approved',
            'review_notes': _blankToNull(reviewNotes),
            'date_approved': approvedAt,
            'zip_code': _blankToNull(resolvedZipCode),
            'latitude': point?.latitude ?? _toDouble(application?['latitude']),
            'longitude': point?.longitude ?? _toDouble(application?['longitude']),
          })
          .eq('rider_app_id', applicationId);
      await _sendApplicationNotification(
        accountId: accountId,
        approved: true,
        role: 'Rider',
        notes: reviewNotes,
      );
      return true;
    } catch (e) {
      _logDbError('Failed to approve rider application', e);
      final account = await _supabase
          .from('account')
          .select('account_type')
          .eq('account_id', accountId)
          .maybeSingle();
      final app = await getRiderApplicationByAccountId(accountId);
      return account?['account_type'] == 'Rider' &&
          app?['status'] == 'Approved';
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
      final application = await _supabase
          .from('rider_application')
          .select('account_id')
          .eq('rider_app_id', applicationId)
          .maybeSingle();
      final accountId = application?['account_id']?.toString();
      if (accountId != null) {
        await _sendApplicationNotification(
          accountId: accountId,
          approved: false,
          role: 'Rider',
          notes: reviewNotes,
        );
      }
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
    String? reviewNotes,
  }) async {
    try {
      final approvedAt = DateTime.now().toIso8601String();
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

      // Update account type to Seller
      await _supabase
          .from('account')
          .update({
            'account_type': 'Seller',
            'is_verified': true,
            'date_verified': approvedAt,
          })
          .eq('account_id', accountId);

      final existingStore = await _supabase
          .from('store')
          .select('store_id, slug')
          .eq('owner_account_id', accountId)
          .maybeSingle();
      final baseSlug = _slugFor(storeName);
      final slug = existingStore?['slug']?.toString() ?? '$baseSlug-${accountId.substring(0, 8)}';

      final storeData = {
        'owner_account_id': accountId,
        'store_name': storeName,
        'slug': slug,
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

      try {
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
      } catch (addressError) {
        _logDbError('Failed to save approved seller address', addressError);
      }
      await _supabase
          .from('seller_application')
          .update({
            'status': 'Approved',
            'review_notes': _blankToNull(reviewNotes),
            'date_approved': approvedAt,
            'zip_code': _blankToNull(resolvedZipCode),
          })
          .eq('application_id', applicationId);
      await _sendApplicationNotification(
        accountId: accountId,
        approved: true,
        role: 'Seller',
        notes: reviewNotes,
      );
      return true;
    } catch (e) {
      _logDbError('Failed to approve seller application', e);
      final account = await _supabase
          .from('account')
          .select('account_type')
          .eq('account_id', accountId)
          .maybeSingle();
      final app = await getSellerApplicationByAccountId(accountId);
      return account?['account_type'] == 'Seller' &&
          app?['status'] == 'Approved';
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
      final application = await _supabase
          .from('seller_application')
          .select('account_id')
          .eq('application_id', applicationId)
          .maybeSingle();
      final accountId = application?['account_id']?.toString();
      if (accountId != null) {
        await _sendApplicationNotification(
          accountId: accountId,
          approved: false,
          role: 'Seller',
          notes: reviewNotes,
        );
      }
    } catch (e) {
      _logDbError('Failed to reject seller application', e);
    }
  }

  static Future<void> _sendApplicationNotification({
    required String accountId,
    required bool approved,
    required String role,
    String? notes,
  }) async {
    final title = '$role application ${approved ? 'approved' : 'rejected'}';
    final fallback = approved
        ? 'Your $role application has been approved.'
        : 'Your $role application was rejected.';
    final body = _blankToNull(notes) ?? fallback;

    try {
      await _supabase.from('notification').insert({
        'account_id': accountId,
        'title': title,
        'body': body,
        'notification_type': 'Application',
      });
    } catch (e) {
      _logDbError('Failed to send application notification', e);
    }

    try {
      final account = await _supabase
          .from('account')
          .select('firstname, surname, email')
          .eq('account_id', accountId)
          .maybeSingle();
      final email = account?['email']?.toString();
      if (_blankToNull(email) == null) return;

      final firstName = account?['firstname']?.toString() ?? '';
      final surname = account?['surname']?.toString() ?? '';
      final name = '$firstName $surname'.trim();
      final escapedBody = body
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;')
          .replaceAll('\n', '<br>');

      await _supabase.functions.invoke(
        'send-application-email',
        body: {
          'toEmail': email,
          'toName': name.isEmpty ? email : name,
          'subject': title,
          'textContent': body,
          'htmlContent':
              '<html><body><p>Hello ${name.isEmpty ? 'there' : name},</p><p>$escapedBody</p></body></html>',
        },
      );
    } catch (e) {
      _logDbError('Failed to send application email', e);
    }
  }
}
