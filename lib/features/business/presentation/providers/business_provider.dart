import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../data/models/business_models.dart';
import '../../data/services/business_api_service.dart';

class BusinessProvider extends ChangeNotifier {
  final BusinessApiService _api;
  final SecureStorageService _storage;

  BusinessProvider({
    required BusinessApiService api,
    required SecureStorageService storage,
  }) : _api = api,
       _storage = storage;

  BusinessProfile _profile = BusinessProfile.demo();
  List<BusinessPromotion> _promotions = BusinessPromotion.seed();
  List<int> _dailyViews = const [42, 66, 55, 79, 94, 116, 84];
  List<int> _hourlyActivity = const [18, 34, 54, 46, 28, 64, 78, 58, 38];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _lastSyncMessage;

  BusinessProfile get profile => _profile;
  List<BusinessPromotion> get promotions => List.unmodifiable(_promotions);
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get lastSyncMessage => _lastSyncMessage;

  List<BusinessPromotion> get activePromotions =>
      _promotions.where((promo) => promo.active).toList(growable: false);

  BusinessAnalyticsSnapshot get analytics {
    final promoViews = _promotions.fold<int>(
      0,
      (sum, promo) => sum + promo.impressions,
    );
    final routeAdds = _promotions.fold<int>(
      0,
      (sum, promo) => sum + promo.routeAdds,
    );
    final searchViews = _dailyViews.fold<int>(0, (sum, value) => sum + value);
    final routeEntries = max(12, (searchViews * 0.15).round() + routeAdds);
    final maxHour = _hourlyActivity.reduce(max);
    final maxIndex = _hourlyActivity.indexOf(maxHour);
    final startHour = 9 + maxIndex;
    return BusinessAnalyticsSnapshot(
      dailyViews: List.unmodifiable(_dailyViews),
      hourlyActivity: List.unmodifiable(_hourlyActivity),
      searchViews: searchViews,
      routeEntries: routeEntries,
      promotionViews: promoViews,
      routeAdds: routeAdds,
      savedUsers: max(1, (searchViews * 0.08).round()),
      todayViews: _dailyViews.last,
      activeHourLabel: '${_two(startHour)}:00 - ${_two(startHour + 2)}:00',
    );
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final raw = await _storage.getBusinessState();
      if (raw != null && raw.isNotEmpty) {
        final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        _profile = BusinessProfile.fromJson(
          Map<String, dynamic>.from(decoded['profile'] as Map),
        );
        final rawPromotions = decoded['promotions'];
        if (rawPromotions is List) {
          _promotions = rawPromotions
              .whereType<Map>()
              .map(
                (promo) => BusinessPromotion.fromJson(
                  Map<String, dynamic>.from(promo),
                ),
              )
              .toList();
        }
        final rawDaily = decoded['dailyViews'];
        if (rawDaily is List) {
          _dailyViews = rawDaily
              .map((value) => (value as num).toInt())
              .toList();
        }
        final rawHourly = decoded['hourlyActivity'];
        if (rawHourly is List) {
          _hourlyActivity = rawHourly
              .map((value) => (value as num).toInt())
              .toList();
        }
      }
    } catch (_) {
      _profile = BusinessProfile.demo();
      _promotions = BusinessPromotion.seed();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createOrganization(BusinessProfile draft) async {
    _isSubmitting = true;
    _errorMessage = null;
    _lastSyncMessage = null;
    notifyListeners();

    var profile = draft.copyWith(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      status: 'active',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      profile = await _api.createOrganization(profile);
      _lastSyncMessage = 'Серверт хүсэлт илгээгдлээ.';
    } on ApiException catch (error) {
      _lastSyncMessage =
          '${error.message} Одоогоор төхөөрөмж дээр хадгалж, dashboard үүсгэлээ.';
    } catch (_) {
      _lastSyncMessage =
          'Сервертэй холбогдсонгүй. Одоогоор төхөөрөмж дээр хадгалж, dashboard үүсгэлээ.';
    }

    _profile = profile;
    _promotions = BusinessPromotion.seed();
    _seedAnalyticsFor(profile.organizationName);
    await _save();
    _isSubmitting = false;
    notifyListeners();
    return true;
  }

  Future<void> updateProfile(BusinessProfile profile) async {
    var updated = profile.copyWith(updatedAt: DateTime.now());
    if (!_isLocalId(profile.id)) {
      try {
        updated = await _api.updateOrganization(updated);
      } on ApiException {
        // Keep the edited profile locally if the real API is unavailable.
      } catch (_) {
        // Keep the edited profile locally if the real API is unavailable.
      }
    }
    _profile = updated;
    _lastSyncMessage = 'Байгууллагын мэдээлэл хадгалагдлаа.';
    await _save();
    notifyListeners();
  }

  Future<void> addPromotion({
    required String title,
    required String type,
    required String description,
    required String startDate,
    required String endDate,
    required String limit,
    bool isActive = true,
    bool showOnMap = true,
    bool isSponsored = false,
  }) async {
    final seed = title.hashCode.abs();
    var promo = BusinessPromotion(
      id: 'promo-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      type: type,
      description: description,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
      active: isActive,
      showOnMap: showOnMap,
      isSponsored: isSponsored,
      impressions: 18 + seed % 38,
      routeAdds: 4 + seed % 12,
      createdAt: DateTime.now(),
    );
    if (!_isLocalId(_profile.id)) {
      try {
        final result = await _api.createPromotion(
          organizationId: _profile.id,
          title: title,
          type: type,
          description: description,
          startDate: startDate,
          endDate: endDate,
          isActive: isActive,
          showOnMap: showOnMap,
          isSponsored: isSponsored,
        );
        promo = promo.copyWith(id: result.id);
      } on ApiException {
        // Keep the promotion locally if the real API is unavailable.
      } catch (_) {
        // Keep the promotion locally if the real API is unavailable.
      }
    }
    _promotions = [promo, ..._promotions];
    _bumpAnalytics(impressions: promo.impressions, routes: promo.routeAdds);
    _lastSyncMessage = 'Урамшуулал нийтлэгдлээ.';
    await _save();
    notifyListeners();
  }

  Future<void> togglePromotion(String id) async {
    _promotions = [
      for (final promo in _promotions)
        if (promo.id == id) promo.copyWith(active: !promo.active) else promo,
    ];
    _lastSyncMessage = 'Урамшууллын төлөв шинэчлэгдлээ.';
    await _save();
    notifyListeners();
  }

  Future<void> refreshAnalytics() async {
    final activeBonus = max(1, activePromotions.length);
    _dailyViews = [
      ..._dailyViews.skip(1),
      _dailyViews.last + 7 + activeBonus * 3,
    ];
    _hourlyActivity = [
      for (var i = 0; i < _hourlyActivity.length; i++)
        _hourlyActivity[i] + (i.isEven ? activeBonus : activeBonus * 2),
    ];
    _promotions = [
      for (final promo in _promotions)
        if (promo.active)
          promo.copyWith(
            impressions: promo.impressions + 6,
            routeAdds: promo.routeAdds + 2,
          )
        else
          promo,
    ];
    _lastSyncMessage = 'Статистик шинэчлэгдлээ.';
    await _save();
    notifyListeners();
  }

  void clearMessage() {
    if (_lastSyncMessage == null && _errorMessage == null) return;
    _lastSyncMessage = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _save() async {
    final encoded = jsonEncode({
      'profile': _profile.toJson(),
      'promotions': _promotions.map((promo) => promo.toJson()).toList(),
      'dailyViews': _dailyViews,
      'hourlyActivity': _hourlyActivity,
    });
    await _storage.saveBusinessState(encoded);
  }

  void _seedAnalyticsFor(String name) {
    final seed = name.hashCode.abs();
    _dailyViews = List<int>.generate(7, (index) {
      return 32 + ((seed >> index) % 70) + index * 7;
    });
    _hourlyActivity = List<int>.generate(9, (index) {
      return 16 + ((seed >> (index + 1)) % 46) + index * 3;
    });
  }

  void _bumpAnalytics({required int impressions, required int routes}) {
    _dailyViews = [
      for (var i = 0; i < _dailyViews.length; i++)
        if (i == _dailyViews.length - 1)
          _dailyViews[i] + max(4, impressions ~/ 4)
        else
          _dailyViews[i],
    ];
    _hourlyActivity = [
      for (var i = 0; i < _hourlyActivity.length; i++)
        if (i >= 4 && i <= 6)
          _hourlyActivity[i] + routes
        else
          _hourlyActivity[i],
    ];
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  bool _isLocalId(String id) =>
      id.isEmpty || id.startsWith('local-') || id.startsWith('draft-');
}
