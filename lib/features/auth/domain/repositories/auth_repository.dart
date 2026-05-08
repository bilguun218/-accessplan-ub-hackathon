import '../../data/models/auth_response_model.dart';
import '../../data/models/user_model.dart';

abstract class AuthRepository {
  Future<AuthResponse> register(RegisterRequest request);
  Future<AuthResponse> login(LoginRequest request);
  Future<void> logout();
  Future<void> forgotPassword(String email);
  Future<void> resetPassword(String token, String newPassword);
  Future<UserModel> getMe();
  Future<UserModel?> tryAutoLogin();
  Future<void> persistTokens(String accessToken, String refreshToken);
  Future<void> clearTokens();
}
