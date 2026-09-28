import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/rental_models.dart';
import '../services/property24_api.dart';

class Property24State extends ChangeNotifier {
  Property24State({Property24Api? api}) : _api = api ?? Property24Api() {
    _syncTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (signedIn && !_refreshing) refresh(silent: true);
    });
  }

  static const _tokenKey = 'property24.flutter.accessToken';
  static const _refreshTokenKey = 'property24.flutter.refreshToken';
  static const _darkModeKey = 'property24.flutter.darkMode';

  final Property24Api _api;
  Timer? _syncTimer;
  bool _refreshing = false;

  PlatformSnapshot snapshot = PlatformSnapshot.empty();
  AccountUser? user;
  AccountContext account = AccountContext.guest();
  String? _refreshToken;
  String? _token;
  bool loading = true;
  String? error;
  bool darkMode = false;
  String publicUsername = 'property24_member';
  String profileImageUrl = '';
  bool usernameVerified = false;
  final Set<String> savedPropertyIds = <String>{};
  final Set<String> comparisonPropertyIds = <String>{};
  final List<String> smartAlerts = <String>[];
  final List<String> notifications = <String>[];
  final List<ChatMessageDraft> localChatMessages = <ChatMessageDraft>[];
  List<CallLogItem> get callHistory => snapshot.calls;

  String? get token => _token;
  bool get signedIn => _token != null && user != null;
  bool get canManageListings =>
      account.capabilities.contains('add_properties') ||
      account.capabilities.contains('list_properties');

  int get verifiedProperties =>
      snapshot.properties.where((item) => item.verified).length;
  int get openMaintenance =>
      snapshot.maintenance.where((item) => item.status != 'Resolved').length;
  int get receivedPayments =>
      snapshot.payments.where((item) => item.status == 'Received').length;
  List<PropertyListing> get comparedProperties => snapshot.properties
      .where((property) => comparisonPropertyIds.contains(property.id))
      .toList(growable: false);

  Future<void> boot() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      _token = preferences.getString(_tokenKey);
      darkMode = preferences.getBool(_darkModeKey) ?? false;
      _refreshToken = preferences.getString(_refreshTokenKey);
      if (_token != null && _token!.isNotEmpty) {
        AuthSession session;
        try {
          session = await _api.me(_token!);
        } catch (exception) {
          if (!_isUnauthorized(exception)) rethrow;
          final restored = await _restoreSession();
          if (restored == null) rethrow;
          session = restored;
        }
        _applySession(session);
        try {
          snapshot = await _api.snapshot(token: _token);
        } catch (exception) {
          if (!_isVerificationGate(exception)) rethrow;
          await _loadVerificationSnapshot();
        }
      } else {
        snapshot = await _api.snapshot();
      }
    } catch (exception) {
      await _clearToken();
      user = null;
      account = AccountContext.guest();
      snapshot = await _api.snapshot();
      error = userFacingError(exception);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    error = null;
    if (!silent) notifyListeners();
    try {
      try {
        if (_token == null || _token!.isEmpty) {
          snapshot = await _api.snapshot();
        } else {
          final session = await _api.me(_token!);
          _applySession(session);
          snapshot = await _api.snapshot(token: _token);
        }
      } catch (exception) {
        if (_isUnauthorized(exception)) {
          final restored = await _restoreSession();
          if (restored == null) rethrow;
          _applySession(restored);
          snapshot = await _api.snapshot(token: _token);
        } else if (!_isVerificationGate(exception)) {
          rethrow;
        } else {
          await _loadVerificationSnapshot();
        }
      }
    } catch (exception) {
      error = userFacingError(exception);
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> signIn(
    String username,
    String password, {
    AccountRole? role,
  }) async {
    await _authenticate(
      () => _api.login(username: username, password: password, role: role),
    );
  }

  Future<void> signInWithGoogle(AccountRole role) async {
    await _authenticate(() async {
      final google = await _api.googleSignIn();
      return _api.loginWithGoogle(idToken: google, role: role);
    });
  }

  Future<String> register({
    required AccountRole role,
    required String name,
    required String email,
    required String password,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await _api.register(
        role: role,
        name: name,
        email: email,
        password: password,
      );
      return '${response['challenge_id']}';
    } catch (exception) {
      error = userFacingError(exception);
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> verifyRegistrationEmail(String challengeId, String code) async {
    final session = await _api.verifyRegistrationEmail(
      challengeId: challengeId,
      code: code,
    );
    await _storeSession(session);
    _applySession(session);
    try {
      snapshot = await _api.snapshot(token: session.token);
    } catch (_) {
      try {
        await _loadVerificationSnapshot();
      } catch (_) {
        snapshot = PlatformSnapshot.empty();
      }
    }
    notifyListeners();
  }

  Future<String> resendRegistrationEmail(String challengeId) {
    return _api.resendRegistrationEmail(challengeId);
  }

  Future<void> updateProfile({
    String? username,
    required String name,
    required String bio,
    String? profilePictureUrl,
    String? phone,
    Uint8List? profilePictureBytes,
    String? profilePictureName,
    String? profilePictureMimeType,
    bool removeProfilePicture = false,
  }) async {
    final activeToken = _requireToken();
    final hasUploadedPicture =
        profilePictureBytes != null && profilePictureBytes.isNotEmpty;
    final session = hasUploadedPicture || removeProfilePicture
        ? await _api.updateProfileMultipart(
            token: activeToken,
            username: username,
            name: name,
            bio: bio,
            phone: phone,
            profilePictureBytes: profilePictureBytes,
            profilePictureName: profilePictureName,
            profilePictureMimeType: profilePictureMimeType,
            removeProfilePicture: removeProfilePicture,
          )
        : await _api.updateProfile(
            token: activeToken,
            username: username,
            name: name,
            bio: bio,
            profilePictureUrl: profilePictureUrl,
            phone: phone,
          );
    user = session.user;

    account = session.account;
    publicUsername = session.user.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    profileImageUrl = session.user.profilePicture;
    usernameVerified = session.user.verified;
    notifyListeners();
  }

  Future<String> requestPhoneVerification() async {
    final activeToken = _requireToken();
    return _api.requestPhoneVerification(
      token: activeToken,
      phone: user?.phone ?? '',
    );
  }

  Future<void> verifyPhone(String challengeId, String code) async {
    final activeToken = _requireToken();
    final session = await _api.verifyPhone(
      token: activeToken,
      challengeId: challengeId,
      code: code,
    );
    user = session.user;

    account = session.account;
    notifyListeners();
  }

  Future<void> submitIdentityVerification({
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
    final activeToken = _requireToken();
    final activeUser = user;
    if (activeUser == null) {
      throw const ApiException('Sign in to verify your account.');
    }
    await _api.submitIdentityVerification(
      token: activeToken,
      role: activeUser.role.apiValue,
      name: activeUser.name,
      phone: activeUser.phone,
      phoneVerified: activeUser.phoneVerified,
      nationalIdNumber: nationalIdNumber,
      idFrontBytes: idFrontBytes,
      idFrontName: idFrontName,
      idFrontMimeType: idFrontMimeType,
      idBackBytes: idBackBytes,
      idBackName: idBackName,
      idBackMimeType: idBackMimeType,
      ownershipBytes: ownershipBytes,
      ownershipName: ownershipName,
      ownershipMimeType: ownershipMimeType,
      estateAgencyRegistration: estateAgencyRegistration,
      agencyName: agencyName,
      contactDetails: contactDetails,
    );
    final session = await _api.me(activeToken);
    user = session.user;

    account = session.account;
    snapshot = await _api.snapshot(token: activeToken);
    notifyListeners();
  }

  Future<void> _authenticate(Future<AuthSession> Function() request) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final session = await request();
      await _storeSession(session);
      _applySession(session);
      try {
        snapshot = await _api.snapshot(token: session.token);
      } catch (exception) {
        if (!_isVerificationGate(exception)) rethrow;
        await _loadVerificationSnapshot();
      }
    } catch (exception) {
      error = userFacingError(exception);
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _clearToken();
    user = null;
    account = AccountContext.guest();
    snapshot = await _api.snapshot();
    notifyListeners();
  }

  Future<PropertyListing> saveProperty(PropertyDraft draft,
      {String? propertyId}) async {
    final activeToken = _requireToken();
    loading = true;
    error = null;
    notifyListeners();
    try {
      final saved = propertyId == null
          ? await _api.createProperty(activeToken, draft)
          : await _api.updateProperty(activeToken, propertyId, draft);
      snapshot = await _api.snapshot(token: activeToken);
      return saved;
    } catch (exception) {
      error = userFacingError(exception);
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> deleteProperty(String propertyId) async {
    final activeToken = _requireToken();
    await _api.deleteProperty(activeToken, propertyId);
    snapshot = await _api.snapshot(token: activeToken);
    notifyListeners();
  }

  Future<void> requestViewing(PropertyListing property) async {
    final activeToken = _requireToken();
    await _api.requestViewing(activeToken, property.id);
    await refresh();
  }

  Future<void> submitApplication(PropertyListing property) async {
    final activeToken = _requireToken();
    await _api.submitApplication(activeToken, property.id);
    await refresh();
  }

  Future<ConversationItem> holdProperty(PropertyListing property) async {
    final activeToken = _requireToken();
    final conversation = await _api.holdProperty(activeToken, property.id);
    snapshot = await _api.snapshot(token: activeToken);
    notifyListeners();
    return conversation;
  }

  Future<void> uploadPropertyPhoto(String propertyId, XFile file) async {
    final activeToken = _requireToken();
    final bytes = await file.readAsBytes();
    await _api.uploadPropertyPhoto(
      token: activeToken,
      propertyId: propertyId,
      bytes: bytes,
      filename: file.name,
      mimeType: file.mimeType,
    );
  }

  Future<void> uploadPropertyVideo(String propertyId, XFile file) async {
    final activeToken = _requireToken();
    final bytes = await file.readAsBytes();
    await _api.uploadPropertyVideo(
      token: activeToken,
      propertyId: propertyId,
      bytes: bytes,
      filename: file.name,
      mimeType: file.mimeType,
    );
  }

  Future<void> sendMessageAttachment(
    String conversationId,
    XFile file,
    String attachmentType,
  ) async {
    final activeToken = _requireToken();
    final bytes = await file.readAsBytes();
    await _api.sendMessageAttachment(
      token: activeToken,
      conversationId: conversationId,
      bytes: bytes,
      filename: file.name,
      attachmentType: attachmentType,
      mimeType: file.mimeType,
    );
    addLocalChatMessage(file.name, _attachmentTypeFrom(attachmentType));
    await refresh();
  }

  AttachmentType _attachmentTypeFrom(String value) {
    return switch (value) {
      'image' => AttachmentType.image,
      'video' => AttachmentType.video,
      'audio' => AttachmentType.audio,
      _ => AttachmentType.none,
    };
  }

  Future<void> sendMessage(String conversationId, String body) async {
    final activeToken = _requireToken();
    await _api.sendMessage(activeToken, conversationId, body);
    await refresh();
  }

  Future<void> toggleSaved(PropertyListing property) async {
    final activeToken = _requireToken();
    final saved = !savedPropertyIds.contains(property.id);
    await _api.toggleSavedProperty(activeToken, property.id, saved: saved);
    if (saved) {
      savedPropertyIds.add(property.id);
    } else {
      savedPropertyIds.remove(property.id);
    }
    await refresh();
  }

  void toggleComparison(PropertyListing property) {
    if (comparisonPropertyIds.contains(property.id)) {
      comparisonPropertyIds.remove(property.id);
    } else {
      if (comparisonPropertyIds.length >= 3) {
        comparisonPropertyIds.remove(comparisonPropertyIds.first);
      }
      comparisonPropertyIds.add(property.id);
    }
    notifyListeners();
  }

  void addSmartAlert(String label) {
    if (!smartAlerts.contains(label)) {
      smartAlerts.add(label);
      notifyListeners();
    }
  }

  void toggleThemeMode(bool value) {
    darkMode = value;
    SharedPreferences.getInstance().then(
      (preferences) => preferences.setBool(_darkModeKey, value),
    );
    notifyListeners();
  }

  void updatePublicProfile({
    required String username,
    required String imageUrl,
  }) {
    publicUsername = username.trim().isEmpty ? publicUsername : username.trim();
    profileImageUrl = imageUrl.trim();
    usernameVerified =
        publicUsername.length >= 3 && !publicUsername.contains(' ');
    notifyListeners();
  }

  void addNotification(String notification) {
    notifications.insert(0, notification);
    notifyListeners();
  }

  void addLocalChatMessage(String body, AttachmentType attachmentType) {
    localChatMessages.add(
      ChatMessageDraft(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        body: body,
        mine: true,
        attachmentType: attachmentType,
      ),
    );
    notifyListeners();
  }

  void addLocalLocationMessage({
    required PropertyListing property,
    bool liveLocation = true,
  }) {
    if (!property.hasCoordinates) return;
    localChatMessages.add(
      ChatMessageDraft(
        id: 'location-${DateTime.now().microsecondsSinceEpoch}',
        body: liveLocation ? 'Live location' : property.heroLocation,
        mine: true,
        attachmentType: AttachmentType.location,
        latitude: property.latitude,
        longitude: property.longitude,
        locationLabel: property.address.isNotEmpty
            ? property.address
            : property.heroLocation,
        liveLocation: liveLocation,
      ),
    );
    notifyListeners();
  }

  void updateLocalChatMessage(String id, String body) {
    final index = localChatMessages.indexWhere((message) => message.id == id);
    if (index == -1) return;
    localChatMessages[index] = localChatMessages[index].copyWith(body: body);
    notifyListeners();
  }

  void deleteLocalChatMessage(String id) {
    localChatMessages.removeWhere((message) => message.id == id);
    notifyListeners();
  }

  void recordCall({
    required PropertyListing property,
    required CallMode mode,
  }) {
    callHistory.insert(
      0,
      CallLogItem(
        name: property.supplier?.name ?? 'Listing contact',
        property: property.title,
        mode: mode,
        direction: 'Outgoing',
        when: 'Just now',
      ),
    );
    notifyListeners();
  }

  String _requireToken() {
    final activeToken = _token;
    if (activeToken == null || activeToken.isEmpty) {
      throw const ApiException('Sign in is required for this action.');
    }
    return activeToken;
  }

  Future<void> _clearToken() async {
    _token = null;
    _refreshToken = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_refreshTokenKey);
  }

  Future<void> _storeSession(AuthSession session) async {
    _token = session.token;
    if (session.refreshToken != null && session.refreshToken!.isNotEmpty) {
      _refreshToken = session.refreshToken;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, session.token);
    if (_refreshToken != null && _refreshToken!.isNotEmpty) {
      await preferences.setString(_refreshTokenKey, _refreshToken!);
    }
  }

  Future<AuthSession?> _restoreSession() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return null;
    final session = await _api.refresh(refreshToken);
    await _storeSession(session);
    return session;
  }

  bool _isUnauthorized(Object exception) {
    return exception is ApiException && exception.statusCode == 401;
  }

  void _applySession(AuthSession session) {
    user = session.user;
    account = session.account;
    publicUsername = session.user.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r"^_|_$"), '');
    profileImageUrl = session.user.profilePicture;
    usernameVerified = session.user.verified;
  }

  Future<void> _loadVerificationSnapshot() async {
    final publicSnapshot = await _api.snapshot();
    final properties = await _api.searchProperties(token: _token);
    snapshot = PlatformSnapshot(
      properties: properties,
      payments: publicSnapshot.payments,
      maintenance: publicSnapshot.maintenance,
      leases: publicSnapshot.leases,
      applications: publicSnapshot.applications,
      verifications: publicSnapshot.verifications,
      conversations: publicSnapshot.conversations,
      viewings: publicSnapshot.viewings,
      calls: publicSnapshot.calls,
      savedProperties: publicSnapshot.savedProperties,
    );
  }

  bool _isVerificationGate(Object exception) {
    return exception is ApiException &&
        exception.statusCode == 403 &&
        user != null &&
        !user!.accountOnboardingComplete;
  }
}

enum AttachmentType { none, image, video, audio, location }

class ChatMessageDraft {
  const ChatMessageDraft({
    required this.id,
    required this.body,
    required this.mine,
    required this.attachmentType,
    this.latitude,
    this.longitude,
    this.locationLabel = '',
    this.liveLocation = false,
  });

  final String id;
  final String body;
  final bool mine;
  final AttachmentType attachmentType;
  final num? latitude;
  final num? longitude;
  final String locationLabel;
  final bool liveLocation;

  ChatMessageDraft copyWith({String? body}) {
    return ChatMessageDraft(
      id: id,
      body: body ?? this.body,
      mine: mine,
      attachmentType: attachmentType,
      latitude: latitude,
      longitude: longitude,
      locationLabel: locationLabel,
      liveLocation: liveLocation,
    );
  }
}
