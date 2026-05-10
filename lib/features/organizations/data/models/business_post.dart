enum BusinessPostType {
  promotion,
  announcement,
  event,
  discount,
  serviceUpdate,
  general,
}

class BusinessPost {
  final String id;
  final String organizationId;
  final String title;
  final String description;
  final BusinessPostType type;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isActive;
  final bool showOnMap;
  final bool isSponsored;

  const BusinessPost({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.description,
    required this.type,
    this.startsAt,
    this.endsAt,
    this.isActive = true,
    this.showOnMap = true,
    this.isSponsored = false,
  });

  bool get isCurrentlyVisibleOnMap {
    final now = DateTime.now();
    final started = startsAt == null || !startsAt!.isAfter(now);
    final notExpired = endsAt == null || !endsAt!.isBefore(now);
    return isActive && showOnMap && started && notExpired;
  }

  BusinessPost copyWith({
    String? id,
    String? organizationId,
    String? title,
    String? description,
    BusinessPostType? type,
    DateTime? startsAt,
    DateTime? endsAt,
    bool? clearStartsAt,
    bool? clearEndsAt,
    bool? isActive,
    bool? showOnMap,
    bool? isSponsored,
  }) {
    return BusinessPost(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      startsAt: clearStartsAt == true ? null : startsAt ?? this.startsAt,
      endsAt: clearEndsAt == true ? null : endsAt ?? this.endsAt,
      isActive: isActive ?? this.isActive,
      showOnMap: showOnMap ?? this.showOnMap,
      isSponsored: isSponsored ?? this.isSponsored,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'organizationId': organizationId,
    'title': title,
    'description': description,
    'type': businessPostTypeToJson(type),
    'startsAt': startsAt?.toIso8601String(),
    'endsAt': endsAt?.toIso8601String(),
    'isActive': isActive,
    'showOnMap': showOnMap,
    'isSponsored': isSponsored,
  };

  factory BusinessPost.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return BusinessPost(
      id: (json['id'] ?? '').toString(),
      organizationId: (json['organizationId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      type: parseBusinessPostType(json['type']?.toString()),
      startsAt: parseDate(json['startsAt']),
      endsAt: parseDate(json['endsAt']),
      isActive: json['isActive'] as bool? ?? true,
      showOnMap: json['showOnMap'] as bool? ?? true,
      isSponsored: json['isSponsored'] as bool? ?? false,
    );
  }
}

BusinessPostType parseBusinessPostType(String? raw) {
  switch (raw?.trim()) {
    case 'promotion':
      return BusinessPostType.promotion;
    case 'announcement':
      return BusinessPostType.announcement;
    case 'event':
      return BusinessPostType.event;
    case 'discount':
      return BusinessPostType.discount;
    case 'service_update':
    case 'serviceUpdate':
      return BusinessPostType.serviceUpdate;
    default:
      return BusinessPostType.general;
  }
}

String businessPostTypeToJson(BusinessPostType type) {
  switch (type) {
    case BusinessPostType.promotion:
      return 'promotion';
    case BusinessPostType.announcement:
      return 'announcement';
    case BusinessPostType.event:
      return 'event';
    case BusinessPostType.discount:
      return 'discount';
    case BusinessPostType.serviceUpdate:
      return 'service_update';
    case BusinessPostType.general:
      return 'general';
  }
}

String businessPostTypeLabel(BusinessPostType type) {
  switch (type) {
    case BusinessPostType.promotion:
      return 'Урамшуулал';
    case BusinessPostType.announcement:
      return 'Зарлал';
    case BusinessPostType.event:
      return 'Эвент';
    case BusinessPostType.discount:
      return 'Хямдрал';
    case BusinessPostType.serviceUpdate:
      return 'Үйлчилгээний шинэчлэл';
    case BusinessPostType.general:
      return 'Мэдээлэл';
  }
}
