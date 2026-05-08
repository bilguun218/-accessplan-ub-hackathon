import 'package:dio/dio.dart';

import '../models/place_detail_model.dart';
import '../models/place_prediction_model.dart';

class MapApiService {
  // USB debug + adb reverse tcp:5000 tcp:5000 ашиглаж байгаа тул localhost.
  // Wi-Fi холболтоор бол: 'http://192.168.15.169:5000/api'
  // Emulator-ийн хувьд:    'http://10.0.2.2:5000/api'
  static const String _baseUrl = 'http://localhost:5000/api';

  final Dio _dio;

  MapApiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
                contentType: 'application/json',
              ),
            );

  Future<List<PlacePredictionModel>> autocomplete(String input) async {
    final query = input.trim();
    if (query.isEmpty) return <PlacePredictionModel>[];

    try {
      final response = await _dio.get(
        '/maps/autocomplete',
        queryParameters: {'input': query},
      );
      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => PlacePredictionModel.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList();
      }
      return <PlacePredictionModel>[];
    } on DioException catch (e) {
      throw Exception(_extractMessage(e, 'Байршил хайхад алдаа гарлаа.'));
    }
  }

  Future<PlaceDetailModel> getPlaceDetails(String placeId) async {
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
      throw Exception(_extractMessage(e, 'Байршлын мэдээлэл татаж чадсангүй.'));
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
