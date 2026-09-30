import 'dart:convert';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../core/config.dart';
import '../models/rental_models.dart';

class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

String userFacingError(Object error) {
  if (error is ApiException) {
    return switch (error.statusCode) {
      400 || 403 || 404 || 409 || 429 => error.message,
      401 => 'Your session has expired. Please sign in again.',
      500 ||
      502 ||
      503 =>
        'The service is temporarily unavailable. Please try again later.',
      _ => 'Something went wrong. Please try again.',
    };
  }
  return 'Something went wrong. Please try again.';
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
    this.refreshToken,
    required this.account,
  });

  final String token;
  final AccountUser user;
  final AccountContext account;
  final String? refreshToken;
}

class PropertyDraft {
  const PropertyDraft({
    required this.title,
    required this.address,
    required this.city,
    required this.suburb,
    this.latitude,
    this.longitude,
    this.showExactLocation = false,
    this.listingIntent = 'rent',
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
    this.standReference = '',
    this.standsAvailable = 1,
    this.landSize = '',
    this.landSizeUnit = 'sqm',
    this.titleDeedStatus = 'not_provided',
    this.servicingStatus = 'not_serviced',
    this.zoning = '',
    this.roadAccess = '',
    this.electricityAvailable = false,
    this.landWaterAvailable = false,
    this.paymentTerms = '',
  });

  final String title;
  final String address;
  final String city;
  final String suburb;
  final String? latitude;
  final String? longitude;
  final bool showExactLocation;
  final String listingIntent;
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
  final String standReference;
  final int standsAvailable;
  final String landSize;
  final String landSizeUnit;
  final String titleDeedStatus;
  final String servicingStatus;
  final String zoning;
  final String roadAccess;
  final bool electricityAvailable;
  final bool landWaterAvailable;
  final String paymentTerms;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'address': address,
      'city': city,
      'suburb': suburb,
      if (latitude != null && latitude!.trim().isNotEmpty)
        'latitude': latitude!.trim(),
      if (longitude != null && longitude!.trim().isNotEmpty)
        'longitude': longitude!.trim(),
      'show_exact_location': showExactLocation,
      'listing_intent': listingIntent,
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
      'stand_reference': standReference,
      'stands_available': standsAvailable,
      if (landSize.trim().isNotEmpty)
        'land_size': landSize.replaceAll(RegExp(r'[^0-9.]'), ''),
      'land_size_unit': landSizeUnit,
      'title_deed_status': titleDeedStatus,
      'servicing_status': servicingStatus,
      'zoning': zoning,
      'road_access': roadAccess,
      'electricity_available': electricityAvailable,
      'land_water_available': landWaterAvailable,
      'payment_terms': paymentTerms,
    };
  }
}

class Property24Api {
  Property24Api({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> googleSignIn() async {
    final account = await GoogleSignIn().signIn();
    if (account == null) {
      throw const ApiException('Google sign-in was cancelled');
    }
    final authentication = await account.authentication;
    final idToken = authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const ApiException('Google did not return an ID token');
    }
    return idToken;
  }

  Future<AuthSession> login({
    required String username,
    required String password,
    AccountRole? role,
  }) async {
    final body = await _post(
      'auth/login/',
      body: {
        'username': username,
        'password': password,
        if (role != null) 'account_type': role.apiValue,
      },
    );
    return _authSessionFromBody(body);
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final body = await _post(
      'auth/refresh/',
      body: {'refresh': refreshToken},
    );
    return _authSessionFromBody(body);
  }

  Future<Map<String, dynamic>> register({
    required AccountRole role,
    required String name,
    required String email,
    required String password,
  }) async {
    return _post(
      'auth/register/',
      body: {
        'account_type': role.apiValue,
        'name': name,
        'email': email,
        'username': email,
        'password': password,
      },
    );
  }

  Future<AuthSession> verifyRegistrationEmail({
    required String challengeId,
    required String code,
  }) async {
    final body = await _post(
      'auth/register/verify/',
      body: {'challenge_id': challengeId, 'code': code},
    );
    return _authSessionFromBody(body);
  }

  Future<String> resendRegistrationEmail(String challengeId) async {
    final body = await _post(
      'auth/register/resend/',
      body: {'challenge_id': challengeId},
    );
    return '${body['challenge_id']}';
  }

  Future<AuthSession> loginWithGoogle({
    required String idToken,
    required AccountRole role,
  }) async {
    final body = await _post(
      'auth/google/',
      body: {
        'id_token': idToken,
        'account_type': role.apiValue,
      },
    );
    return _authSessionFromBody(body);
  }

  Future<AuthSession> updateProfile({
    required String token,
    String? username,
    String? name,
    String? bio,
    String? profilePictureUrl,
    String? phone,
  }) async {
    final body = await _patch(
      'auth/profile/',
      token: token,
      body: {
        if (username != null) 'username': username,
        if (name != null) 'name': name,
        if (bio != null) 'bio': bio,
        if (profilePictureUrl != null) 'profile_picture_url': profilePictureUrl,
        if (phone != null) 'phone': phone,
      },
    );
    return AuthSession(
      token: token,
      user: AccountUser.fromJson(
        body['user'] as Map<String, dynamic>,
        body['account'] as Map<String, dynamic>?,
      ),
      account: AccountContext.fromJson(body['account'] as Map<String, dynamic>),
    );
  }

  Future<AuthSession> updateProfileMultipart({
    required String token,
    String? username,
    String? name,
    String? bio,
    String? phone,
    Uint8List? profilePictureBytes,
    String? profilePictureName,
    String? profilePictureMimeType,
    bool removeProfilePicture = false,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      AppConfig.apiUri('auth/profile/'),
    );
    request.headers.addAll(_multipartHeaders(token));
    void addField(String key, String? value) {
      if (value != null) request.fields[key] = value;
    }

    addField('username', username);
    addField('name', name);
    addField('bio', bio);
    addField('phone', phone);
    if (removeProfilePicture) {
      request.fields['remove_profile_picture'] = 'true';
    }
    if (profilePictureBytes != null && profilePictureBytes.isNotEmpty) {
      final filename = _safeFilename(profilePictureName, 'profile-picture.jpg');
      request.files.add(
        http.MultipartFile.fromBytes(
          'profile_picture',
          profilePictureBytes,
          filename: filename,
          contentType: _mediaTypeFor(profilePictureMimeType, filename),
        ),
      );
    }

    final response = await http.Response.fromStream(await request.send());
    final body = _decode(response);
    return AuthSession(
      token: token,
      user: AccountUser.fromJson(
        body['user'] as Map<String, dynamic>,
        body['account'] as Map<String, dynamic>?,
      ),
      account: AccountContext.fromJson(body['account'] as Map<String, dynamic>),
    );
  }

  Future<String> requestPhoneVerification({
    required String token,
    required String phone,
  }) async {
    final body = await _post(
      'verifications/phone-otp/',
      token: token,
      body: {'phone': phone},
    );
    return '${body['challenge_id']}';
  }

  Future<AuthSession> verifyPhone({
    required String token,
    required String challengeId,
    required String code,
  }) async {
    final body = await _post(
      'verifications/phone-otp/verify/',
      token: token,
      body: {'challenge_id': challengeId, 'code': code},
    );
    return AuthSession(
      token: token,
      user: AccountUser.fromJson(
        body['user'] as Map<String, dynamic>,
        body['account'] as Map<String, dynamic>?,
      ),
      account: AccountContext.fromJson(body['account'] as Map<String, dynamic>),
    );
  }

  Future<VerificationItem> submitIdentityVerification({
    required String token,
    required String role,
    required String name,
    required String phone,
    required String nationalIdNumber,
    required Uint8List idFrontBytes,
    required String idFrontName,
    required String idFrontMimeType,
    required Uint8List idBackBytes,
    required String idBackName,
    required String idBackMimeType,
    Uint8List? ownershipBytes,
    String? ownershipName,
    String? ownershipMimeType,
    String? estateAgencyRegistration,
    String? agencyName,
    String? contactDetails,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      AppConfig.apiUri('verifications/'),
    );
    request.headers.addAll(_multipartHeaders(token));
    request.fields.addAll({
      'role': role,
      'name': name,
      'phone': phone,
      'document_type': 'identity_document',
      'national_id_number': nationalIdNumber,
      'identity_confirmed': 'true',
      'privacy_notice_accepted': 'true',
      'declaration_accepted': 'true',
      if (estateAgencyRegistration?.trim().isNotEmpty == true)
        'estate_agency_registration': estateAgencyRegistration!.trim(),
      if (agencyName?.trim().isNotEmpty == true)
        'agency_name': agencyName!.trim(),
      if (contactDetails?.trim().isNotEmpty == true)
        'contact_details': contactDetails!.trim(),
    });
    request.files.add(
      http.MultipartFile.fromBytes(
        'id_front_document',
        idFrontBytes,
        filename: _safeFilename(idFrontName, 'id-front.jpg'),
        contentType: _mediaTypeFor(idFrontMimeType, idFrontName),
      ),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'id_back_document',
        idBackBytes,
        filename: _safeFilename(idBackName, 'id-back.jpg'),
        contentType: _mediaTypeFor(idBackMimeType, idBackName),
      ),
    );
    if (ownershipBytes != null && ownershipBytes.isNotEmpty) {
      final filename = _safeFilename(ownershipName, 'ownership.jpg');
      request.files.add(
        http.MultipartFile.fromBytes(
          'ownership_or_authorization_document',
          ownershipBytes,
          filename: filename,
          contentType: _mediaTypeFor(ownershipMimeType, filename),
        ),
      );
    }
    final response = await http.Response.fromStream(await request.send());
    return VerificationItem.fromJson(_decode(response));
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
      _get('calls/', token: token),
      _get('viewings/', token: token),
      _get('saved-properties/', token: token),
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
      calls: _results(responses[6]).map(CallLogItem.fromJson).toList(),
      viewings: _results(responses[7]).map(ViewingItem.fromJson).toList(),
      savedProperties:
          _results(responses[8]).map(PropertyListing.fromJson).toList(),
    );
  }

  Future<List<PropertyListing>> searchProperties({
    String? token,
    String? query,
    String? city,
    String? suburb,
    String? type,
  }) async {
    final response = await _get(
      'properties/',
      token: token,
      query: {
        'search': query,
        'city': city,
        'suburb': suburb,
        'type': type,
      },
    );
    return _results(response).map(PropertyListing.fromJson).toList();
  }

  Future<AiSearchResponse> aiPropertySearch({
    String? token,
    required String query,
  }) async {
    final body = await _post(
      'ai/property-search/',
      token: token,
      body: {'query': query},
    );
    return AiSearchResponse.fromJson(body);
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

  Future<PropertyListing> confirmPropertyAvailability(
    String token,
    String propertyId, {
    String action = 'available',
  }) async {
    final body = await _post(
      'properties/$propertyId/availability/',
      token: token,
      body: {'action': action},
    );
    return PropertyListing.fromJson(body);
  }

  Future<void> deleteProperty(String token, String propertyId) async {
    await _delete('properties/$propertyId/', token: token);
  }

  Future<void> toggleSavedProperty(
    String token,
    String propertyId, {
    required bool saved,
  }) async {
    final path = 'properties/$propertyId/save/';
    if (saved) {
      await _post(path, token: token, body: const {});
    } else {
      await _delete(path, token: token);
    }
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

  Future<CallLogItem> startCall(
    String token,
    String conversationId, {
    required CallMode mode,
  }) async {
    final body = await _post(
      'conversations/$conversationId/calls/',
      token: token,
      body: {'mode': mode.name},
    );
    return CallLogItem.fromJson(body);
  }

  Future<CallLogItem> endCall(
    String token,
    String conversationId,
    String callId, {
    String status = 'ended',
  }) async {
    final body = await _patch(
      'conversations/$conversationId/calls/$callId/',
      token: token,
      body: {'status': status},
    );
    return CallLogItem.fromJson(body);
  }

  Future<ConversationItem> holdProperty(String token, String propertyId) async {
    final body = await _post(
      'properties/$propertyId/hold/',
      token: token,
      body: const {},
    );
    return ConversationItem.fromJson(
        body['conversation'] as Map<String, dynamic>);
  }

  Future<PropertyListing> uploadPropertyPhoto({
    required String token,
    required String propertyId,
    required Uint8List bytes,
    required String filename,
    String? mimeType,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      AppConfig.apiUri('properties/$propertyId/photos/'),
    )
      ..headers.addAll(_multipartHeaders(token))
      ..fields['caption'] = filename
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: filename,
        contentType: _mediaTypeFor(mimeType, filename),
      ));
    final response = await http.Response.fromStream(await request.send());
    _decode(response);
    return PropertyListing.fromJson(
      await _get('properties/$propertyId/', token: token),
    );
  }

  Future<PropertyListing> uploadPropertyVideo({
    required String token,
    required String propertyId,
    required Uint8List bytes,
    required String filename,
    String? mimeType,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      AppConfig.apiUri('properties/$propertyId/videos/'),
    )
      ..headers.addAll(_multipartHeaders(token))
      ..fields['caption'] = filename
      ..files.add(http.MultipartFile.fromBytes(
        'video',
        bytes,
        filename: filename,
        contentType: _mediaTypeFor(mimeType, filename),
      ));
    final response = await http.Response.fromStream(await request.send());
    _decode(response);
    return PropertyListing.fromJson(
      await _get('properties/$propertyId/', token: token),
    );
  }

  Future<Map<String, dynamic>> sendMessageAttachment({
    required String token,
    required String conversationId,
    required Uint8List bytes,
    required String filename,
    required String attachmentType,
    String? mimeType,
    String body = '',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      AppConfig.apiUri('conversations/$conversationId/messages/'),
    )
      ..headers.addAll(_multipartHeaders(token))
      ..fields['body'] = body
      ..fields['attachment_type'] = attachmentType
      ..fields['attachment_name'] = filename
      ..fields['client_message_id'] =
          'flutter-media-${DateTime.now().microsecondsSinceEpoch}'
      ..files.add(http.MultipartFile.fromBytes(
        'attachment',
        bytes,
        filename: filename,
        contentType: _mediaTypeFor(mimeType, filename),
      ));
    final response = await http.Response.fromStream(await request.send());
    return _decode(response);
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

  Future<List<ChatMessageItem>> conversationMessages(
    String token,
    String conversationId,
  ) async {
    final body = await _get(
      'conversations/$conversationId/messages/',
      token: token,
    );
    return _results(body).map(ChatMessageItem.fromJson).toList();
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

  Map<String, String> _multipartHeaders(String token) {
    return {
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  MediaType _mediaTypeFor(String? mimeType, String filename) {
    final cleanMime = (mimeType ?? '').split(';').first.trim().toLowerCase();
    if (cleanMime.contains('/')) {
      final parts = cleanMime.split('/');
      return MediaType(parts.first, parts.last);
    }
    final lowerName = filename.toLowerCase();
    if (lowerName.endsWith('.png')) return MediaType('image', 'png');
    if (lowerName.endsWith('.webp')) return MediaType('image', 'webp');
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    return MediaType('image', 'jpeg');
  }

  String _safeFilename(String? value, String fallback) {
    final clean = (value?.trim().isNotEmpty == true ? value!.trim() : fallback)
        .replaceAll(RegExp(r'[/\\]'), '_');
    return clean.isEmpty ? fallback : clean;
  }

  Map<String, dynamic> _decode(http.Response response) {
    final text = response.body.trim();
    late final Map<String, dynamic> body;
    try {
      final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      if (decoded is! Map) throw const FormatException();
      body = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw ApiException(
        response.statusCode >= 200 && response.statusCode < 300
            ? 'The server returned an invalid response. Please try again.'
            : 'The server returned an invalid error response (${response.statusCode}).',
        response.statusCode,
      );
    }
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
      refreshToken: '${tokens?['refresh'] ?? ''}'.trim().isEmpty
          ? null
          : '${tokens?['refresh']}'.trim(),
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
    List<ViewingItem>? viewings,
    List<CallLogItem>? calls,
    List<PropertyListing>? savedProperties,
  }) {
    return PlatformSnapshot(
      properties: properties ?? this.properties,
      payments: payments ?? this.payments,
      maintenance: maintenance ?? this.maintenance,
      leases: leases ?? this.leases,
      applications: applications ?? this.applications,
      verifications: verifications ?? this.verifications,
      conversations: conversations ?? this.conversations,
      viewings: viewings ?? this.viewings,
      calls: calls ?? this.calls,
      savedProperties: savedProperties ?? this.savedProperties,
    );
  }
}
