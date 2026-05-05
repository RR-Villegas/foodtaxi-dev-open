import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class LocalStorageService {
  static const String _signupDataKey = 'signup_data';

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
}
