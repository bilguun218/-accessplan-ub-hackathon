import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../tasks/data/models/standard_task.dart';
import '../../../organizations/data/models/business_post.dart';
import '../../../organizations/data/models/map_promotion_item.dart';
import '../../../organizations/data/services/mock_business_post_service.dart';
import '../../data/models/place_detail_model.dart';
import '../../data/models/place_prediction_model.dart';
import '../../data/models/route_segment.dart';
import '../../data/services/map_api_service.dart';
import '../../data/services/place_geocoding_service.dart';
import '../../data/services/segment_route_service.dart';
import '../utils/business_marker_factory.dart';
import '../widgets/promotion_preview_bottom_sheet.dart';
import '_route_summary_panel.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.tasks = const <StandardTask>[],
    this.savedTaskIds = const <String>{},
    this.completedTaskIds = const <String>{},
    this.onSaveTask,
    this.onTaskCompletionChanged,
    this.reserveBottomNavSpace = false,
    this.enablePlaceSelection = false,
  });

  final List<StandardTask> tasks;
  final Set<String> savedTaskIds;
  final Set<String> completedTaskIds;
  final ValueChanged<StandardTask>? onSaveTask;
  final void Function(StandardTask task, bool completed)?
  onTaskCompletionChanged;
  final bool reserveBottomNavSpace;
  final bool enablePlaceSelection;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const double _defaultZoom = 13.0;
  static const MarkerId _selectedMarkerId = MarkerId('selected_place');

  final Completer<GoogleMapController> _controllerCompleter =
      Completer<GoogleMapController>();

  final TextEditingController _searchCtrl = TextEditingController();

  final FocusNode _searchFocus = FocusNode();

  final MapApiService _mapApiService = MapApiService();
  final PlaceGeocodingService _geocodingService = PlaceGeocodingService();
  final SegmentRouteService _segmentRouteService = SegmentRouteService();
  final MockBusinessPostService _mockBusinessPostService =
      MockBusinessPostService();

  GoogleMapController? _controller;
  Timer? _searchDebounce;
  StreamSubscription<Position>? _positionSub;

  BitmapDescriptor? _liveLocationIcon;
  BitmapDescriptor? _startPointIcon;
  BitmapDescriptor? _giftMarkerIcon;
  BitmapDescriptor? _sponsoredGiftMarkerIcon;
  Marker? _liveLocationMarker;
  Marker? _startPointMarker;

  String? _permissionMessage;
  String? _errorMessage;

  bool _trafficEnabled = true;
  bool _showPromotions = true;
  bool _isSearching = false;
  bool _isLoadingPlace = false;

  MapType _mapType = MapType.normal;

  List<PlacePredictionModel> _suggestions = <PlacePredictionModel>[];

  PlaceDetailModel? _selectedPlace;

  Set<Marker> _markers = <Marker>{};
  List<MapPromotionItem> _mapPromotions = <MapPromotionItem>[];

  // Task-driven route state
  List<RouteSegment> _segments = <RouteSegment>[];
  Set<Polyline> _segmentPolylines = <Polyline>{};
  Set<Polyline> _placeRoutePolylines = <Polyline>{};
  Set<Marker> _taskMarkers = <Marker>{};
  bool _isBuildingRoute = false;
  String? _routeErrorMessage;
  int? _focusedSegmentIndex;
  LatLng? _currentLatLng;
  late Set<String> _savedTaskIds;
  late Set<String> _completedTaskIds;
  List<StandardTask> _routableTasks = <StandardTask>[];
  List<StandardTask> _promotionTasks = <StandardTask>[];

  late CameraPosition _initialCameraPosition;
  bool _locationLoaded = false;

  List<StandardTask> get _activeRouteTasks => [
    ...widget.tasks,
    ..._promotionTasks,
  ];

  bool get _hasRouteTasks => _activeRouteTasks.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _savedTaskIds = Set<String>.of(widget.savedTaskIds);
    _completedTaskIds = Set<String>.of(widget.completedTaskIds);
    // Initialize with a default location, will be updated when actual location loads
    _initialCameraPosition = const CameraPosition(
      target: LatLng(47.918873, 106.917701),
      zoom: _defaultZoom,
    );
    _prepareLocationIcons();
    _initPromotionMarkerIcons();
    _initLocation();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tasksChanged = !_sameRouteTasks(oldWidget.tasks, widget.tasks);

    if (!_sameStringSet(oldWidget.savedTaskIds, widget.savedTaskIds)) {
      _savedTaskIds = Set<String>.of(widget.savedTaskIds);
    }
    if (!_sameStringSet(oldWidget.completedTaskIds, widget.completedTaskIds)) {
      _completedTaskIds = Set<String>.of(widget.completedTaskIds);
      unawaited(_refreshStatuses());
    }

    if (tasksChanged) {
      _promotionTasks = <StandardTask>[];
      _clearRouteState();
      if (_hasRouteTasks && _currentLatLng != null && !_isBuildingRoute) {
        unawaited(_buildRouteForTasks());
      }
    }
  }

  bool _sameRouteTasks(List<StandardTask> a, List<StandardTask> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameRouteTask(a[i], b[i])) return false;
    }
    return true;
  }

  bool _sameStringSet(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final value in a) {
      if (!b.contains(value)) return false;
    }
    return true;
  }

  bool _sameRouteTask(StandardTask a, StandardTask b) {
    return a.id == b.id &&
        a.order == b.order &&
        a.title == b.title &&
        a.category == b.category &&
        a.locationText == b.locationText &&
        a.timeText == b.timeText &&
        a.priority == b.priority &&
        a.needsPlaceSearch == b.needsPlaceSearch &&
        a.placeSearchQuery == b.placeSearchQuery &&
        a.lat == b.lat &&
        a.lng == b.lng;
  }

  void _clearRouteState() {
    setState(() {
      _segments = <RouteSegment>[];
      _segmentPolylines = <Polyline>{};
      _placeRoutePolylines = <Polyline>{};
      _taskMarkers = <Marker>{};
      _routableTasks = <StandardTask>[];
      _mapPromotions = <MapPromotionItem>[];
      _focusedSegmentIndex = null;
      _routeErrorMessage = null;
      if (!_hasRouteTasks) {
        _startPointMarker = null;
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _positionSub?.cancel();
    _controller?.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _prepareLocationIcons() async {
    final start = await _buildStartPointBitmap();
    final live = await _buildLiveLocationBitmap();
    if (!mounted) return;
    setState(() {
      _startPointIcon = start;
      _liveLocationIcon = live;
      if (_currentLatLng != null) {
        _liveLocationMarker = _makeLiveLocationMarker(_currentLatLng!);
      }
    });
  }

  Future<void> _initPromotionMarkerIcons() async {
    final gift = await BusinessMarkerFactory.createGiftMarker(
      type: BusinessPostType.promotion,
    );
    final sponsored = await BusinessMarkerFactory.createGiftMarker(
      type: BusinessPostType.promotion,
      isSponsored: true,
    );
    if (!mounted) return;
    setState(() {
      _giftMarkerIcon = gift;
      _sponsoredGiftMarkerIcon = sponsored;
    });
  }

  Future<BitmapDescriptor> _buildStartPointBitmap() async {
    const double size = 84;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = const Offset(size / 2, size / 2);
    final radius = size / 2 - 10;

    canvas.drawCircle(
      Offset(center.dx, center.dy + 4),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, radius + 3, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF1E88E5));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: 26);
  }

  Future<BitmapDescriptor> _buildLiveLocationBitmap() async {
    const double size = 120;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = const Offset(size / 2, size / 2);
    final radius = size / 2 - 10;
    const blue = Color(0xFF1E88E5);
    final white = Paint()..color = Colors.white;

    canvas.drawCircle(
      Offset(center.dx, center.dy + 4),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(center, radius + 3, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius, Paint()..color = blue);

    canvas.save();
    final clip = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.clipPath(clip);

    canvas.drawCircle(
      Offset(center.dx, center.dy - radius * 0.28),
      radius * 0.32,
      white,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius * 0.85),
        width: radius * 1.55,
        height: radius * 1.40,
      ),
      white,
    );
    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: 44);
  }

  Marker _makeLiveLocationMarker(LatLng pos) {
    return Marker(
      markerId: const MarkerId('live_user_location'),
      position: pos,
      anchor: const Offset(0.5, 0.5),
      zIndexInt: 3,
      infoWindow: const InfoWindow(
        title: 'Миний одоогийн байршил',
        snippet: 'GPS дагаж шинэчлэгдэнэ',
      ),
      icon: _liveLocationIcon ?? BitmapDescriptor.defaultMarker,
    );
  }

  Marker _makeStartPointMarker(LatLng pos) {
    return Marker(
      markerId: const MarkerId('route_start_point'),
      position: pos,
      anchor: const Offset(0.5, 0.5),
      zIndexInt: 1,
      infoWindow: const InfoWindow(
        title: 'Эхлэх цэг',
        snippet: 'Маршрут эхэлсэн байршил',
      ),
      icon: _startPointIcon ?? BitmapDescriptor.defaultMarker,
    );
  }

  void _startLocationStream() {
    _positionSub?.cancel();
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 4,
          ),
        ).listen((pos) {
          if (!mounted) return;
          final ll = LatLng(pos.latitude, pos.longitude);
          setState(() {
            _currentLatLng = ll;
            _liveLocationMarker = _makeLiveLocationMarker(ll);
          });
        });
  }

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _setPermissionMessage('Байршлын үйлчилгээ идэвхгүй байна.');
        return;
      }

      var status = await Permission.locationWhenInUse.status;

      if (status.isDenied || status.isRestricted) {
        status = await Permission.locationWhenInUse.request();
      }

      if (status.isPermanentlyDenied) {
        _setPermissionMessage('Байршлын permission permanently denied.');
        return;
      }

      if (!status.isGranted) {
        _setPermissionMessage('Location permission required.');
        return;
      }

      if (!mounted) return;

      setState(() {
        _permissionMessage = null;
      });

      await _goToCurrentLocation();
    } catch (e) {
      debugPrint('Init location error: $e');
    }
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final currentLatLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      if (!_locationLoaded) {
        _initialCameraPosition = CameraPosition(
          target: currentLatLng,
          zoom: 16,
        );
        _locationLoaded = true;
      }

      setState(() {
        _currentLatLng = currentLatLng;
        _liveLocationMarker = _makeLiveLocationMarker(currentLatLng);
      });

      _startLocationStream();

      await _animateTo(currentLatLng, zoom: 16);

      if (_hasRouteTasks && _segments.isEmpty && !_isBuildingRoute) {
        unawaited(_buildRouteForTasks());
      }
    } catch (e) {
      debugPrint('Current location error: $e');
    }
  }

  static const List<Color> _segmentColors = <Color>[
    Color(0xFF2563EB),
    Color(0xFFDC2626),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFF0891B2),
    Color(0xFF65A30D),
  ];

  Color _segmentColor(int index) =>
      _segmentColors[index % _segmentColors.length];

  Future<void> _buildRouteForTasks() async {
    final origin = _currentLatLng;
    final routeTasks = _activeRouteTasks;
    if (origin == null || routeTasks.isEmpty) return;

    setState(() {
      _isBuildingRoute = true;
      _routeErrorMessage = null;
      _segments = <RouteSegment>[];
      _segmentPolylines = <Polyline>{};
      _placeRoutePolylines = <Polyline>{};
      _taskMarkers = <Marker>{};
      _focusedSegmentIndex = null;
      _startPointMarker = _makeStartPointMarker(origin);
    });

    final resolved = <StandardTask>[];
    final addresses = <String, String>{};
    for (final t in routeTasks) {
      if (t.lat != null && t.lng != null) {
        resolved.add(t);
        continue;
      }
      final query = t.needsPlaceSearch && t.placeSearchQuery.isNotEmpty
          ? t.placeSearchQuery
          : (t.locationText.isNotEmpty ? t.locationText : t.placeSearchQuery);
      if (query.isEmpty) {
        resolved.add(t);
        continue;
      }
      final geo = await _geocodingService.resolve(query);
      if (geo != null) {
        final r = t.copyWith(
          lat: geo.latLng.latitude,
          lng: geo.latLng.longitude,
          locationText: t.locationText.isEmpty ? geo.name : t.locationText,
        );
        resolved.add(r);
        addresses[r.id] = geo.address;
      } else {
        resolved.add(t);
      }
    }

    final routable = resolved
        .where((t) => t.lat != null && t.lng != null)
        .toList();

    if (routable.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isBuildingRoute = false;
        _routeErrorMessage = 'Аль ч ажилд байршил олдсонгүй.';
      });
      return;
    }

    // Build segments
    final segments = <RouteSegment>[];
    final polylines = <Polyline>{};

    final firstPendingIdx = routable.indexWhere(
      (t) => !_completedTaskIds.contains(t.id),
    );

    LatLng prev = origin;
    String prevLabel = 'Current location';
    for (var i = 0; i < routable.length; i++) {
      final t = routable[i];
      final dest = LatLng(t.lat!, t.lng!);
      final result = await _segmentRouteService.fetch(
        origin: prev,
        destination: dest,
      );

      final color = _segmentColor(i);
      final segIndex = i;

      final points = result?.points ?? <LatLng>[prev, dest];
      final distanceMeters = result?.distanceMeters ?? 0;
      final durationSeconds = result?.durationSeconds ?? 0;
      final delaySeconds = _trafficDelaySeconds(durationSeconds);

      final status = _completedTaskIds.contains(t.id)
          ? RouteTaskStatus.completed
          : (i == firstPendingIdx
                ? RouteTaskStatus.current
                : RouteTaskStatus.pending);

      segments.add(
        RouteSegment(
          index: segIndex,
          taskId: t.id,
          taskOrder: t.order,
          fromLabel: prevLabel,
          toLabel: t.title,
          toAddress: addresses[t.id] ?? '',
          toCategory: t.category,
          toTimeText: t.timeText,
          fromLatLng: prev,
          toLatLng: dest,
          polyline: points,
          distanceMeters: distanceMeters,
          durationSeconds: durationSeconds,
          trafficDelaySeconds: delaySeconds,
          status: status,
        ),
      );

      final lineColor = status == RouteTaskStatus.completed
          ? const Color(0xFF16A34A)
          : color;

      polylines.add(
        Polyline(
          polylineId: PolylineId('segment_$segIndex'),
          points: points,
          width: 6,
          color: lineColor,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          consumeTapEvents: true,
          onTap: () => _onSegmentTap(segIndex),
        ),
      );

      prev = dest;
      prevLabel = t.title;
    }

    final markers = await _buildTaskMarkers(routable, firstPendingIdx);

    if (!mounted) return;
    setState(() {
      _routableTasks = routable;
      _segments = segments;
      _segmentPolylines = polylines;
      _taskMarkers = markers;
      _isBuildingRoute = false;
    });

    unawaited(_loadRouteMockPromotions(segments: segments, origin: origin));

    await _fitBounds(origin, segments);
  }

  Future<Set<Marker>> _buildTaskMarkers(
    List<StandardTask> tasks,
    int currentIdx,
  ) async {
    final markers = <Marker>{};
    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      final status = _completedTaskIds.contains(t.id)
          ? RouteTaskStatus.completed
          : (i == currentIdx
                ? RouteTaskStatus.current
                : RouteTaskStatus.pending);
      final icon = await _taskMarkerBitmap(t.order, status);
      markers.add(
        Marker(
          markerId: MarkerId('task_${t.id}'),
          position: LatLng(t.lat!, t.lng!),
          infoWindow: InfoWindow(
            title: '${t.order}. ${t.title}',
            snippet: t.locationText.isNotEmpty ? t.locationText : t.category,
          ),
          icon: icon,
          zIndexInt: status == RouteTaskStatus.current ? 2 : 1,
          onTap: () => _onTaskMarkerTap(t, i),
        ),
      );
    }
    return markers;
  }

  static const Color _statusGreen = Color(0xFF16A34A);
  static const Color _statusBlue = Color(0xFFF59E0B);
  static const Color _statusGray = Color(0xFF9CA3AF);

  Color _statusColor(RouteTaskStatus status) {
    switch (status) {
      case RouteTaskStatus.completed:
        return _statusGreen;
      case RouteTaskStatus.current:
        return _statusBlue;
      case RouteTaskStatus.pending:
        return _statusGray;
    }
  }

  Future<BitmapDescriptor> _taskMarkerBitmap(
    int number,
    RouteTaskStatus status,
  ) async {
    const double size = 84;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final fill = _statusColor(status);
    final center = const Offset(size / 2, size / 2);
    final radius = size / 2 - 12;

    // Soft shadow
    canvas.drawCircle(
      Offset(center.dx, center.dy + 4),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // White ring
    canvas.drawCircle(center, radius + 3, Paint()..color = Colors.white);

    // Filled status circle
    canvas.drawCircle(center, radius, Paint()..color = fill);

    // Highlight ring for current
    if (status == RouteTaskStatus.current) {
      canvas.drawCircle(
        center,
        radius + 6,
        Paint()
          ..color = fill.withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }

    // Number or check
    if (status == RouteTaskStatus.completed) {
      final p = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(center.dx - 12, center.dy + 1)
        ..lineTo(center.dx - 3, center.dy + 10)
        ..lineTo(center.dx + 13, center.dy - 8);
      canvas.drawPath(path, p);
    } else {
      final tp = TextPainter(
        text: TextSpan(
          text: '$number',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: 44);
  }

  int _trafficDelaySeconds(int durationSeconds) {
    if (!_trafficEnabled || durationSeconds <= 0) return 0;
    final hour = DateTime.now().hour;
    final isPeak = (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 20);
    final factor = isPeak ? 0.25 : 0.06;
    return (durationSeconds * factor).round();
  }

  Future<void> _toggleTaskCompletion(int segmentIndex) async {
    if (segmentIndex < 0 || segmentIndex >= _segments.length) return;
    final seg = _segments[segmentIndex];
    final completed = !_completedTaskIds.contains(seg.taskId);
    setState(() {
      if (completed) {
        _completedTaskIds.add(seg.taskId);
      } else {
        _completedTaskIds.remove(seg.taskId);
      }
    });
    final task = _taskForSegment(seg);
    if (task != null) {
      widget.onTaskCompletionChanged?.call(task, completed);
    }
    await _refreshStatuses();
  }

  StandardTask? _taskForSegment(RouteSegment segment) {
    for (final task in _routableTasks) {
      if (task.id == segment.taskId) return task;
    }
    for (final task in _promotionTasks) {
      if (task.id == segment.taskId) return task;
    }
    for (final task in widget.tasks) {
      if (task.id == segment.taskId) return task;
    }
    return null;
  }

  void _saveSegmentTask(RouteSegment segment) {
    final task = _taskForSegment(segment);
    if (task == null) return;
    setState(() => _savedTaskIds.add(task.id));
    widget.onSaveTask?.call(task);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${task.title} хадгаллаа'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _refreshStatuses() async {
    if (_routableTasks.isEmpty) return;
    final firstPendingIdx = _routableTasks.indexWhere(
      (t) => !_completedTaskIds.contains(t.id),
    );

    final updatedSegments = <RouteSegment>[];
    for (var i = 0; i < _segments.length; i++) {
      final s = _segments[i];
      final status = _completedTaskIds.contains(s.taskId)
          ? RouteTaskStatus.completed
          : (i == firstPendingIdx
                ? RouteTaskStatus.current
                : RouteTaskStatus.pending);
      updatedSegments.add(s.copyWith(status: status));
    }

    final updatedPolylines = <Polyline>{};
    for (var i = 0; i < updatedSegments.length; i++) {
      final s = updatedSegments[i];
      final color = s.status == RouteTaskStatus.completed
          ? _statusGreen
          : _segmentColor(i);
      updatedPolylines.add(
        Polyline(
          polylineId: PolylineId('segment_$i'),
          points: s.polyline,
          width: 6,
          color: color,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          consumeTapEvents: true,
          onTap: () => _onSegmentTap(i),
        ),
      );
    }

    final markers = await _buildTaskMarkers(_routableTasks, firstPendingIdx);
    if (!mounted) return;
    setState(() {
      _segments = updatedSegments;
      _segmentPolylines = updatedPolylines;
      _taskMarkers = markers;
    });
  }

  Future<void> _fitBounds(LatLng origin, List<RouteSegment> segments) async {
    if (segments.isEmpty) return;
    final controller = _controller ?? await _controllerCompleter.future;

    double minLat = origin.latitude;
    double maxLat = origin.latitude;
    double minLng = origin.longitude;
    double maxLng = origin.longitude;
    void include(LatLng p) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    for (final s in segments) {
      include(s.fromLatLng);
      include(s.toLatLng);
      for (final p in s.polyline) {
        include(p);
      }
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    if (minLat == maxLat && minLng == maxLng) {
      await _animateTo(LatLng(minLat, minLng), zoom: 15);
      return;
    }
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  Future<void> _fitLatLngs(List<LatLng> points, {double padding = 90}) async {
    if (points.isEmpty) return;
    final controller = _controller ?? await _controllerCompleter.future;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    if (minLat == maxLat && minLng == maxLng) {
      await _animateTo(points.first, zoom: 15);
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        padding,
      ),
    );
  }

  void _onSegmentTap(int index) {
    setState(() {
      _focusedSegmentIndex = index;
    });
    if (index >= 0 && index < _segments.length) {
      unawaited(_centerOnSegment(_segments[index]));
    }
  }

  Future<void> _centerOnSegment(RouteSegment segment) async {
    final controller = _controller ?? await _controllerCompleter.future;
    final pts = segment.polyline.isNotEmpty
        ? segment.polyline
        : <LatLng>[segment.fromLatLng, segment.toLatLng];

    double minLat = pts.first.latitude;
    double maxLat = pts.first.latitude;
    double minLng = pts.first.longitude;
    double maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    if (minLat == maxLat && minLng == maxLng) {
      await _animateTo(LatLng(minLat, minLng), zoom: 15);
      return;
    }
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  void _setPermissionMessage(String msg) {
    if (!mounted) return;

    setState(() {
      _permissionMessage = msg;
    });
  }

  Future<void> _animateTo(LatLng pos, {double zoom = 15}) async {
    final controller = _controller ?? await _controllerCompleter.future;

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: zoom)),
    );
  }

  void _toggleTraffic() {
    setState(() {
      _trafficEnabled = !_trafficEnabled;
    });
  }

  void _changeMapType(MapType type) {
    setState(() {
      _mapType = type;
    });
  }

  void _showMapTypeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Зургийн төрөл',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                _MapTypeOption(
                  title: 'Энгийн',
                  subtitle: 'Стандарт газрын зураг',
                  icon: Icons.map_rounded,
                  isSelected: _mapType == MapType.normal,
                  onTap: () {
                    Navigator.pop(context);
                    _changeMapType(MapType.normal);
                  },
                ),
                _MapTypeOption(
                  title: 'Сансрын зураг',
                  subtitle: 'Дэлгэрэнгүй дүрслэл',
                  icon: Icons.satellite_alt_rounded,
                  isSelected: _mapType == MapType.satellite,
                  onTap: () {
                    Navigator.pop(context);
                    _changeMapType(MapType.satellite);
                  },
                ),
                _MapTypeOption(
                  title: 'Хосолсон',
                  subtitle: 'Зураг болон тэмдэглэгээ',
                  icon: Icons.layers_rounded,
                  isSelected: _mapType == MapType.hybrid,
                  onTap: () {
                    Navigator.pop(context);
                    _changeMapType(MapType.hybrid);
                  },
                ),
                _MapTypeOption(
                  title: 'Газрын гадарга',
                  subtitle: 'Өндөршил, газрын хэлбэр',
                  icon: Icons.terrain_rounded,
                  isSelected: _mapType == MapType.terrain,
                  onTap: () {
                    Navigator.pop(context);
                    _changeMapType(MapType.terrain);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
        _errorMessage = null;
      });

      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _runAutocomplete(query);
    });
  }

  Future<void> _runAutocomplete(String query) async {
    try {
      final result = await _mapApiService.autocomplete(query);

      if (!mounted) return;

      if (_searchCtrl.text.trim() != query) {
        return;
      }

      setState(() {
        _suggestions = result;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _suggestions = [];
        _isSearching = false;
        _errorMessage = 'Хайлт амжилтгүй боллоо.';
      });
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();

    _searchCtrl.clear();

    setState(() {
      _suggestions = [];
      _isSearching = false;
      _errorMessage = null;
      _selectedPlace = null;
      _markers = <Marker>{};
      _placeRoutePolylines = <Polyline>{};
    });

    _goToCurrentLocation();
  }

  Future<void> _onTaskMarkerTap(StandardTask task, int segmentIndex) async {
    _onSegmentTap(segmentIndex);
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoadingPlace = true;
      _suggestions = [];
      _isSearching = false;
      _errorMessage = null;
    });

    final detail = await _findPlaceDetailForTask(task);
    if (!mounted) return;

    if (detail == null) {
      setState(() {
        _isLoadingPlace = false;
        _errorMessage = 'Энэ ажлын газрын дэлгэрэнгүй мэдээлэл олдсонгүй.';
      });
      return;
    }

    await _selectPlace(detail, moveCamera: false);
  }

  Future<PlaceDetailModel?> _findPlaceDetailForTask(StandardTask task) async {
    final queries = <String>[
      task.locationText,
      task.placeSearchQuery,
      task.title,
      task.category,
    ].map((value) => value.trim()).where((value) => value.isNotEmpty).toList();

    for (final query in queries) {
      final predictions = await _mapApiService.autocomplete(query);
      if (predictions.isEmpty) continue;

      return _mapApiService.getPlaceDetails(predictions.first.placeId);
    }

    if (task.lat == null || task.lng == null) return null;

    return PlaceDetailModel(
      placeId: 'task_${task.id}',
      name: task.locationText.isNotEmpty ? task.locationText : task.title,
      secondaryText: 'Ажлын байршил',
      address: task.locationText,
      latitude: task.lat!,
      longitude: task.lng!,
      category: task.category.isNotEmpty ? task.category : 'Бусад',
    );
  }

  Future<void> _onSuggestionTap(PlacePredictionModel prediction) async {
    _searchDebounce?.cancel();

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoadingPlace = true;
      _suggestions = [];
      _isSearching = false;
      _errorMessage = null;
    });

    try {
      final detail = await _mapApiService.getPlaceDetails(prediction.placeId);

      if (!mounted) return;

      await _selectPlace(detail);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingPlace = false;
        _errorMessage = 'Газрын мэдээлэл ачаалж чадсангүй.';
      });
    }
  }

  Future<void> _selectPlace(
    PlaceDetailModel detail, {
    bool moveCamera = true,
  }) async {
    final position = LatLng(detail.latitude, detail.longitude);
    final marker = Marker(
      markerId: _selectedMarkerId,
      position: position,
      infoWindow: InfoWindow(title: detail.name, snippet: detail.address),
      onTap: () {
        setState(() {
          _selectedPlace = detail;
        });
      },
    );

    setState(() {
      _selectedPlace = detail;
      _markers = {marker};
      _placeRoutePolylines = <Polyline>{};
      _isLoadingPlace = false;
    });

    if (moveCamera) {
      await _animateTo(position, zoom: 16);
    }
  }

  void _clearSelectedPlace() {
    setState(() {
      _selectedPlace = null;
    });
  }

  Future<void> _showDirectionsToSelectedPlace() async {
    final place = _selectedPlace;
    if (place == null) return;

    var origin = _currentLatLng;
    if (origin == null) {
      await _goToCurrentLocation();
      if (!mounted) return;
      origin = _currentLatLng;
    }

    if (origin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Одоогийн байршил олдсонгүй.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final LatLng routeOrigin = origin;
    final destination = LatLng(place.latitude, place.longitude);

    setState(() {
      _isBuildingRoute = true;
      _routeErrorMessage = null;
      _startPointMarker = _makeStartPointMarker(routeOrigin);
    });

    final result = await _segmentRouteService.fetch(
      origin: routeOrigin,
      destination: destination,
    );

    if (!mounted) return;

    final points = result?.points ?? <LatLng>[routeOrigin, destination];
    setState(() {
      _placeRoutePolylines = {
        Polyline(
          polylineId: const PolylineId('selected_place_route'),
          points: points,
          width: 6,
          color: const Color(0xFF2563EB),
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      };
      _isBuildingRoute = false;
    });

    await _fitLatLngs(<LatLng>[
      routeOrigin,
      destination,
      ...points,
    ], padding: 110);
  }

  Future<void> _loadRouteMockPromotions({
    List<RouteSegment>? segments,
    LatLng? origin,
  }) async {
    final routeSegments = segments ?? _segments;
    if (routeSegments.isEmpty) {
      if (!mounted) return;
      setState(() => _mapPromotions = <MapPromotionItem>[]);
      return;
    }

    final samplePoints = _routePromotionSamplePoints(
      routeSegments,
      origin: origin ?? _startPointMarker?.position ?? _currentLatLng,
    );
    if (samplePoints.isEmpty) return;

    try {
      final byPost = <String, MapPromotionItem>{};
      for (final point in samplePoints) {
        final nearby = await _mockBusinessPostService.getActiveMapPromotions(
          lat: point.latitude,
          lng: point.longitude,
          radiusKm: 1.4,
        );
        for (final item in nearby) {
          final key = item.post.id;
          final existing = byPost[key];
          if (existing == null ||
              (item.distanceKm ?? double.infinity) <
                  (existing.distanceKm ?? double.infinity)) {
            byPost[key] = item;
          }
        }
      }

      final items = byPost.values.toList(growable: false)
        ..sort((a, b) {
          final sponsored = b.post.isSponsored.toString().compareTo(
            a.post.isSponsored.toString(),
          );
          if (sponsored != 0) return sponsored;
          return (a.distanceKm ?? double.infinity).compareTo(
            b.distanceKm ?? double.infinity,
          );
        });

      if (!mounted) return;
      setState(() {
        _mapPromotions = items.take(15).toList(growable: false);
      });
    } catch (e) {
      debugPrint('Failed to load route mock promotions: $e');
    }
  }

  List<LatLng> _routePromotionSamplePoints(
    List<RouteSegment> segments, {
    LatLng? origin,
  }) {
    final points = <LatLng>[];

    void addPoint(LatLng point) {
      final duplicate = points.any(
        (existing) =>
            (existing.latitude - point.latitude).abs() < 0.00001 &&
            (existing.longitude - point.longitude).abs() < 0.00001,
      );
      if (!duplicate) points.add(point);
    }

    if (origin != null) addPoint(origin);
    for (final segment in segments) {
      addPoint(segment.fromLatLng);
      final polyline = segment.polyline;
      if (polyline.isEmpty) {
        addPoint(segment.toLatLng);
        continue;
      }

      final stride = (polyline.length / 6)
          .ceil()
          .clamp(1, polyline.length)
          .toInt();
      for (var i = 0; i < polyline.length; i += stride) {
        addPoint(polyline[i]);
      }
      addPoint(polyline.last);
      addPoint(segment.toLatLng);
    }

    if (points.length <= 36) return points;
    final stride = (points.length / 36).ceil();
    final sampled = <LatLng>[
      for (var i = 0; i < points.length; i += stride) points[i],
    ];
    final sampledLast = sampled.last;
    final routeLast = points.last;
    final hasRouteEnd =
        (sampledLast.latitude - routeLast.latitude).abs() < 0.00001 &&
        (sampledLast.longitude - routeLast.longitude).abs() < 0.00001;
    if (!hasRouteEnd) sampled.add(routeLast);
    return sampled;
  }

  Set<Marker> _promotionMarkers() {
    if (!_showPromotions || _giftMarkerIcon == null) return <Marker>{};
    return {
      for (final item in _mapPromotions)
        Marker(
          markerId: MarkerId('promotion_${item.post.id}'),
          position: LatLng(item.latitude, item.longitude),
          icon: item.post.isSponsored && _sponsoredGiftMarkerIcon != null
              ? _sponsoredGiftMarkerIcon!
              : _giftMarkerIcon!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: item.post.isSponsored ? 5 : 4,
          infoWindow: InfoWindow(
            title: item.post.title,
            snippet: item.businessName,
          ),
          onTap: () => _showPromotionPreview(item),
        ),
    };
  }

  void _showPromotionPreview(MapPromotionItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return PromotionPreviewBottomSheet(
          item: item,
          onViewDetails: () {
            Navigator.pop(context);
            _showPromotionDetailsDialog(item);
          },
          onAddToRoute: () {
            Navigator.pop(context);
            _addPromotionToRoute(item);
          },
        );
      },
    );
  }

  void _showPromotionDetailsDialog(MapPromotionItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9DEE7),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item.branchName == null
                        ? item.businessName
                        : '${item.businessName} · ${item.branchName}',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 20,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _PromotionDetailBadge(
                        businessPostTypeLabel(item.post.type),
                        _promotionTypeColor(item.post.type),
                      ),
                      _PromotionDetailBadge(
                        item.serviceType,
                        AppColors.primary,
                      ),
                      if (item.post.isSponsored)
                        const _PromotionDetailBadge(
                          'Онцлох',
                          Color(0xFFF59E0B),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    item.post.title,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 18,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.post.description,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      height: 1.42,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _PromotionDetailRow(
                    label: 'Хаяг',
                    value: item.address,
                    icon: Icons.place_outlined,
                  ),
                  if (item.distanceText != null)
                    _PromotionDetailRow(
                      label: 'Зай',
                      value: item.distanceText!,
                      icon: Icons.near_me_outlined,
                    ),
                  _PromotionDetailRow(
                    label: 'Хүчинтэй хугацаа',
                    value: _promotionDateRange(item.post),
                    icon: Icons.calendar_today_outlined,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _addPromotionToRoute(item);
                          },
                          icon: const Icon(Icons.alt_route_rounded, size: 18),
                          label: const Text('Маршрут нэмэх'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textDark,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          child: const Text('Хаах'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addPromotionToRoute(MapPromotionItem item) async {
    final taskId = 'promotion_${item.organizationId}';
    if (_activeRouteTasks.any((task) => task.id == taskId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Аль хэдийн маршрутад нэмэгдсэн'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_currentLatLng == null) {
      await _goToCurrentLocation();
      if (!mounted) return;
      if (_currentLatLng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Одоогийн байршил олдсонгүй.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final task = StandardTask(
      id: taskId,
      order: _activeRouteTasks.length + 1,
      title: item.businessName,
      category: item.serviceType,
      locationText: item.businessName,
      timeText: 'Өнөөдөр',
      priority: StandardTaskPriority.medium,
      needsPlaceSearch: false,
      placeSearchQuery: item.businessName,
      source: TaskSource.manual,
      lat: item.latitude,
      lng: item.longitude,
      notes: '${item.post.title}\n${item.post.description}',
    );

    setState(() {
      _promotionTasks = [..._promotionTasks, task];
      _selectedPlace = null;
      _placeRoutePolylines = <Polyline>{};
    });

    await _buildRouteForTasks();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Маршрутад нэмэгдлээ'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _togglePromotions() {
    setState(() {
      _showPromotions = !_showPromotions;
    });
    if (_showPromotions && _segments.isNotEmpty && _mapPromotions.isEmpty) {
      unawaited(_loadRouteMockPromotions());
    }
  }

  String _promotionDateRange(BusinessPost post) {
    final start = post.startsAt == null ? 'Одоо' : _formatDate(post.startsAt!);
    final end = post.endsAt == null ? 'Хугацаагүй' : _formatDate(post.endsAt!);
    return '$start - $end';
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.of(context).padding;

    final showSuggestionPanel =
        _suggestions.isNotEmpty || _isSearching || _errorMessage != null;
    final canSelectPlace = widget.enablePlaceSelection;
    final selectedPlaceBottom = _hasRouteTasks
        ? 360.0
        : (widget.reserveBottomNavSpace ? 118.0 : 24.0);
    final selectedPlaceMaxHeight = _hasRouteTasks
        ? 330.0
        : MediaQuery.sizeOf(context).height * (canSelectPlace ? 0.62 : 0.54);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            mapType: _mapType,
            trafficEnabled: _trafficEnabled,
            markers: {
              ..._markers,
              ..._taskMarkers,
              ..._promotionMarkers(),
              if (_startPointMarker != null) _startPointMarker!,
              if (_liveLocationMarker != null) _liveLocationMarker!,
            },
            polylines: {..._segmentPolylines, ..._placeRoutePolylines},
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            padding: EdgeInsets.only(
              top: viewPadding.top + 94,
              bottom: _segments.isEmpty ? 24 : 430,
            ),
            onTap: (_) {
              FocusScope.of(context).unfocus();
              if (_selectedPlace != null) {
                _clearSelectedPlace();
              }
            },
            onMapCreated: (controller) {
              _controller = controller;

              if (!_controllerCompleter.isCompleted) {
                _controllerCompleter.complete(controller);
              }

              if (_segments.isNotEmpty && _mapPromotions.isEmpty) {
                unawaited(_loadRouteMockPromotions());
              }
            },
          ),

          Positioned(
            top: viewPadding.top + 24,
            left: 16,
            right: 16,
            child: Column(
              children: [
                _MapSearchInput(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  isLoading: _isSearching || _isLoadingPlace,
                  onChanged: _onSearchChanged,
                  onClear: _clearSearch,
                ),

                if (showSuggestionPanel)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _SuggestionPanel(
                      isLoading: _isSearching,
                      errorMessage: _errorMessage,
                      suggestions: _suggestions,
                      hasQuery: _searchCtrl.text.trim().isNotEmpty,
                      onTap: _onSuggestionTap,
                    ),
                  ),
              ],
            ),
          ),

          Positioned(
            top: viewPadding.top + 104,
            right: 16,
            child: Column(
              children: [
                _MapFloatingButton(
                  icon: _trafficEnabled
                      ? Icons.traffic_rounded
                      : Icons.traffic_outlined,
                  tooltip: 'Түгжрэл',
                  isActive: _trafficEnabled,
                  onTap: _toggleTraffic,
                ),

                const SizedBox(height: 10),

                _MapFloatingButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Одоогийн байршил',
                  isActive: false,
                  onTap: _goToCurrentLocation,
                ),

                const SizedBox(height: 10),

                _MapFloatingButton(
                  icon: Icons.layers_rounded,
                  tooltip: 'Зургийн төрөл',
                  isActive: _mapType != MapType.normal,
                  onTap: _showMapTypeSheet,
                ),

                const SizedBox(height: 10),

                _MapFloatingButton(
                  icon: _showPromotions
                      ? Icons.card_giftcard_rounded
                      : Icons.card_giftcard_outlined,
                  tooltip: 'Урамшуулал',
                  isActive: _showPromotions,
                  onTap: _togglePromotions,
                ),

                const SizedBox(height: 10),

                _MapFloatingButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Урамшуулал шинэчлэх',
                  isActive: false,
                  onTap: () => unawaited(_loadRouteMockPromotions()),
                ),

                const SizedBox(height: 10),

                if (_hasRouteTasks)
                  _MapFloatingButton(
                    icon: _isBuildingRoute
                        ? Icons.hourglass_top_rounded
                        : Icons.alt_route_rounded,
                    tooltip: 'Маршрут шинэчлэх',
                    isActive: _segments.isNotEmpty,
                    onTap: _isBuildingRoute ? () {} : _buildRouteForTasks,
                  ),
              ],
            ),
          ),

          if (_hasRouteTasks)
            Positioned.fill(
              child: RouteSummaryPanel(
                segments: _segments,
                isLoading: _isBuildingRoute,
                errorMessage: _routeErrorMessage,
                focusedIndex: _focusedSegmentIndex,
                savedTaskIds: _savedTaskIds,
                onTapSegment: _onSegmentTap,
                onSaveSegment: _saveSegmentTask,
                onToggleComplete: _toggleTaskCompletion,
                onDismissFocus: () =>
                    setState(() => _focusedSegmentIndex = null),
              ),
            ),

          if (_permissionMessage != null)
            Positioned(
              top: viewPadding.top + 70,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_off_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _permissionMessage!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_selectedPlace != null)
            Positioned(
              bottom: selectedPlaceBottom,
              left: 16,
              right: 16,
              child: _SelectedPlaceCard(
                place: _selectedPlace!,
                maxHeight: selectedPlaceMaxHeight,
                onClose: _clearSelectedPlace,
                onDirections: _showDirectionsToSelectedPlace,
                onSelect: canSelectPlace
                    ? () => Navigator.pop(context, _selectedPlace)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectedPlaceCard extends StatelessWidget {
  const _SelectedPlaceCard({
    required this.place,
    required this.maxHeight,
    required this.onClose,
    required this.onDirections,
    required this.onSelect,
  });

  final PlaceDetailModel place;
  final double maxHeight;
  final VoidCallback onClose;
  final VoidCallback onDirections;
  final VoidCallback? onSelect;

  bool get _showDetailBody => true;

  String get _coordinateText =>
      '${place.latitude.toStringAsFixed(5)}, ${place.longitude.toStringAsFixed(5)}';

  String get _statusText {
    if (place.hours.isNotEmpty) return place.hours;
    return place.openNow ? 'Нээлттэй' : 'Хаалттай';
  }

  String get _categoryLine {
    final parts = <String>[
      if (place.category.isNotEmpty) place.category,
      if (place.priceLevel.isNotEmpty) place.priceLevel,
      if (place.accessibility.isNotEmpty) '♿',
    ];
    return parts.join(' · ');
  }

  Widget _detailRow({
    required IconData icon,
    required String text,
    Color iconColor = const Color(0xFF008A9A),
    int maxLines = 2,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: iconColor),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool primary = false,
  }) {
    final color = primary ? Colors.white : const Color(0xFF008A9A);
    final bg = primary ? const Color(0xFF008A9A) : const Color(0xFFD8F7FB);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ratingRow() {
    if (place.rating <= 0) return const SizedBox.shrink();

    return Row(
      children: [
        Text(
          place.rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 14.5,
            color: AppColors.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 5),
        _RatingStars(rating: place.rating),
        if (place.reviewCount > 0) ...[
          const SizedBox(width: 5),
          Text(
            '(${place.reviewCount})',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 26,
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                            ),
                          ),
                          if (place.secondaryText.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              place.secondaryText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      tooltip: 'Хаах',
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _ratingRow(),
                if (_categoryLine.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _categoryLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const _PlaceTabs(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _actionItem(
                      icon: Icons.directions_rounded,
                      label: 'Чиглэл',
                      primary: true,
                      onTap: onDirections,
                    ),
                    _actionItem(
                      icon: Icons.bookmark_border_rounded,
                      label: 'Хадгалах',
                    ),
                    _actionItem(
                      icon: Icons.near_me_outlined,
                      label: 'Ойролцоо',
                    ),
                    _actionItem(icon: Icons.share_outlined, label: 'Хуваалцах'),
                  ],
                ),
                if (_showDetailBody) ...[
                  const SizedBox(height: 16),
                  Divider(color: Colors.black.withValues(alpha: 0.08)),
                  const SizedBox(height: 16),
                  _detailRow(
                    icon: Icons.place_outlined,
                    text: place.address.isNotEmpty
                        ? place.address
                        : 'Хаягийн мэдээлэл байхгүй',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 18),
                  _detailRow(
                    icon: Icons.schedule_rounded,
                    text: _statusText,
                    iconColor: place.openNow
                        ? const Color(0xFF008A9A)
                        : AppColors.error,
                    maxLines: 1,
                  ),
                  if (place.website.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _detailRow(
                      icon: Icons.public_rounded,
                      text: place.website,
                      maxLines: 1,
                    ),
                  ],
                  if (place.phone.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _detailRow(
                      icon: Icons.phone_rounded,
                      text: place.phone,
                      maxLines: 1,
                    ),
                  ],
                  if (place.plusCode.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _detailRow(
                      icon: Icons.apps_rounded,
                      text: place.plusCode,
                      maxLines: 1,
                    ),
                  ],
                  const SizedBox(height: 18),
                  _detailRow(
                    icon: Icons.explore_outlined,
                    text: 'Координат: $_coordinateText',
                    maxLines: 1,
                  ),
                  if (place.accessibility.isNotEmpty ||
                      place.tags.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in [
                          ...place.accessibility.take(2),
                          ...place.tags.take(3),
                        ])
                          _PlaceChip(label: tag),
                      ],
                    ),
                  ],
                  if (place.reviews.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Сэтгэгдэл',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final review in place.reviews.take(2))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ReviewPreview(review: review),
                      ),
                  ],
                ],
                if (onSelect != null) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onSelect,
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text('Байршил сонгох'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star_rounded
                : (rating >= i - 0.5
                      ? Icons.star_half_rounded
                      : Icons.star_border_rounded),
            color: const Color(0xFFF4B400),
            size: 18,
          ),
      ],
    );
  }
}

class _PlaceTabs extends StatelessWidget {
  const _PlaceTabs();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _PlaceTab(label: 'Overview', active: true)),
        Expanded(child: _PlaceTab(label: 'Reviews')),
        Expanded(child: _PlaceTab(label: 'About')),
      ],
    );
  }
}

class _PlaceTab extends StatelessWidget {
  const _PlaceTab({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF008A9A);

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: active ? activeColor : AppColors.textMuted,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 3,
          width: 78,
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }
}

class _PlaceChip extends StatelessWidget {
  const _PlaceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFD8F7FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF006B76),
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReviewPreview extends StatelessWidget {
  const _ReviewPreview({required this.review});

  final PlaceReviewModel review;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                review.rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFF4B400),
                size: 15,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            review.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.8,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapTypeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _MapTypeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : AppColors.primary,
                  size: 22,
                ),
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromotionDetailBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _PromotionDetailBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PromotionDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _PromotionDetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
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

Color _promotionTypeColor(BusinessPostType type) {
  switch (type) {
    case BusinessPostType.discount:
      return const Color(0xFFD97706);
    case BusinessPostType.event:
      return const Color(0xFF9333EA);
    case BusinessPostType.announcement:
    case BusinessPostType.serviceUpdate:
      return const Color(0xFF0891B2);
    case BusinessPostType.promotion:
    case BusinessPostType.general:
      return AppColors.primary;
  }
}

class _MapSearchInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final Function(String) onChanged;
  final VoidCallback onClear;

  const _MapSearchInput({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 72,
        padding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              color: Color(0xFF9AA3B2),
              size: 30,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                decoration: const InputDecoration(
                  hintText: 'Газар эсвэл ажил хайх...',
                  hintStyle: TextStyle(
                    color: Color(0xFF9AA3B2),
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(13),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.primary,
                  ),
                ),
              )
            else if (controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                ),
                onPressed: onClear,
                tooltip: 'Арилгах',
              )
            else
              GestureDetector(
                onTap: focusNode.requestFocus,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionPanel extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final List<PlacePredictionModel> suggestions;
  final bool hasQuery;
  final Function(PlacePredictionModel) onTap;

  const _SuggestionPanel({
    required this.isLoading,
    required this.errorMessage,
    required this.suggestions,
    required this.hasQuery,
    required this.onTap,
  });

  BoxDecoration _panelDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );

  Widget _infoRow({
    required IconData icon,
    required String text,
    Color? color,
  }) {
    final c = color ?? AppColors.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: c,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && suggestions.isEmpty) {
      return Material(
        color: Colors.transparent,
        child: Container(
          decoration: _panelDecoration(),
          child: _infoRow(icon: Icons.search_rounded, text: 'Хайж байна...'),
        ),
      );
    }

    if (errorMessage != null) {
      return Material(
        color: Colors.transparent,
        child: Container(
          decoration: _panelDecoration(),
          child: _infoRow(
            icon: Icons.error_outline_rounded,
            text: errorMessage!,
            color: AppColors.warning,
          ),
        ),
      );
    }

    if (suggestions.isEmpty && !isLoading && hasQuery) {
      return Material(
        color: Colors.transparent,
        child: Container(
          decoration: _panelDecoration(),
          child: _infoRow(
            icon: Icons.location_off_rounded,
            text: 'Илэрц олдсонгүй',
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: _panelDecoration(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 1,
                color: Colors.black.withValues(alpha: 0.05),
              ),
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return InkWell(
                  onTap: () => onTap(suggestion),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                suggestion.mainText.isNotEmpty
                                    ? suggestion.mainText
                                    : suggestion.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              if (suggestion.secondaryText.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  suggestion.secondaryText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MapFloatingButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _MapFloatingButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.13),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: isActive
                    ? AppColors.primary
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : AppColors.textDark,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
