import 'package:flutter/material.dart';
import 'app.dart';
import 'features/map/data/services/map_api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable mock data to avoid extra API costs
  MapApiService.useMockData = true;

  runApp(const AccessPlanApp());
}
