import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../map/presentation/screens/map_screen.dart';
import '../../../tasks/data/models/standard_task.dart';
import '../../../tasks/data/services/user_task_progress_service.dart';
import '../../../tasks/presentation/screens/add_task_screen.dart';
import '../widgets/main_bottom_nav.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _index = 0;
  final List<StandardTask> _recentTasks = <StandardTask>[];
  final List<StandardTask> _mapTasks = <StandardTask>[];
  final List<StandardTask> _savedTasks = <StandardTask>[];
  final List<StandardTask> _completedTasks = <StandardTask>[];
  final Set<String> _savedTaskIds = <String>{};
  final Set<String> _completedTaskIds = <String>{};
  final Set<String> _claimedRewardIds = <String>{};
  final Map<String, DateTime> _savedAtById = <String, DateTime>{};
  final Map<String, DateTime> _completedAtById = <String, DateTime>{};
  final Map<String, String> _taskOwnerById = <String, String>{};
  final UserTaskProgressService _progressService = UserTaskProgressService();
  String? _loadedProgressUserId;
  bool _isProgressLoading = false;

  void _go(int i) => setState(() => _index = i);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = Provider.of<AuthProvider>(context).user;
    final userId = user?.id.trim();
    if (userId == null || userId.isEmpty) {
      _loadedProgressUserId = null;
      return;
    }
    if (_loadedProgressUserId == userId) return;
    _loadedProgressUserId = userId;
    unawaited(_loadProgress(userId));
  }

  String _activeUserId() =>
      context.read<AuthProvider>().user?.id.trim().isNotEmpty == true
      ? context.read<AuthProvider>().user!.id.trim()
      : 'local_user';

  bool _isOwned(StandardTask task, String userId) {
    return _taskOwnerById[task.id] == userId;
  }

  List<StandardTask> _ownedTasks(List<StandardTask> tasks, String userId) {
    return tasks.where((task) => _isOwned(task, userId)).toList();
  }

  bool _hasSignedInUser() {
    final userId = context.read<AuthProvider>().user?.id.trim();
    return userId != null && userId.isNotEmpty;
  }

  Future<void> _loadProgress(String userId) async {
    setState(() => _isProgressLoading = true);
    try {
      final snapshot = await _progressService.fetchProgress();
      if (!mounted) return;
      if (_activeUserId() != userId) {
        setState(() => _isProgressLoading = false);
        return;
      }
      setState(() {
        _replaceProgress(userId, snapshot);
        _isProgressLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isProgressLoading = false);
    }
  }

  void _replaceProgress(String userId, UserTaskProgressSnapshot snapshot) {
    final oldSavedIds = _savedTasks
        .where((task) => _isOwned(task, userId))
        .map((task) => task.id)
        .toList();
    final oldCompletedIds = _completedTasks
        .where((task) => _isOwned(task, userId))
        .map((task) => task.id)
        .toList();

    _savedTasks.removeWhere((task) => _isOwned(task, userId));
    _completedTasks.removeWhere((task) => _isOwned(task, userId));
    for (final id in oldSavedIds) {
      _savedTaskIds.remove(id);
      _savedAtById.remove(id);
    }
    for (final id in oldCompletedIds) {
      _completedTaskIds.remove(id);
      _completedAtById.remove(id);
    }

    for (final entry in snapshot.savedTasks) {
      _taskOwnerById[entry.task.id] = userId;
      _savedTasks.add(entry.task);
      _savedTaskIds.add(entry.task.id);
      _savedAtById[entry.task.id] = entry.at ?? DateTime.now();
    }
    for (final entry in snapshot.completedTasks) {
      _taskOwnerById[entry.task.id] = userId;
      _completedTasks.add(entry.task);
      _completedTaskIds.add(entry.task.id);
      _completedAtById[entry.task.id] = entry.at ?? DateTime.now();
    }
    _claimedRewardIds
      ..clear()
      ..addAll(snapshot.claimedRewardIds);
  }

  void _queueProgressSync(Future<void> Function() action) {
    if (!_hasSignedInUser()) return;
    unawaited(_runProgressSync(action));
  }

  Future<void> _runProgressSync(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Өгөгдөл хадгалахад алдаа гарлаа.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _rememberTasks(List<StandardTask> tasks) {
    final userId = _activeUserId();
    setState(() {
      final nextOrder = _ownedTasks(_mapTasks, userId).length + 1;
      final orderedTasks = <StandardTask>[
        for (var i = 0; i < tasks.length; i++)
          tasks[i].copyWith(order: nextOrder + i),
      ];

      for (final task in orderedTasks) {
        _taskOwnerById[task.id] = userId;
        _mapTasks.add(task);
      }

      for (final task in orderedTasks.reversed) {
        _taskOwnerById[task.id] = userId;
        _recentTasks.removeWhere(
          (existing) => _isOwned(existing, userId) && _sameTask(existing, task),
        );
        _recentTasks.insert(0, task);
      }
      final owned = _ownedTasks(_recentTasks, userId);
      if (owned.length > 12) {
        for (final extra in owned.skip(12)) {
          _recentTasks.removeWhere((task) => task.id == extra.id);
        }
      }
    });
  }

  void _saveTask(StandardTask task) {
    final userId = _activeUserId();
    final savedAt = DateTime.now();
    setState(() {
      _savedTasks.removeWhere((existing) {
        final remove =
            _isOwned(existing, userId) &&
            (existing.id == task.id || _sameTask(existing, task));
        if (remove) {
          _savedTaskIds.remove(existing.id);
          _savedAtById.remove(existing.id);
        }
        return remove;
      });
      _taskOwnerById[task.id] = userId;
      _savedTasks.insert(0, task);
      _savedTaskIds.add(task.id);
      _savedAtById[task.id] = savedAt;
    });
    _queueProgressSync(() => _progressService.saveTask(task, savedAt: savedAt));
  }

  void _removeSaved(StandardTask task) {
    setState(() {
      _savedTasks.removeWhere((saved) => saved.id == task.id);
      _savedTaskIds.remove(task.id);
      _savedAtById.remove(task.id);
    });
    _queueProgressSync(() => _progressService.removeSavedTask(task.id));
  }

  void _setTaskCompleted(StandardTask task, bool completed) {
    final userId = _activeUserId();
    final completedAt = DateTime.now();
    setState(() {
      _taskOwnerById[task.id] = userId;
      if (completed) {
        _completedTasks.removeWhere((existing) => existing.id == task.id);
        _completedTasks.insert(0, task);
        _completedTaskIds.add(task.id);
        _completedAtById[task.id] = completedAt;
      } else {
        _completedTasks.removeWhere((existing) => existing.id == task.id);
        _completedTaskIds.remove(task.id);
        _completedAtById.remove(task.id);
      }
    });
    _queueProgressSync(
      () => _progressService.setCompletedTask(
        task,
        completed,
        completedAt: completedAt,
      ),
    );
  }

  void _claimReward(String rewardId) {
    setState(() => _claimedRewardIds.add(rewardId));
    _queueProgressSync(() => _progressService.claimReward(rewardId));
  }

  void _openTaskRoute(StandardTask task) {
    final userId = _activeUserId();
    final routeTask = task.copyWith(order: 1);
    setState(() {
      _taskOwnerById[routeTask.id] = userId;
      _mapTasks
        ..clear()
        ..add(routeTask);
      _index = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeUser = context.watch<AuthProvider>().user;
    final userId = activeUser?.id.trim().isNotEmpty == true
        ? activeUser!.id.trim()
        : 'local_user';
    final recentTasks = _ownedTasks(_recentTasks, userId);
    final mapTasks = _ownedTasks(_mapTasks, userId);
    final savedTasks = _ownedTasks(_savedTasks, userId);
    final completedTasks = _ownedTasks(_completedTasks, userId);
    final savedTaskIds = savedTasks.map((task) => task.id).toSet();
    final completedTaskIds = completedTasks.map((task) => task.id).toSet();
    final pages = <Widget>[
      AddTaskScreen(
        recentTasks: recentTasks,
        savedTaskIds: savedTaskIds,
        completedTaskIds: completedTaskIds,
        onTasksCreated: _rememberTasks,
        onSaveTask: _saveTask,
        onOpenTaskRoute: _openTaskRoute,
        onOpenMap: () => _go(2),
        onTaskCompletionChanged: _setTaskCompleted,
        onOpenSaved: () => _go(1),
      ),
      _SavedTab(
        tasks: savedTasks,
        savedAtById: _savedAtById,
        onRemove: _removeSaved,
        onOpenRoute: _openTaskRoute,
      ),
      MapScreen(
        tasks: mapTasks,
        savedTaskIds: savedTaskIds,
        completedTaskIds: completedTaskIds,
        onSaveTask: _saveTask,
        onTaskCompletionChanged: _setTaskCompleted,
        reserveBottomNavSpace: true,
      ),
      _RewardsTab(
        completedTasks: completedTasks,
        completedAtById: _completedAtById,
        savedCount: savedTasks.length,
        claimedRewardIds: _claimedRewardIds,
        onClaimReward: _claimReward,
      ),
      _ProfileTab(
        plannedCount: recentTasks.length,
        savedCount: savedTasks.length,
        completedTasks: completedTasks,
        completedAtById: _completedAtById,
        onOpenRoutes: () => _go(2),
        onOpenRewards: () => _go(3),
      ),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: MainBottomNav(currentIndex: _index, onTap: _go),
    );
  }
}

class _SavedTab extends StatefulWidget {
  final List<StandardTask> tasks;
  final Map<String, DateTime> savedAtById;
  final ValueChanged<StandardTask> onRemove;
  final ValueChanged<StandardTask> onOpenRoute;

  const _SavedTab({
    required this.tasks,
    required this.savedAtById,
    required this.onRemove,
    required this.onOpenRoute,
  });

  @override
  State<_SavedTab> createState() => _SavedTabState();
}

class _SavedTabState extends State<_SavedTab> {
  final _searchCtrl = TextEditingController();
  var _filter = _SavedFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<StandardTask> get _visibleItems {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = widget.tasks.where((item) {
      final savedAt =
          widget.savedAtById[item.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final haystack =
          '${item.title} ${item.notes} ${item.category} ${_taskLocation(item)}'
              .toLowerCase();
      final matchesQuery = query.isEmpty || haystack.contains(query);

      final matchesFilter = switch (_filter) {
        _SavedFilter.all => true,
        _SavedFilter.recent => DateTime.now().difference(savedAt).inDays <= 7,
        _SavedFilter.nearby =>
          item.lat != null ||
              item.lng != null ||
              item.locationText.trim().isNotEmpty,
        _SavedFilter.highScore => _taskPoints(item) >= 30,
      };

      return matchesQuery && matchesFilter;
    }).toList();

    filtered.sort((a, b) {
      if (_filter == _SavedFilter.highScore) {
        return _taskPoints(b).compareTo(_taskPoints(a));
      }
      final aSavedAt =
          widget.savedAtById[a.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bSavedAt =
          widget.savedAtById[b.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bSavedAt.compareTo(aSavedAt);
    });

    return filtered;
  }

  void _openRoute(StandardTask item) {
    widget.onOpenRoute(item);
  }

  void _removeSaved(StandardTask item) {
    widget.onRemove(item);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.title} хадгалснаас хасагдлаа'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 122),
          children: [
            _PageHeader(
              title: 'Хадгалсан ажлууд',
              subtitle: '${widget.tasks.length} ажил хадгалагдсан',
              actionIcon: Icons.bookmark_rounded,
              actionColor: AppColors.primary,
              onAction: () => setState(() => _filter = _SavedFilter.all),
            ),
            const SizedBox(height: 18),
            _SearchField(
              controller: _searchCtrl,
              hint: 'Хадгалсан ажлаас хайх...',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Бүгд',
                    selected: _filter == _SavedFilter.all,
                    onTap: () => setState(() => _filter = _SavedFilter.all),
                  ),
                  _FilterChip(
                    label: 'Сүүлд',
                    selected: _filter == _SavedFilter.recent,
                    onTap: () => setState(() => _filter = _SavedFilter.recent),
                  ),
                  _FilterChip(
                    label: 'Ойрхон',
                    selected: _filter == _SavedFilter.nearby,
                    onTap: () => setState(() => _filter = _SavedFilter.nearby),
                  ),
                  _FilterChip(
                    label: 'Өндөр оноо',
                    selected: _filter == _SavedFilter.highScore,
                    onTap: () =>
                        setState(() => _filter = _SavedFilter.highScore),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (visible.isEmpty)
              _EmptyState(
                icon: Icons.bookmark_border_rounded,
                title: widget.tasks.isEmpty
                    ? 'Хадгалсан ажил алга'
                    : 'Илэрц олдсонгүй',
                message: widget.tasks.isEmpty
                    ? 'Home дээр ажил үүсгээд bookmark дарж хадгална.'
                    : 'Хайлт эсвэл filter-ээ өөрчлөөд дахин үзээрэй.',
              )
            else
              for (final item in visible) ...[
                _SavedTaskCard(
                  item: item,
                  onRoute: () => _openRoute(item),
                  onRemove: () => _removeSaved(item),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _RewardsTab extends StatefulWidget {
  final List<StandardTask> completedTasks;
  final Map<String, DateTime> completedAtById;
  final int savedCount;
  final Set<String> claimedRewardIds;
  final ValueChanged<String> onClaimReward;

  const _RewardsTab({
    required this.completedTasks,
    required this.completedAtById,
    required this.savedCount,
    required this.claimedRewardIds,
    required this.onClaimReward,
  });

  @override
  State<_RewardsTab> createState() => _RewardsTabState();
}

class _RewardsTabState extends State<_RewardsTab> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final completedCount = widget.completedTasks.length;
    final totalScore = _activityScore(completedCount, widget.savedCount);
    final achievements = _buildAchievements(
      completedTasks: completedCount,
      savedCount: widget.savedCount,
    );
    final rewards = _buildRewards(totalScore);
    final completedAchievements = achievements
        .where((item) => item.completed)
        .length;
    final unlockedRewards = rewards.where((item) => item.unlocked).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 122),
          children: [
            const _PageHeader(
              title: 'Шагнал',
              subtitle: 'Таны оноо, амжилт, урамшуулал',
              leadingIcon: Icons.emoji_events_rounded,
              leadingColor: Color(0xFFF59E0B),
            ),
            const SizedBox(height: 12),
            _RewardStatsGrid(
              totalScore: totalScore,
              weeklyScore: totalScore,
              completedTasks: completedCount,
              unlockedRewards: unlockedRewards,
            ),
            const SizedBox(height: 10),
            _SegmentSwitch(
              index: _tabIndex,
              onChanged: (index) => setState(() => _tabIndex = index),
            ),
            const SizedBox(height: 10),
            if (_tabIndex == 0)
              for (final item in achievements) ...[
                _AchievementCard(item: item),
                const SizedBox(height: 12),
              ]
            else
              for (final item in rewards) ...[
                _RewardCard(
                  item: item,
                  claimed: widget.claimedRewardIds.contains(item.id),
                  onClaim: item.unlocked
                      ? () => widget.onClaimReward(item.id)
                      : null,
                ),
                const SizedBox(height: 12),
              ],
            _SmallNote(
              text:
                  '$completedAchievements/${achievements.length} амжилт биелсэн',
            ),
            if (widget.completedTasks.isNotEmpty) ...[
              const SizedBox(height: 18),
              const _SectionLabel('ДУУССАН АЖЛУУД'),
              const SizedBox(height: 10),
              for (final task in widget.completedTasks.take(5)) ...[
                _HistoryTaskTile(
                  task: task,
                  completedAt: widget.completedAtById[task.id],
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final int plannedCount;
  final int savedCount;
  final List<StandardTask> completedTasks;
  final Map<String, DateTime> completedAtById;
  final VoidCallback onOpenRoutes;
  final VoidCallback onOpenRewards;

  const _ProfileTab({
    required this.plannedCount,
    required this.savedCount,
    required this.completedTasks,
    required this.completedAtById,
    required this.onOpenRoutes,
    required this.onOpenRewards,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final totalScore = _activityScore(completedTasks.length, savedCount);
    final rewardCount = _buildRewards(
      totalScore,
    ).where((reward) => reward.unlocked).length;
    final name = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : 'Хэрэглэгч';
    final email = user?.email.trim().isNotEmpty == true
        ? user!.email.trim()
        : 'Бүртгэлгүй имэйл';
    final district = user?.district?.trim().isNotEmpty == true
        ? '${user!.district} дүүрэг'
        : 'Дүүрэг бүртгээгүй';
    final userType =
        AppStrings.userTypeLabels[user?.userType] ?? 'Энгийн хэрэглэгч';
    final phone = user?.phone?.trim().isNotEmpty == true
        ? user!.phone!.trim()
        : 'Бүртгээгүй';
    final profileInfoRows = <_InfoRow>[
      _InfoRow(icon: Icons.person_outline, label: 'Төрөл', value: userType),
      _InfoRow(icon: Icons.phone_outlined, label: 'Утас', value: phone),
      _InfoRow(
        icon: Icons.language_rounded,
        label: 'Хэл',
        value: user?.preferredLanguage == 'en' ? 'English' : 'Монгол',
      ),
      _InfoRow(
        icon: Icons.verified_user_outlined,
        label: 'UID',
        value: user?.id ?? 'local_user',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 122),
          children: [
            _PageHeader(
              title: 'Профайл',
              subtitle: email,
              actionIcon: Icons.edit_outlined,
              actionColor: AppColors.textMuted,
              onAction: () =>
                  _showProfileInfoSheet(context, rows: profileInfoRows),
            ),
            const SizedBox(height: 18),
            _ProfileSummary(
              name: name,
              district: district,
              verified: user?.isEmailVerified ?? true,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ProfileStat(
                    value: '${completedTasks.length}',
                    label: 'Дууссан',
                    color: AppColors.primary,
                    background: const Color(0xFFEAF3FF),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ProfileStat(
                    value: '$totalScore',
                    label: 'Оноо',
                    color: const Color(0xFFF59E0B),
                    background: const Color(0xFFFFF7EC),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ProfileStat(
                    value: '$savedCount',
                    label: 'Хадгалсан',
                    color: const Color(0xFF16A34A),
                    background: const Color(0xFFECFDF3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ProfileStat(
                    value: '$rewardCount',
                    label: 'Шагнал',
                    color: const Color(0xFF9333EA),
                    background: const Color(0xFFFBF1FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionLabel('МИНИЙ'),
            const SizedBox(height: 10),
            _MenuGroup(
              children: [
                _MenuRow(
                  icon: Icons.account_circle_outlined,
                  title: 'Миний мэдээлэл',
                  onTap: () =>
                      _showProfileInfoSheet(context, rows: profileInfoRows),
                ),
                _MenuRow(
                  icon: Icons.route_outlined,
                  title: 'Миний маршрут',
                  badge: plannedCount > 0 ? '$plannedCount' : null,
                  onTap: onOpenRoutes,
                ),
                _MenuRow(
                  icon: Icons.history_rounded,
                  title: 'Ажлын түүх',
                  badge: completedTasks.isNotEmpty
                      ? '${completedTasks.length}'
                      : null,
                  onTap: () => _showTaskHistorySheet(context),
                ),
                _MenuRow(
                  icon: Icons.emoji_events_outlined,
                  title: 'Шагнал, урамшуулал',
                  badge: rewardCount > 0 ? '$rewardCount' : null,
                  onTap: onOpenRewards,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionLabel('ТОХИРГОО'),
            const SizedBox(height: 10),
            _MenuGroup(
              children: [
                _MenuRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Мэдэгдэл',
                  onTap: () => _showNotificationSheet(context),
                ),
                _MenuRow(
                  icon: Icons.shield_outlined,
                  title: 'Нууцлал',
                  onTap: () => _showPrivacySheet(context, userId: user?.id),
                ),
                _MenuRow(
                  icon: Icons.logout_rounded,
                  title: 'Гарах',
                  danger: true,
                  onTap: auth.isLoading
                      ? null
                      : () async {
                          await context.read<AuthProvider>().logout();
                          if (context.mounted) context.go('/login');
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileInfoSheet(
    BuildContext context, {
    required List<_InfoRow> rows,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: _BottomSheetScaffold(
              title: 'Миний мэдээлэл',
              child: _InfoCard(rows: rows),
            ),
          ),
        );
      },
    );
  }

  void _showTaskHistorySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: _BottomSheetScaffold(
              title: 'Ажлын түүх',
              child: completedTasks.isEmpty
                  ? const _EmptyState(
                      icon: Icons.history_rounded,
                      title: 'Амжуулсан ажил алга',
                      message: 'Map дээр ажлаа дуусгахад энд харагдана.',
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 430),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: completedTasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final task = completedTasks[index];
                          final completedAt = completedAtById[task.id];
                          return _HistoryTaskTile(
                            task: task,
                            completedAt: completedAt,
                          );
                        },
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  void _showNotificationSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        var routeAlerts = true;
        var rewardAlerts = true;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return _BottomSheetScaffold(
                  title: 'Мэдэгдэл',
                  child: _MenuGroup(
                    children: [
                      SwitchListTile(
                        value: routeAlerts,
                        onChanged: (value) =>
                            setModalState(() => routeAlerts = value),
                        title: const Text('Маршрутын сануулга'),
                        secondary: const Icon(
                          Icons.route_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      SwitchListTile(
                        value: rewardAlerts,
                        onChanged: (value) =>
                            setModalState(() => rewardAlerts = value),
                        title: const Text('Шагналын мэдэгдэл'),
                        secondary: const Icon(
                          Icons.emoji_events_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showPrivacySheet(BuildContext context, {required String? userId}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: _BottomSheetScaffold(
              title: 'Нууцлал',
              child: _InfoCard(
                rows: [
                  _InfoRow(
                    icon: Icons.verified_user_outlined,
                    label: 'UID',
                    value: userId ?? 'local_user',
                  ),
                  const _InfoRow(
                    icon: Icons.lock_outline,
                    label: 'Өгөгдөл',
                    value: 'Зөвхөн таны бүртгэл',
                  ),
                  const _InfoRow(
                    icon: Icons.history_toggle_off_rounded,
                    label: 'Түүх',
                    value: 'UID-ээр шүүгдэнэ',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _SavedFilter { all, recent, nearby, highScore }

bool _sameTask(StandardTask a, StandardTask b) => _taskKey(a) == _taskKey(b);

String _taskKey(StandardTask task) {
  return [
    task.title,
    task.category,
    task.locationText,
    task.placeSearchQuery,
  ].map((value) => value.trim().toLowerCase()).join('|');
}

String _taskCategory(StandardTask task) {
  final category = task.category.trim();
  return category.isEmpty ? 'Ажил' : category;
}

String _taskLocation(StandardTask task) {
  final location = task.locationText.trim();
  if (location.isNotEmpty &&
      !location.toLowerCase().startsWith('search nearby')) {
    return location;
  }
  final query = task.placeSearchQuery.trim();
  if (query.toLowerCase().startsWith('search nearby')) {
    return query
        .replaceFirst(RegExp('search nearby', caseSensitive: false), '')
        .trim();
  }
  return query.isEmpty ? 'Байршил тодорхойгүй' : query;
}

String _taskDescription(StandardTask task) {
  final notes = task.notes.trim();
  if (notes.isNotEmpty) return notes;
  return _taskLocation(task);
}

int _taskMinutes(StandardTask task) {
  final match = RegExp(r'\d+').firstMatch(task.timeText);
  if (match != null) return int.tryParse(match.group(0)!) ?? 20;
  return switch (task.priority) {
    StandardTaskPriority.high => 30,
    StandardTaskPriority.medium => 20,
    StandardTaskPriority.low => 15,
  };
}

int _taskPoints(StandardTask task) {
  return switch (task.priority) {
    StandardTaskPriority.high => 35,
    StandardTaskPriority.medium => 25,
    StandardTaskPriority.low => 15,
  };
}

IconData _taskIcon(StandardTask task) {
  final text = '${task.category} ${task.title}'.toLowerCase();
  if (text.contains('эм') || text.contains('тусламж')) {
    return Icons.medication_outlined;
  }
  if (text.contains('баримт') || text.contains('бичиг')) {
    return Icons.description_outlined;
  }
  if (text.contains('хүнс') || text.contains('дэлгүүр')) {
    return Icons.shopping_cart_outlined;
  }
  if (text.contains('банк')) return Icons.account_balance_outlined;
  if (text.contains('бараа') || text.contains('хүрг')) {
    return Icons.inventory_2_outlined;
  }
  return Icons.task_alt_outlined;
}

Color _taskAccent(StandardTask task) {
  final text = '${task.category} ${task.title}'.toLowerCase();
  if (text.contains('баримт') || text.contains('бичиг')) {
    return const Color(0xFF16A34A);
  }
  if (text.contains('хүнс') || text.contains('дэлгүүр')) {
    return const Color(0xFFEA580C);
  }
  if (text.contains('бараа') || text.contains('хүрг')) {
    return const Color(0xFF9333EA);
  }
  return AppColors.primary;
}

int _activityScore(int routeCount, int savedCount) {
  return routeCount * 25 + savedCount * 10;
}

String _shortDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$month/$day';
}

class _Achievement {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final int points;
  final bool completed;

  const _Achievement({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.completed,
  });
}

class _RewardItem {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final int cost;
  final bool unlocked;

  const _RewardItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cost,
    required this.unlocked,
  });
}

List<_Achievement> _buildAchievements({
  required int completedTasks,
  required int savedCount,
}) {
  return <_Achievement>[
    _Achievement(
      id: 'first_task',
      icon: Icons.track_changes_rounded,
      title: 'Эхний ажил',
      subtitle: 'Маршрутаа анх удаа үүсгэсэн',
      points: 50,
      completed: completedTasks >= 1,
    ),
    _Achievement(
      id: 'five_tasks',
      icon: Icons.schedule_rounded,
      title: '5 ажил төлөвлөсөн',
      subtitle: 'Нэг дор олон ажлаа зохион байгуулсан',
      points: 75,
      completed: completedTasks >= 5,
    ),
    _Achievement(
      id: 'saved_task',
      icon: Icons.bookmark_added_outlined,
      title: 'Хадгалсан ажлууд',
      subtitle: 'Дахин ашиглах ажлаа хадгалсан',
      points: 60,
      completed: savedCount >= 1,
    ),
    _Achievement(
      id: 'city_friendly',
      icon: Icons.apartment_rounded,
      title: 'Оновчтой төлөвлөгч',
      subtitle: '10 ажил төлөвлөсөн үед нээгдэнэ',
      points: 100,
      completed: completedTasks >= 10,
    ),
  ];
}

List<_RewardItem> _buildRewards(int totalScore) {
  return <_RewardItem>[
    _RewardItem(
      id: 'starter',
      icon: Icons.workspace_premium_outlined,
      title: 'Эхлэгч тэмдэг',
      subtitle: '50 оноо хүрэхэд нээгдэнэ',
      cost: 50,
      unlocked: totalScore >= 50,
    ),
    _RewardItem(
      id: 'planner',
      icon: Icons.route_outlined,
      title: 'Төлөвлөгч тэмдэг',
      subtitle: '150 оноо хүрэхэд нээгдэнэ',
      cost: 150,
      unlocked: totalScore >= 150,
    ),
    _RewardItem(
      id: 'pro',
      icon: Icons.emoji_events_outlined,
      title: 'Идэвхтэй хэрэглэгч',
      subtitle: '300 оноо хүрэхэд нээгдэнэ',
      cost: 300,
      unlocked: totalScore >= 300,
    ),
  ];
}

class _SavedTaskCard extends StatelessWidget {
  final StandardTask item;
  final VoidCallback onRoute;
  final VoidCallback onRemove;

  const _SavedTaskCard({
    required this.item,
    required this.onRoute,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = _taskAccent(item);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(radius: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SoftIcon(icon: _taskIcon(item), color: color, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    _TinyIconButton(
                      icon: Icons.bookmark_remove_outlined,
                      color: AppColors.primary,
                      onTap: onRemove,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _taskDescription(item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8E99AA),
                    fontSize: 13.5,
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MiniPill(label: _taskCategory(item), color: color),
                    _InlineMetric(
                      icon: Icons.schedule_outlined,
                      text: '${_taskMinutes(item)} мин',
                    ),
                    _InlineMetric(
                      icon: Icons.star_rounded,
                      text: '+${_taskPoints(item)}',
                      color: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: onRoute,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text(
                      'Маршрут руу нэмэх',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(19),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardStatsGrid extends StatelessWidget {
  final int totalScore;
  final int weeklyScore;
  final int completedTasks;
  final int unlockedRewards;

  const _RewardStatsGrid({
    required this.totalScore,
    required this.weeklyScore,
    required this.completedTasks,
    required this.unlockedRewards,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 300 ? 1 : 2;
        final spacing = columns == 1 ? 0.0 : 8.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: 8,
          children: [
            SizedBox(
              width: itemWidth,
              child: _RewardStatTile(
                icon: Icons.star_border_rounded,
                label: 'Нийт оноо',
                value: '$totalScore',
                color: const Color(0xFFF59E0B),
                background: const Color(0xFFFFF7EC),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _RewardStatTile(
                icon: Icons.trending_up_rounded,
                label: 'Энэ 7 хоног',
                value: '+$weeklyScore',
                color: const Color(0xFF16A34A),
                background: const Color(0xFFECFDF3),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _RewardStatTile(
                icon: Icons.check_circle_outline_rounded,
                label: 'Дууссан',
                value: '$completedTasks',
                color: AppColors.primary,
                background: const Color(0xFFEAF3FF),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _RewardStatTile(
                icon: Icons.card_giftcard_rounded,
                label: 'Шагнал',
                value: '$unlockedRewards',
                color: const Color(0xFF9333EA),
                background: const Color(0xFFFBF1FF),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RewardStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color background;

  const _RewardStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EEF5)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentSwitch extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _SegmentSwitch({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentPill(
              icon: Icons.emoji_events_rounded,
              label: 'Амжилт',
              active: index == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _SegmentPill(
              icon: Icons.card_giftcard_rounded,
              label: 'Шагналууд',
              active: index == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SegmentPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: active ? AppColors.textDark : const Color(0xFF9AA3B2),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? AppColors.textDark : const Color(0xFF9AA3B2),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final _Achievement item;

  const _AchievementCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return _RewardListCard(
      icon: item.icon,
      title: item.title,
      subtitle: item.subtitle,
      trailing: item.completed
          ? const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF16A34A),
              size: 22,
            )
          : const Icon(Icons.lock_outline_rounded, color: Color(0xFFB8C0CC)),
      footer: Row(
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFFB000), size: 18),
          const SizedBox(width: 5),
          Text(
            '+${item.points} оноо',
            style: const TextStyle(
              color: Color(0xFFF59E0B),
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final _RewardItem item;
  final bool claimed;
  final VoidCallback? onClaim;

  const _RewardCard({
    required this.item,
    required this.claimed,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return _RewardListCard(
      icon: item.icon,
      title: item.title,
      subtitle: item.subtitle,
      trailing: SizedBox(
        height: 34,
        child: FilledButton(
          onPressed: claimed ? null : onClaim,
          style: FilledButton.styleFrom(
            backgroundColor: item.unlocked ? AppColors.primary : Colors.grey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Text(
            claimed ? 'Авсан' : (item.unlocked ? 'Авах' : 'Түгжээтэй'),
          ),
        ),
      ),
      footer: Text(
        '${item.cost} оноо',
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RewardListCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final Widget footer;

  const _RewardListCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(radius: 18),
      child: Row(
        children: [
          _SoftIcon(
            icon: icon,
            color: const Color(0xFFF59E0B),
            background: const Color(0xFFFFF7EC),
            size: 48,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    trailing,
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8E99AA),
                    fontSize: 13.5,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                footer,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  final String name;
  final String district;
  final bool verified;

  const _ProfileSummary({
    required this.name,
    required this.district,
    required this.verified,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(radius: 20),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              const _ProfileAvatar(),
              if (verified)
                const Positioned(
                  right: -4,
                  bottom: -4,
                  child: _VerifiedBadge(),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF9AA3B2),
                      size: 17,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        district,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8E99AA),
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFB000),
                      size: 18,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '4.9',
                      style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      ' • Үнэлгээ',
                      style: TextStyle(
                        color: Color(0xFF9AA3B2),
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF60A5FA), AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 54),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final Color background;

  const _ProfileStat({
    required this.value,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> rows;

  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(radius: 18),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _InfoTile(row: rows[i]),
            if (i != rows.length - 1)
              Divider(
                height: 1,
                color: AppColors.border.withValues(alpha: 0.6),
              ),
          ],
        ],
      ),
    );
  }
}

class _BottomSheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const _BottomSheetScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD9DEE7),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _HistoryTaskTile extends StatelessWidget {
  final StandardTask task;
  final DateTime? completedAt;

  const _HistoryTaskTile({required this.task, this.completedAt});

  @override
  Widget build(BuildContext context) {
    final color = _taskAccent(task);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(radius: 16),
      child: Row(
        children: [
          _SoftIcon(icon: _taskIcon(task), color: color, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _taskDescription(task),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF16A34A),
                size: 22,
              ),
              if (completedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  _shortDate(completedAt!),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final _InfoRow row;

  const _InfoTile({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(row.icon, color: AppColors.primary, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            child: Text(
              row.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final List<Widget> children;

  const _MenuGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(radius: 18),
      child: Column(children: children),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;
  final bool danger;
  final VoidCallback? onTap;

  const _MenuRow({
    required this.icon,
    required this.title,
    this.badge,
    this.danger = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.55)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: danger
                    ? AppColors.error.withValues(alpha: 0.08)
                    : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: danger ? AppColors.error : const Color(0xFF334155),
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              color: danger ? AppColors.error : const Color(0xFFCBD5E1),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? leadingIcon;
  final Color? leadingColor;
  final IconData? actionIcon;
  final Color? actionColor;
  final VoidCallback? onAction;

  const _PageHeader({
    required this.title,
    required this.subtitle,
    this.leadingIcon,
    this.leadingColor,
    this.actionIcon,
    this.actionColor,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leadingIcon != null) ...[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: leadingColor ?? AppColors.primary,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: (leadingColor ?? AppColors.primary).withValues(
                    alpha: 0.22,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(leadingIcon, color: Colors.white, size: 27),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 25,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF8E99AA),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (actionIcon != null) ...[
          const SizedBox(width: 12),
          _RoundIconButton(
            icon: actionIcon!,
            color: actionColor ?? AppColors.primary,
            background: Colors.white,
            onTap: onAction ?? () {},
          ),
        ],
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF9AA3B2),
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF9AA3B2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        backgroundColor: const Color(0xFFEFF3F8),
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textMuted,
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
        ),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF9AA3B2),
        fontSize: 15,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: color, size: 23),
      ),
    );
  }
}

class _SoftIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? background;
  final double size;

  const _SoftIcon({
    required this.icon,
    required this.color,
    this.background,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _TinyIconButton({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 19),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InlineMetric({
    required this.icon,
    required this.text,
    this.color = const Color(0xFF9AA3B2),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(radius: 18),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 36),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallNote extends StatelessWidget {
  final String text;

  const _SmallNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

BoxDecoration _cardDecoration({double radius = 18}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.045),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
