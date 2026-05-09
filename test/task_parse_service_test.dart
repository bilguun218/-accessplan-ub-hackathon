import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackhathon/features/tasks/data/services/task_parse_service.dart';

void main() {
  test(
    'splits multiple Mongolian tasks when API returns unavailable',
    () async {
      final dio = Dio()..httpClientAdapter = _FailingAdapter();
      final service = TaskParseService(dio: dio);

      final tasks = await service.parseTasks('эмийн сан орох банк орох');

      expect(tasks, hasLength(2));
      expect(tasks[0].title, contains('эмийн сан'));
      expect(tasks[1].title, contains('банк'));
    },
  );

  test(
    'splits connector separated tasks when API returns unavailable',
    () async {
      final dio = Dio()..httpClientAdapter = _FailingAdapter();
      final service = TaskParseService(dio: dio);

      final tasks = await service.parseTasks('кофе авах бас хүнс авах');

      expect(tasks, hasLength(2));
      expect(tasks[0].title, contains('кофе'));
      expect(tasks[1].title, contains('хүнс'));
    },
  );
}

class _FailingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'offline',
    );
  }
}
