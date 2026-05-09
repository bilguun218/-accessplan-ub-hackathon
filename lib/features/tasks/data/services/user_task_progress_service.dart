import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/standard_task.dart';

class TaskProgressEntry {
  final StandardTask task;
  final DateTime? at;

  const TaskProgressEntry({required this.task, this.at});
}

class UserTaskProgressSnapshot {
  final List<TaskProgressEntry> savedTasks;
  final List<TaskProgressEntry> completedTasks;
  final Set<String> claimedRewardIds;

  const UserTaskProgressSnapshot({
    required this.savedTasks,
    required this.completedTasks,
    required this.claimedRewardIds,
  });

  factory UserTaskProgressSnapshot.fromJson(Map<String, dynamic> json) {
    List<TaskProgressEntry> readEntries(String key, String dateKey) {
      final raw = json[key];
      if (raw is! List) return const <TaskProgressEntry>[];

      return raw
          .whereType<Map>()
          .map((item) {
            final taskJson = item['task'];
            if (taskJson is! Map) return null;
            return TaskProgressEntry(
              task: StandardTask.fromJson(Map<String, dynamic>.from(taskJson)),
              at: DateTime.tryParse(item[dateKey]?.toString() ?? ''),
            );
          })
          .whereType<TaskProgressEntry>()
          .where((entry) => entry.task.id.isNotEmpty)
          .toList();
    }

    final rawClaimed = json['claimedRewardIds'];
    return UserTaskProgressSnapshot(
      savedTasks: readEntries('savedTasks', 'savedAt'),
      completedTasks: readEntries('completedTasks', 'completedAt'),
      claimedRewardIds: rawClaimed is List
          ? rawClaimed.map((value) => value.toString()).toSet()
          : <String>{},
    );
  }
}

class UserTaskProgressService {
  UserTaskProgressService({ApiClient? client})
    : _client = client ?? ApiClient(storage: SecureStorageService());

  final ApiClient _client;

  Future<UserTaskProgressSnapshot> fetchProgress() async {
    try {
      final res = await _client.dio.get('/progress');
      return UserTaskProgressSnapshot.fromJson(
        Map<String, dynamic>.from(res.data['progress'] as Map),
      );
    } catch (e) {
      throw _client.toApiException(e);
    }
  }

  Future<void> saveTask(StandardTask task, {DateTime? savedAt}) async {
    try {
      await _client.dio.post(
        '/progress/saved-tasks',
        data: {
          'task': task.toJson(),
          'savedAt': (savedAt ?? DateTime.now()).toIso8601String(),
        },
      );
    } catch (e) {
      throw _client.toApiException(e);
    }
  }

  Future<void> removeSavedTask(String taskId) async {
    try {
      await _client.dio.delete('/progress/saved-tasks/$taskId');
    } catch (e) {
      throw _client.toApiException(e);
    }
  }

  Future<void> setCompletedTask(
    StandardTask task,
    bool completed, {
    DateTime? completedAt,
  }) async {
    try {
      if (completed) {
        await _client.dio.post(
          '/progress/completed-tasks',
          data: {
            'task': task.toJson(),
            'completedAt': (completedAt ?? DateTime.now()).toIso8601String(),
          },
        );
      } else {
        await _client.dio.delete('/progress/completed-tasks/${task.id}');
      }
    } catch (e) {
      throw _client.toApiException(e);
    }
  }

  Future<void> claimReward(String rewardId) async {
    try {
      await _client.dio.post('/progress/rewards/$rewardId/claim');
    } catch (e) {
      throw _client.toApiException(e);
    }
  }
}
