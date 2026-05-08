import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../constants/app_strings.dart';
import '../storage/secure_storage_service.dart';
import 'api_exception.dart';

typedef OnSessionExpired = Future<void> Function();

class ApiClient {
  final Dio _dio;
  final SecureStorageService _storage;
  final OnSessionExpired? onSessionExpired;
  bool _isRefreshing = false;

  ApiClient({
    required SecureStorageService storage,
    this.onSessionExpired,
    Dio? dio,
  })  : _storage = storage,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                contentType: 'application/json',
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] != true) {
            final token = await _storage.getAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (err, handler) async {
          final status = err.response?.statusCode;
          final isAuthCall = err.requestOptions.path.contains('/auth/login') ||
              err.requestOptions.path.contains('/auth/register') ||
              err.requestOptions.path.contains('/auth/refresh');

          if (status == 401 && !isAuthCall && !_isRefreshing) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              try {
                final clone = await _dio.fetch(err.requestOptions);
                return handler.resolve(clone);
              } catch (_) {
                // fall through
              }
            }
            await _storage.clear();
            if (onSessionExpired != null) await onSessionExpired!();
          }
          handler.next(err);
        },
      ),
    );
  }

  Dio get dio => _dio;

  Future<bool> _tryRefresh() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) return false;
      final res = await _dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );
      final newAccess = res.data['accessToken'] as String?;
      if (newAccess == null) return false;
      await _storage.saveAccessToken(newAccess);
      return true;
    } catch (_) {
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  ApiException toApiException(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return ApiException.network();
      }
      final status = error.response?.statusCode;
      final data = error.response?.data;
      String? message;
      String? code;
      if (data is Map && data['error'] is Map) {
        message = data['error']['message']?.toString();
        code = data['error']['code']?.toString();
      }
      if (status == 401) {
        return ApiException(
          message ?? AppStrings.errInvalidCredentials,
          code: code,
          status: status,
        );
      }
      if (status != null && status >= 500) {
        return ApiException.server();
      }
      return ApiException(
        message ?? AppStrings.errServer,
        code: code,
        status: status,
      );
    }
    return ApiException.server();
  }
}
