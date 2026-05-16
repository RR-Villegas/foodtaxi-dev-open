import 'package:flutter/foundation.dart';

/// Input validation and sanitization service to prevent XSS and injection attacks
class InputValidator {
  /// Dangerous characters that could be used for XSS/injection
  static const String _dangerousChars = '<>"\';()[]{}';

  /// HTML/JavaScript dangerous tags
  static const List<String> _dangerousTags = [
    '<script',
    '</script',
    '<iframe',
    '</iframe',
    '<svg',
    '</svg',
    'onclick',
    'onerror',
    'onload',
    'onmouseover',
    'javascript:',
    '<img',
    '<embed',
    '<object',
    '<form',
    '<input'
  ];

  /// Sanitize user input to prevent XSS attacks
  /// Removes or escapes potentially dangerous characters and HTML tags
  static String sanitizeInput(String input) {
    if (input.isEmpty) return '';

    String sanitized = input;

    // Check for dangerous HTML tags (case-insensitive)
    for (final tag in _dangerousTags) {
      sanitized = sanitized.replaceAll(
        RegExp(tag, caseSensitive: false),
        '',
      );
    }

    // Escape HTML special characters
    sanitized = _escapeHtml(sanitized);

    // Remove control characters
    sanitized = sanitized.replaceAll(
      RegExp(r'[\x00-\x1F\x7F]'),
      '',
    );

    return sanitized.trim();
  }

  /// Escape HTML special characters
  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;

    final sanitized = sanitizeInput(email).trim();

    // RFC 5322 simplified email regex
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
    );

    return emailRegex.hasMatch(sanitized) &&
        sanitized.length <= 254;
  }

  /// Validate Philippine phone numbers
  static bool isValidPhoneNumber(String phone) {
    if (phone.isEmpty) return false;

    final sanitized = phone.replaceAll(RegExp(r'\D'), '');

    // Accept local 9xxxxxxxxx input, 09xxxxxxxxx, +639xxxxxxxxx,
    // and 639xxxxxxxxx.
    final phoneRegex = RegExp(
      r'^(9\d{9}|09\d{9}|639\d{9})$',
    );

    return phoneRegex.hasMatch(sanitized);
  }

  /// Validate URL format
  static bool isValidUrl(String url) {
    if (url.isEmpty) return false;

    try {
      final uri = Uri.parse(url);

      return uri.hasScheme &&
          (uri.scheme == 'http' ||
              uri.scheme == 'https' ||
              uri.scheme == 'ftp');
    } catch (e) {
      return false;
    }
  }

  /// Validate password strength
  static bool isValidPassword(String password) {
    if (password.isEmpty || password.length < 8) {
      return false;
    }

    // At least one uppercase, one lowercase,
    // one digit, one special character
    final hasUppercase =
        RegExp(r'[A-Z]').hasMatch(password);

    final hasLowercase =
        RegExp(r'[a-z]').hasMatch(password);

    final hasDigits =
        RegExp(r'\d').hasMatch(password);

    final hasSpecialChar = RegExp(
      r'[!@#$%^&*(),.?":{}|<>]',
    ).hasMatch(password);

    return hasUppercase &&
        hasLowercase &&
        hasDigits &&
        hasSpecialChar;
  }

  /// Get password strength message
  static String getPasswordStrengthMessage(
    String password,
  ) {
    if (password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    final hasUppercase =
        RegExp(r'[A-Z]').hasMatch(password);

    final hasLowercase =
        RegExp(r'[a-z]').hasMatch(password);

    final hasDigits =
        RegExp(r'\d').hasMatch(password);

    final hasSpecialChar = RegExp(
      r'[!@#$%^&*(),.?":{}|<>]',
    ).hasMatch(password);

    int strength = 0;

    if (hasUppercase) strength++;
    if (hasLowercase) strength++;
    if (hasDigits) strength++;
    if (hasSpecialChar) strength++;

    switch (strength) {
      case 1:
        return 'Weak password';

      case 2:
        return 'Fair password';

      case 3:
        return 'Good password';

      case 4:
        return 'Strong password';

      default:
        return 'Very weak password';
    }
  }

  /// Validate name
  /// Allows letters, spaces, apostrophes, and hyphens
  static bool isValidName(String name) {
    if (name.isEmpty) return false;

    final sanitized = sanitizeInput(name).trim();

    final nameRegex = RegExp(
      r"^[a-zA-Z\s'-]{2,100}$",
    );

    return nameRegex.hasMatch(sanitized);
  }

  /// Validate store name
  static bool isValidStoreName(String name) {
    if (name.isEmpty) return false;

    final sanitized = sanitizeInput(name).trim();

    return sanitized.length >= 3 &&
        sanitized.length <= 100;
  }

  /// Validate product name
  static bool isValidProductName(String name) {
    if (name.isEmpty) return false;

    final sanitized = sanitizeInput(name).trim();

    return sanitized.length >= 2 &&
        sanitized.length <= 255;
  }

  /// Check for possible SQL injection patterns
  static bool containsSQLInjectionPatterns(
    String input,
  ) {
    if (input.isEmpty) return false;

    final sqlPatterns = [
      RegExp(
        r'(\b(UNION|SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER)\b)',
        caseSensitive: false,
      ),

      RegExp(
        r"[';][\s]*(OR|AND)[\s]*['=]",
        caseSensitive: false,
      ),

      RegExp(r'--[\s]*$'),

      RegExp(
        r'/\*.*?\*/',
        dotAll: true,
      ),
    ];

    for (final pattern in sqlPatterns) {
      if (pattern.hasMatch(input)) {
        debugPrint(
          'WARNING: Potential SQL injection detected: $input',
        );

        return true;
      }
    }

    return false;
  }

  /// Validate and sanitize user input
  static String? validateAndSanitize(
    String input, {
    required String fieldName,
    required int maxLength,
    bool allowSpecialChars = false,
    bool isEmail = false,
    bool isPhone = false,
  }) {
    if (input.isEmpty) {
      return '$fieldName is required';
    }

    if (containsSQLInjectionPatterns(input)) {
      return '$fieldName contains invalid characters';
    }

    if (isEmail && !isValidEmail(input)) {
      return 'Invalid email format';
    }

    if (isPhone && !isValidPhoneNumber(input)) {
      return 'Invalid phone number format';
    }

    final sanitized = sanitizeInput(input);

    if (sanitized.length > maxLength) {
      return '$fieldName exceeds maximum length of $maxLength characters';
    }

    if (sanitized.isEmpty &&
        input.isNotEmpty) {
      return '$fieldName contains invalid characters';
    }

    return null; // No error
  }
}
