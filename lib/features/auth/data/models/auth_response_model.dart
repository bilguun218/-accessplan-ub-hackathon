import 'user_model.dart';

class AuthResponse {
  final UserModel user;
  final String accessToken;
  final String refreshToken;

  AuthResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );
}

class RegisterRequest {
  final String fullName;
  final String email;
  final String? phone;
  final String password;
  final String userType;
  final String? district;
  final String preferredLanguage;

  RegisterRequest({
    required this.fullName,
    required this.email,
    this.phone,
    required this.password,
    required this.userType,
    this.district,
    this.preferredLanguage = 'mn',
  });

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'email': email,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        'password': password,
        'userType': userType,
        if (district != null && district!.isNotEmpty) 'district': district,
        'preferredLanguage': preferredLanguage,
      };
}

class LoginRequest {
  final String email;
  final String password;
  final String userType;
  LoginRequest({
    required this.email,
    required this.password,
    this.userType = 'general',
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'userType': userType,
  };
}
