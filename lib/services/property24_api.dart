import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../models/rental_models.dart';

class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
    required this.account,
  });

  final String token;
  final AccountUser user;
  final AccountContext account;
}

class PropertyDraft {
  const PropertyDraft({
    required this.title,
    required this.address,
    required this.city,
    required this.suburb,
    required this.monthlyRent,
    required this.depositRequired,
    required this.propertyType,
    required this.bedrooms,
    required this.bathrooms,
    required this.description,
    this.waterAvailability = 'Available',
    this.parking = 'Parking available',
    this.furnished = false,
    this.solarPower = false,
    this.borehole = false,
    this.petFriendly = false,
    this.has360Tour = false,
  });

  final String title;
  final String address;
  final String city;
  final String suburb;
  final String monthlyRent;
  final String depositRequired;
  final String propertyType;
  final int bedrooms;
  final num bathrooms;
  final String description;
  final String waterAvailability;
  final String parking;
  final bool furnished;
  final bool solarPower;
  final bool borehole;
  final bool petFriendly;
  final bool has360Tour;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'address': address,
      'city': city,
      'suburb': suburb,
      'monthly_rent': monthlyRent.replaceAll(RegExp(r'[^0-9.]'), ''),
      'deposit_required': depositRequired.replaceAll(RegExp(r'[^0-9.]'), ''),
      'property_type': propertyType.toLowerCase().replaceAll(' ', '_'),
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'description': description,
      'water_availability': waterAvailability,
      'parking': parking,
      'furnished': furnished,
      'solar_power': solarPower,
      'borehole': borehole,
      'pet_friendly': petFriendly,
      'has_360_tour': has360Tour,
    };
  }
}

class Property24Api {
  Property24Api({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final body = await _post(
      'auth/login/',
      body: {'username': username, 'password': password},
    );
    return _authSessionFromBody(body);
  }

  Future<AuthSession> register({
    required AccountRole role,
    required String name,
    required String email,
    required String password,
  }) async {
    await _post(
      'auth/register/',
      body: {
        'account_type': role.apiValue,
        'name': name,
        'email': email,
        'username': email,
        'password': password,
      },
    );
    return login(username: email, password: password);
  }

  Future<AuthSession> me(String token) async {
    final body = await _get('auth/me/', token: token);
    return AuthSession(
      token: token,
      user: AccountUser.fromJson(
        body['user'] as Map<String, dynamic>,
        body['account'] as Map<String, dynamic>?,
      ),
      account: AccountContext.fromJson(body['account'] as Map<String, dynamic>),
    );
  }

  Future<PlatformSnapshot> snapshot({String? token}) async {
    final propertiesResponse = await _get('properties/', token: token);
    final properties =
        _results(propertiesResponse).map(PropertyListing.fromJson).toList();

    if (token == null || token.isEmpty) {
      return PlatformSnapshot.empty().copyWith(properties: properties);
    }

    final responses = await Future.wait([
      _get('payments/', token: token),
      _get('maintenance/', token: token),
      _get('leases/', token: token),
      _get('applications/', token: token),
      _get('verifications/', token: token),
      _get('conversations/', token: token),
    ]);

    return PlatformSnapshot(
      properties: properties,
      payments: _results(responses[0]).map(PaymentItem.fromJson).toList(),
      maintenance:
          _results(responses[1]).map(MaintenanceItem.fromJson).toList(),
      leases: _results(responses[2]).map(LeaseItem.fromJson).toList(),
      applications:
          _results(responses[3]).map(ApplicationItem.fromJson).toList(),
      verifications:
          _results(responses[4]).map(VerificationItem.fromJson).toList(),
      conversations:
          _results(responses[5]).map(ConversationItem.fromJson).toList(),
    );
  }

  Future<List<PropertyListing>> searchProperties({
    String? query,
    String? city,
    String? suburb,
    String? type,
  }) async {
    final response = await _get(
      'properties/',
      query: {
        'search': query,
        'city': city,
        'suburb': suburb,
        'type': type,
      },
    );
    return _results(response).map(PropertyListing.fromJson).toList();
  }

  Future<PropertyListing> createProperty(
      String token, PropertyDraft draft) async {
    final body = await _post('properties/', token: token, body: draft.toJson());
    return PropertyListing.fromJson(body);
  }

  Future<PropertyListing> updateProperty(
    String token,
    String propertyId,
    PropertyDraft draft,
  ) async {
    final body = await _patch('properties/$propertyId/',
        token: token, body: draft.toJson());
    return PropertyListing.fromJson(body);
  }

  Future<void> deleteProperty(String token, String propertyId) async {
    await _delete('properties/$propertyId/', token: token);
  }

  Future<void> requestViewing(String token, String propertyId) async {
    await _post(
      'viewings/',
      token: token,
      body: {
        'property_id': propertyId,
        'scheduled_for':
            DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'notes': 'Tenant requested a physical viewing from the Flutter app.',
      },
    );
  }

  Future<void> submitApplication(String token, String propertyId) async {
    await _post(
      'applications/',
      token: token,
      body: {
        'property_id': propertyId,
        'message': 'Tenant application submitted from the Flutter app.',
      },
    );
  }

  Future<ConversationItem> startConversation(
      String token, String propertyId) async {
    final body = await _post(
      'conversations/',
      token: token,
      body: {'property_id': propertyId},
    );
    return ConversationItem.fromJson(body);
  }

  Future<void> sendMessage(
      String token, String conversationId, String body) async {
    await _post(
      'conversations/$conversationId/messages/',
      token: token,
      body: {
        'body': body,
        'client_message_id': 'flutter-${DateTime.now().microsecondsSinceEpoch}',
      },
    );
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    String? token,
    Map<String, String?> query = const {},
  }) async {
    final response = await _client.get(AppConfig.apiUri(path, query),
        headers: _headers(token));
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    String? token,
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.post(
      AppConfig.apiUri(path),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _patch(
    String path, {
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.patch(
      AppConfig.apiUri(path),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<void> _delete(String path, {required String token}) async {
    final response =
        await _client.delete(AppConfig.apiUri(path), headers: _headers(token));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
    }
  }

  Map<String, String> _headers(String? token) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final text = response.body.trim();
    final body = text.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(text) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final errors = body['errors'];
    final message = errors is List && errors.isNotEmpty
        ? errors.join('\n')
        : '${body['error'] ?? 'API request failed'}';
    throw ApiException(message, response.statusCode);
  }

  AuthSession _authSessionFromBody(Map<String, dynamic> body) {
    final tokens = body['tokens'] as Map<String, dynamic>?;
    final token = '${tokens?['access'] ?? ''}';
    if (token.isEmpty) {
      throw const ApiException(
          'The account service did not return an access token.');
    }
    return AuthSession(
      token: token,
      user: AccountUser.fromJson(
        body['user'] as Map<String, dynamic>,
        body['account'] as Map<String, dynamic>?,
      ),
      account: body['account'] is Map<String, dynamic>
          ? AccountContext.fromJson(body['account'] as Map<String, dynamic>)
          : AccountContext.guest(),
    );
  }

  List<Map<String, dynamic>> _results(Map<String, dynamic> response) {
    return (response['results'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }
}

extension on PlatformSnapshot {
  PlatformSnapshot copyWith({
    List<PropertyListing>? properties,
    List<PaymentItem>? payments,
    List<MaintenanceItem>? maintenance,
    List<LeaseItem>? leases,
    List<ApplicationItem>? applications,
    List<VerificationItem>? verifications,
    List<ConversationItem>? conversations,
  }) {
    return PlatformSnapshot(
      properties: properties ?? this.properties,
      payments: payments ?? this.payments,
      maintenance: maintenance ?? this.maintenance,
      leases: leases ?? this.leases,
      applications: applications ?? this.applications,
      verifications: verifications ?? this.verifications,
      conversations: conversations ?? this.conversations,
    );
  }
}
