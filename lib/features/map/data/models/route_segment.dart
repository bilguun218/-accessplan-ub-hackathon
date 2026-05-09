import 'package:google_maps_flutter/google_maps_flutter.dart';

enum RouteTaskStatus { pending, current, completed }

class RouteSegment {
  /// 0..n-1 — segment N goes from previous point to task index N.
  final int index;
  final String taskId;
  final int taskOrder;
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
  final int trafficDelaySeconds;
  final RouteTaskStatus status;

  const RouteSegment({
    required this.index,
    required this.taskId,
    required this.taskOrder,
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
    this.trafficDelaySeconds = 0,
    this.status = RouteTaskStatus.pending,
  });

  double get distanceKm => distanceMeters / 1000.0;
  int get durationMinutes => (durationSeconds / 60).round();
  int get trafficDelayMinutes => (trafficDelaySeconds / 60).round();
  int get totalDurationSeconds => durationSeconds + trafficDelaySeconds;

  RouteSegment copyWith({
    RouteTaskStatus? status,
    int? trafficDelaySeconds,
  }) {
    return RouteSegment(
      index: index,
      taskId: taskId,
      taskOrder: taskOrder,
      fromLabel: fromLabel,
      toLabel: toLabel,
      toAddress: toAddress,
      toCategory: toCategory,
      toTimeText: toTimeText,
      fromLatLng: fromLatLng,
      toLatLng: toLatLng,
      polyline: polyline,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      trafficDelaySeconds: trafficDelaySeconds ?? this.trafficDelaySeconds,
      status: status ?? this.status,
    );
  }
}
