import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_service.dart';
import 'local_storage_service.dart';

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

  // ============== Session Management (Persistent Login) ==============

  /// Save session after successful login
  static Future<void> saveLoginSession(User user) async {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        await LocalStorageService.saveSession(
          sessionToken: session.accessToken,
          refreshToken: session.refreshToken ?? '',
          userId: user.id,
          userEmail: user.email ?? '',
          accountType: await getCurrentUserType(),
        );
        logSecurityEvent('LOGIN_SESSION_SAVED', 'Session stored for user: ${user.email}');
      }
    } catch (e) {
      debugPrint('Error saving login session: $e');
    }
  }

  /// Restore session from stored credentials (auto-login on app start)
  static Future<bool> restoreSession() async {
    try {
      final hasValidSession = await LocalStorageService.hasValidSession();
      if (!hasValidSession) {
        debugPrint('No valid session found in storage');
        return false;
      }

      final sessionToken = await LocalStorageService.getSessionToken();
      final refreshToken = await LocalStorageService.getRefreshToken();

      if (sessionToken == null || refreshToken == null) {
        await clearLoginSession();
        return false;
      }

      // Verify the session is still valid with Supabase
      try {
        // Attempt to refresh the session
        await _supabase.auth.refreshSession();
        logSecurityEvent('SESSION_RESTORED', 'Session restored from storage');
        return true;
      } catch (e) {
        // Session expired or invalid, clear it
        debugPrint('Session refresh failed: $e');
        await clearLoginSession();
        return false;
      }
    } catch (e) {
      debugPrint('Error restoring session: $e');
      return false;
    }
  }

  /// Get stored user info without requiring active session
  static Future<Map<String, String?>> getStoredUserInfo() async {
    return {
      'userId': await LocalStorageService.getUserId(),
      'email': await LocalStorageService.getUserEmail(),
      'accountType': await LocalStorageService.getAccountType(),
    };
  }

  /// Clear login session (logout)
  static Future<void> clearLoginSession() async {
    try {
      // Sign out from Supabase
      await _supabase.auth.signOut();
      
      // Clear stored credentials
      await LocalStorageService.clearSession();
      
      logSecurityEvent('LOGOUT', 'User session cleared');
    } catch (e) {
      debugPrint('Error clearing login session: $e');
      // Even if Supabase logout fails, clear local storage
      await LocalStorageService.clearSession();
    }
  }

  /// Check if session is still valid and refresh if needed
  static Future<bool> isSessionValid() async {
    try {
      if (!isAuthenticated()) {
        return false;
      }

      // Try to refresh to ensure token is still valid
      await _supabase.auth.refreshSession();
      return true;
    } catch (e) {
      debugPrint('Session validation failed: $e');
      return false;
    }
  }
}
