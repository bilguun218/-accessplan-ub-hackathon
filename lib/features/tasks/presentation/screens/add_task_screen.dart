import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../map/data/models/place_detail_model.dart';
import '../../../map/data/models/place_prediction_model.dart';
import '../../../map/data/services/mock_map_api_service.dart';
import '../../../map/presentation/screens/map_screen.dart';

const _primaryBlue = Color(0xFF2563EB);
const _primaryIndigo = Color(0xFF4F46E5);
const _softBlue = Color(0xFFDBEAFE);
const _slateSurface = Color(0xFFF8FAFC);

enum StartLocationType { current, custom }

enum TaskPriority { high, medium, low }

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _TaskItem {
  final int id;
  final String taskName;
  final String organization;
  final String selectedBranch;
  final TaskPriority priority;

  const _TaskItem({
    required this.id,
    required this.taskName,
    required this.organization,
    required this.selectedBranch,
    required this.priority,
  });
}

class _BranchSuggestion {
  final String organization;
  final String branch;

  const _BranchSuggestion(this.organization, this.branch);
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _taskName = TextEditingController();
  final _organizationController = TextEditingController();
  final _customStartLocation = TextEditingController();

  final MockMapApiService _mockMapService = MockMapApiService();

  StartLocationType _startLocationType = StartLocationType.current;
  TaskPriority _priority = TaskPriority.medium;
  String _organization = '';
  String _selectedBranch = '';
  String? _branchError;

  List<PlacePredictionModel> _placePredictions = [];
  bool _isSearchingPlaces = false;
  PlaceDetailModel? _selectedStartLocation;
  String? _currentLocationText;

  final List<_TaskItem> _tasks = [];

  static const _organizationOptions = ['Khan Bank', 'Emart', 'CU'];

  static const _branchesByOrganization = {
    'Khan Bank': [
      'Khan Bank - ShangriLa',
      'Khan Bank - Zaisan',
      'Khan Bank - 3,4 Horoolol',
    ],
    'Emart': ['Emart - Khan-Uul', 'Emart - Chinggis', 'Emart - Ikh Nayad'],
    'CU': ['CU - Peace Mall', 'CU - Sansar', 'CU - 120 Myangat'],
  };

  @override
  void initState() {
    super.initState();
    _organizationController.addListener(_handleOrganizationChange);
  }

  @override
  void dispose() {
    _organizationController.removeListener(_handleOrganizationChange);
    _taskName.dispose();
    _organizationController.dispose();
    _customStartLocation.dispose();
    super.dispose();
  }

  void _handleOrganizationChange() {
    final value = _organizationController.text;
    if (value == _organization) return;
    setState(() {
      _organization = value;
      if (!_branchOptions.contains(_selectedBranch)) {
        _selectedBranch = '';
      }
      _branchError = null;
    });
  }

  String get _matchedOrganization {
    final value = _organization.trim().toLowerCase();
    return _organizationOptions.firstWhere(
      (o) => o.toLowerCase() == value,
      orElse: () => '',
    );
  }

  List<String> get _branchOptions =>
      _branchesByOrganization[_matchedOrganization] ?? const [];

  List<_BranchSuggestion> get _branchSuggestions {
    final query = _organizationController.text.trim().toLowerCase();
    if (query.isEmpty) return const [];
    final matches = _organizationOptions.where(
      (org) => org.toLowerCase().contains(query),
    );
    return matches.expand((org) {
      final branches = _branchesByOrganization[org] ?? const [];
      return branches.map((branch) => _BranchSuggestion(org, branch));
    }).toList();
  }

  void _addTask() {
    final ok = _formKey.currentState?.validate() ?? false;
    setState(() {
      _branchError = _selectedBranch.isEmpty ? 'Салбар сонгоно уу.' : null;
    });
    if (!ok || _selectedBranch.isEmpty) return;

    setState(() {
      _tasks.add(
        _TaskItem(
          id: DateTime.now().millisecondsSinceEpoch,
          taskName: _taskName.text.trim(),
          organization: _organization.trim(),
          selectedBranch: _selectedBranch,
          priority: _priority,
        ),
      );
    });

    _resetForm();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ажил нэмэгдлээ.')));
  }

  void _resetForm() {
    _taskName.clear();
    _organizationController.clear();
    _customStartLocation.clear();
    setState(() {
      _startLocationType = StartLocationType.current;
      _priority = TaskPriority.medium;
      _organization = '';
      _selectedBranch = '';
      _branchError = null;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _placePredictions = [];
        _isSearchingPlaces = false;
      });
      return;
    }

    setState(() => _isSearchingPlaces = true);
    try {
      final predictions = await _mockMapService.autocomplete(query);
      if (mounted) {
        setState(() {
          _placePredictions = predictions;
          _isSearchingPlaces = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearchingPlaces = false);
      }
    }
  }

  Future<void> _selectPlace(PlacePredictionModel prediction) async {
    try {
      final detail = await _mockMapService.getPlaceDetails(prediction.placeId);
      if (mounted) {
        setState(() {
          _organizationController.text = detail.name;
          _organization = detail.name;
          _selectedBranch = detail.address;
          _placePredictions = [];
          _branchError = null;
        });
      }
    } catch (e) {
      debugPrint('Error getting place details: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() {
          _currentLocationText =
              '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
      }
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<PlaceDetailModel>(
      context,
      MaterialPageRoute(builder: (_) => const MapScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedStartLocation = result;
        _customStartLocation.text = result.address;
      });
    }
  }

  void _moveTaskUp(int index) {
    if (index == 0) return;
    setState(() {
      final item = _tasks.removeAt(index);
      _tasks.insert(index - 1, item);
    });
  }

  void _moveTaskDown(int index) {
    if (index >= _tasks.length - 1) return;
    setState(() {
      final item = _tasks.removeAt(index);
      _tasks.insert(index + 1, item);
    });
  }

  String _priorityLabel(TaskPriority value) {
    switch (value) {
      case TaskPriority.high:
        return 'High';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.low:
        return 'Low';
    }
  }

  Color _priorityBadgeBg(TaskPriority value) {
    switch (value) {
      case TaskPriority.high:
        return const Color(0xFFFEE2E2);
      case TaskPriority.medium:
        return const Color(0xFFFEF9C3);
      case TaskPriority.low:
        return const Color(0xFFDCFCE7);
    }
  }

  Color _priorityBadgeText(TaskPriority value) {
    switch (value) {
      case TaskPriority.high:
        return const Color(0xFFDC2626);
      case TaskPriority.medium:
        return const Color(0xFFB45309);
      case TaskPriority.low:
        return const Color(0xFF15803D);
    }
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    counterText: '',
    hintStyle: const TextStyle(color: AppColors.textMuted),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: AppColors.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 24,
        offset: const Offset(0, 14),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1000;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF1F5F9), Colors.white, Color(0xFFEFF6FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeaderSection(taskCount: _tasks.length),
                        const SizedBox(height: 24),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildFormCard()),
                              const SizedBox(width: 24),
                              Expanded(child: _buildTaskListCard()),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildFormCard(),
                              const SizedBox(height: 24),
                              _buildTaskListCard(),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormCard() {
    final suggestions = _branchSuggestions;
    final hasMatch = _matchedOrganization.isNotEmpty;

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _softBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.business_center_rounded,
                    color: _primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Add New Task',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Enter task details for smart route optimization.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'Starting Location',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _StartLocationTile(
              title: 'Use Current Location',
              subtitle: 'GPS detected location',
              value: StartLocationType.current,
              groupValue: _startLocationType,
              onChanged: (v) {
                setState(() => _startLocationType = v);
                if (v == StartLocationType.current) {
                  _getCurrentLocation();
                }
              },
            ),
            const SizedBox(height: 10),
            _StartLocationTile(
              title: 'Choose Location Manually',
              subtitle: 'Select from map',
              value: StartLocationType.custom,
              groupValue: _startLocationType,
              onChanged: (v) => setState(() => _startLocationType = v),
            ),
            if (_startLocationType == StartLocationType.current &&
                _currentLocationText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _softBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _currentLocationText!,
                  style: const TextStyle(fontSize: 12, color: _primaryBlue),
                ),
              ),
            ],
            if (_startLocationType == StartLocationType.custom) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openMapPicker,
                  icon: const Icon(Icons.map_rounded),
                  label: const Text('Pick Location from Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_selectedStartLocation != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _softBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedStartLocation!.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedStartLocation!.address,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            const Text(
              'Task Name',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _taskName,
              decoration: _inputDecoration('Ex: Open bank account'),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  Validators.required(v, message: 'Ажлын нэр шаардлагатай.'),
            ),
            const SizedBox(height: 18),
            const Text(
              'Organization / Place Name',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _organizationController,
              decoration: _inputDecoration('Search for places...'),
              textInputAction: TextInputAction.next,
              onChanged: _searchPlaces,
              validator: (v) => Validators.required(
                v,
                message: 'Байгууллагын нэр шаардлагатай.',
              ),
            ),
            if (_isSearchingPlaces) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const SizedBox(
                  height: 40,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ] else if (_placePredictions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _placePredictions.length,
                  itemBuilder: (context, index) {
                    final place = _placePredictions[index];
                    return InkWell(
                      onTap: () => _selectPlace(place),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: index < _placePredictions.length - 1
                                ? const BorderSide(color: AppColors.border)
                                : BorderSide.none,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.mainText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              place.secondaryText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (hasMatch) ...[
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Text(
                      'Nearby Branches',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _branchOptions.isEmpty
                        ? null
                        : () {
                            setState(() {
                              _selectedBranch = _branchOptions.first;
                              _branchError = null;
                            });
                          },
                    child: const Text('AI Select Best Branch'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                children: _branchOptions.map((branch) {
                  final selected = _selectedBranch == branch;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: selected ? _softBlue : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected ? _primaryBlue : AppColors.border,
                        width: selected ? 1.4 : 1,
                      ),
                    ),
                    child: ListTile(
                      onTap: () {
                        setState(() {
                          _selectedBranch = branch;
                          _branchError = null;
                        });
                      },
                      title: Text(
                        branch,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        '12-18 min away',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      trailing: selected
                          ? Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: _primaryBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
            if (_branchError != null) ...[
              const SizedBox(height: 6),
              Text(
                _branchError!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              'Priority',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<TaskPriority>(
              initialValue: _priority,
              decoration: _inputDecoration('Select priority'),
              items: TaskPriority.values
                  .map(
                    (priority) => DropdownMenuItem(
                      value: priority,
                      child: Text(_priorityLabel(priority)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _priority = value);
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('+ Add Task'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskListCard() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Task List',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tasks added for optimization',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _slateSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_tasks.length} Tasks',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_tasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _slateSurface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'No tasks added yet.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  final badgeBg = _priorityBadgeBg(task.priority);
                  final badgeText = _priorityBadgeText(task.priority);
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _slateSurface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: _primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.taskName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                task.organization,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151),
                                ),
                              ),
                              if (task.selectedBranch.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  task.selectedBranch,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _primaryBlue,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _priorityLabel(task.priority),
                                style: TextStyle(
                                  color: badgeText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _MoveButton(
                                  icon: Icons.keyboard_arrow_up,
                                  onTap: () => _moveTaskUp(index),
                                ),
                                const SizedBox(width: 6),
                                _MoveButton(
                                  icon: Icons.keyboard_arrow_down,
                                  onTap: () => _moveTaskDown(index),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primaryBlue, _primaryIndigo],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text(
                'Generate Smart Route',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final int taskCount;

  const _HeaderSection({required this.taskCount});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return isWide
        ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HeaderText(),
              _HeaderStats(taskCount: taskCount),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HeaderText(),
              const SizedBox(height: 16),
              _HeaderStats(taskCount: taskCount),
            ],
          );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _softBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'AI Powered Route Optimization',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _primaryBlue,
        ),
      ),
    );
  }
}

class _HeaderStats extends StatelessWidget {
  final int taskCount;

  const _HeaderStats({required this.taskCount});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class _StartLocationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final StartLocationType value;
  final StartLocationType groupValue;
  final ValueChanged<StartLocationType> onChanged;

  const _StartLocationTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _primaryBlue : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<StartLocationType>(
              value: value,
              groupValue: groupValue,
              onChanged: (v) => v != null ? onChanged(v) : null,
              activeColor: _primaryBlue,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MoveButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 20, color: AppColors.textMuted),
      ),
    );
  }
}
