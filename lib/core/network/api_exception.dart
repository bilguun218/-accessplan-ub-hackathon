import '../constants/app_strings.dart';

class ApiException implements Exception {
  final String message;
  final String? code;
  final int? status;

  ApiException(this.message, {this.code, this.status});

  factory ApiException.network() =>
      ApiException(AppStrings.errNetwork, code: 'NETWORK');

  factory ApiException.server() =>
      ApiException(AppStrings.errServer, code: 'INTERNAL', status: 500);

  factory ApiException.session() =>
      ApiException(AppStrings.errSession, code: 'TOKEN_EXPIRED', status: 401);

  @override
  String toString() => message;
}
