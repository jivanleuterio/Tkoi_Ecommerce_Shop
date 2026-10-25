class Validators {
  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required.';
    return null;
  }

  static String? text(
    String? value,
    String label, {
    int min = 2,
    int max = 100,
  }) {
    final requiredMessage = required(value, label);
    if (requiredMessage != null) return requiredMessage;
    final clean = value!.trim();
    if (clean.length < min) return '$label must have at least $min characters.';
    if (clean.length > max) return '$label cannot exceed $max characters.';
    if (!RegExp(r'[A-Za-z0-9]').hasMatch(clean)) {
      return '$label must contain letters or numbers.';
    }
    return null;
  }

  static String? personName(String? value, {String label = 'Full name'}) {
    final lengthError = text(value, label, min: 2, max: 80);
    if (lengthError != null) return lengthError;
    if (!RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿÑñ .'-]+$").hasMatch(value!.trim())) {
      return '$label contains invalid characters.';
    }
    return null;
  }

  static String? username(String? value) {
    final requiredMessage = required(value, 'Username');
    if (requiredMessage != null) return requiredMessage;
    if (!RegExp(r'^[A-Za-z0-9_]{3,30}$').hasMatch(value!.trim())) {
      return 'Use 3–30 letters, numbers, or underscores.';
    }
    return null;
  }

  static String? email(String? value) {
    final requiredMessage = required(value, 'Email');
    if (requiredMessage != null) return requiredMessage;
    final clean = value!.trim();
    final pattern = RegExp(
      r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
    );
    if (clean.length > 254 || !pattern.hasMatch(clean)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? phone(String? value) {
    final requiredMessage = required(value, 'Mobile number');
    if (requiredMessage != null) return requiredMessage;
    final clean = value!.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (!RegExp(r'^(?:\+639|09)\d{9}$').hasMatch(clean)) {
      return 'Use a Philippine number like 09171234567 or +639171234567.';
    }
    return null;
  }

  static String? address(String? value, {String label = 'Address'}) =>
      text(value, label, min: 10, max: 300);

  static String? password(String? value, {String? username, String? email}) {
    final requiredMessage = required(value, 'Password');
    if (requiredMessage != null) return requiredMessage;
    final password = value!;
    if (password.length < 8) return 'Use at least 8 characters.';
    if (password.length > 72) return 'Password cannot exceed 72 characters.';
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Add at least one uppercase letter.';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Add at least one lowercase letter.';
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return 'Add at least one number.';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Add at least one special character.';
    }
    final lower = password.toLowerCase();
    const commonPasswords = {
      'password1!',
      'password123!',
      'qwerty123!',
      'admin123!',
    };
    if (commonPasswords.contains(lower)) {
      return 'Choose a less common password.';
    }
    final cleanUsername = username?.trim().toLowerCase() ?? '';
    final emailName = email?.trim().split('@').first.toLowerCase() ?? '';
    if ((cleanUsername.length >= 3 && lower.contains(cleanUsername)) ||
        (emailName.length >= 3 && lower.contains(emailName))) {
      return 'Password cannot contain your username or email name.';
    }
    return null;
  }

  static String? price(String? value) {
    final number = num.tryParse(value?.trim() ?? '');
    if (number == null || number < 1 || number > 1000000) {
      return 'Enter a price from ₱1 to ₱1,000,000.';
    }
    return null;
  }

  static String? quantity(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < 0 || number > 10000) {
      return 'Enter a quantity from 0 to 10,000.';
    }
    return null;
  }

  static String? age(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final number = int.tryParse(value.trim());
    if (number == null || number < 0 || number > 1200) {
      return 'Enter an age from 0 to 1,200 months.';
    }
    return null;
  }
}
