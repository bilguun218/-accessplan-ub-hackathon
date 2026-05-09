enum TaskPriority { low, medium, high }

class ExtractedTaskModel {
  final String? taskName;
  final String? organization;
  final String? branch;
  final TaskPriority? priority;
  final String rawText;
  final Map<String, dynamic> extractedEntities;
  final double confidenceScore;

  const ExtractedTaskModel({
    this.taskName,
    this.organization,
    this.branch,
    this.priority,
    required this.rawText,
    this.extractedEntities = const <String, dynamic>{},
    this.confidenceScore = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'taskName': taskName,
      'organization': organization,
      'branch': branch,
      'priority': priority?.name,
      'rawText': rawText,
      'extractedEntities': extractedEntities,
      'confidenceScore': confidenceScore,
    };
  }
}
