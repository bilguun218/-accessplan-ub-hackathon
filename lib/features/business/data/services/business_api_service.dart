import '../../../../core/network/api_client.dart';
import '../models/business_models.dart';

class OrganizationSubmissionResult {
  final String id;
  final String status;

  const OrganizationSubmissionResult({required this.id, required this.status});
}

class BusinessPostSubmissionResult {
  final String id;
  final String status;

  const BusinessPostSubmissionResult({required this.id, required this.status});
}

class BusinessApiService {
  final ApiClient _client;

  BusinessApiService(this._client);

  Future<OrganizationSubmissionResult> submitOrganizationRequest(
    BusinessProfile profile,
  ) async {
    try {
      final response = await _client.dio.post(
        '/organizations/requests',
        data: {
          'organizationName': profile.organizationName,
          'activityType': profile.activityType,
          'registrationNumber': profile.registrationNumber,
          'location': profile.location,
          'contactPerson': profile.contactPerson,
          'phone': profile.phone,
          'email': profile.email,
          'description': profile.description,
          'verificationMethod': profile.verificationMethod,
        },
      );
      final request = Map<String, dynamic>.from(
        response.data['request'] as Map,
      );
      return OrganizationSubmissionResult(
        id: request['id'].toString(),
        status: (request['status'] ?? 'pending').toString(),
      );
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  Future<BusinessProfile> createOrganization(BusinessProfile profile) async {
    try {
      final response = await _client.dio.post(
        '/organizations',
        data: _organizationPayload(profile),
      );
      final organization = Map<String, dynamic>.from(
        response.data['organization'] as Map,
      );
      return BusinessProfile.fromJson(organization);
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  Future<BusinessProfile> updateOrganization(BusinessProfile profile) async {
    try {
      final response = await _client.dio.put(
        '/organizations/${profile.id}',
        data: _organizationPayload(profile),
      );
      final organization = Map<String, dynamic>.from(
        response.data['organization'] as Map,
      );
      return BusinessProfile.fromJson(organization);
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  Future<BusinessPostSubmissionResult> createPromotion({
    required String organizationId,
    required String title,
    required String type,
    required String description,
    required String startDate,
    required String endDate,
    required bool isActive,
    required bool showOnMap,
    required bool isSponsored,
  }) async {
    try {
      final response = await _client.dio.post(
        '/organizations/$organizationId/posts',
        data: {
          'title': title,
          'description': description,
          'type': _postTypeValue(type),
          'startsAt': _dateOrNull(startDate),
          'endsAt': _dateOrNull(endDate),
          'isActive': isActive,
          'showOnMap': showOnMap,
          'isSponsored': isSponsored,
        },
      );
      final post = Map<String, dynamic>.from(response.data['post'] as Map);
      return BusinessPostSubmissionResult(
        id: post['id'].toString(),
        status: (post['isActive'] as bool? ?? true) ? 'active' : 'inactive',
      );
    } catch (error) {
      throw _client.toApiException(error);
    }
  }

  Map<String, dynamic> _organizationPayload(BusinessProfile profile) => {
    'businessName': profile.organizationName,
    'branchName': profile.branchName,
    'serviceType': _serviceTypeValue(profile.activityType),
    'description': profile.description,
    'address': profile.location,
    'latitude': profile.latitude,
    'longitude': profile.longitude,
    'phone': profile.phone,
    'email': profile.email,
    'website': profile.website,
    'workingHours': profile.hours.map((hour) => hour.toJson()).toList(),
    'parkingAvailable': profile.hasParking,
    'accessibilityAvailable': profile.wheelchairAccessible,
    'digitalServicesAvailable': profile.onlineService,
    'status': 'active',
  };

  String _serviceTypeValue(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return 'general';
    if (normalized.contains('coffee') ||
        normalized.contains('cafe') ||
        normalized.contains('кофе')) {
      return 'coffee_shop';
    }
    if (normalized.contains('pharmacy') || normalized.contains('эмийн')) {
      return 'pharmacy';
    }
    if (normalized.contains('bank') || normalized.contains('банк')) {
      return 'bank';
    }
    if (normalized.contains('restaurant') || normalized.contains('хоол')) {
      return 'restaurant';
    }
    return normalized.replaceAll(RegExp(r'\s+'), '_');
  }

  String _postTypeValue(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'discount' ||
        normalized.contains('хямд') ||
        normalized.contains('discount')) {
      return 'discount';
    }
    if (normalized == 'announcement' ||
        normalized.contains('зар') ||
        normalized.contains('announcement')) {
      return 'announcement';
    }
    if (normalized == 'event' || normalized.contains('event')) {
      return 'event';
    }
    if (normalized == 'service_update' ||
        normalized == 'serviceupdate' ||
        normalized.contains('service')) {
      return 'service_update';
    }
    if (normalized == 'general') return 'general';
    return 'promotion';
  }

  String? _dateOrNull(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = DateTime.tryParse(trimmed);
    return parsed?.toIso8601String();
  }
}
