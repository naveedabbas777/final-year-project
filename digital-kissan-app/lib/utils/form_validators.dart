/// Validation helpers for forms
class FormValidators {
  /// Validates email format
  static bool isValidEmail(String email) {
    final trimmed = email.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
  }

  /// Validates phone number (digits only, 7-15 digits)
  static bool isValidPhone(String phone) {
    final trimmed = phone.trim();
    return RegExp(r'^\d{7,15}$').hasMatch(trimmed);
  }

  /// Validates password (minimum 6 characters)
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  /// Validates name (not empty, at least 2 characters)
  static bool isValidName(String name) {
    final trimmed = name.trim();
    return trimmed.length >= 2;
  }

  /// Validates crop name (not empty, at most 50 characters)
  static bool isValidCropName(String crop) {
    final trimmed = crop.trim();
    return trimmed.isNotEmpty && trimmed.length <= 50;
  }

  /// Validates district (not empty, at most 50 characters)
  static bool isValidDistrict(String district) {
    final trimmed = district.trim();
    return trimmed.isNotEmpty && trimmed.length <= 50;
  }

  /// Validates quantity (positive number, max 999999)
  static bool isValidQuantity(String quantity) {
    final trimmed = quantity.trim();
    final value = double.tryParse(trimmed);
    return value != null && value > 0 && value <= 999999;
  }

  /// Validates price (positive number, max 9999999)
  static bool isValidPrice(String price) {
    final trimmed = price.trim();
    final value = double.tryParse(trimmed);
    return value != null && value > 0 && value <= 9999999;
  }

  /// Returns user-friendly error message for email
  static String? validateEmail(String email) {
    if (email.trim().isEmpty) return 'Email is required.';
    if (!isValidEmail(email)) return 'Please enter a valid email address.';
    return null;
  }

  /// Returns user-friendly error message for phone
  static String? validatePhone(String phone) {
    if (phone.trim().isEmpty) return 'Phone number is required.';
    if (!isValidPhone(phone)) return 'Phone must be 7-15 digits.';
    return null;
  }

  /// Returns user-friendly error message for password
  static String? validatePassword(String password) {
    if (password.isEmpty) return 'Password is required.';
    if (!isValidPassword(password))
      return 'Password must be at least 6 characters.';
    return null;
  }

  /// Returns user-friendly error message for name
  static String? validateName(String name) {
    if (name.trim().isEmpty) return 'Name is required.';
    if (!isValidName(name)) return 'Name must be at least 2 characters.';
    return null;
  }

  /// Returns user-friendly error message for crop name
  static String? validateCropName(String crop) {
    if (crop.trim().isEmpty) return 'Crop name is required.';
    if (!isValidCropName(crop)) return 'Crop name must be 1-50 characters.';
    return null;
  }

  /// Returns user-friendly error message for district
  static String? validateDistrict(String district) {
    if (district.trim().isEmpty) return 'District is required.';
    if (!isValidDistrict(district)) return 'District must be 1-50 characters.';
    return null;
  }

  /// Returns user-friendly error message for quantity
  static String? validateQuantity(String quantity) {
    if (quantity.trim().isEmpty) return 'Quantity is required.';
    if (!isValidQuantity(quantity))
      return 'Quantity must be between 0 and 999,999.';
    return null;
  }

  /// Returns user-friendly error message for price
  static String? validatePrice(String price) {
    if (price.trim().isEmpty) return 'Price is required.';
    if (!isValidPrice(price)) return 'Price must be between 0 and 9,999,999.';
    return null;
  }
}
