import '../models/place_detail_model.dart';
import '../models/place_prediction_model.dart';

class MockMapApiService {
  // Sample Ulaanbaatar locations
  static const List<Map<String, dynamic>> _mockPlaces = [
    {
      'placeId': 'mock_peace_avenue',
      'description': 'Peace Avenue (Enkh Taivny Urgon Chuloo), Ulaanbaatar',
      'mainText': 'Peace Avenue',
      'secondaryText': 'Enkh Taivny Urgon Chuloo, Ulaanbaatar',
      'latitude': 47.9215,
      'longitude': 106.9155,
      'address': 'Peace Avenue, Sukhbaatar District, Ulaanbaatar',
    },
    {
      'placeId': 'mock_khan_bank',
      'description': 'Khan Bank Head Office, Ulaanbaatar',
      'mainText': 'Khan Bank',
      'secondaryText': 'Peace Avenue, Ulaanbaatar',
      'latitude': 47.9198,
      'longitude': 106.9168,
      'address': 'Khan Bank, Sukhbaatar District, Ulaanbaatar',
    },
    {
      'placeId': 'mock_parliament',
      'description': 'Parliament House (Khural), Ulaanbaatar',
      'mainText': 'Parliament House',
      'secondaryText': 'Sukhbaatar Square, Ulaanbaatar',
      'latitude': 47.9202,
      'longitude': 106.9192,
      'address': 'Parliament House, Sukhbaatar District, Ulaanbaatar',
    },
    {
      'placeId': 'mock_gandantegchinlen',
      'description': 'Gandantegchinlen Monastery, Ulaanbaatar',
      'mainText': 'Gandantegchinlen Monastery',
      'secondaryText': 'Bayanzurkh District, Ulaanbaatar',
      'latitude': 47.9297,
      'longitude': 106.8993,
      'address': 'Gandantegchinlen Monastery, Bayanzurkh District, Ulaanbaatar',
    },
    {
      'placeId': 'mock_bogd_palace',
      'description': 'Bogd Palace Museum, Ulaanbaatar',
      'mainText': 'Bogd Palace Museum',
      'secondaryText': 'Chingeltei District, Ulaanbaatar',
      'latitude': 47.8903,
      'longitude': 106.9267,
      'address': 'Bogd Palace Museum, Chingeltei District, Ulaanbaatar',
    },
    {
      'placeId': 'mock_sukhbaatar_square',
      'description': 'Sukhbaatar Square, Ulaanbaatar',
      'mainText': 'Sukhbaatar Square',
      'secondaryText': 'Sukhbaatar District, Ulaanbaatar',
      'latitude': 47.9206,
      'longitude': 106.9155,
      'address': 'Sukhbaatar Square, Sukhbaatar District, Ulaanbaatar',
    },
    {
      'placeId': 'mock_zaisan_memorial',
      'description': 'Zaisan Memorial, Ulaanbaatar',
      'mainText': 'Zaisan Memorial',
      'secondaryText': 'Bayanzurkh District, Ulaanbaatar',
      'latitude': 47.8528,
      'longitude': 106.8697,
      'address': 'Zaisan Memorial, Bayanzurkh District, Ulaanbaatar',
    },
    {
      'placeId': 'mock_gorkhi_terelj',
      'description': 'Gorkhi-Terelj National Park, Töv Province',
      'mainText': 'Gorkhi-Terelj National Park',
      'secondaryText': 'Töv Province, Mongolia',
      'latitude': 48.0667,
      'longitude': 107.3333,
      'address': 'Gorkhi-Terelj National Park, Töv Province',
    },
    {
      'placeId': 'mock_naadam_stadium',
      'description': 'Naadam Stadium, Ulaanbaatar',
      'mainText': 'Naadam Stadium',
      'secondaryText': 'Bayanzurkh District, Ulaanbaatar',
      'latitude': 47.9039,
      'longitude': 106.9406,
      'address': 'Peace Avenue, Bayanzurkh District, Ulaanbaatar',
    },
    {
      'placeId': 'mock_khustain_nuruu',
      'description': 'Khustain Nuruu National Park, Töv Province',
      'mainText': 'Khustain Nuruu National Park',
      'secondaryText': 'Töv Province, Mongolia',
      'latitude': 48.0139,
      'longitude': 106.4694,
      'address': 'Khustain Nuruu National Park, Töv Province',
    },
  ];

  Future<List<PlacePredictionModel>> autocomplete(String input) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    final query = input.toLowerCase().trim();
    if (query.isEmpty) return [];

    // Filter mock places by search query
    return _mockPlaces
        .where(
          (place) =>
              place['mainText'].toLowerCase().contains(query) ||
              place['description'].toLowerCase().contains(query) ||
              place['secondaryText'].toLowerCase().contains(query),
        )
        .map(
          (place) => PlacePredictionModel(
            placeId: place['placeId'] as String,
            description: place['description'] as String,
            mainText: place['mainText'] as String,
            secondaryText: place['secondaryText'] as String,
          ),
        )
        .toList();
  }

  Future<PlaceDetailModel> getPlaceDetails(String placeId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    final place = _mockPlaces.firstWhere(
      (p) => p['placeId'] == placeId,
      orElse: () => _mockPlaces[0],
    );

    return PlaceDetailModel(
      placeId: place['placeId'] as String,
      name: place['mainText'] as String,
      address: place['address'] as String,
      latitude: place['latitude'] as double,
      longitude: place['longitude'] as double,
    );
  }
}
