import 'dart:math';

import '../../../map/data/services/mock_map_api_service.dart';
import '../models/business_post.dart';
import '../models/map_promotion_item.dart';

class MockBusinessPostService {
  Future<List<MapPromotionItem>> getActiveMapPromotions({
    required double lat,
    required double lng,
    double radiusKm = 5,
  }) async {
    final items = <MapPromotionItem>[];
    var sponsoredCount = 0;

    for (var i = 0; i < MockMapApiService.mockPlaces.length; i++) {
      final place = MockMapApiService.mockPlaces[i];
      final latitude = _readDouble(place['latitude']);
      final longitude = _readDouble(place['longitude']);
      if (!_isValidCoordinate(latitude, longitude)) continue;

      final organizationId = place['placeId']?.toString() ?? 'mock_place_$i';
      final businessName = place['mainText']?.toString().trim() ?? '';
      if (businessName.isEmpty) continue;

      final description = place['description']?.toString() ?? '';
      final serviceType = _serviceTypeFor('$businessName $description');
      final shouldSponsor =
          sponsoredCount < 2 &&
          (serviceType == 'Банк' ||
              serviceType == 'Кофе' ||
              serviceType == 'Эмийн сан');
      final post = _postFor(
        organizationId: organizationId,
        serviceType: serviceType,
        seedText: '$businessName $description',
        sponsored: shouldSponsor,
        index: i,
      );
      if (post == null || !post.isCurrentlyVisibleOnMap) continue;
      if (shouldSponsor) sponsoredCount++;

      final distance = _distanceKm(
        lat1: lat,
        lng1: lng,
        lat2: latitude!,
        lng2: longitude!,
      );
      if (distance > radiusKm) continue;

      items.add(
        MapPromotionItem(
          organizationId: organizationId,
          businessName: businessName,
          branchName: _branchName(place['secondaryText']?.toString()),
          serviceType: serviceType,
          address: place['address']?.toString() ?? description,
          latitude: latitude,
          longitude: longitude,
          post: post,
          distanceKm: distance,
        ),
      );
    }

    items.sort((a, b) {
      final sponsored = b.post.isSponsored.toString().compareTo(
        a.post.isSponsored.toString(),
      );
      if (sponsored != 0) return sponsored;
      return (a.distanceKm ?? double.infinity).compareTo(
        b.distanceKm ?? double.infinity,
      );
    });
    return items.take(15).toList(growable: false);
  }

  BusinessPost? _postFor({
    required String organizationId,
    required String serviceType,
    required String seedText,
    required bool sponsored,
    required int index,
  }) {
    final text = seedText.toLowerCase();
    final expires = DateTime.now().add(const Duration(days: 7));

    if (_containsAny(text, ['pharmacy', 'эмийн', 'аптек'])) {
      return BusinessPost(
        id: 'post_${organizationId}_vitamin',
        organizationId: organizationId,
        title: 'Витамин 15% хямдралтай',
        description:
            'Өнөөдөр бүх төрлийн витамин болон дархлаа дэмжих бүтээгдэхүүн 15% хямдралтай.',
        type: BusinessPostType.discount,
        endsAt: expires,
        isSponsored: sponsored,
      );
    }
    if (_containsAny(text, ['bank', 'банк'])) {
      return BusinessPost(
        id: 'post_${organizationId}_fee_free',
        organizationId: organizationId,
        title: 'Шимтгэлгүй үйлчилгээ',
        description:
            'Өнөөдөр салбараар үйлчлүүлсэн хэрэглэгчдэд зарим гүйлгээний шимтгэлгүй.',
        type: BusinessPostType.promotion,
        endsAt: expires,
        isSponsored: sponsored,
      );
    }
    if (_containsAny(text, ['coffee', 'cafe', 'café', 'кофе', 'кафе'])) {
      return BusinessPost(
        id: 'post_${organizationId}_coffee_gift',
        organizationId: organizationId,
        title: '2 кофе авбал 1 амттан бэлэгтэй',
        description:
            'Өнөөдрийн урамшууллаар 2 кофе худалдан авбал сонгосон амттан бэлэглэнэ.',
        type: BusinessPostType.promotion,
        endsAt: expires,
        isSponsored: sponsored,
      );
    }
    if (_containsAny(text, [
      'supermarket',
      'market',
      'mart',
      'store',
      'shop',
      'shopping',
      'mall',
      'дэлгүүр',
    ])) {
      return BusinessPost(
        id: 'post_${organizationId}_daily_discount',
        organizationId: organizationId,
        title: 'Өнөөдрийн онцгой хямдрал',
        description:
            'Сонгогдсон бараа бүтээгдэхүүнүүд өнөөдөр тусгай үнээр худалдаалагдаж байна.',
        type: BusinessPostType.discount,
        endsAt: expires,
        isSponsored: sponsored,
      );
    }
    if (_containsAny(text, ['restaurant', 'food', 'kitchen', 'хоол'])) {
      return BusinessPost(
        id: 'post_${organizationId}_lunch_set',
        organizationId: organizationId,
        title: 'Өдрийн хоолны багц',
        description:
            'Өдрийн хоолны багц меню хөнгөлөлттэй үнээр үйлчилж байна.',
        type: BusinessPostType.promotion,
        endsAt: expires,
        isSponsored: sponsored,
      );
    }

    if (index % 37 != 0) return null;
    return BusinessPost(
      id: 'post_${organizationId}_announcement',
      organizationId: organizationId,
      title: 'Өнөөдрийн мэдээлэл',
      description:
          '$serviceType байгууллага өнөөдөр хэвийн цагийн хуваариар ажиллаж байна.',
      type: BusinessPostType.general,
      endsAt: expires,
      isSponsored: false,
    );
  }

  String _serviceTypeFor(String raw) {
    final value = raw.toLowerCase();
    if (_containsAny(value, ['pharmacy', 'эмийн', 'аптек'])) return 'Эмийн сан';
    if (_containsAny(value, ['bank', 'банк'])) return 'Банк';
    if (_containsAny(value, ['coffee', 'cafe', 'café', 'кофе', 'кафе'])) {
      return 'Кофе';
    }
    if (_containsAny(value, [
      'supermarket',
      'market',
      'mart',
      'store',
      'shop',
      'shopping',
      'mall',
      'дэлгүүр',
    ])) {
      return 'Дэлгүүр';
    }
    if (_containsAny(value, ['restaurant', 'food', 'kitchen', 'хоол'])) {
      return 'Ресторан';
    }
    return 'Байгууллага';
  }

  String? _branchName(String? raw) {
    final value = raw?.trim();
    if (value == null ||
        value.isEmpty ||
        value.toLowerCase() == 'ulaanbaatar') {
      return null;
    }
    return value;
  }

  bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }

  double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool _isValidCoordinate(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;
    if (latitude.abs() > 90 || longitude.abs() > 180) return false;
    if (latitude == 0 && longitude == 0) return false;
    return true;
  }

  double _distanceKm({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180.0;
}
