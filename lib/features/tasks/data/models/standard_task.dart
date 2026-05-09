enum TaskSource { manual, ai }

enum StandardTaskPriority { low, medium, high }

StandardTaskPriority parsePriority(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'high':
      return StandardTaskPriority.high;
    case 'low':
      return StandardTaskPriority.low;
    default:
      return StandardTaskPriority.medium;
  }
}

String priorityToString(StandardTaskPriority p) {
  switch (p) {
    case StandardTaskPriority.high:
      return 'high';
    case StandardTaskPriority.low:
      return 'low';
    case StandardTaskPriority.medium:
      return 'medium';
  }
}

class StandardTask {
  final String id;
  final int order;
  final String title;
  final String category;
  final String locationText;
  final String timeText;
  final StandardTaskPriority priority;
  final bool needsPlaceSearch;
  final String placeSearchQuery;
  final double? lat;
  final double? lng;
  final TaskSource source;
  final String notes;

  const StandardTask({
    required this.id,
    required this.order,
    required this.title,
    required this.category,
    required this.locationText,
    required this.timeText,
    required this.priority,
    required this.needsPlaceSearch,
    required this.placeSearchQuery,
    required this.source,
    this.lat,
    this.lng,
    this.notes = '',
  });

  factory StandardTask.fromJson(Map<String, dynamic> json) {
    double? readDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    bool readBool(dynamic value) {
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      return false;
    }

    int readInt(dynamic value, int fallback) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    return StandardTask(
      id: json['id']?.toString() ?? '',
      order: readInt(json['order'], 1),
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      locationText: json['locationText']?.toString() ?? '',
      timeText: json['timeText']?.toString() ?? '',
      priority: parsePriority(json['priority']?.toString()),
      needsPlaceSearch: readBool(json['needsPlaceSearch']),
      placeSearchQuery: json['placeSearchQuery']?.toString() ?? '',
      lat: readDouble(json['lat']),
      lng: readDouble(json['lng']),
      source: json['source']?.toString() == 'manual'
          ? TaskSource.manual
          : TaskSource.ai,
      notes: json['notes']?.toString() ?? '',
    );
  }

  StandardTask copyWith({
    int? order,
    String? title,
    String? category,
    String? locationText,
    String? timeText,
    StandardTaskPriority? priority,
    bool? needsPlaceSearch,
    String? placeSearchQuery,
    double? lat,
    double? lng,
    TaskSource? source,
    String? notes,
  }) {
    return StandardTask(
      id: id,
      order: order ?? this.order,
      title: title ?? this.title,
      category: category ?? this.category,
      locationText: locationText ?? this.locationText,
      timeText: timeText ?? this.timeText,
      priority: priority ?? this.priority,
      needsPlaceSearch: needsPlaceSearch ?? this.needsPlaceSearch,
      placeSearchQuery: placeSearchQuery ?? this.placeSearchQuery,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      source: source ?? this.source,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'order': order,
    'title': title,
    'category': category,
    'locationText': locationText,
    'timeText': timeText,
    'priority': priorityToString(priority),
    'needsPlaceSearch': needsPlaceSearch,
    'placeSearchQuery': placeSearchQuery,
    'lat': lat,
    'lng': lng,
    'source': source == TaskSource.ai ? 'ai' : 'manual',
    'notes': notes,
  };
}
