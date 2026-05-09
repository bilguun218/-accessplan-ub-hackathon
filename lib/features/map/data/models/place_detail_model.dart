class PlaceReviewModel {
  final String author;
  final double rating;
  final String text;
  final String date;

  const PlaceReviewModel({
    required this.author,
    required this.rating,
    required this.text,
    required this.date,
  });

  factory PlaceReviewModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return PlaceReviewModel(
      author: json['author']?.toString() ?? '',
      rating: parseDouble(json['rating']),
      text: json['text']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'author': author,
    'rating': rating,
    'text': text,
    'date': date,
  };
}

class PlaceDetailModel {
  final String placeId;
  final String name;
  final String secondaryText;
  final String address;
  final double latitude;
  final double longitude;
  final String category;
  final double rating;
  final int reviewCount;
  final bool openNow;
  final String hours;
  final String phone;
  final String website;
  final String plusCode;
  final String priceLevel;
  final List<String> tags;
  final List<String> accessibility;
  final List<PlaceReviewModel> reviews;

  const PlaceDetailModel({
    required this.placeId,
    required this.name,
    this.secondaryText = '',
    required this.address,
    required this.latitude,
    required this.longitude,
    this.category = 'Бусад',
    this.rating = 0.0,
    this.reviewCount = 0,
    this.openNow = false,
    this.hours = '',
    this.phone = '',
    this.website = '',
    this.plusCode = '',
    this.priceLevel = '',
    this.tags = const <String>[],
    this.accessibility = const <String>[],
    this.reviews = const <PlaceReviewModel>[],
  });

  factory PlaceDetailModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    List<String> parseStringList(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList(growable: false);
      }
      return const <String>[];
    }

    List<PlaceReviewModel> parseReviews(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map>()
            .map((e) => PlaceReviewModel.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false);
      }
      return const <PlaceReviewModel>[];
    }

    return PlaceDetailModel(
      placeId: json['placeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      secondaryText: json['secondaryText']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      category: json['category']?.toString() ?? 'Бусад',
      rating: parseDouble(json['rating']),
      reviewCount: parseInt(json['reviewCount']),
      openNow: json['openNow'] == true,
      hours: json['hours']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      plusCode: json['plusCode']?.toString() ?? '',
      priceLevel: json['priceLevel']?.toString() ?? '',
      tags: parseStringList(json['tags']),
      accessibility: parseStringList(json['accessibility']),
      reviews: parseReviews(json['reviews']),
    );
  }
}
