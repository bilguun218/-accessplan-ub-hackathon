import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../tasks/data/models/standard_task.dart';
import '../../data/models/place_detail_model.dart';
import '../../data/models/place_prediction_model.dart';
import '../../data/models/route_segment.dart';
import '../../data/services/map_api_service.dart';
import '../../data/services/place_geocoding_service.dart';
import '../../data/services/segment_route_service.dart';
import '_route_summary_panel.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.tasks = const <StandardTask>[]});

  final List<StandardTask> tasks;

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

  GoogleMapController? _controller;
  Timer? _searchDebounce;

  String? _permissionMessage;
  String? _errorMessage;

  bool _trafficEnabled = true;
  bool _locationGranted = false;
  bool _isSearching = false;
  bool _isLoadingPlace = false;

  MapType _mapType = MapType.normal;

  List<PlacePredictionModel> _suggestions = <PlacePredictionModel>[];

  PlaceDetailModel? _selectedPlace;

  Set<Marker> _markers = <Marker>{};

  // Task-driven route state
  List<RouteSegment> _segments = <RouteSegment>[];
  Set<Polyline> _segmentPolylines = <Polyline>{};
  Set<Marker> _taskMarkers = <Marker>{};
  bool _isBuildingRoute = false;
  String? _routeErrorMessage;
  int? _focusedSegmentIndex;
  LatLng? _currentLatLng;

  late CameraPosition _initialCameraPosition;
  bool _locationLoaded = false;

  @override
  void initState() {
    super.initState();
    // Initialize with a default location, will be updated when actual location loads
    _initialCameraPosition = const CameraPosition(
      target: LatLng(47.918873, 106.917701),
      zoom: _defaultZoom,
    );
    _initLocation();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller?.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
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
        _locationGranted = true;
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
        _markers = {
          Marker(
            markerId: const MarkerId('current_location'),
            position: currentLatLng,
            infoWindow: const InfoWindow(title: 'My Current Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
          ),
        };
      });

      await _animateTo(currentLatLng, zoom: 16);

      if (widget.tasks.isNotEmpty &&
          _segments.isEmpty &&
          !_isBuildingRoute) {
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
    if (origin == null || widget.tasks.isEmpty) return;

    setState(() {
      _isBuildingRoute = true;
      _routeErrorMessage = null;
      _segments = <RouteSegment>[];
      _segmentPolylines = <Polyline>{};
      _taskMarkers = <Marker>{};
      _focusedSegmentIndex = null;
    });

    final resolved = <StandardTask>[];
    final addresses = <String, String>{};
    for (final t in widget.tasks) {
      if (t.lat != null && t.lng != null) {
        resolved.add(t);
        continue;
      }
      final query = t.needsPlaceSearch && t.placeSearchQuery.isNotEmpty
          ? t.placeSearchQuery
          : (t.locationText.isNotEmpty
              ? t.locationText
              : t.placeSearchQuery);
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

      segments.add(
        RouteSegment(
          index: segIndex,
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
        ),
      );

      polylines.add(
        Polyline(
          polylineId: PolylineId('segment_$segIndex'),
          points: points,
          width: 6,
          color: color,
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

    final markers = await _buildTaskMarkers(routable);

    if (!mounted) return;
    setState(() {
      _segments = segments;
      _segmentPolylines = polylines;
      _taskMarkers = markers;
      _isBuildingRoute = false;
    });

    await _fitBounds(origin, segments);
  }

  Future<Set<Marker>> _buildTaskMarkers(List<StandardTask> tasks) async {
    final markers = <Marker>{};
    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      markers.add(
        Marker(
          markerId: MarkerId('task_${t.id}'),
          position: LatLng(t.lat!, t.lng!),
          infoWindow: InfoWindow(
            title: '${t.order}. ${t.title}',
            snippet: t.locationText.isNotEmpty ? t.locationText : t.category,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _hueForIndex(i),
          ),
        ),
      );
    }
    return markers;
  }

  double _hueForIndex(int i) {
    const hues = <double>[
      BitmapDescriptor.hueBlue,
      BitmapDescriptor.hueRed,
      BitmapDescriptor.hueGreen,
      BitmapDescriptor.hueOrange,
      BitmapDescriptor.hueViolet,
      BitmapDescriptor.hueRose,
      BitmapDescriptor.hueCyan,
      BitmapDescriptor.hueYellow,
    ];
    return hues[i % hues.length];
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
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
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
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
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
                  'Map Type',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                _MapTypeOption(
                  title: 'Normal',
                  subtitle: 'Standard map',
                  icon: Icons.map_rounded,
                  isSelected: _mapType == MapType.normal,
                  onTap: () {
                    Navigator.pop(context);
                    _changeMapType(MapType.normal);
                  },
                ),
                _MapTypeOption(
                  title: 'Satellite',
                  subtitle: 'Satellite imagery',
                  icon: Icons.satellite_alt_rounded,
                  isSelected: _mapType == MapType.satellite,
                  onTap: () {
                    Navigator.pop(context);
                    _changeMapType(MapType.satellite);
                  },
                ),
                _MapTypeOption(
                  title: 'Hybrid',
                  subtitle: 'Satellite + labels',
                  icon: Icons.layers_rounded,
                  isSelected: _mapType == MapType.hybrid,
                  onTap: () {
                    Navigator.pop(context);
                    _changeMapType(MapType.hybrid);
                  },
                ),
                _MapTypeOption(
                  title: 'Terrain',
                  subtitle: 'Terrain map',
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
        _errorMessage = 'Search failed.';
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
    });

    _goToCurrentLocation();
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

      final position = LatLng(detail.latitude, detail.longitude);

      final marker = Marker(
        markerId: _selectedMarkerId,
        position: position,
        infoWindow: InfoWindow(title: detail.name, snippet: detail.address),
      );

      setState(() {
        _selectedPlace = detail;
        _markers = {marker};
        _isLoadingPlace = false;
      });

      await _animateTo(position, zoom: 16);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingPlace = false;
        _errorMessage = 'Failed to load place.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.of(context).padding;

    final showSuggestionPanel =
        _suggestions.isNotEmpty || _isSearching || _errorMessage != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            mapType: _mapType,
            trafficEnabled: _trafficEnabled,
            markers: {..._markers, ..._taskMarkers},
            polylines: _segmentPolylines,
            myLocationEnabled: _locationGranted,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            padding: EdgeInsets.only(
              top: viewPadding.top + 70,
              bottom: _segments.isEmpty ? 24 : 240,
            ),
            onTap: (_) => FocusScope.of(context).unfocus(),
            onMapCreated: (controller) {
              _controller = controller;

              if (!_controllerCompleter.isCompleted) {
                _controllerCompleter.complete(controller);
              }
            },
          ),

          Positioned(
            top: viewPadding.top + 8,
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
            top: viewPadding.top + 82,
            right: 16,
            child: Column(
              children: [
                _MapFloatingButton(
                  icon: _trafficEnabled
                      ? Icons.traffic_rounded
                      : Icons.traffic_outlined,
                  tooltip: 'Traffic',
                  isActive: _trafficEnabled,
                  onTap: _toggleTraffic,
                ),

                const SizedBox(height: 10),

                _MapFloatingButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Current Location',
                  isActive: false,
                  onTap: _goToCurrentLocation,
                ),

                const SizedBox(height: 10),

                _MapFloatingButton(
                  icon: Icons.layers_rounded,
                  tooltip: 'Map Type',
                  isActive: _mapType != MapType.normal,
                  onTap: _showMapTypeSheet,
                ),

                const SizedBox(height: 10),

                if (widget.tasks.isNotEmpty)
                  _MapFloatingButton(
                    icon: _isBuildingRoute
                        ? Icons.hourglass_top_rounded
                        : Icons.alt_route_rounded,
                    tooltip: 'Rebuild route',
                    isActive: _segments.isNotEmpty,
                    onTap: _isBuildingRoute ? () {} : _buildRouteForTasks,
                  ),
              ],
            ),
          ),

          if (widget.tasks.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RouteSummaryPanel(
                segments: _segments,
                isLoading: _isBuildingRoute,
                errorMessage: _routeErrorMessage,
                focusedIndex: _focusedSegmentIndex,
                onTapSegment: _onSegmentTap,
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
              bottom: 24,
              left: 16,
              right: 16,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, _selectedPlace);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Confirm Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
        decoration: BoxDecoration(
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
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          decoration: InputDecoration(
            hintText: 'Search places...',
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.textMuted,
              size: 22,
            ),
            suffixIcon: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textMuted,
                    ),
                    onPressed: onClear,
                    tooltip: 'Clear',
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
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
          child: _infoRow(
            icon: Icons.search_rounded,
            text: 'Searching...',
          ),
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
            text: 'No results found',
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

