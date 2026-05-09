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
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
                contentType: 'application/json',
              ),
            );

  Future<List<ParsedTask>> parseTasks(String text) async {
    try {
      final res = await _dio.post(
        '/ai/parse-tasks',
        data: {'text': text},
      );

      final data = res.data;
      List<dynamic>? rawList;
      if (data is List) {
        rawList = data;
      } else if (data is Map<String, dynamic>) {
        final candidate = data['tasks'] ?? data['data'] ?? data['result'];
        if (candidate is List) rawList = candidate;
      }
      if (rawList == null) return <ParsedTask>[];

      return [
        for (var i = 0; i < rawList.length; i++)
          ParsedTask.fromJson(
            Map<String, dynamic>.from(rawList[i] as Map),
            fallbackOrder: i + 1,
          ),
      ];
    } on DioException catch (e) {
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
      throw TaskParseException('Failed to process tasks.');
    }
  }
}
