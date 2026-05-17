/// Shared form field validators. Use these in TextFormField.validator callbacks.
/// All validators trim input before checking so surrounding whitespace is
/// treated as empty. The trimmed value is what callers should submit.
class InputValidators {
  InputValidators._();

  static String? required(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String? name(String? value, {String label = 'Name'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label is required';
    if (v.length < 2) return '$label must be at least 2 characters';
    if (v.length > 100) return '$label must be under 100 characters';
    return null;
  }

  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null; // phone is typically optional
    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(v)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? shortText(String? value, {String label = 'Title', int max = 255}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label is required';
    if (v.length > max) return '$label must be under $max characters';
    return null;
  }

  static String? longText(String? value, {String label = 'Description', int max = 2000}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$label is required';
    if (v.length > max) return '$label must be under $max characters';
    return null;
  }

  static String? optionalText(String? value, {int max = 500}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (v.length > max) return 'Must be under $max characters';
    return null;
  }

  static String? vehicleNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final v = value.trim().toUpperCase();
    if (v.length > 20) return 'Vehicle number too long';
    return null;
  }

  static String? otp(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter the OTP';
    if (!RegExp(r'^\d{6}$').hasMatch(v)) return 'OTP must be 6 digits';
    return null;
  }
}
