import '../constants/app_strings.dart';

class Validators {
  Validators._();

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phoneRegex = RegExp(r'^(\+?976)?[6-9]\d{7}$');
  static final _hasLetter = RegExp(r'[A-Za-z]');
  static final _hasNumber = RegExp(r'[0-9]');

  static String? email(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return AppStrings.errEmailRequired;
    if (!_emailRegex.hasMatch(value)) return AppStrings.errEmailInvalid;
    return null;
  }

  static String? required(String? v, {String? message}) {
    if (v == null || v.trim().isEmpty) {
      return message ?? 'Шаардлагатай талбар.';
    }
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return AppStrings.errPasswordRequired;
    if (v.length < 8) return AppStrings.errPasswordMin;
    if (!_hasLetter.hasMatch(v) || !_hasNumber.hasMatch(v)) {
      return AppStrings.errPasswordPattern;
    }
    return null;
  }

  static String? loginPassword(String? v) {
    if (v == null || v.isEmpty) return AppStrings.errPasswordRequired;
    return null;
  }

  static String? phoneOptional(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return null;
    if (!_phoneRegex.hasMatch(value)) return AppStrings.errPhoneInvalid;
    return null;
  }

  static String? Function(String?) confirmMatches(
    String Function() other, {
    String? message,
  }) {
    return (v) {
      if (v != other()) return message ?? AppStrings.errPasswordsMismatch;
      return null;
    };
  }
}
