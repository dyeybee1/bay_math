/// Reusable validation and normalization for Teacher self-registration.
///
/// These checks are deliberately independent of widgets so the repository can
/// apply the same rules as a defense in depth before calling Supabase Auth.
abstract final class TeacherRegistrationValidators {
  static const int nameMaxLength = 100;
  static const int emailMaxLength = 254;
  static const int passwordMinLength = 8;
  static const int passwordMaxLength = 128;

  static final RegExp _namePattern = RegExp(
    r"^[\p{L}\p{M}]+(?:[ '\u2019-][\p{L}\p{M}]+)*$",
    unicode: true,
  );
  static final RegExp _emailPattern = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    unicode: true,
  );
  static final RegExp _emailLocalPattern = RegExp(
    r"^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+$",
    caseSensitive: false,
  );
  static final RegExp _emailDomainLabelPattern = RegExp(
    r'^[a-z0-9-]+$',
    caseSensitive: false,
  );

  static String normalizeName(String value) => value.trim();

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static String? validateName(String? value) {
    final String name = normalizeName(value ?? '');
    if (name.isEmpty) return 'Enter your full name.';
    if (name.length > nameMaxLength) {
      return 'Name must be $nameMaxLength characters or fewer.';
    }
    if (!_namePattern.hasMatch(name)) {
      return 'Name must contain letters and cannot contain numbers.';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    final String email = normalizeEmail(value ?? '');
    if (email.isEmpty) return 'Enter your email address.';
    if (email.length > emailMaxLength) {
      return 'Email must be $emailMaxLength characters or fewer.';
    }

    final int separator = email.indexOf('@');
    final bool hasOneAtSign =
        separator > 0 && separator == email.lastIndexOf('@');
    if (!hasOneAtSign ||
        separator > 64 ||
        email.startsWith('.') ||
        email.contains('..') ||
        !_emailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }

    final String domain = email.substring(separator + 1);
    final String localPart = email.substring(0, separator);
    final List<String> domainLabels = domain.split('.');
    final bool invalidDomain = domainLabels.any(
      (String label) =>
          label.isEmpty ||
          label.length > 63 ||
          label.startsWith('-') ||
          label.endsWith('-') ||
          !_emailDomainLabelPattern.hasMatch(label),
    );
    if (!_emailLocalPattern.hasMatch(localPart) ||
        localPart.endsWith('.') ||
        invalidDomain ||
        domainLabels.last.length < 2) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static PasswordRequirements passwordRequirements(String value) {
    return PasswordRequirements(
      hasMinimumLength: value.length >= passwordMinLength,
      hasUppercase: RegExp('[A-Z]').hasMatch(value),
      hasLowercase: RegExp('[a-z]').hasMatch(value),
      hasNumber: RegExp('[0-9]').hasMatch(value),
      hasSpecialCharacter: RegExp(
        r'''[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?`~]''',
      ).hasMatch(value),
      isWithinMaximumLength: value.length <= passwordMaxLength,
    );
  }

  static String? validatePassword(String? value) {
    final String password = value ?? '';
    if (password.isEmpty) return 'Enter a password.';
    if (password.length > passwordMaxLength) {
      return 'Password must be $passwordMaxLength characters or fewer.';
    }
    if (!passwordRequirements(password).isComplete) {
      return 'Use a password that meets every requirement below.';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Confirm your password.';
    if (value != password) return 'Passwords do not match.';
    return null;
  }
}

class PasswordRequirements {
  const PasswordRequirements({
    required this.hasMinimumLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSpecialCharacter,
    required this.isWithinMaximumLength,
  });

  final bool hasMinimumLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSpecialCharacter;
  final bool isWithinMaximumLength;

  bool get isComplete =>
      hasMinimumLength &&
      hasUppercase &&
      hasLowercase &&
      hasNumber &&
      hasSpecialCharacter &&
      isWithinMaximumLength;
}
