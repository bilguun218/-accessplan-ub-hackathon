class ParsedTask {
  final int order;
  final String title;
  final String category;
  final String locationText;
  final String timeText;
  final String priority;
  final bool needsPlaceSearch;

  const ParsedTask({
    required this.order,
    required this.title,
    required this.category,
    required this.locationText,
    required this.timeText,
    required this.priority,
    required this.needsPlaceSearch,
  });

  factory ParsedTask.fromJson(Map<String, dynamic> json, {int fallbackOrder = 0}) {
    return ParsedTask(
      order: (json['order'] as num?)?.toInt() ?? fallbackOrder,
      title: (json['title'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      locationText: (json['locationText'] ?? '').toString(),
      timeText: (json['timeText'] ?? '').toString(),
      priority: (json['priority'] ?? '').toString(),
      needsPlaceSearch: json['needsPlaceSearch'] == true,
    );
  }
}
