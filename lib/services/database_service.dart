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
      throw Exception('Failed to insert address: $e');
}
  }

  // Insert user profile after signup
  static Future<void> insertUserProfile({
    required String id,
    required String fullName,
    String? phoneNumber,
    required String role,
  }) async {
    try {
      await _supabase
          .from('profiles')
          .insert({
            'id': id,
            'full_name': fullName,
            'phone_number': phoneNumber ?? '',
            'role': role,
          });
    } catch (e) {
      throw Exception('Failed to insert user profile: $e');
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
      throw Exception('Failed to fetch addresses: $e');
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
      throw Exception('Failed to update address: $e');
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
      throw Exception('Failed to delete address: $e');
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
      throw Exception('Failed to set default address: $e');
    }
  }
}
