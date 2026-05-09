import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../organizations/data/models/organization_model.dart';
import '../models/ranked_job_route.dart';

/// Directions API key (Application restriction = None эсвэл server IP-р
/// хязгаарласан байх ёстой). Key буруу бол Haversine fallback ажиллана.
const String kRoutesApiKey = 'AIzaSyCzSEiXfzNxih5jwMoIi154djLt86lCymI';

const String _directionsEndpoint =
    'https://maps.googleapis.com/maps/api/directions/json';

/// OSRM нь үнэгүй, key шаарддаггүй жинхэнэ замын дагуу route өгдөг public сервис.
const String _osrmEndpoint = 'https://router.project-osrm.org/route/v1/driving';

class JobRouteService {
  /// Эхний дуудалтад зөвхөн Haversine-аар ranking хийгээд буцаана.
  /// Polyline хоосон, distance ойролцоогоор. UI marker-уудыг шууд гаргахад.
  List<RankedJobRoute> rankJobsLocal({
    required LatLng origin,
    required List<Organization> jobs,
    int limit = 5,
  }) {
    if (jobs.isEmpty) return const [];

    final shortlist = _nearestByHaversine(origin, jobs, limit);
    final results = <RankedJobRoute>[];

    for (final job in shortlist) {
      final distanceMeters = haversineMeters(
        origin.latitude,
        origin.longitude,
        job.latitude,
        job.longitude,
      ).round();
      final durationSeconds = _estimateDurationSeconds(distanceMeters);
      final score = _scoreFor(
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        priority: job.priority,
      );

      results.add(
        RankedJobRoute(
          job: job,
          rank: 0,
          distanceMeters: distanceMeters,
          durationSeconds: durationSeconds,
          score: score,
          polylinePoints: const <LatLng>[],
        ),
      );
    }

    results.sort((a, b) => a.score.compareTo(b.score));
    return [
      for (var i = 0; i < results.length; i++)
        results[i].copyWith(rank: i + 1),
    ];
  }

  /// Тухайн нэг job-руу route татна. Эхлээд OSRM (үнэгүй, key-гүй),
  /// амжилтгүй бол Google Directions API руу шилжинэ.
  Future<RankedJobRoute?> fetchRouteFor({
    required LatLng origin,
    required RankedJobRoute baseline,
  }) async {
    final dest = LatLng(baseline.job.latitude, baseline.job.longitude);

    var route = await _fetchOsrmRoute(origin: origin, destination: dest);
    route ??= await _fetchRoute(origin: origin, destination: dest);
    if (route == null) return null;

    final score = _scoreFor(
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
      priority: baseline.job.priority,
    );

    return RankedJobRoute(
      job: baseline.job,
      rank: baseline.rank,
      distanceMeters: route.distanceMeters,
      durationSeconds: route.durationSeconds,
      score: score,
      polylinePoints: route.points,
    );
  }

  Future<_RouteResult?> _fetchOsrmRoute({
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
          await http.get(uri).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        debugPrint('OSRM ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') {
        debugPrint('OSRM code=${data['code']}: ${data['message'] ?? ''}');
        return null;
      }

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

      return _RouteResult(
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        points: points,
      );
    } catch (e) {
      debugPrint('OSRM error: $e');
      return null;
    }
  }

  List<Organization> _nearestByHaversine(
    LatLng origin,
    List<Organization> jobs,
    int limit,
  ) {
    final entries = jobs
        .map((j) => MapEntry(
              j,
              haversineMeters(
                origin.latitude,
                origin.longitude,
                j.latitude,
                j.longitude,
              ),
            ))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries.take(limit).map((e) => e.key).toList();
  }

  double _scoreFor({
    required int distanceMeters,
    required int durationSeconds,
    required int priority,
  }) {
    final distanceKm = distanceMeters / 1000.0;
    final durationMinutes = durationSeconds / 60.0;
    return distanceKm * 0.55 + durationMinutes * 0.35 - priority * 0.10;
  }

  int _estimateDurationSeconds(int meters) {
    // ~30 km/h average → meters / (30000/3600) = meters * 0.12
    return (meters * 0.12).round();
  }

  Future<_RouteResult?> _fetchRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (kRoutesApiKey.isEmpty) return null;

    try {
      final uri = Uri.parse(_directionsEndpoint).replace(
        queryParameters: {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination':
              '${destination.latitude},${destination.longitude}',
          'mode': 'driving',
          'language': 'mn',
          'key': kRoutesApiKey,
        },
      );

      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint(
          'Directions API ${response.statusCode}: ${response.body}',
        );
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final status = data['status']?.toString() ?? '';
      if (status != 'OK') {
        debugPrint(
          'Directions API status=$status: ${data['error_message'] ?? ''}',
        );
        return null;
      }

      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final legs = route['legs'] as List?;
      if (legs == null || legs.isEmpty) return null;

      final leg = legs.first as Map<String, dynamic>;
      final distanceMeters =
          ((leg['distance'] as Map?)?['value'] as num?)?.toInt() ?? 0;
      final durationSeconds =
          ((leg['duration'] as Map?)?['value'] as num?)?.toInt() ?? 0;

      final encoded = (route['overview_polyline'] as Map?)?['points']
              ?.toString() ??
          '';

      final points = encoded.isEmpty
          ? const <LatLng>[]
          : PolylinePoints()
              .decodePolyline(encoded)
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();

      return _RouteResult(
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        points: points,
      );
    } catch (e) {
      debugPrint('Directions API error: $e');
      return null;
    }
  }
}

double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0; // earth radius meters
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(lat1)) *
          math.cos(_toRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

double _toRad(double deg) => deg * math.pi / 180.0;

class _RouteResult {
  final int distanceMeters;
  final int durationSeconds;
  final List<LatLng> points;

  const _RouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.points,
  });
}
