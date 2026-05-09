import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteSegment {
  /// 0..n-1 — segment N goes from previous point to task index N.
  final int index;
  final String fromLabel;
  final String toLabel;
  final String toAddress;
  final String toCategory;
  final String toTimeText;
  final LatLng fromLatLng;
  final LatLng toLatLng;
  final List<LatLng> polyline;
  final int distanceMeters;
  final int durationSeconds;

  const RouteSegment({
    required this.index,
    required this.fromLabel,
    required this.toLabel,
    required this.toAddress,
    required this.toCategory,
    required this.toTimeText,
    required this.fromLatLng,
    required this.toLatLng,
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  double get distanceKm => distanceMeters / 1000.0;
  int get durationMinutes => (durationSeconds / 60).round();
}
