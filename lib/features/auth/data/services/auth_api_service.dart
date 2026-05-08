import '../../../../core/network/api_client.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

class AuthApiService {
  final ApiClient _client;
  AuthApiService(this._client);

  Future<AuthResponse> register(RegisterRequest request) async {
    try {
      final res = await _client.dio.post(
        '/auth/register',
        data: request.toJson(),
      );
      return AuthResponse.fromJson(Map<String, dynamic>.from(res.data));
    } catch (e) {
      throw _client.toApiException(e);
    }
  }

  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final res = await _client.dio.post('/auth/login', data: request.toJson());
      return AuthResponse.fromJson(Map<String, dynamic>.from(res.data));
    } catch (e) {
      throw _client.toApiException(e);
    }
  }

  Future<String> refreshToken(String refreshToken) async {
    try {
      final res = await _client.dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      return res.data['accessToken'] as String;
    } catch (e) {
      throw _client.toApiException(e);
    }
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _client.dio.post(
        '/auth/logout',
        data: {'refreshToken': refreshToken},
      );
    } catch (e) {
      throw _client.toApiException(e);
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _client.dio.post('/auth/forgot-password', data: {'email': email});
    } catch (e) {
      throw _client.toApiException(e);
    }
  }

  Future<void> resetPassword(String token, String newPassword) async {
    try {
      await _client.dio.post(
        '/auth/reset-password',
        data: {'token': token, 'newPassword': newPassword},
      );
    } catch (e) {
      throw _client.toApiException(e);
    }
  }

  Future<UserModel> getMe() async {
    try {
      final res = await _client.dio.get('/auth/me');
      return UserModel.fromJson(
        Map<String, dynamic>.from(res.data['user'] as Map),
      );
    } catch (e) {
      throw _client.toApiException(e);
    }
  }
}
