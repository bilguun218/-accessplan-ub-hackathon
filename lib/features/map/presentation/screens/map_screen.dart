import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../organizations/data/mock/mock_organizations.dart';
import '../../../organizations/data/models/organization_model.dart';
import '../../data/models/place_detail_model.dart';
import '../../data/models/place_prediction_model.dart';
import '../../data/models/ranked_job_route.dart';
import '../../data/services/job_route_service.dart';
import '../../data/services/map_api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.focusOrganization});

  /// Open the map with this organization pre-selected: pin + driving route.
  final Organization? focusOrganization;

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
  final JobRouteService _routeService = JobRouteService();

  GoogleMapController? _controller;
  Timer? _searchDebounce;

  String? _permissionMessage;
  String? _errorMessage;
  String? _jobsErrorMessage;

  bool _trafficEnabled = true;
  bool _locationGranted = false;
  bool _isSearching = false;
  bool _isLoadingPlace = false;
  bool _isComputingJobs = false;

  MapType _mapType = MapType.normal;

  List<PlacePredictionModel> _suggestions = <PlacePredictionModel>[];

  PlaceDetailModel? _selectedPlace;

  Set<Marker> _markers = <Marker>{};
  Set<Marker> _jobMarkers = <Marker>{};
  Set<Polyline> _jobPolylines = <Polyline>{};

  List<RankedJobRoute> _rankedRoutes = <RankedJobRoute>[];
  int? _focusedRank;
  LatLng? _currentLatLng;

  static const int kMaxRoutesToShow = 5;

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
      // Хэрэв тодорхой organization-той орж ирсэн бол түүний route-ыг,
      // үгүй бол хамгийн боломжит ажлуудыг харуулна.
      if (widget.focusOrganization != null) {
        unawaited(_focusOrganizationRoute(widget.focusOrganization!));
      } else if (_rankedRoutes.isEmpty && !_isComputingJobs) {
        unawaited(_computeRankedJobs());
      }
    } catch (e) {
      debugPrint('Current location error: $e');
    }
  }

  Future<void> _focusOrganizationRoute(Organization org) async {
    final origin = _currentLatLng ?? const LatLng(47.918873, 106.917701);
    final destination = LatLng(org.latitude, org.longitude);

    setState(() {
      _isComputingJobs = true;
      _jobsErrorMessage = null;
    });

    // 1. Marker-уудыг шууд харуулна (Haversine + шулуун зам).
    final straightDistance = haversineMeters(
      origin.latitude,
      origin.longitude,
      org.latitude,
      org.longitude,
    ).round();

    final baseline = RankedJobRoute(
      job: org,
      rank: 1,
      distanceMeters: straightDistance,
      durationSeconds: (straightDistance * 0.12).round(),
      score: 0,
      polylinePoints: <LatLng>[origin, destination],
    );

    var routes = [baseline];
    var markers = await _buildJobMarkers(routes);
    var polylines = _buildPolylines(routes);

    if (!mounted) return;
    setState(() {
      _rankedRoutes = routes;
      _jobMarkers = markers;
      _jobPolylines = polylines;
    });
    await _fitBoundsToRoutes(origin, routes);

    // 2. OSRM-аар жинхэнэ замын дагуу зам татна (үнэгүй, key-гүй).
    final fetched = await _routeService.fetchRouteFor(
      origin: origin,
      baseline: baseline,
    );

    if (!mounted) return;

    if (fetched != null) {
      routes = [fetched];
      markers = await _buildJobMarkers(routes);
      polylines = _buildPolylines(routes);
      setState(() {
        _rankedRoutes = routes;
        _jobMarkers = markers;
        _jobPolylines = polylines;
        _isComputingJobs = false;
      });
      await _fitBoundsToRoutes(origin, routes);
    } else {
      setState(() {
        _isComputingJobs = false;
        _jobsErrorMessage =
            'Замын мэдээлэл татаж чадсангүй. Шулуун зай харуулав.';
      });
    }
  }

  Future<void> _computeRankedJobs() async {
    // Байршил байхгүй бол УБ төвийг origin болгоно (marker заавал гарна).
    final origin = _currentLatLng ?? const LatLng(47.918873, 106.917701);

    setState(() {
      _isComputingJobs = true;
      _jobsErrorMessage = null;
    });

    try {
      // 1. Эхлээд Haversine-аар ranking хийнэ — API хүлээхгүй.
      final initial = _routeService.rankJobsLocal(
        origin: origin,
        jobs: MockOrganizations.all,
        limit: kMaxRoutesToShow,
      );

      if (!mounted) return;

      // 2. Marker-уудыг шууд харуулна (polyline хоосон).
      final markers = await _buildJobMarkers(initial);
      setState(() {
        _rankedRoutes = initial;
        _jobMarkers = markers;
        _jobPolylines = <Polyline>{};
      });

      await _fitBoundsToRoutes(origin, initial);

      // 3. Дараа нь Directions API-р polyline + бодит distance/duration татна.
      final updated = <RankedJobRoute>[];
      for (final base in initial) {
        final fetched = await _routeService.fetchRouteFor(
          origin: origin,
          baseline: base,
        );
        updated.add(fetched ?? base);
      }

      if (!mounted) return;

      // 4. Re-rank score-оор (API-аас бодит дата ирсэн тохиолдолд).
      updated.sort((a, b) => a.score.compareTo(b.score));
      final reranked = [
        for (var i = 0; i < updated.length; i++)
          updated[i].copyWith(rank: i + 1),
      ];

      // Rank өөрчлөгдсөн бол marker-уудыг дахин зурна.
      final newMarkers = await _buildJobMarkers(reranked);
      final newPolylines = _buildPolylines(reranked);

      if (!mounted) return;

      setState(() {
        _rankedRoutes = reranked;
        _jobMarkers = newMarkers;
        _jobPolylines = newPolylines;
        _isComputingJobs = false;
      });

      await _fitBoundsToRoutes(origin, reranked);
    } catch (e) {
      debugPrint('Rank jobs error: $e');
      if (!mounted) return;
      setState(() {
        _isComputingJobs = false;
        _jobsErrorMessage = 'Маршрут татаж чадсангүй.';
      });
    }
  }

  Future<Set<Marker>> _buildJobMarkers(List<RankedJobRoute> ranked) async {
    final markers = <Marker>{};
    for (final r in ranked) {
      final icon = await _numberedMarkerIcon(r.rank, isTop: r.rank == 1);
      markers.add(
        Marker(
          markerId: MarkerId('job_${r.rank}'),
          position: LatLng(r.job.latitude, r.job.longitude),
          icon: icon,
          infoWindow: InfoWindow(
            title: '${r.rank}. ${r.job.name}',
            snippet:
                '${r.distanceKm.toStringAsFixed(1)} км · ${r.durationMinutes} мин',
          ),
          onTap: () => _focusJob(r.rank),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _buildPolylines(List<RankedJobRoute> ranked) {
    final polylines = <Polyline>{};
    for (final r in ranked) {
      if (r.polylinePoints.isEmpty) continue;
      final isTop = r.rank == 1;
      final isFocused = _focusedRank == r.rank;
      polylines.add(
        Polyline(
          polylineId: PolylineId('route_${r.rank}'),
          points: r.polylinePoints,
          width: isFocused ? 8 : (isTop ? 7 : 4),
          color: isTop
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: isFocused ? 0.95 : 0.45),
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
          zIndex: isTop ? 3 : (isFocused ? 2 : 1),
        ),
      );
    }
    return polylines;
  }

  Future<void> _fitBoundsToRoutes(
    LatLng origin,
    List<RankedJobRoute> ranked,
  ) async {
    if (ranked.isEmpty) return;
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

    for (final r in ranked) {
      include(LatLng(r.job.latitude, r.job.longitude));
      for (final p in r.polylinePoints) {
        include(p);
      }
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  final Map<String, BitmapDescriptor> _markerIconCache =
      <String, BitmapDescriptor>{};

  Future<BitmapDescriptor> _numberedMarkerIcon(
    int number, {
    bool isTop = false,
  }) async {
    final key = '${isTop ? 'top' : 'reg'}_$number';
    final cached = _markerIconCache[key];
    if (cached != null) return cached;

    const size = 70.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final fillColor = isTop
        ? AppColors.primary
        : AppColors.primary.withValues(alpha: 0.92);
    final strokeColor = Colors.white;

    // Drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(const Offset(size / 2, size / 2 + 3), 24, shadowPaint);

    // Outer ring
    final ringPaint = Paint()..color = strokeColor;
    canvas.drawCircle(const Offset(size / 2, size / 2), 26, ringPaint);

    // Filled circle
    final fillPaint = Paint()..color = fillColor;
    canvas.drawCircle(const Offset(size / 2, size / 2), 22, fillPaint);

    // Pin tail
    final path = Path()
      ..moveTo(size / 2 - 7, size / 2 + 18)
      ..lineTo(size / 2 + 7, size / 2 + 18)
      ..lineTo(size / 2, size - 4)
      ..close();
    canvas.drawPath(path, fillPaint);

    // Number
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          color: Colors.white,
          fontSize: isTop ? 22 : 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2 - 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    final descriptor = BitmapDescriptor.bytes(bytes);
    _markerIconCache[key] = descriptor;
    return descriptor;
  }

  Future<void> _focusJob(int rank) async {
    final route = _rankedRoutes.firstWhere(
      (r) => r.rank == rank,
      orElse: () => _rankedRoutes.first,
    );
    setState(() {
      _focusedRank = rank;
      _jobPolylines = _buildPolylines(_rankedRoutes);
    });
    await _animateTo(LatLng(route.job.latitude, route.job.longitude), zoom: 16);
    final controller = _controller;
    if (controller != null) {
      await controller.showMarkerInfoWindow(MarkerId('job_$rank'));
    }
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
            markers: {..._markers, ..._jobMarkers},
            polylines: _jobPolylines,
            myLocationEnabled: _locationGranted,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            padding: EdgeInsets.only(
              top: viewPadding.top + 70,
              bottom: _rankedRoutes.isEmpty ? 24 : 220,
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

                _MapFloatingButton(
                  icon: _isComputingJobs
                      ? Icons.hourglass_top_rounded
                      : Icons.auto_awesome_rounded,
                  tooltip: 'Suggest top jobs',
                  isActive: _rankedRoutes.isNotEmpty,
                  onTap: _isComputingJobs ? () {} : _computeRankedJobs,
                ),
              ],
            ),
          ),

          if (_rankedRoutes.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _RankedJobsPanel(
                routes: _rankedRoutes,
                focusedRank: _focusedRank,
                onTap: _focusJob,
                onClose: () {
                  setState(() {
                    _rankedRoutes = <RankedJobRoute>[];
                    _jobMarkers = <Marker>{};
                    _jobPolylines = <Polyline>{};
                    _focusedRank = null;
                  });
                },
              ),
            ),

          if (_jobsErrorMessage != null && _rankedRoutes.isEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
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
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _jobsErrorMessage!,
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

class _RankedJobsPanel extends StatelessWidget {
  const _RankedJobsPanel({
    required this.routes,
    required this.focusedRank,
    required this.onTap,
    required this.onClose,
  });

  final List<RankedJobRoute> routes;
  final int? focusedRank;
  final ValueChanged<int> onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'AI санал',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Боломжит ажлын дараалал',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
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
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(),
                    itemCount: routes.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                    itemBuilder: (context, index) {
                      final r = routes[index];
                      final focused = r.rank == focusedRank;
                      return InkWell(
                        onTap: () => onTap(r.rank),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: r.rank == 1
                                      ? AppColors.primary
                                      : AppColors.primary
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${r.rank}',
                                  style: TextStyle(
                                    color: r.rank == 1
                                        ? Colors.white
                                        : AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.job.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: focused
                                            ? FontWeight.w800
                                            : FontWeight.w700,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${r.distanceKm.toStringAsFixed(1)} км · ${r.durationMinutes} мин',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: focused
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
