import '../../../map/data/services/mock_map_api_service.dart';
import '../models/organization_model.dart';

class MockOrganizations {
  static const List<String> categories = <String>[
    'Бүгд',
    'Зочид буудал',
    'Музей',
    'Кафе',
    'Ресторан',
    'Эмнэлэг',
    'Банк',
    'Дэлгүүр',
    'Боловсрол',
    'Албан газар',
    'Сервис',
    'Соёл',
    'Бусад',
  ];

  // mock_map_api_service.dart дотор байгаа 353 газрыг Organization болгож ашиглана.
  static final List<Organization> all = _buildFromMockPlaces();

  static List<Organization> _buildFromMockPlaces() {
    final list = <Organization>[];
    for (var i = 0; i < MockMapApiService.mockPlaces.length; i++) {
      final p = MockMapApiService.mockPlaces[i];
      final name = (p['mainText'] as String?)?.trim() ?? 'Unknown';
      final address = (p['address'] as String?)?.trim() ?? '';
      final lat = (p['latitude'] as num?)?.toDouble() ?? 47.918873;
      final lng = (p['longitude'] as num?)?.toDouble() ?? 106.917701;
      list.add(
        _organizationFrom(
          i: i,
          name: name,
          address: address,
          latitude: lat,
          longitude: lng,
        ),
      );
    }
    return list;
  }

  static Organization _organizationFrom({
    required int i,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
  }) {
    final category = _inferCategory(name);
    final seed = name.hashCode ^ i;
    final rating = _pseudoRating(seed);
    final reviewCount = _pseudoReviewCount(seed);
    final distanceKm = _pseudoDistance(seed);
    final price = _pseudoPrice(seed, category);
    final openNow = (seed.abs() % 5) != 0;
    final hours = openNow ? 'Өнөөдөр 09:00-22:00' : 'Өнөөдөр 09:00-18:00';
    final phone = _pseudoPhone(seed);
    final priority = (seed.abs() % 10); // 0..9

    return Organization(
      name: name,
      category: category,
      rating: rating,
      reviewCount: reviewCount,
      distanceKm: distanceKm,
      openNow: openNow,
      price: price,
      address: address.isEmpty ? 'Улаанбаатар, Монгол' : address,
      phone: phone,
      hours: hours,
      tags: _tagsFor(category),
      accessibility: _accessibilityFor(seed),
      reviews: _reviewsFor(seed, name),
      latitude: latitude,
      longitude: longitude,
      priority: priority,
    );
  }

  static String _inferCategory(String name) {
    final n = name.toLowerCase();
    if (_containsAny(n, ['hotel', 'буудал', 'lodge', 'guest', 'inn', 'resort'])) {
      return 'Зочид буудал';
    }
    if (_containsAny(n, ['museum', 'музей', 'gallery', 'galery'])) {
      return 'Музей';
    }
    if (_containsAny(n, ['hospital', 'эмнэл', 'clinic', 'medical', 'health'])) {
      return 'Эмнэлэг';
    }
    if (_containsAny(n, ['bank', 'банк'])) {
      return 'Банк';
    }
    if (_containsAny(n, ['cafe', 'café', 'coffee', 'кофе', 'кафе'])) {
      return 'Кафе';
    }
    if (_containsAny(n, [
      'restaurant', 'ресторан', 'kitchen', 'grill', 'sushi', 'pizza',
      'burger', 'lounge', 'food',
    ])) {
      return 'Ресторан';
    }
    if (_containsAny(n, [
      'mart', 'mall', 'store', 'shop', 'дэлгүүр', 'plaza',
      'market', 'supermarket', 'cu ', 'gs25', 'circle k', 'emart',
    ])) {
      return 'Дэлгүүр';
    }
    if (_containsAny(n, [
      'university', 'school', 'institute', 'college', 'их сургууль',
      'academy', 'kindergarten', 'цэцэрлэг', 'сургууль',
    ])) {
      return 'Боловсрол';
    }
    if (_containsAny(n, [
      'theatre', 'theater', 'cinema', 'opera', 'palace', 'temple',
      'monastery', 'хийд', 'парк', 'park',
    ])) {
      return 'Соёл';
    }
    if (_containsAny(n, [
      'service', 'service center', 'сервис', 'wash', 'auto', 'repair',
      'gas', 'fuel',
    ])) {
      return 'Сервис';
    }
    if (_containsAny(n, [
      'office', 'government', 'ministry', 'embassy', 'tower', 'plaza',
      'centre', 'center',
    ])) {
      return 'Албан газар';
    }
    return 'Бусад';
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final n in needles) {
      if (haystack.contains(n)) return true;
    }
    return false;
  }

  static double _pseudoRating(int seed) {
    final v = (seed.abs() % 18) / 10.0; // 0.0 - 1.7
    final base = 3.3 + v;
    return double.parse(base.toStringAsFixed(1));
  }

  static int _pseudoReviewCount(int seed) {
    return 24 + (seed.abs() % 580);
  }

  static double _pseudoDistance(int seed) {
    final v = (seed.abs() % 95) / 10.0; // 0.0 - 9.4
    return double.parse((0.3 + v).toStringAsFixed(1));
  }

  static String _pseudoPrice(int seed, String category) {
    if (category == 'Эмнэлэг' || category == 'Зочид буудал') {
      return ['₮₮', '₮₮₮', '₮₮₮'][(seed.abs()) % 3];
    }
    if (category == 'Албан газар' || category == 'Боловсрол') return '₮';
    return ['₮', '₮₮', '₮₮', '₮₮₮'][seed.abs() % 4];
  }

  static String _pseudoPhone(int seed) {
    final part = 1000 + (seed.abs() % 8999);
    final part2 = 1000 + ((seed >> 4).abs() % 8999);
    return '+976 $part $part2';
  }

  static List<String> _tagsFor(String category) {
    switch (category) {
      case 'Зочид буудал':
        return const ['Wi-Fi', 'Зогсоол', 'Ресторантай'];
      case 'Музей':
        return const ['Соёл', 'Үзвэр', 'Аяллын газар'];
      case 'Эмнэлэг':
        return const ['Эмчийн цаг', 'Лаборатори', 'Яаралтай'];
      case 'Банк':
        return const ['ATM', 'Цахим үйлчилгээ'];
      case 'Кафе':
        return const ['Wi-Fi', 'Tакеaway', 'Кофе'];
      case 'Ресторан':
        return const ['Хүргэлт', 'Захиалга', 'Гэр бүлд ээлтэй'];
      case 'Дэлгүүр':
        return const ['Хүргэлт', 'Сонголт өргөн'];
      case 'Боловсрол':
        return const ['Хичээл', 'Сургалт'];
      case 'Соёл':
        return const ['Үзвэр', 'Аялал жуулчлал'];
      case 'Сервис':
        return const ['Авто', 'Угаалга'];
      case 'Албан газар':
        return const ['Үйлчилгээ', 'Цахим'];
      default:
        return const ['Үйлчилгээ'];
    }
  }

  static List<String> _accessibilityFor(int seed) {
    final all = const [
      'Тэргэнцэрт ээлтэй орц',
      'Лифттэй',
      'Тэргэнцэрт ээлтэй ариун цэврийн өрөө',
      'Хүүхдийн өрөө',
      'Харааны тэмдэглэгээтэй',
      'Хүлээлгийн бүс',
      'Орчуулагч',
    ];
    final count = 2 + (seed.abs() % 3); // 2-4
    final start = seed.abs() % all.length;
    return List<String>.generate(
      count,
      (i) => all[(start + i) % all.length],
    );
  }

  static List<OrganizationReview> _reviewsFor(int seed, String name) {
    const authors = [
      'Энхтүвшин', 'Саруул', 'Бат-Эрдэнэ', 'Дөлгөөн', 'Ганболд', 'Болор',
      'Сайнбаяр', 'Мөнх-Эрдэнэ', 'Тэмүүлэн', 'Ариунболд', 'Отгон', 'Гэрэл',
      'Цэрэн', 'Номин', 'Долгор', 'Бямбажав', 'Жавхлан', 'Уянга',
      'Эрдэнэ', 'Сувд', 'Энхжин', 'Билгүүн', 'Баатар', 'Оюун',
    ];
    const phrases = [
      'Үйлчилгээ хурдан, орчин цэвэрхэн.',
      'Ажилтнууд найрсаг, мэргэжлийн.',
      'Үнэ боломжийн, чанар сайн.',
      'Хүлээлт бага зэрэг удаан байсан.',
      'Орц гарц тэргэнцэрт ээлтэй.',
      'Ахин очно гэж бодож байна.',
      'Чанарын төлөө сэтгэл хангалуун.',
      'Орчин тухтай, тав тухтай.',
    ];
    final r1 = 3.6 + ((seed.abs() % 14) / 10.0);
    final r2 = 3.4 + (((seed >> 3).abs() % 16) / 10.0);
    return [
      OrganizationReview(
        author: authors[seed.abs() % authors.length],
        rating: double.parse(r1.toStringAsFixed(1)),
        text: phrases[seed.abs() % phrases.length],
        date: '2026-04-${10 + (seed.abs() % 20)}',
      ),
      OrganizationReview(
        author: authors[(seed >> 5).abs() % authors.length],
        rating: double.parse(r2.toStringAsFixed(1)),
        text: phrases[((seed >> 7).abs()) % phrases.length],
        date: '2026-04-${1 + ((seed >> 4).abs() % 9)}',
      ),
    ];
  }
}
