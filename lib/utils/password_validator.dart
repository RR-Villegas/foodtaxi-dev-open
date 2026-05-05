import 'package:flutter/material.dart';

enum PasswordStrength { weak, fair, good, strong }

class PasswordValidator {
  // Safe characters for password: alphanumeric + safe special characters
  // Excluded: _ - and other SQL injection risky characters
  static const String allowedSpecialChars = '@#\$%^&*+=!~';
  static const String allowedChars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789$allowedSpecialChars';

  /// Validates password contains only safe characters
  static bool isValidCharacters(String password) {
    for (int i = 0; i < password.length; i++) {
      if (!allowedChars.contains(password[i])) {
        return false;
      }
    }
    return true;
  }

  /// Calculates password strength
  static PasswordStrength calculateStrength(String password) {
    if (password.isEmpty) {
      return PasswordStrength.weak;
    }

    int score = 0;

    // Length score
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;

    // Character variety
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasNumber = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[@#\$%^&*+=!~]'));

    if (hasLower) score++;
    if (hasUpper) score++;
    if (hasNumber) score++;
    if (hasSpecial) score++;

    // Return strength based on score
    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.fair;
    if (score <= 6) return PasswordStrength.good;
    return PasswordStrength.strong;
  }

  /// Gets color for password strength indicator
  static Color getStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return const Color(0xFFE53935);
      case PasswordStrength.fair:
        return const Color(0xFFFFA726);
      case PasswordStrength.good:
        return const Color(0xFFFFCA28);
      case PasswordStrength.strong:
        return const Color(0xFF43A047);
    }
  }

  /// Gets text label for password strength
  static String getStrengthLabel(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.fair:
        return 'Fair';
      case PasswordStrength.good:
        return 'Good';
      case PasswordStrength.strong:
        return 'Strong';
    }
  }

  /// Get feedback message
  static String getFeedback(String password) {
    if (!isValidCharacters(password)) {
      return 'Contains invalid characters. Use: a-z, A-Z, 0-9, @#\$%^&*+=!~';
    }
    return '';
  }
}
