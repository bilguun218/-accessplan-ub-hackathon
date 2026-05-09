import 'package:dio/dio.dart';

import '../../../../core/config/api_config.dart';
import '../models/parsed_task_model.dart';

class TaskParseException implements Exception {
  final String message;
  final bool isNetwork;
  TaskParseException(this.message, {this.isNetwork = false});
}

class TaskParseService {
  final Dio _dio;

  TaskParseService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              contentType: 'application/json',
            ),
          );

  Future<List<ParsedTask>> parseTasks(String text) async {
    final fallback = _parseTasksLocally(text);

    try {
      final res = await _dio.post('/ai/parse-tasks', data: {'text': text});

      final data = res.data;
      List<dynamic>? rawList;
      if (data is List) {
        rawList = data;
      } else if (data is Map<String, dynamic>) {
        final candidate = data['tasks'] ?? data['data'] ?? data['result'];
        if (candidate is List) rawList = candidate;
      }
      if (rawList == null) return <ParsedTask>[];

      final parsed = [
        for (var i = 0; i < rawList.length; i++)
          ParsedTask.fromJson(
            Map<String, dynamic>.from(rawList[i] as Map),
            fallbackOrder: i + 1,
          ),
      ];

      if (parsed.length <= 1 && fallback.length > 1) {
        return fallback;
      }

      return parsed;
    } on DioException catch (e) {
      if (fallback.isNotEmpty) return fallback;

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw TaskParseException(
          'Please check your network connection.',
          isNetwork: true,
        );
      }
      throw TaskParseException('Failed to process tasks.');
    } catch (_) {
      if (fallback.isNotEmpty) return fallback;
      throw TaskParseException('Failed to process tasks.');
    }
  }

  List<ParsedTask> _parseTasksLocally(String text) {
    final normalized = text.replaceAll(
      RegExp(r'(^|\s)(?:\d+[\.\)]|[-•])\s+'),
      '\n',
    );
    final chunks = normalized
        .split(
          RegExp(
            r',|\.|;|\n|&| and | then | also | next | дараа нь | дараа | тэгээд | мөн | бас | ба | болон ',
            caseSensitive: false,
          ),
        )
        .expand(_splitActionBoundaries)
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    return [
      for (var i = 0; i < chunks.length; i++)
        _parsedTaskFromText(chunks[i], i + 1),
    ];
  }

  Iterable<String> _splitActionBoundaries(String text) {
    const taskStartPattern =
        r'(?:банк|эмийн\s+сан|эмнэлэг|хүнс|дэлгүүр|баримт|бичиг|бараа|кофе|кафе|ресторан|хоол|сургууль|khan\s+bank|golomt\s+bank|m\s+bank|монос|монфарм|emart|nomin|номин|gs25|cu\b|intermed|pharmacy|hospital|school|restaurant|cafe|market|supermarket)';
    const actionPattern =
        r'(?:орох|орно|очих|очно|авах|авна|хүргэх|хүргэнэ|өгөх|өгнө|хийх|хийнэ|төлөх|төлнө|уулзах|уулзана)';
    final boundary = RegExp(
      '($actionPattern)\\s+(?=$taskStartPattern)',
      caseSensitive: false,
      unicode: true,
    );
    return text
        .replaceAllMapped(boundary, (match) => '${match.group(1)}|||')
        .split('|||');
  }

  ParsedTask _parsedTaskFromText(String text, int order) {
    final lower = text.toLowerCase();
    final category = _inferCategory(lower);
    final location = _inferLocation(text, lower, category);

    return ParsedTask(
      order: order,
      title: _cleanTitle(text),
      category: category,
      locationText: location,
      timeText: _inferTimeText(lower),
      priority: _inferPriority(lower),
      needsPlaceSearch: location.isEmpty,
    );
  }

  String _cleanTitle(String text) {
    final cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return 'Шинэ ажил';
    return cleaned.length > 80 ? '${cleaned.substring(0, 80)}...' : cleaned;
  }

  String _inferCategory(String lower) {
    if (_containsAny(lower, ['эмийн сан', 'эм ', 'pharmacy', 'аптек'])) {
      return 'Эмийн сан';
    }
    if (_containsAny(lower, ['банк', 'bank', 'atm', 'мөнгө'])) {
      return 'Банк';
    }
    if (_containsAny(lower, [
      'хүнс',
      'дэлгүүр',
      'market',
      'mart',
      'supermarket',
      'emart',
      'nomin',
      'gs25',
      'cu',
    ])) {
      return 'Хүнс, дэлгүүр';
    }
    if (_containsAny(lower, ['баримт', 'бичиг', 'document'])) {
      return 'Баримт хүргэлт';
    }
    if (_containsAny(lower, ['хүргэх', 'delivery', 'package', 'бараа'])) {
      return 'Бараа хүргэлт';
    }
    if (_containsAny(lower, ['эмнэлэг', 'hospital', 'clinic'])) {
      return 'Эмнэлэг';
    }
    if (_containsAny(lower, ['сургууль', 'school', 'university'])) {
      return 'Боловсрол';
    }
    if (_containsAny(lower, ['кофе', 'кафе', 'cafe', 'coffee'])) {
      return 'Кафе';
    }
    if (_containsAny(lower, ['хоол', 'ресторан', 'restaurant', 'food'])) {
      return 'Ресторан';
    }
    return 'Бусад';
  }

  String _inferLocation(String text, String lower, String category) {
    final explicit = _knownPlaceFromText(lower);
    if (explicit.isNotEmpty) return explicit;

    switch (category) {
      case 'Эмийн сан':
        return 'Монос Эмийн сан';
      case 'Банк':
        return 'Khan Bank';
      case 'Хүнс, дэлгүүр':
        return 'Nomin Supermarket';
      case 'Эмнэлэг':
        return 'Intermed Hospital';
      case 'Боловсрол':
        return 'International School of Ulaanbaatar';
      case 'Кафе':
        return 'Cafe Camino';
      case 'Ресторан':
        return 'Grand Lux Restaurant';
      default:
        return _extractNamedLocation(text);
    }
  }

  String _knownPlaceFromText(String lower) {
    if (lower.contains('khan') || lower.contains('хаан банк')) {
      return 'Khan Bank';
    }
    if (lower.contains('golomt') || lower.contains('голомт')) {
      return 'Golomt Bank';
    }
    if (lower.contains('m bank')) {
      return 'M bank';
    }
    if (lower.contains('монос')) {
      return 'Монос Эмийн сан';
    }
    if (lower.contains('монфарм')) {
      return 'Монфарм эмийн сан';
    }
    if (lower.contains('emart')) {
      return 'Emart - Chinggis';
    }
    if (lower.contains('nomin') || lower.contains('номин')) {
      return 'Nomin Supermarket';
    }
    if (lower.contains('gs25')) {
      return 'GS25';
    }
    if (lower.contains('intermed')) {
      return 'Intermed Hospital';
    }
    return '';
  }

  String _extractNamedLocation(String text) {
    final match = RegExp(
      r'(?:руу|дээр|дотор|орчим)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(1)?.trim() ?? '';
  }

  String _inferTimeText(String lower) {
    final timeMatch = RegExp(r'\b\d{1,2}[:.]\d{2}\b').firstMatch(lower);
    if (timeMatch != null) return timeMatch.group(0)!.replaceAll('.', ':');

    final hourMatch = RegExp(r'\b\d{1,2}\s*цаг').firstMatch(lower);
    if (hourMatch != null) return hourMatch.group(0)!.trim();

    if (_containsAny(lower, ['маргааш', 'tomorrow'])) return 'Маргааш';
    if (_containsAny(lower, ['өнөөдөр', 'today'])) return 'Өнөөдөр';
    return '';
  }

  String _inferPriority(String lower) {
    if (_containsAny(lower, ['яаралтай', 'urgent', 'өндөр'])) return 'high';
    if (_containsAny(lower, ['дараа', 'later', 'бага'])) return 'low';
    return 'medium';
  }

  bool _containsAny(String text, List<String> needles) {
    for (final needle in needles) {
      if (text.contains(needle)) return true;
    }
    return false;
  }
}
