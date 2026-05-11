import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_service.dart';

/// Authorization service for route protection and permission checks
class AuthService {
  static final _supabase = Supabase.instance.client;

  /// Check if user is authenticated
  static bool isAuthenticated() {
    return _supabase.auth.currentUser != null;
  }

  /// Get current user's account type
  static Future<String?> getCurrentUserType() {
    return DatabaseService.getCurrentAccountType();
  }

  /// Check if user has specific role
  static Future<bool> hasRole(String requiredRole) async {
    try {
      final userType = await getCurrentUserType();
      return userType?.toLowerCase() == requiredRole.toLowerCase();
    } catch (e) {
      debugPrint('Error checking role: $e');
      return false;
    }
  }

  /// Check if user is admin
  static Future<bool> isAdmin() => hasRole('Admin');

  /// Check if user is seller
  static Future<bool> isSeller() => hasRole('Seller');

  /// Check if user is buyer
  static Future<bool> isBuyer() => hasRole('Buyer');

  /// Check if user is rider
  static Future<bool> isRider() => hasRole('Rider');

  /// Verify user has access to specific resource (ownership check)
  static Future<bool> canAccessResource(String resourceOwnerId) async {
    try {
      final currentAccountId = await DatabaseService.getCurrentAccountId();
      return currentAccountId == resourceOwnerId;
    } catch (e) {
      debugPrint('Error verifying resource access: $e');
      return false;
    }
  }

  /// Verify admin access before route navigation
  static Future<bool> verifyAdminAccess() async {
    final isAdmin = await AuthService.isAdmin();
    if (!isAdmin) {
      debugPrint('WARNING: Unauthorized admin access attempt detected');
      return false;
    }
    return true;
  }

  /// Verify seller access before route navigation
  static Future<bool> verifySellerAccess() async {
    final isSeller = await AuthService.isSeller();
    if (!isSeller) {
      debugPrint('WARNING: Unauthorized seller access attempt detected');
      return false;
    }
    return true;
  }

  /// Verify buyer access before route navigation
  static Future<bool> verifyBuyerAccess() async {
    final isBuyer = await AuthService.isBuyer();
    if (!isBuyer) {
      debugPrint('WARNING: Unauthorized buyer access attempt detected');
      return false;
    }
    return true;
  }

  /// Log security event for audit trail
  static void logSecurityEvent(String eventType, String details) {
    final timestamp = DateTime.now().toIso8601String();
    final userId = _supabase.auth.currentUser?.id ?? 'anonymous';
    debugPrint('[SECURITY] $timestamp | Event: $eventType | User: $userId | Details: $details');
  }
}
