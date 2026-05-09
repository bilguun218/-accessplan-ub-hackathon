import '../../presentation/screens/add_task_screen.dart';

/// Model representing task data extracted from natural language text using NLP
class ExtractedTaskModel {
  final String? taskName;
  final String? organization;
  final String? branch;
  final TaskPriority? priority;
  final String? rawText;
  final Map<String, dynamic> extractedEntities;
  final double confidenceScore;

  ExtractedTaskModel({
    this.taskName,
    this.organization,
    this.branch,
    this.priority,
    this.rawText,
    required this.extractedEntities,
    this.confidenceScore = 0.0,
  });

  /// Check if extraction was successful and has enough data
  bool get isValid => taskName != null && organization != null;

  /// Convert to JSON for debugging
  Map<String, dynamic> toJson() => {
    'taskName': taskName,
    'organization': organization,
    'branch': branch,
    'priority': priority?.toString(),
    'rawText': rawText,
    'extractedEntities': extractedEntities,
    'confidenceScore': confidenceScore,
  };
}
