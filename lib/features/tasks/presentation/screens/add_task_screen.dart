import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../map/presentation/screens/map_screen.dart';
import '../../data/models/parsed_task_model.dart';
import '../../data/models/standard_task.dart';
import '../../data/services/task_parse_service.dart';

const _primaryBlue = Color(0xFF2563EB);
const _primaryIndigo = Color(0xFF4F46E5);
const _slateSurface = Color(0xFFF8FAFC);

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

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
    final hasNamedPlace = p.locationText.isNotEmpty &&
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
      setState(() => _isParsing = false);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MapScreen(tasks: tasks)),
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
        _parseError = 'Failed to process tasks.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'AI-аар ажлуудаа бичнэ үү',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Жишээ: "Өнөөдөр банк орно, дараа эмийн сан, орой Тэнгис дээр найзтайгаа уулзана."',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _slateSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: _aiCtrl,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText:
                                'Энд өөрийн өдрийн ажлуудаа бичнэ үү...',
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ),
                    if (_parseError != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.warning,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _parseError!,
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isParsing ? null : _onGenerate,
                    icon: _isParsing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                      _isParsing ? 'Боловсруулж байна...' : 'Generate',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_primaryBlue, _primaryIndigo]),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ажил нэмэх',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Та өдрийн ажлуудаа бичээд Generate дарахад AI задлан маршрут зурна.',
            style: TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
