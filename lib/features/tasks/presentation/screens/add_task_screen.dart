import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../map/presentation/screens/map_screen.dart';
import '../../data/models/parsed_task_model.dart';
import '../../data/models/standard_task.dart';
import '../../data/services/task_parse_service.dart';

const _primaryBlue = Color(0xFF2563EB);
const _surfaceTint = Color(0xFFF6F9FD);

class AddTaskScreen extends StatefulWidget {
  final List<StandardTask> recentTasks;
  final Set<String> savedTaskIds;
  final Set<String> completedTaskIds;
  final ValueChanged<List<StandardTask>>? onTasksCreated;
  final ValueChanged<StandardTask>? onSaveTask;
  final ValueChanged<StandardTask>? onOpenTaskRoute;
  final void Function(StandardTask task, bool completed)?
  onTaskCompletionChanged;
  final VoidCallback? onOpenSaved;

  const AddTaskScreen({
    super.key,
    this.recentTasks = const <StandardTask>[],
    this.savedTaskIds = const <String>{},
    this.completedTaskIds = const <String>{},
    this.onTasksCreated,
    this.onSaveTask,
    this.onOpenTaskRoute,
    this.onTaskCompletionChanged,
    this.onOpenSaved,
  });

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _aiCtrl = TextEditingController();
  final TaskParseService _taskParseService = TaskParseService();

  bool _isParsing = false;
  String? _parseError;
  int _idCounter = 0;

  @override
  void dispose() {
    _aiCtrl.dispose();
    super.dispose();
  }

  String _newId() {
    _idCounter += 1;
    return '${DateTime.now().millisecondsSinceEpoch}_$_idCounter';
  }

  StandardTask _fromParsed(ParsedTask p, int order) {
    final hasNamedPlace =
        p.locationText.isNotEmpty &&
        !p.locationText.toLowerCase().startsWith('search nearby');
    final placeSearchQuery = hasNamedPlace
        ? p.locationText
        : (p.locationText.isNotEmpty
              ? p.locationText
              : (p.category.isNotEmpty ? 'search nearby ${p.category}' : ''));

    return StandardTask(
      id: _newId(),
      order: order,
      title: p.title,
      category: p.category,
      locationText: p.locationText,
      timeText: p.timeText,
      priority: parsePriority(p.priority),
      needsPlaceSearch: p.needsPlaceSearch || !hasNamedPlace,
      placeSearchQuery: placeSearchQuery,
      source: TaskSource.ai,
    );
  }

  Future<void> _onGenerate() async {
    final input = _aiCtrl.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _isParsing = true;
      _parseError = null;
    });

    try {
      final parsed = await _taskParseService.parseTasks(input);
      if (!mounted) return;
      if (parsed.isEmpty) {
        setState(() {
          _isParsing = false;
          _parseError = 'Ажил олдсонгүй. Дахин оролдоно уу.';
        });
        return;
      }
      final tasks = <StandardTask>[
        for (var i = 0; i < parsed.length; i++) _fromParsed(parsed[i], i + 1),
      ];
      widget.onTasksCreated?.call(tasks);
      setState(() => _isParsing = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MapScreen(
            tasks: tasks,
            savedTaskIds: widget.savedTaskIds,
            completedTaskIds: widget.completedTaskIds,
            onSaveTask: widget.onSaveTask,
            onTaskCompletionChanged: widget.onTaskCompletionChanged,
          ),
        ),
      );
    } on TaskParseException catch (e) {
      if (!mounted) return;
      setState(() {
        _isParsing = false;
        _parseError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isParsing = false;
        _parseError = 'Ажлуудыг боловсруулахад алдаа гарлаа.';
      });
    }
  }

  void _insertQuickText(String text) {
    final current = _aiCtrl.text.trim();
    final next = current.isEmpty ? text : '$current\n$text';
    _aiCtrl
      ..text = next
      ..selection = TextSelection.collapsed(offset: next.length);
    setState(() => _parseError = null);
  }

  void _openSaved() {
    final onOpenSaved = widget.onOpenSaved;
    if (onOpenSaved != null) {
      onOpenSaved();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Хадгалсан хэсэг home tab-аас нээгдэнэ'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openTaskRoute(StandardTask task) {
    final onOpenTaskRoute = widget.onOpenTaskRoute;
    if (onOpenTaskRoute != null) {
      onOpenTaskRoute(task);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapScreen(
          tasks: [task],
          savedTaskIds: widget.savedTaskIds,
          completedTaskIds: widget.completedTaskIds,
          onSaveTask: widget.onSaveTask,
          onTaskCompletionChanged: widget.onTaskCompletionChanged,
        ),
      ),
    );
  }

  void _saveTask(StandardTask task) {
    widget.onSaveTask?.call(task);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${task.title} хадгаллаа'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _userName(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final name = user?.fullName.trim() ?? '';
    return name.isEmpty ? 'Б. Бат-Эрдэнэ' : name;
  }

  @override
  Widget build(BuildContext context) {
    final userName = _userName(context);
    final recentTasks = widget.recentTasks;
    final totalMinutes = recentTasks.fold<int>(
      0,
      (sum, task) => sum + _taskMinutes(task),
    );
    final highPriorityCount = recentTasks
        .where((task) => task.priority == StandardTaskPriority.high)
        .length;
    final totalScore = recentTasks.fold<int>(
      0,
      (sum, task) => sum + _taskPoints(task),
    );

    return Scaffold(
      backgroundColor: _surfaceTint,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 118),
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _primaryBlue,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryBlue.withValues(alpha: 0.20),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on_outlined,
                          color: Colors.white,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AccessPlan UB',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textDark,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Саадгүй хотын ухаалаг төлөвлөгөө',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFF9AA3B2),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: AppColors.textDark,
                              size: 24,
                            ),
                          ),
                          Positioned(
                            top: 9,
                            right: 9,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF3B4E),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Сайн байна уу,',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$userName 👋',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: _homeCardDecoration(radius: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _primaryBlue,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Өнөөдрийн ажлуудаа оруулна уу',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontSize: 17,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 96,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFBFD),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _aiCtrl,
                        maxLines: 4,
                        minLines: 4,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.32,
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText:
                              'Өнөөдрийн хийх ажлуудаа нэг дор бичнэ үү...',
                          hintStyle: TextStyle(
                            color: Color(0xFF9AA3B2),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CategoryPill(
                          icon: Icons.medication_outlined,
                          label: 'Эмийн сан',
                          color: _primaryBlue,
                          background: const Color(0xFFEFF6FF),
                          onTap: () => _insertQuickText('Эмийн сан орох'),
                        ),
                        _CategoryPill(
                          icon: Icons.description_outlined,
                          label: 'Баримт хүргэлт',
                          color: const Color(0xFF16A34A),
                          background: const Color(0xFFECFDF3),
                          onTap: () => _insertQuickText('Баримт бичиг хүргэх'),
                        ),
                        _CategoryPill(
                          icon: Icons.shopping_cart_outlined,
                          label: 'Хүнс авах',
                          color: const Color(0xFFEA580C),
                          background: const Color(0xFFFFF7EC),
                          onTap: () => _insertQuickText('Хүнс авах'),
                        ),
                        _CategoryPill(
                          icon: Icons.inventory_2_outlined,
                          label: 'Бараа хүргэх',
                          color: const Color(0xFF9333EA),
                          background: const Color(0xFFFBF1FF),
                          onTap: () => _insertQuickText('Бараа хүргэх'),
                        ),
                      ],
                    ),
                    if (_parseError != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _parseError!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stacked = constraints.maxWidth < 300;
                        final primary = _TaskActionButton(
                          label: _isParsing ? 'Боловсруулж байна' : 'Эхлэх',
                          icon: _isParsing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                          filled: true,
                          onPressed: _isParsing ? null : _onGenerate,
                        );
                        final secondary = _TaskActionButton(
                          label: 'Хадгалснаас',
                          icon: const Icon(Icons.bookmark_border_rounded),
                          onPressed: _openSaved,
                        );

                        if (stacked) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              primary,
                              const SizedBox(height: 8),
                              secondary,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: primary),
                            const SizedBox(width: 10),
                            Expanded(child: secondary),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'Өнөөдрийн тойм',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: _TodayTile(
                      value: '${recentTasks.length}',
                      label: 'Нийт ажил',
                      color: _primaryBlue,
                      background: const Color(0xFFEAF3FF),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TodayTile(
                      value: '$totalMinutes',
                      label: 'мин',
                      color: const Color(0xFF16A34A),
                      background: const Color(0xFFECFDF3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TodayTile(
                      value: '$highPriorityCount',
                      label: 'ажил',
                      color: const Color(0xFFEA580C),
                      background: const Color(0xFFFFF7EC),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TodayTile(
                      value: '$totalScore',
                      label: 'Оноо',
                      color: const Color(0xFF9333EA),
                      background: const Color(0xFFFBF1FF),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Байнга хийдэг ажлууд',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 18,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (widget.onOpenSaved != null)
                    InkWell(
                      onTap: _openSaved,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Хадгалсан',
                              style: TextStyle(
                                color: _primaryBlue,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: _primaryBlue,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (recentTasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: _HomeEmptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'Ажил үүсгээгүй байна',
                  message: 'Дээр ажлуудаа бичээд эхлүүлэхэд энд харагдана.',
                ),
              )
            else
              SizedBox(
                height: 116,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  itemCount: recentTasks.length > 10 ? 10 : recentTasks.length,
                  itemBuilder: (context, index) {
                    final task = recentTasks[index];
                    return _FrequentTaskCard(
                      task: task,
                      saved: widget.savedTaskIds.contains(task.id),
                      onRoute: () => _openTaskRoute(task),
                      onSave: () => _saveTask(task),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskActionButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final bool filled;
  final VoidCallback? onPressed;

  const _TaskActionButton({
    required this.label,
    required this.icon,
    this.filled = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 8),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return SizedBox(
      height: 48,
      child: filled
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _primaryBlue.withValues(alpha: 0.55),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                shape: shape,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF475569),
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 9),
                shape: shape,
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: child,
            ),
    );
  }
}

class _TodayTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final Color background;

  const _TodayTile({
    required this.value,
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(15),
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
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FrequentTaskCard extends StatelessWidget {
  final StandardTask task;
  final bool saved;
  final VoidCallback onRoute;
  final VoidCallback onSave;

  const _FrequentTaskCard({
    required this.task,
    required this.saved,
    required this.onRoute,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final color = _taskAccent(task);
    return InkWell(
      onTap: onRoute,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 108,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(10),
        decoration: _homeCardDecoration(radius: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(_taskIcon(task), color: color, size: 22),
                ),
                const Spacer(),
                InkWell(
                  onTap: onSave,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: _primaryBlue,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
                height: 1.08,
              ),
            ),
            const Spacer(),
            Text(
              _taskSubtitle(task),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF9AA3B2),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _HomeEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _homeCardDecoration(radius: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: _primaryBlue, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.25,
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
  return _primaryBlue;
}

String _taskSubtitle(StandardTask task) {
  final location = task.locationText.trim().isNotEmpty
      ? task.locationText.trim()
      : task.placeSearchQuery.trim();
  return location.isEmpty ? 'Байршилгүй' : location;
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

BoxDecoration _homeCardDecoration({double radius = 22}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.045),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
