class Validators {
  // ===========================
  // Store Name Validation
  // ===========================
  /// Validates the store name based on several rules.
  ///
  /// Rules:
  /// - Cannot be empty or just whitespace.
  /// - Must be between 3 and 50 characters long.
  /// - Can only contain Arabic or English letters and spaces.
  ///
  /// Returns:
  /// - `null` if the name is valid.
  /// - An Arabic error message string if any rule is violated.
  static String? validateStoreName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال اسم المحل';
    }
    if (value.length < 3) {
      return 'اسم المحل يجب أن يكون 3 حروف على الأقل';
    }
    if (value.length > 50) {
      return 'اسم المحل يجب أن لا يتجاوز 50 حرفًا';
    }
    // Regex to allow Arabic/English letters and spaces.
    final RegExp nameRegExp = RegExp(r'^[a-zA-Z؀-ۿ ]+$');
    if (!nameRegExp.hasMatch(value)) {
      return 'يجب أن يحتوي الاسم على حروف وأرقام فقط';
    }
    return null;
  }

  // ===========================
  // Store Password Validation
  // ===========================
  /// Validates the store password.
  ///
  /// Rules:
  /// - Cannot be empty.
  /// - Must be at least 6 characters long.
  /// - Must contain only digits (0-9).
  ///
  /// Returns:
  /// - `null` if the password is valid.
  /// - An Arabic error message string if any rule is violated.
  static String? validateStorePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال كلمة السر';
    }
    if (value.length < 6) {
      return 'كلمة السر يجب أن تكون 6 أرقام على الأقل';
    }
    // Regex to ensure only digits are present.
    final RegExp digitsOnly = RegExp(r'^[0-9]+$');
    if (!digitsOnly.hasMatch(value)) {
      return 'كلمة السر يجب أن تحتوي على أرقام فقط';
    }
    return null;
  }

  // ===========================
  // Confirm Password Validation
  // ===========================
  /// Validates that the confirmed password matches the original password.
  ///
  /// Rules:
  /// - Cannot be empty.
  /// - Must be an exact match to the `password` parameter.
  ///
  /// Returns:
  /// - `null` if the passwords match.
  /// - An Arabic error message string if they do not match or if the field is empty.
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'يرجى تأكيد كلمة السر';
    }
    if (value != password) {
      return 'كلمتا السر غير متطابقتين';
    }
    return null;
  }

  // ===========================
  // License Key Validation
  // ===========================
  /// Validates the license key.
  ///
  /// Rules:
  /// - Cannot be empty.
  /// - Must be at least 5 characters long.
  ///
  /// Returns:
  /// - `null` if the license key is valid.
  /// - An Arabic error message string if any rule is violated.
  static String? validateLicenseKey(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'مفتاح الترخيص مطلوب';
    }

    final trimmedValue = value.trim();

    // Correct length: WALLET-2025-XXXX-XXXX = 23 characters
    if (trimmedValue.length != 21) {
      return 'مفتاح الترخيص يجب أن يكون 21 حرف';
    }

    // Check format
    final RegExp licenseRegExp = RegExp(r'^WALLET-2025-[A-Z0-9]{4}-[A-Z0-9]{4}$');
    if (!licenseRegExp.hasMatch(trimmedValue.toUpperCase())) {
      return 'صيغة مفتاح الترخيص غير صحيحة';
    }

    return null;
  }
  // ===========================
  // Phone Number Validation (Egyptian format)
  // ===========================
  /// Validates an Egyptian phone number.
  ///
  /// Rules:
  /// - Cannot be empty.
  /// - Must be exactly 11 digits.
  /// - Must match the Egyptian phone number format (e.g., 01xxxxxxxxx).
  /// - Pattern: `^01[0-2,5]{1}[0-9]{8}$`
  ///
  /// Returns:
  /// - `null` if the phone number is valid.
  /// - An Arabic error message string if invalid.
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال رقم الموبايل';
    }
    // Egyptian phone number regex.
    final RegExp phoneRegExp = RegExp(r'^01[0-2,5]{1}[0-9]{8}$');
    if (!phoneRegExp.hasMatch(value)) {
      return 'رقم الموبايل غير صحيح';
    }
    return null;
  }

  // ===========================
  // Amount Validation
  // ===========================
  /// Validates a numeric amount.
  ///
  /// Rules:
  /// - Cannot be empty.
  /// - Must be a valid number (can be decimal).
  /// - Must be greater than `minAmount` (defaults to 0).
  ///
  /// Returns:
  /// - `null` if the amount is valid.
  /// - An Arabic error message string if any rule is violated.
  static String? validateAmount(String? value, {double minAmount = 0}) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال المبلغ';
    }
    final double? amount = double.tryParse(value);
    if (amount == null) {
      return 'الرجاء إدخال مبلغ صحيح';
    }
    if (amount <= minAmount) {
      return 'المبلغ يجب أن يكون أكبر من $minAmount';
    }
    return null;
  }

  // ===========================
  // General Required Field Validation
  // ===========================
  /// Validates that a field is not empty.
  ///
  /// Rules:
  /// - Cannot be null, empty, or contain only whitespace.
  ///
  /// Returns:
  /// - `null` if the field has a value.
  /// - A dynamic Arabic error message: "يرجى إدخال [fieldName]".
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال $fieldName';
    }
    return null;
  }

  // ===========================
  // Name Validation
  // ===========================
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال الاسم';
    }
    if (value.length < 3) {
      return 'الاسم يجب أن يكون 3 حروف على الأقل';
    }
    if (value.length > 50) {
      return 'الاسم يجب أن لا يتجاوز 50 حرفًا';
    }
    final RegExp nameRegExp = RegExp(r'^[a-zA-Z؀-ۿ ]+$');
    if (!nameRegExp.hasMatch(value)) {
      return 'يجب أن يحتوي الاسم على حروف فقط';
    }
    return null;
  }

  // ===========================
  // Email Validation
  // ===========================
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال البريد الإلكتروني';
    }
    final RegExp emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegExp.hasMatch(value)) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }
    return null;
  }

  // ===========================
  // PIN Validation
  // ===========================
  static String? validatePin(String? value) {
    if (value == null || value.isEmpty) {
      return 'يرجى إدخال الرقم السري';
    }
    if (value.length != 4) {
      return 'الرقم السري يجب أن يكون 4 أرقام';
    }
    final RegExp digitsOnly = RegExp(r'^[0-9]+$');
    if (!digitsOnly.hasMatch(value)) {
      return 'الرقم السري يجب أن يحتوي على أرقام فقط';
    }
    return null;
  }

  // ===========================
  // Notes Validation (Optional Field)
  // ===========================
  /// Validates optional notes for maximum length.
  ///
  /// Rules:
  /// - Field is optional (can be empty or null).
  /// - If a value is provided, its length cannot exceed `maxLength`.
  ///
  /// Returns:
  /// - `null` if the field is empty or within the length limit.
  /// - An Arabic error message if the notes are too long.
  static String? validateNotes(String? value, {int maxLength = 200}) {
    if (value != null && value.length > maxLength) {
      return 'الملاحظات يجب أن لا تتجاوز $maxLength حرفًا';
    }
    return null;
  }
}