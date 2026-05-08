import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/place_detail_model.dart';
import '../../data/models/place_prediction_model.dart';
import '../../data/services/map_api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _ulaanbaatar = LatLng(47.918873, 106.917701);
  static const double _defaultZoom = 13.0;
  static const MarkerId _ubMarkerId = MarkerId('ulaanbaatar_center');
  static const MarkerId _selectedMarkerId = MarkerId('selected_place');

  final Completer<GoogleMapController> _controllerCompleter =
      Completer<GoogleMapController>();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final MapApiService _mapApiService = MapApiService();

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
  Set<Marker> _markers = <Marker>{
    const Marker(
      markerId: _ubMarkerId,
      position: _ulaanbaatar,
      infoWindow: InfoWindow(title: 'Улаанбаатар хот'),
    ),
  };

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocation();
    });
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
        _setPermissionMessage(
          'Байршлын үйлчилгээ идэвхгүй байна. Тохиргоог нээнэ үү.',
        );
        return;
      }

      var status = await Permission.locationWhenInUse.status;

      if (status.isDenied || status.isRestricted) {
        status = await Permission.locationWhenInUse.request();
      }

      if (status.isPermanentlyDenied) {
        _setPermissionMessage(
          'Байршлын зөвшөөрөл бүрмөсөн хаалттай. Тохиргооноос идэвхжүүлнэ үү.',
        );
        return;
      }

      if (!status.isGranted) {
        _setPermissionMessage('Байршлын зөвшөөрөл шаардлагатай байна.');
        return;
      }

      if (!mounted) return;

      setState(() {
        _locationGranted = true;
        _permissionMessage = null;
      });

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      await _animateTo(LatLng(position.latitude, position.longitude), zoom: 15);
    } catch (_) {
      // Emulator эсвэл location fix олдохгүй үед УБ default center дээр үлдэнэ.
    }
  }

  void _setPermissionMessage(String msg) {
    if (!mounted) return;
    setState(() => _permissionMessage = msg);
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _trafficEnabled
              ? 'Түгжрэлийн давхарга асаалттай.'
              : 'Түгжрэлийн давхарга унтраалттай.',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _goToUlaanbaatarCenter() async {
    await _animateTo(_ulaanbaatar, zoom: 15);
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
                const Text(
                  'Газрын зургийн төрөл',
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
                  title: 'Сансрын',
                  subtitle: 'Бодит satellite зураг',
                  icon: Icons.satellite_alt_rounded,
                  isSelected: _mapType == MapType.satellite,
                  onTap: () {
                    Navigator.pop(context);
                    _changeMapType(MapType.satellite);
                  },
                ),
                _MapTypeOption(
                  title: 'Холимог',
                  subtitle: 'Satellite + замын нэр, тэмдэглэгээ',
                  icon: Icons.layers_rounded,
                  isSelected: _mapType == MapType.hybrid,
                  onTap: () {
                    Navigator.pop(context);
                    _changeMapType(MapType.hybrid);
                  },
                ),
                _MapTypeOption(
                  title: 'Газрын хэлбэр',
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
        _suggestions = <PlacePredictionModel>[];
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
      // Хэрэглэгч энэ хооронд өөр зүйл бичсэн бол хэвээр үлдээх.
      if (_searchCtrl.text.trim() != query) return;
      setState(() {
        _suggestions = result;
        _isSearching = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      if (_searchCtrl.text.trim() != query) return;
      setState(() {
        _suggestions = <PlacePredictionModel>[];
        _isSearching = false;
        _errorMessage = 'Байршил хайхад алдаа гарлаа.';
      });
    }
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();

    setState(() {
      _suggestions = <PlacePredictionModel>[];
      _isSearching = false;
      _errorMessage = null;
      _selectedPlace = null;
      _markers = <Marker>{
        const Marker(
          markerId: _ubMarkerId,
          position: _ulaanbaatar,
          infoWindow: InfoWindow(title: 'Улаанбаатар хот'),
        ),
      };
    });

    _goToUlaanbaatarCenter();
  }

  Future<void> _onSuggestionTap(PlacePredictionModel prediction) async {
    _searchDebounce?.cancel();
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoadingPlace = true;
      _suggestions = <PlacePredictionModel>[];
      _isSearching = false;
      _errorMessage = null;
      _searchCtrl.text = prediction.mainText.isNotEmpty
          ? prediction.mainText
          : prediction.description;
      _searchCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchCtrl.text.length),
      );
    });

    try {
      final detail = await _mapApiService.getPlaceDetails(prediction.placeId);
      if (!mounted) return;

      final position = LatLng(detail.latitude, detail.longitude);

      final marker = Marker(
        markerId: _selectedMarkerId,
        position: position,
        infoWindow: InfoWindow(
          title: detail.name.isNotEmpty ? detail.name : prediction.mainText,
          snippet: detail.address.isEmpty ? null : detail.address,
        ),
      );

      setState(() {
        _selectedPlace = detail;
        _markers = <Marker>{marker};
        _isLoadingPlace = false;
        _searchCtrl.text = detail.name.isNotEmpty
            ? detail.name
            : prediction.mainText;
        _searchCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _searchCtrl.text.length),
        );
      });

      await _animateTo(position, zoom: 16);

      final controller = _controller;
      if (controller != null) {
        await controller.showMarkerInfoWindow(_selectedMarkerId);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingPlace = false;
        _errorMessage = 'Байршлын мэдээлэл татаж чадсангүй.';
      });
    }
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.of(context).padding;
    final showSuggestionPanel = _suggestions.isNotEmpty ||
        _isSearching ||
        _errorMessage != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _ulaanbaatar,
              zoom: _defaultZoom,
            ),
            mapType: _mapType,
            trafficEnabled: _trafficEnabled,
            markers: _markers,
            myLocationEnabled: _locationGranted,
            myLocationButtonEnabled: _locationGranted,
            zoomControlsEnabled: false,
            compassEnabled: true,
            padding: EdgeInsets.only(
              top: viewPadding.top + 70,
              bottom: _selectedPlace != null ? 200 : 24,
            ),
            onTap: (_) => FocusScope.of(context).unfocus(),
            onMapCreated: (controller) {
              _controller = controller;
              if (!_controllerCompleter.isCompleted) {
                _controllerCompleter.complete(controller);
              }
            },
          ),

          // Search bar + suggestion panel
          Positioned(
            top: viewPadding.top + 8,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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

          // Right floating buttons
          Positioned(
            top: viewPadding.top + 82,
            right: 16,
            child: Column(
              children: [
                _MapFloatingButton(
                  icon: _trafficEnabled
                      ? Icons.traffic_rounded
                      : Icons.traffic_outlined,
                  tooltip: _trafficEnabled ? 'Түгжрэл нуух' : 'Түгжрэл харах',
                  isActive: _trafficEnabled,
                  onTap: _toggleTraffic,
                ),
                const SizedBox(height: 10),
                _MapFloatingButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Улаанбаатар төв',
                  isActive: false,
                  onTap: _goToUlaanbaatarCenter,
                ),
                const SizedBox(height: 10),
                _MapFloatingButton(
                  icon: Icons.layers_rounded,
                  tooltip: 'Газрын зургийн төрөл',
                  isActive: _mapType != MapType.normal,
                  onTap: _showMapTypeSheet,
                ),
              ],
            ),
          ),

          if (_trafficEnabled)
            Positioned(
              top: viewPadding.top + 82,
              left: 16,
              child: const _StatusBadge(
                icon: Icons.traffic_rounded,
                text: 'Түгжрэл асаалттай',
                color: AppColors.primary,
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
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_off,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _permissionMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => openAppSettings(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        child: const Text(
                          'Тохиргоо',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
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
              left: 16,
              right: 16,
              bottom: 24,
              child: _SelectedPlaceCard(
                place: _selectedPlace!,
                onRoute: () => _showComingSoon('Маршрут удахгүй нэмэгдэнэ.'),
                onAddToWork: () =>
                    _showComingSoon('Ажилд нэмэх удахгүй нэмэгдэнэ.'),
                onClose: () {
                  setState(() {
                    _selectedPlace = null;
                    _markers = <Marker>{
                      const Marker(
                        markerId: _ubMarkerId,
                        position: _ulaanbaatar,
                        infoWindow: InfoWindow(title: 'Улаанбаатар хот'),
                      ),
                    };
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MapSearchInput extends StatelessWidget {
  const _MapSearchInput({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(
              Icons.search_rounded,
              color: AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.search,
                onChanged: onChanged,
                decoration: const InputDecoration(
                  hintText: 'Байршил хайх...',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              )
            else if (controller.text.isNotEmpty)
              IconButton(
                onPressed: onClear,
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                ),
                tooltip: 'Цэвэрлэх',
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({
    required this.isLoading,
    required this.errorMessage,
    required this.suggestions,
    required this.hasQuery,
    required this.onTap,
  });

  final bool isLoading;
  final String? errorMessage;
  final List<PlacePredictionModel> suggestions;
  final bool hasQuery;
  final ValueChanged<PlacePredictionModel> onTap;

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (isLoading) {
      body = const _PanelInfoRow(
        icon: Icons.search_rounded,
        text: 'Хайж байна...',
      );
    } else if (errorMessage != null) {
      body = _PanelInfoRow(
        icon: Icons.error_outline_rounded,
        text: errorMessage!,
        color: AppColors.warning,
      );
    } else if (suggestions.isEmpty) {
      if (!hasQuery) return const SizedBox.shrink();
      body = const _PanelInfoRow(
        icon: Icons.location_off_rounded,
        text: 'Байршил олдсонгүй.',
      );
    } else {
      body = ListView.separated(
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
          final s = suggestions[index];
          return InkWell(
            onTap: () => onTap(s),
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
                      color: AppColors.primary.withValues(alpha: 0.1),
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
                          s.mainText.isNotEmpty ? s.mainText : s.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (s.secondaryText.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            s.secondaryText,
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
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: body,
        ),
      ),
    );
  }
}

class _PanelInfoRow extends StatelessWidget {
  const _PanelInfoRow({
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
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
}

class _SelectedPlaceCard extends StatelessWidget {
  const _SelectedPlaceCard({
    required this.place,
    required this.onRoute,
    required this.onAddToWork,
    required this.onClose,
  });

  final PlaceDetailModel place;
  final VoidCallback onRoute;
  final VoidCallback onAddToWork;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name.isNotEmpty ? place.name : 'Байршил',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (place.address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          place.address,
                          maxLines: 2,
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
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textMuted,
                  ),
                  tooltip: 'Хаах',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onRoute,
                    icon: const Icon(Icons.directions_rounded, size: 18),
                    label: const Text('Маршрут харах'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAddToWork,
                    icon: const Icon(Icons.add_task_rounded, size: 18),
                    label: const Text('Ажилд нэмэх'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
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
    );
  }
}

class _MapFloatingButton extends StatelessWidget {
  const _MapFloatingButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

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

class _MapTypeOption extends StatelessWidget {
  const _MapTypeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

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
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
