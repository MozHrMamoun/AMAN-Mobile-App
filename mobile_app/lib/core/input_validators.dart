class InputValidators {
  InputValidators._();

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _passwordPattern = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z\d]).{8,}$',
  );
  static final RegExp _idNumberPattern = RegExp(r'^\d{11}$');
  static final RegExp _phonePattern = RegExp(r'^\+249\d{9}$');

  static String? validateEmail(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'Please enter your email.';
    }
    if (!_emailPattern.hasMatch(normalized)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  static String? validateStrongPassword(String password) {
    final trimmed = password.trim();
    if (trimmed.isEmpty) {
      return 'Please enter your password.';
    }
    if (!_passwordPattern.hasMatch(trimmed)) {
      return 'Password must be at least 8 characters and include uppercase, lowercase, number, and special character.';
    }
    return null;
  }

  static String? validateIdNumber(String idNumber) {
    final trimmed = idNumber.trim();
    if (trimmed.isEmpty) {
      return 'Please enter your ID number.';
    }
    if (!_idNumberPattern.hasMatch(trimmed)) {
      return 'ID number must be exactly 11 digits.';
    }
    return null;
  }

  static String? validateSudanPhoneNumber(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) {
      return 'Please enter your phone number.';
    }
    if (!_phonePattern.hasMatch(trimmed)) {
      return 'Phone number must start with +249 and contain 9 digits after it.';
    }
    return null;
  }
}
