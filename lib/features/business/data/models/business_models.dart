class BusinessProfile {
  final String id;
  final String organizationName;
  final String branchName;
  final String activityType;
  final String registrationNumber;
  final String location;
  final String contactPerson;
  final String phone;
  final String email;
  final String description;
  final String verificationMethod;
  final String status;
  final String website;
  final double latitude;
  final double longitude;
  final bool hasParking;
  final bool hasCoveredParking;
  final int parkingSpaces;
  final bool wheelchairAccessible;
  final bool hasElevator;
  final bool accessibleRestroom;
  final bool onlineService;
  final bool appointmentBooking;
  final List<BusinessHour> hours;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BusinessProfile({
    required this.id,
    required this.organizationName,
    required this.branchName,
    required this.activityType,
    required this.registrationNumber,
    required this.location,
    required this.contactPerson,
    required this.phone,
    required this.email,
    required this.description,
    required this.verificationMethod,
    required this.status,
    required this.website,
    required this.latitude,
    required this.longitude,
    required this.hasParking,
    required this.hasCoveredParking,
    required this.parkingSpaces,
    required this.wheelchairAccessible,
    required this.hasElevator,
    required this.accessibleRestroom,
    required this.onlineService,
    required this.appointmentBooking,
    required this.hours,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BusinessProfile.demo() {
    final now = DateTime.now();
    return BusinessProfile(
      id: 'local-demo-business',
      organizationName: 'Blue Bean Coffee',
      branchName: '',
      activityType: 'Кофе шоп',
      registrationNumber: 'UB-1020304',
      location: 'Сүхбаатар дүүрэг, 1-р хороо',
      contactPerson: 'Б. Номин',
      phone: '99001234',
      email: 'hello@bluebean.mn',
      description: 'Хотын төвд байрлах хүртээмжтэй кофе шоп.',
      verificationMethod: 'emongolia',
      status: 'active',
      website: 'www.bluebean.mn',
      latitude: 47.918873,
      longitude: 106.917701,
      hasParking: true,
      hasCoveredParking: false,
      parkingSpaces: 12,
      wheelchairAccessible: true,
      hasElevator: true,
      accessibleRestroom: true,
      onlineService: true,
      appointmentBooking: false,
      hours: BusinessHour.defaultWeek(),
      createdAt: now,
      updatedAt: now,
    );
  }

  BusinessProfile copyWith({
    String? id,
    String? organizationName,
    String? branchName,
    String? activityType,
    String? registrationNumber,
    String? location,
    String? contactPerson,
    String? phone,
    String? email,
    String? description,
    String? verificationMethod,
    String? status,
    String? website,
    double? latitude,
    double? longitude,
    bool? hasParking,
    bool? hasCoveredParking,
    int? parkingSpaces,
    bool? wheelchairAccessible,
    bool? hasElevator,
    bool? accessibleRestroom,
    bool? onlineService,
    bool? appointmentBooking,
    List<BusinessHour>? hours,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BusinessProfile(
      id: id ?? this.id,
      organizationName: organizationName ?? this.organizationName,
      branchName: branchName ?? this.branchName,
      activityType: activityType ?? this.activityType,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      location: location ?? this.location,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      description: description ?? this.description,
      verificationMethod: verificationMethod ?? this.verificationMethod,
      status: status ?? this.status,
      website: website ?? this.website,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      hasParking: hasParking ?? this.hasParking,
      hasCoveredParking: hasCoveredParking ?? this.hasCoveredParking,
      parkingSpaces: parkingSpaces ?? this.parkingSpaces,
      wheelchairAccessible: wheelchairAccessible ?? this.wheelchairAccessible,
      hasElevator: hasElevator ?? this.hasElevator,
      accessibleRestroom: accessibleRestroom ?? this.accessibleRestroom,
      onlineService: onlineService ?? this.onlineService,
      appointmentBooking: appointmentBooking ?? this.appointmentBooking,
      hours: hours ?? this.hours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'organizationName': organizationName,
    'branchName': branchName,
    'businessName': organizationName,
    'activityType': activityType,
    'serviceType': activityType,
    'registrationNumber': registrationNumber,
    'location': location,
    'address': location,
    'contactPerson': contactPerson,
    'phone': phone,
    'email': email,
    'description': description,
    'verificationMethod': verificationMethod,
    'status': status,
    'website': website,
    'latitude': latitude,
    'longitude': longitude,
    'hasParking': hasParking,
    'parkingAvailable': hasParking,
    'hasCoveredParking': hasCoveredParking,
    'parkingSpaces': parkingSpaces,
    'wheelchairAccessible': wheelchairAccessible,
    'accessibilityAvailable': wheelchairAccessible,
    'hasElevator': hasElevator,
    'accessibleRestroom': accessibleRestroom,
    'onlineService': onlineService,
    'digitalServicesAvailable': onlineService,
    'appointmentBooking': appointmentBooking,
    'hours': hours.map((hour) => hour.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory BusinessProfile.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(Object? value, DateTime fallback) {
      if (value == null) return fallback;
      return DateTime.tryParse(value.toString()) ?? fallback;
    }

    final now = DateTime.now();
    final rawHours = json['hours'] ?? json['workingHours'];
    return BusinessProfile(
      id: (json['id'] ?? 'local-business').toString(),
      organizationName: (json['organizationName'] ?? json['businessName'] ?? '')
          .toString(),
      branchName: (json['branchName'] ?? '').toString(),
      activityType: (json['activityType'] ?? json['serviceType'] ?? '')
          .toString(),
      registrationNumber: (json['registrationNumber'] ?? '').toString(),
      location: (json['location'] ?? json['address'] ?? '').toString(),
      contactPerson: (json['contactPerson'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      verificationMethod: (json['verificationMethod'] ?? 'emongolia')
          .toString(),
      status: (json['status'] ?? 'active').toString(),
      website: (json['website'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 47.918873,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 106.917701,
      hasParking:
          json['hasParking'] as bool? ??
          json['parkingAvailable'] as bool? ??
          true,
      hasCoveredParking: json['hasCoveredParking'] as bool? ?? false,
      parkingSpaces: (json['parkingSpaces'] as num?)?.toInt() ?? 0,
      wheelchairAccessible:
          json['wheelchairAccessible'] as bool? ??
          json['accessibilityAvailable'] as bool? ??
          true,
      hasElevator: json['hasElevator'] as bool? ?? true,
      accessibleRestroom: json['accessibleRestroom'] as bool? ?? true,
      onlineService:
          json['onlineService'] as bool? ??
          json['digitalServicesAvailable'] as bool? ??
          true,
      appointmentBooking: json['appointmentBooking'] as bool? ?? false,
      hours: rawHours is List
          ? rawHours
                .whereType<Map>()
                .map(
                  (value) =>
                      BusinessHour.fromJson(Map<String, dynamic>.from(value)),
                )
                .toList()
          : BusinessHour.defaultWeek(),
      createdAt: parseDate(json['createdAt'], now),
      updatedAt: parseDate(json['updatedAt'], now),
    );
  }
}

class BusinessHour {
  final String day;
  final bool open;
  final String start;
  final String end;

  const BusinessHour({
    required this.day,
    required this.open,
    required this.start,
    required this.end,
  });

  static List<BusinessHour> defaultWeek() => const [
    BusinessHour(day: 'Даваа', open: true, start: '09:00', end: '18:00'),
    BusinessHour(day: 'Мягмар', open: true, start: '09:00', end: '18:00'),
    BusinessHour(day: 'Лхагва', open: true, start: '09:00', end: '18:00'),
    BusinessHour(day: 'Пүрэв', open: true, start: '09:00', end: '18:00'),
    BusinessHour(day: 'Баасан', open: true, start: '09:00', end: '18:00'),
    BusinessHour(day: 'Бямба', open: true, start: '10:00', end: '16:00'),
    BusinessHour(day: 'Ням', open: false, start: '10:00', end: '16:00'),
  ];

  BusinessHour copyWith({String? day, bool? open, String? start, String? end}) {
    return BusinessHour(
      day: day ?? this.day,
      open: open ?? this.open,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  Map<String, dynamic> toJson() => {
    'day': day,
    'open': open,
    'start': start,
    'end': end,
  };

  factory BusinessHour.fromJson(Map<String, dynamic> json) => BusinessHour(
    day: (json['day'] ?? '').toString(),
    open: json['open'] as bool? ?? true,
    start: (json['start'] ?? '09:00').toString(),
    end: (json['end'] ?? '18:00').toString(),
  );
}

class BusinessPromotion {
  final String id;
  final String title;
  final String type;
  final String description;
  final String startDate;
  final String endDate;
  final String limit;
  final bool active;
  final bool showOnMap;
  final bool isSponsored;
  final int impressions;
  final int routeAdds;
  final DateTime createdAt;

  const BusinessPromotion({
    required this.id,
    required this.title,
    required this.type,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.limit,
    required this.active,
    required this.showOnMap,
    required this.isSponsored,
    required this.impressions,
    required this.routeAdds,
    required this.createdAt,
  });

  static List<BusinessPromotion> seed() {
    final now = DateTime.now();
    return [
      BusinessPromotion(
        id: 'promo-transfer-free',
        title: 'Кофе 10% хямдрал',
        type: 'Хямдрал',
        description:
            'Аппаас ирсэн хэрэглэгч бүрт сонгосон кофенд 10% хөнгөлөлт.',
        startDate: '2026-05-01',
        endDate: '2026-05-31',
        limit: '1 хэрэглэгч 1 удаа',
        active: true,
        showOnMap: true,
        isSponsored: false,
        impressions: 64,
        routeAdds: 22,
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      BusinessPromotion(
        id: 'promo-premium',
        title: 'Өглөөний комбо',
        type: 'Урамшуулал',
        description: '09:00-11:00 цагт кофе болон амттаны комбо үнэ.',
        startDate: '2026-05-05',
        endDate: '2026-06-05',
        limit: 'Өдөр бүр 30 багц',
        active: true,
        showOnMap: true,
        isSponsored: true,
        impressions: 41,
        routeAdds: 15,
        createdAt: now.subtract(const Duration(days: 6)),
      ),
    ];
  }

  String get dateRange => '$startDate - $endDate';

  BusinessPromotion copyWith({
    String? id,
    String? title,
    String? type,
    String? description,
    String? startDate,
    String? endDate,
    String? limit,
    bool? active,
    bool? showOnMap,
    bool? isSponsored,
    int? impressions,
    int? routeAdds,
    DateTime? createdAt,
  }) {
    return BusinessPromotion(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      limit: limit ?? this.limit,
      active: active ?? this.active,
      showOnMap: showOnMap ?? this.showOnMap,
      isSponsored: isSponsored ?? this.isSponsored,
      impressions: impressions ?? this.impressions,
      routeAdds: routeAdds ?? this.routeAdds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type,
    'description': description,
    'startDate': startDate,
    'endDate': endDate,
    'limit': limit,
    'active': active,
    'isActive': active,
    'showOnMap': showOnMap,
    'isSponsored': isSponsored,
    'impressions': impressions,
    'routeAdds': routeAdds,
    'createdAt': createdAt.toIso8601String(),
  };

  factory BusinessPromotion.fromJson(Map<String, dynamic> json) {
    return BusinessPromotion(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      type: (json['type'] ?? 'Урамшуулал').toString(),
      description: (json['description'] ?? '').toString(),
      startDate: (json['startDate'] ?? json['startsAt'] ?? '').toString(),
      endDate: (json['endDate'] ?? json['endsAt'] ?? '').toString(),
      limit: (json['limit'] ?? '').toString(),
      active: json['active'] as bool? ?? json['isActive'] as bool? ?? true,
      showOnMap: json['showOnMap'] as bool? ?? true,
      isSponsored: json['isSponsored'] as bool? ?? false,
      impressions: (json['impressions'] as num?)?.toInt() ?? 0,
      routeAdds: (json['routeAdds'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class BusinessAnalyticsSnapshot {
  final List<int> dailyViews;
  final List<int> hourlyActivity;
  final int searchViews;
  final int routeEntries;
  final int promotionViews;
  final int routeAdds;
  final int savedUsers;
  final int todayViews;
  final String activeHourLabel;

  const BusinessAnalyticsSnapshot({
    required this.dailyViews,
    required this.hourlyActivity,
    required this.searchViews,
    required this.routeEntries,
    required this.promotionViews,
    required this.routeAdds,
    required this.savedUsers,
    required this.todayViews,
    required this.activeHourLabel,
  });
}
