enum ReportSeverity { low, medium, high, urgent }

extension ReportSeverityX on ReportSeverity {
  String get label {
    switch (this) {
      case ReportSeverity.low:
        return 'Бага';
      case ReportSeverity.medium:
        return 'Дунд';
      case ReportSeverity.high:
        return 'Өндөр';
      case ReportSeverity.urgent:
        return 'Яаралтай';
    }
  }
}

class ReportCategory {
  final String key;
  final String label;
  const ReportCategory(this.key, this.label);

  static const all = <ReportCategory>[
    ReportCategory('road_damage', 'Эвдэрсэн зам'),
    ReportCategory('sidewalk', 'Явган зам'),
    ReportCategory('snow_ice', 'Цас, мөс'),
    ReportCategory('lighting', 'Гэрэлтүүлэг'),
    ReportCategory('bus_stop', 'Автобусны буудал'),
    ReportCategory('garbage', 'Хог, бохирдол'),
    ReportCategory('ramp', 'Налуу зам'),
    ReportCategory('crossing', 'Гарц'),
    ReportCategory('other', 'Бусад'),
  ];

  static ReportCategory? byKey(String? key) {
    if (key == null) return null;
    for (final c in all) {
      if (c.key == key) return c;
    }
    return null;
  }
}

class ReportModel {
  final String id;
  final String title;
  final String categoryKey;
  final String location;
  final String description;
  final ReportSeverity severity;
  final String? imagePath;
  final bool isAnonymous;
  final DateTime createdAt;

  ReportModel({
    required this.id,
    required this.title,
    required this.categoryKey,
    required this.location,
    required this.description,
    required this.severity,
    this.imagePath,
    this.isAnonymous = false,
    required this.createdAt,
  });

  ReportCategory get category =>
      ReportCategory.byKey(categoryKey) ?? ReportCategory.all.last;
}
