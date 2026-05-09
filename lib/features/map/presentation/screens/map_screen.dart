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
  static const double _defaultZoom = 13.0;
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

  Set<Marker> _markers = <Marker>{};

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

      // Update initial camera position if this is the first load
      if (!_locationLoaded) {
        _initialCameraPosition = CameraPosition(
          target: currentLatLng,
          zoom: 16,
        );
        _locationLoaded = true;
      }

      setState(() {
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
    } catch (e) {
      debugPrint('Current location error: $e');
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
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  subtitle: 'Satellite map',
                  icon: Icons.satellite_alt_rounded,
                  isSelected: _mapType == MapType.satellite,
                  onTap: () {
                    Navigator.pop(context);
                    _changeMapType(MapType.satellite);
                  },
                ),
                _MapTypeOption(
                  title: 'Hybrid',
                  subtitle: 'Hybrid map',
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
            markers: _markers,
            myLocationEnabled: _locationGranted,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
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
              ],
            ),
          ),

          if (_permissionMessage != null)
            Positioned(
              top: viewPadding.top + 70,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_off, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _permissionMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
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
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: onTap,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search places...',
          prefixIcon: const Icon(Icons.location_on),
          suffixIcon: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : controller.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear)
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
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

  @override
  Widget build(BuildContext context) {
    if (isLoading && suggestions.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorMessage != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    if (suggestions.isEmpty && !isLoading && hasQuery) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No results found'),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(suggestion.mainText),
              subtitle: Text(
                suggestion.secondaryText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onTap(suggestion),
            );
          },
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
    return FloatingActionButton(
      mini: true,
      backgroundColor: isActive ? Colors.blue : Colors.white,
      foregroundColor: isActive ? Colors.white : Colors.blue,
      tooltip: tooltip,
      onPressed: onTap,
      child: Icon(icon),
    );
  }
}
