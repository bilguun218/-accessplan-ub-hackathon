import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../organizations/data/models/organization_model.dart';

class RankedJobRoute {
  final Organization job;
  final int rank;
  final int distanceMeters;
  final int durationSeconds;
  final double score;
  final List<LatLng> polylinePoints;

  const RankedJobRoute({
    required this.job,
    required this.rank,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.score,
    required this.polylinePoints,
  });

  double get distanceKm => distanceMeters / 1000.0;
  int get durationMinutes => (durationSeconds / 60).round();

  RankedJobRoute copyWith({int? rank}) => RankedJobRoute(
        job: job,
        rank: rank ?? this.rank,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        score: score,
        polylinePoints: polylinePoints,
      );
}
