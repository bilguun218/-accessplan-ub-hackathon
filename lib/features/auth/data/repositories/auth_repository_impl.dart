import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import '../services/auth_api_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthApiService _api;
  final SecureStorageService _storage;

  AuthRepositoryImpl({
    required AuthApiService api,
    required SecureStorageService storage,
  })  : _api = api,
        _storage = storage;

  @override
  Future<AuthResponse> register(RegisterRequest request) async {
    final res = await _api.register(request);
    await _storage.saveTokens(
      accessToken: res.accessToken,
      refreshToken: res.refreshToken,
    );
    return res;
  }

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    final res = await _api.login(request);
    await _storage.saveTokens(
      accessToken: res.accessToken,
      refreshToken: res.refreshToken,
    );
    return res;
  }

  @override
  Future<void> logout() async {
    final refresh = await _storage.getRefreshToken();
    if (refresh != null) {
      try {
        await _api.logout(refresh);
      } catch (_) {
        // ignore network failure on logout
      }
    }
    await _storage.clear();
  }

  @override
  Future<void> forgotPassword(String email) => _api.forgotPassword(email);

  @override
  Future<void> resetPassword(String token, String newPassword) =>
      _api.resetPassword(token, newPassword);

  @override
  Future<UserModel> getMe() => _api.getMe();

  @override
  Future<UserModel?> tryAutoLogin() async {
    final access = await _storage.getAccessToken();
    if (access == null) return null;
    try {
      return await _api.getMe();
    } catch (_) {
      // try refresh
      final refresh = await _storage.getRefreshToken();
      if (refresh == null) {
        await _storage.clear();
        return null;
      }
      try {
        final newAccess = await _api.refreshToken(refresh);
        await _storage.saveAccessToken(newAccess);
        return await _api.getMe();
      } catch (_) {
        await _storage.clear();
        return null;
      }
    }
  }

  @override
  Future<void> persistTokens(String accessToken, String refreshToken) =>
      _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

  @override
  Future<void> clearTokens() => _storage.clear();
}
