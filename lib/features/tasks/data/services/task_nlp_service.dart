import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';

import '../models/extracted_task_model.dart';

enum TaskIntent { banking, shopping, delivery, medical, education, unknown }

class TaskNlpService {
  static const List<String> _organizationKeywords = [
    'Khan Bank',
    'Emart',
    'CU',
    'Nomin',
    'GS25',
    'сургууль',
    'эмнэлэг',
    'банк',
  ];

  static const List<String> _districts = [
    'zaisan',
    'sansar',
    'khan-uul',
    'chingeltei',
    'bayanzurkh',
    'peace mall',
    'ikh nayad',
  ];

  static const Map<String, List<String>> _priorityKeywords = {
    'high': ['urgent', 'immediately', 'high', 'яаралтай'],
    'low': ['later', 'eventually', 'low'],
  };

  late EntityExtractor _entityExtractor;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    _entityExtractor = EntityExtractor(
      language: EntityExtractorLanguage.english,
    );

    _initialized = true;
  }

  Future<List<ExtractedTaskModel>> extractMultipleTasks(String input) async {
    if (!_initialized) {
      await initialize();
    }

    final chunks = _splitTasks(input);

    final List<ExtractedTaskModel> tasks = [];

    for (final chunk in chunks) {
      final task = await extractTaskEntities(chunk);

      tasks.add(task);
    }

    return tasks;
  }

  Future<ExtractedTaskModel> extractTaskEntities(String input) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      await _entityExtractor.annotateText(input);

      final taskName = _extractTaskName(input);

      final organization = _extractOrganization(input);

      final branch = _extractBranch(input, organization);

      final priority = _extractPriority(input);

      final location = _extractLocation(input);

      final intent = _detectIntent(input);

      final dateTime = _extractDateTime(input);

      return ExtractedTaskModel(
        taskName: taskName,
        organization: organization,
        branch: branch,
        priority: priority,
        rawText: input,
        extractedEntities: {
          'location': location,
          'intent': intent.name,
          'dateTime': dateTime?.toIso8601String(),
        },
        confidenceScore: _calculateConfidence(
          taskName,
          organization,
          branch,
          location,
        ),
      );
    } catch (e) {
      return ExtractedTaskModel(
        rawText: input,
        extractedEntities: {'error': e.toString()},
      );
    }
  }

  List<String> _splitTasks(String input) {
    return input
        .split(
          RegExp(
            r',|\.| and | then | дараа нь | тэгээд | мөн |;|\n',
            caseSensitive: false,
          ),
        )
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String? _extractTaskName(String input) {
    final words = input.split(' ');

    if (words.length <= 6) {
      return input;
    }

    return words.take(6).join(' ');
  }

  String? _extractOrganization(String input) {
    final lower = input.toLowerCase();

    for (final org in _organizationKeywords) {
      if (lower.contains(org.toLowerCase())) {
        return org;
      }
    }

    return null;
  }

  String? _extractBranch(String input, String? organization) {
    if (organization == null) {
      return null;
    }

    final lower = input.toLowerCase();

    if (organization == 'Khan Bank') {
      if (lower.contains('zaisan')) {
        return 'Khan Bank - Zaisan';
      }

      if (lower.contains('shangrila')) {
        return 'Khan Bank - ShangriLa';
      }
    }

    if (organization == 'Emart') {
      if (lower.contains('khan-uul')) {
        return 'Emart - Khan-Uul';
      }

      if (lower.contains('chinggis')) {
        return 'Emart - Chinggis';
      }
    }

    if (organization == 'CU') {
      if (lower.contains('sansar')) {
        return 'CU - Sansar';
      }
    }

    return null;
  }

  TaskPriority? _extractPriority(String input) {
    final lower = input.toLowerCase();

    for (final keyword in _priorityKeywords['high']!) {
      if (lower.contains(keyword)) {
        return TaskPriority.high;
      }
    }

    for (final keyword in _priorityKeywords['low']!) {
      if (lower.contains(keyword)) {
        return TaskPriority.low;
      }
    }

    return TaskPriority.medium;
  }

  String? _extractLocation(String input) {
    final lower = input.toLowerCase();

    for (final district in _districts) {
      if (lower.contains(district)) {
        return district;
      }
    }

    return null;
  }

  TaskIntent _detectIntent(String input) {
    final lower = input.toLowerCase();

    if (lower.contains('bank')) {
      return TaskIntent.banking;
    }

    if (lower.contains('buy') || lower.contains('emart')) {
      return TaskIntent.shopping;
    }

    if (lower.contains('package') || lower.contains('delivery')) {
      return TaskIntent.delivery;
    }

    return TaskIntent.unknown;
  }

  DateTime? _extractDateTime(String input) {
    final lower = input.toLowerCase();

    final now = DateTime.now();

    if (lower.contains('tomorrow')) {
      return now.add(const Duration(days: 1));
    }

    if (lower.contains('today')) {
      return now;
    }

    return null;
  }

  double _calculateConfidence(
    String? taskName,
    String? organization,
    String? branch,
    String? location,
  ) {
    double score = 0.3;

    if (taskName != null) {
      score += 0.2;
    }

    if (organization != null) {
      score += 0.2;
    }

    if (branch != null) {
      score += 0.15;
    }

    if (location != null) {
      score += 0.15;
    }

    return score.clamp(0.0, 1.0);
  }

  void dispose() {
    if (_initialized) {
      _entityExtractor.close();
      _initialized = false;
    }
  }
}
