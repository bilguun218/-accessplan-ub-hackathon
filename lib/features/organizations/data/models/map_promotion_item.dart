import 'business_post.dart';

class MapPromotionItem {
  final String organizationId;
  final String businessName;
  final String? branchName;
  final String serviceType;
  final String address;
  final double latitude;
  final double longitude;
  final BusinessPost post;
  final double? distanceKm;

  const MapPromotionItem({
    required this.organizationId,
    required this.businessName,
    this.branchName,
    required this.serviceType,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.post,
    this.distanceKm,
  });

  String? get distanceText {
    final distance = distanceKm;
    if (distance == null) return null;
    if (distance < 1) return '${(distance * 1000).round()} м';
    return '${distance.toStringAsFixed(1)} км';
  }

  MapPromotionItem copyWith({
    String? organizationId,
    String? businessName,
    String? branchName,
    bool clearBranchName = false,
    String? serviceType,
    String? address,
    double? latitude,
    double? longitude,
    BusinessPost? post,
    double? distanceKm,
    bool clearDistanceKm = false,
  }) {
    return MapPromotionItem(
      organizationId: organizationId ?? this.organizationId,
      businessName: businessName ?? this.businessName,
      branchName: clearBranchName ? null : branchName ?? this.branchName,
      serviceType: serviceType ?? this.serviceType,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      post: post ?? this.post,
      distanceKm: clearDistanceKm ? null : distanceKm ?? this.distanceKm,
    );
  }
}
