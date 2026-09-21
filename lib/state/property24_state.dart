import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/rental_models.dart';
import '../services/property24_api.dart';

class Property24State extends ChangeNotifier {
  Property24State({Property24Api? api}) : _api = api ?? Property24Api();

  static const _tokenKey = 'property24.flutter.accessToken';

  final Property24Api _api;

  PlatformSnapshot snapshot = PlatformSnapshot.empty();
  AccountUser? user;
  AccountContext account = AccountContext.guest();
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
      if (_token != null && _token!.isNotEmpty) {
        final session = await _api.me(_token!);
        user = session.user;
        account = session.account;
        publicUsername = session.user.name
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'_+'), '_')
            .replaceAll(RegExp(r'^_|_$'), '');
        profileImageUrl = session.user.profilePicture;
        usernameVerified = session.user.verified;
      }
      snapshot = await _api.snapshot(token: _token);
    } catch (exception) {
      await _clearToken();
      snapshot = await _api.snapshot();
      error = userFacingError(exception);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    error = null;
    notifyListeners();
    try {
      snapshot = await _api.snapshot(token: _token);
    } catch (exception) {
      error = userFacingError(exception);
    } finally {
      notifyListeners();
    }
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
    await _api.verifyRegistrationEmail(
      challengeId: challengeId,
      code: code,
    );
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
      _token = session.token;
      user = session.user;
      account = session.account;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_tokenKey, session.token);
      snapshot = await _api.snapshot(token: session.token);
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

  Future<void> saveProperty(PropertyDraft draft, {String? propertyId}) async {
    final activeToken = _requireToken();
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (propertyId == null) {
        await _api.createProperty(activeToken, draft);
      } else {
        await _api.updateProperty(activeToken, propertyId, draft);
      }
      snapshot = await _api.snapshot(token: activeToken);
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
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
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
