import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';
import '../models/extracted_task_model.dart';
import '../../presentation/screens/add_task_screen.dart';

/// Service for Natural Language Processing and task entity extraction
/// Uses Google ML Kit's Entity Extraction to parse user input
class TaskNlpService {
  static const List<String> _organizationKeywords = [
    'Khan Bank',
    'Emart',
    'CU',
    'цахилгаан',
    'сургууль',
    'эмнэлэг',
    'банк',
    'дүүргийн',
  ];

  static const Map<String, List<String>> _priorityKeywords = {
    'high': [
      'urgently',
      'immediately',
      'urgent',
      'хэрэтэй',
      'яаралтай',
      'яараал',
    ],
    'medium': ['today', 'soon', 'дараа', 'удахгүй'],
    'low': ['later', 'eventually', 'someday', 'дараахан', 'ямар нэг цаг'],
  };

  static const List<String> _timePatterns = [
    'today',
    'tomorrow',
    'morning',
    'afternoon',
    'evening',
    'am',
    'pm',
  ];

  late EntityExtractor _entityExtractor;
  bool _initialized = false;

  /// Initialize the entity extractor
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _entityExtractor = EntityExtractor(
        language: EntityExtractorLanguage.english,
      );
      _initialized = true;
    } catch (e) {
      print('Error initializing EntityExtractor: $e');
      rethrow;
    }
  }

  /// Extract task entities from natural language text
  /// Example input: "Need to open bank account at Khan Bank Zaisan branch tomorrow morning, high priority"
  Future<ExtractedTaskModel> extractTaskEntities(String input) async {
    if (!_initialized) {
      await initialize();
    }

    if (input.trim().isEmpty) {
      return ExtractedTaskModel(rawText: input, extractedEntities: {});
    }

    try {
      // Use pattern-based extraction (more reliable than ML Kit entity detection)
      final taskName = _extractTaskName(input, []);
      final organization = _extractOrganization(input, []);
      final branch = _extractBranch(input, organization);
      final priority = _extractPriority(input);

      return ExtractedTaskModel(
        taskName: taskName,
        organization: organization,
        branch: branch,
        priority: priority,
        rawText: input,
        extractedEntities: {'method': 'pattern_matching', 'input': input},
        confidenceScore: _calculateConfidence(taskName, organization),
      );
    } catch (e) {
      print('Error extracting entities: $e');
      return _fallbackExtraction(input);
    }
  }

  /// Fallback extraction using pattern matching when ML Kit is unavailable
  ExtractedTaskModel _fallbackExtraction(String input) {
    final lower = input.toLowerCase();

    final taskName = _extractTaskName(input, []);
    final organization = _extractOrganizationPattern(lower);
    final priority = _extractPriorityPattern(lower);

    return ExtractedTaskModel(
      taskName: taskName,
      organization: organization,
      branch: _extractBranch(input, organization),
      priority: priority,
      rawText: input,
      extractedEntities: {
        'method': 'fallback_pattern_matching',
        'input': input,
      },
      confidenceScore: 0.5,
    );
  }

  /// Extract the main task name/description
  String? _extractTaskName(String input, List annotations) {
    // Fallback: take first N words or the entire sentence
    final words = input.split(' ');
    if (words.length <= 3) {
      return input.trim();
    }

    // Look for action verbs at start: "need to", "have to", "open", "close", etc.
    final actionVerbs = [
      'need',
      'have',
      'open',
      'close',
      'visit',
      'go',
      'send',
      'get',
      'apply',
      'register',
    ];
    String? actionStart;

    for (int i = 0; i < words.length; i++) {
      if (actionVerbs.contains(words[i].toLowerCase())) {
        actionStart = words.sublist(i).take(5).join(' ');
        break;
      }
    }

    return actionStart ?? input.trim();
  }

  /// Extract organization name from entities
  String? _extractOrganization(String input, List annotations) {
    final lower = input.toLowerCase();

    // Check for known organizations
    for (final org in _organizationKeywords) {
      if (lower.contains(org.toLowerCase())) {
        return org;
      }
    }

    return null;
  }

  /// Extract organization using pattern matching (fallback)
  String? _extractOrganizationPattern(String input) {
    for (final org in _organizationKeywords) {
      if (input.contains(org.toLowerCase())) {
        return org;
      }
    }
    return null;
  }

  /// Extract branch information
  String? _extractBranch(String input, String? organization) {
    if (organization == null) return null;

    final lower = input.toLowerCase();
    final orgLower = organization.toLowerCase();

    // Look for branch keywords after organization name
    final branchKeywords = [
      'branch',
      'salbar',
      'салбар',
      'location',
      'байршил',
    ];

    for (final keyword in branchKeywords) {
      final index = lower.indexOf(keyword);
      if (index != -1) {
        // Get words after the branch keyword
        final afterKeyword = input.substring(index + keyword.length).trim();
        final branchName = afterKeyword.split(RegExp(r'[,.]'))[0].trim();
        if (branchName.isNotEmpty && branchName.length < 50) {
          return branchName;
        }
      }
    }

    return null;
  }

  /// Extract priority level from text
  TaskPriority? _extractPriority(String input) {
    return _extractPriorityPattern(input.toLowerCase());
  }

  /// Extract priority using pattern matching
  TaskPriority? _extractPriorityPattern(String input) {
    for (final keyword in _priorityKeywords['high']!) {
      if (input.contains(keyword)) {
        return TaskPriority.high;
      }
    }

    for (final keyword in _priorityKeywords['low']!) {
      if (input.contains(keyword)) {
        return TaskPriority.low;
      }
    }

    // Default to medium if no keywords match
    return null;
  }

  /// Calculate confidence score based on extraction results
  double _calculateConfidence(String? taskName, String? organization) {
    double score = 0.5; // Base score

    if (taskName != null && taskName.isNotEmpty) score += 0.25;
    if (organization != null && organization.isNotEmpty) score += 0.25;

    return score.clamp(0.0, 1.0);
  }

  /// Dispose resources
  void dispose() {
    if (_initialized) {
      _entityExtractor.close();
      _initialized = false;
    }
  }
}
