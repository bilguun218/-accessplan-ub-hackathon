class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String role;
  final String userType;
  final String? district;
  final String preferredLanguage;
  final bool isEmailVerified;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    required this.userType,
    this.district,
    required this.preferredLanguage,
    required this.isEmailVerified,
    this.lastLoginAt,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return UserModel(
      id: (json['id'] ?? json['_id']).toString(),
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'user',
      userType: json['userType'] as String,
      district: json['district'] as String?,
      preferredLanguage: json['preferredLanguage'] as String? ?? 'mn',
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
      lastLoginAt: parse(json['lastLoginAt']),
      createdAt: parse(json['createdAt']),
    );
  }
}
