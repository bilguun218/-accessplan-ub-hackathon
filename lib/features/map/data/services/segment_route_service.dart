import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

const String _osrmEndpoint =
    'https://router.project-osrm.org/route/v1/driving';

class SegmentRouteResult {
  final int distanceMeters;
  final int durationSeconds;
  final List<LatLng> points;

  const SegmentRouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
  });
}

class SegmentRouteService {
  /// Fetch a driving route between two arbitrary points using OSRM.
  /// Returns null on any failure.
  Future<SegmentRouteResult?> fetch({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final coords =
          '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
      final uri = Uri.parse('$_osrmEndpoint/$coords').replace(
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'false',
        },
      );

      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint('OSRM ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;

      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final distanceMeters =
          ((route['distance'] as num?)?.toDouble() ?? 0).round();
      final durationSeconds =
          ((route['duration'] as num?)?.toDouble() ?? 0).round();

      final geometry = route['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List?;
      if (coordinates == null || coordinates.isEmpty) return null;

      final points = <LatLng>[];
      for (final c in coordinates) {
        if (c is List && c.length >= 2) {
          final lng = (c[0] as num).toDouble();
          final lat = (c[1] as num).toDouble();
          points.add(LatLng(lat, lng));
        }
      }

      return SegmentRouteResult(
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        points: points,
      );
    } catch (e) {
      debugPrint('OSRM segment error: $e');
      return null;
    }
  }
}
