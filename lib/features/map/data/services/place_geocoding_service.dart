import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/place_detail_model.dart';
import 'mock_map_api_service.dart';

class GeocodedPlace {
  final LatLng latLng;
  final String name;
  final String address;
  const GeocodedPlace({
    required this.latLng,
    required this.name,
    required this.address,
  });
}

class PlaceGeocodingService {
  final MockMapApiService _mockApi;

  PlaceGeocodingService({MockMapApiService? mockApi})
    : _mockApi = mockApi ?? MockMapApiService();

  /// Resolve a free-text query (e.g. "Тэнгис", "search nearby bank")
  /// against the local mock dataset and return the matched place's
  /// coordinate + address. Returns null if nothing matched.
  Future<GeocodedPlace?> resolve(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;

    try {
      final predictions = await _mockApi.autocomplete(_stripSearchPrefix(q));
      if (predictions.isEmpty) return null;

      final first = predictions.first;
      if (first.placeId.isEmpty) return null;

      final PlaceDetailModel detail = await _mockApi.getPlaceDetails(
        first.placeId,
      );
      return GeocodedPlace(
        latLng: LatLng(detail.latitude, detail.longitude),
        name: detail.name,
        address: detail.address,
      );
    } catch (_) {
      return null;
    }
  }

  /// AI parser may emit `search nearby <category>` — strip the prefix so
  /// the mock autocomplete sees just the keyword.
  String _stripSearchPrefix(String q) {
    final lower = q.toLowerCase();
    const prefix = 'search nearby ';
    if (lower.startsWith(prefix)) return q.substring(prefix.length).trim();
    return q;
  }
}
