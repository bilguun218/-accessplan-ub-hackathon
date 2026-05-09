import 'package:dio/dio.dart';

import '../../../../core/config/api_config.dart';
import '../models/place_detail_model.dart';
import '../models/place_prediction_model.dart';
import 'mock_map_api_service.dart';

class MapApiService {
  final Dio _dio;
  final MockMapApiService _mockService = MockMapApiService();

  // Set to true to use mock data instead of real API
  static bool useMockData = false;

  MapApiService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              contentType: 'application/json',
            ),
          );

  Future<List<PlacePredictionModel>> autocomplete(String input) async {
    final query = input.trim();
    if (query.isEmpty) return <PlacePredictionModel>[];

    // Use mock data if enabled
    if (useMockData) {
      return _mockService.autocomplete(query);
    }

    try {
      final response = await _dio.get(
        '/maps/autocomplete',
        queryParameters: {'input': query},
      );
      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map(
              (e) =>
                  PlacePredictionModel.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList();
      }
      return <PlacePredictionModel>[];
    } on DioException catch (e) {
      // Fallback to mock data on network error
      return _mockService.autocomplete(query);
    }
  }

  Future<PlaceDetailModel> getPlaceDetails(String placeId) async {
    // Use mock data if enabled
    if (useMockData) {
      return _mockService.getPlaceDetails(placeId);
    }

    try {
      final response = await _dio.get(
        '/maps/place-details',
        queryParameters: {'placeId': placeId},
      );
      final data = response.data;
      if (data is Map) {
        return PlaceDetailModel.fromJson(Map<String, dynamic>.from(data));
      }
      throw Exception('Байршлын мэдээлэл буруу байна.');
    } on DioException catch (e) {
      // Fallback to mock data on network error
      return _mockService.getPlaceDetails(placeId);
    }
  }

  String _extractMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final err = data['error'];
      if (err is Map && err['message'] is String) {
        return err['message'] as String;
      }
      if (data['message'] is String) {
        return data['message'] as String;
      }
    }
    return fallback;
  }
}
