import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class LocalStorageService {
  static const String _signupDataKey = 'signup_data';
  static const String _sessionTokenKey = 'session_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _accountTypeKey = 'account_type';
  static const String _lastLoginKey = 'last_login_timestamp';

  // ============== Signup Data Management ==============

  // Save signup data
  static Future<void> saveSignupData(UserSignupData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_signupDataKey, data.toJsonString());
  }

  // Load signup data
  static Future<UserSignupData?> loadSignupData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_signupDataKey);
    if (jsonString != null) {
      return UserSignupData.fromJsonString(jsonString);
    }
    return null;
  }

  // Clear signup data
  static Future<void> clearSignupData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_signupDataKey);
  }

  // Check if signup data exists
  static Future<bool> hasSignupData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_signupDataKey);
  }

  // ============== Session Token Management ==============

  /// Save session tokens and user info for persistent login
  static Future<void> saveSession({
    required String sessionToken,
    required String refreshToken,
    required String userId,
    required String userEmail,
    required String? accountType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_sessionTokenKey, sessionToken),
      prefs.setString(_refreshTokenKey, refreshToken),
      prefs.setString(_userIdKey, userId),
      prefs.setString(_userEmailKey, userEmail),
      if (accountType != null) prefs.setString(_accountTypeKey, accountType),
      prefs.setInt(_lastLoginKey, DateTime.now().millisecondsSinceEpoch),
    ]);
  }

  /// Retrieve session token
  static Future<String?> getSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionTokenKey);
  }

  /// Retrieve refresh token
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  /// Retrieve stored user ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Retrieve stored user email
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  /// Retrieve stored account type
  static Future<String?> getAccountType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accountTypeKey);
  }

  /// Get last login timestamp
  static Future<DateTime?> getLastLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastLoginKey);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  /// Check if session exists and is valid
  static Future<bool> hasValidSession() async {
    final token = await getSessionToken();
    return token != null && token.isNotEmpty;
  }

  /// Clear session (logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_sessionTokenKey),
      prefs.remove(_refreshTokenKey),
      prefs.remove(_userIdKey),
      prefs.remove(_userEmailKey),
      prefs.remove(_accountTypeKey),
    ]);
    // Keep last login for analytics
  }

  /// Clear all stored data
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
