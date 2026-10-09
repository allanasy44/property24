import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config.dart';

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
  WebSocketChannel? _liveChannel;
  StreamSubscription<dynamic>? _liveSubscription;
  Timer? _liveReconnectTimer;
  Timer? _syncTimer;
  final Map<String, int> _conversationRevisions = <String, int>{};
  final Map<String, String> _typingUsers = <String, String>{};
  final Map<String, CallLogItem> _activeCalls = <String, CallLogItem>{};
  final Map<String, PropertyListing> _changedProperties =
      <String, PropertyListing>{};
  String? _localActiveCallId;
  final StreamController<Map<String, dynamic>> _callEvents =
      StreamController<Map<String, dynamic>>.broadcast();
  bool _refreshing = false;
  bool _refreshPending = false;

  PlatformSnapshot snapshot = PlatformSnapshot.empty();
  List<PropertyListing> followedProperties = <PropertyListing>[];
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

  int conversationRevision(String conversationId) =>
      _conversationRevisions[conversationId] ?? 0;
  String? typingUserForConversation(String conversationId) =>
      _typingUsers[conversationId];
  CallLogItem? activeCallForConversation(String conversationId) =>
      _activeCalls[conversationId];
  bool get hasLocalActiveCall => _localActiveCallId != null;
  Stream<Map<String, dynamic>> get callEvents => _callEvents.stream;
  List<CallLogItem> get callHistory => snapshot.calls;

  bool activateLocalCall(String callId) {
    if (_localActiveCallId != null && _localActiveCallId != callId) {
      return false;
    }
    _localActiveCallId = callId;
    return true;
  }

  void deactivateLocalCall(String callId) {
    if (_localActiveCallId == callId) _localActiveCallId = null;
  }

  String? get token => _token;
  bool get signedIn => _token != null && user != null;
  bool get canManageListings =>
      account.capabilities.contains('add_properties') ||
      account.capabilities.contains('list_properties');

  int get verifiedProperties =>
      snapshot.properties.where((item) => item.verified).length;
  List<NotificationItem> get allNotifications => snapshot.notifications;
  int get unreadNotificationCount =>
      snapshot.notifications.where((item) => !item.isRead).length;
  int get unreadMessageCount => snapshot.conversations.fold(
        0,
        (total, conversation) => total + conversation.unreadCount,
      );

  List<PropertyListing> get comparedProperties => snapshot.comparisonProperties;
  List<ComparisonSuggestion> get comparisonSuggestions =>
      snapshot.comparisonSuggestions;
  List<SavedSearchItem> get savedSearches => snapshot.savedSearches;

  PropertyListing currentProperty(PropertyListing fallback) {
    final changedProperty = _changedProperties[fallback.id];
    if (changedProperty != null) return changedProperty;
    return snapshot.properties.firstWhere(
      (item) => item.id == fallback.id,
      orElse: () => snapshot.savedProperties.firstWhere(
        (item) => item.id == fallback.id,
        orElse: () => fallback,
      ),
    );
  }

  Future<void> boot() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      _token = preferences.getString(_tokenKey);
      darkMode = preferences.getBool(_darkModeKey) ?? false;
      notifyListeners();
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
          _replaceSnapshot(
            await _api.snapshot(
              token: _token,
              isAdmin: user?.role == AccountRole.admin,
            ),
          );
        } catch (exception) {
          if (!_isVerificationGate(exception)) rethrow;
          await _loadVerificationSnapshot();
        }
        await _refreshFollowedProperties();
      } else {
        _replaceSnapshot(await _api.snapshot());
      }
    } catch (exception) {
      await _clearToken();
      user = null;
      account = AccountContext.guest();
      _replaceSnapshot(await _api.snapshot());
      error = userFacingError(exception);
    } finally {
      loading = false;
      notifyListeners();
      if (signedIn) unawaited(_connectLiveSocket());
    }
  }

  Future<void> refresh({bool silent = false}) async {
    if (_refreshing) {
      _refreshPending = true;
      return;
    }
    _refreshing = true;
    error = null;
    if (!silent) notifyListeners();
    try {
      try {
        if (_token == null || _token!.isEmpty) {
          _replaceSnapshot(await _api.snapshot());
        } else {
          final session = await _api.me(_token!);
          _applySession(session);
          _replaceSnapshot(
            await _api.snapshot(
              token: _token,
              isAdmin: user?.role == AccountRole.admin,
            ),
          );
        }
      } catch (exception) {
        if (_isUnauthorized(exception)) {
          final restored = await _restoreSession();
          if (restored == null) rethrow;
          _applySession(restored);
          _replaceSnapshot(
            await _api.snapshot(
              token: _token,
              isAdmin: user?.role == AccountRole.admin,
            ),
          );
        } else if (!_isVerificationGate(exception)) {
          rethrow;
        } else {
          await _loadVerificationSnapshot();
        }
      }
      await _refreshFollowedProperties();
    } catch (exception) {
      error = userFacingError(exception);
    } finally {
      _refreshing = false;
      notifyListeners();
      if (_refreshPending) {
        _refreshPending = false;
        unawaited(refresh(silent: true));
      }
    }
  }

  Future<void> _connectLiveSocket() async {
    final activeToken = _token;
    if (activeToken == null ||
        activeToken.isEmpty ||
        !signedIn ||
        user?.role == AccountRole.admin) {
      return;
    }
    await _closeLiveSocket();
    try {
      final channel = WebSocketChannel.connect(
        AppConfig.liveSocketUri(activeToken),
      );
      _liveChannel = channel;
      _liveSubscription = channel.stream.listen(
        _handleLiveEvent,
        onError: (_) => _scheduleLiveReconnect(),
        onDone: _scheduleLiveReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleLiveReconnect();
    }
  }

  Future<void> _closeLiveSocket() async {
    _liveReconnectTimer?.cancel();
    _liveReconnectTimer = null;
    await _liveSubscription?.cancel();
    _liveSubscription = null;
    await _liveChannel?.sink.close();
    _liveChannel = null;
  }

  void _scheduleLiveReconnect() {
    if (!signedIn || _liveReconnectTimer?.isActive == true) return;
    _liveReconnectTimer = Timer(const Duration(seconds: 5), () {
      unawaited(_connectLiveSocket());
    });
  }

  void _handleLiveEvent(dynamic raw) {
    if (raw is! String) return;
    try {
      final event = jsonDecode(raw);
      if (event is! Map<String, dynamic>) return;
      final type = '${event['type'] ?? ''}';
      final payload = event['payload'];
      final conversationId =
          payload is Map ? '${payload['conversation_id'] ?? ''}' : '';
      if (type.startsWith('call.') && payload is Map<String, dynamic>) {
        _callEvents.add({
          'type': type,
          'payload': Map<String, dynamic>.from(payload),
        });
      }
      if (type == 'typing' && conversationId.isNotEmpty && payload is Map) {
        final isTyping = payload['is_typing'] == true;
        if (isTyping) {
          _typingUsers[conversationId] =
              '${payload['name'] ?? 'Someone'} is typing...';
        } else {
          _typingUsers.remove(conversationId);
        }
        notifyListeners();
      }
      if (conversationId.isNotEmpty &&
          type == 'call.started' &&
          payload is Map<String, dynamic>) {
        _activeCalls[conversationId] = CallLogItem.fromJson(payload);
        notifyListeners();
      } else if (conversationId.isNotEmpty && type == 'call.ended') {
        _activeCalls.remove(conversationId);
        notifyListeners();
      }
      if (type == 'notification.created' && payload is Map) {
        final message = '${payload['message'] ?? ''}'.trim();
        final kind = '${payload['kind'] ?? ''}';
        final fallback = switch (kind) {
          'application' => 'New application received',
          'application.updated' => 'Application status updated',
          'viewing' => 'New viewing request',
          'viewing.updated' => 'Viewing status updated',
          'conversation.created' => 'New conversation',
          'property.hold' => 'Property hold updated',
          'identity_verification' => 'Identity verification updated',
          _ => kind.isEmpty ? 'New notification' : titleize(kind),
        };
        final notificationId = '${payload['notification_id'] ?? ''}'.trim();
        if (notificationId.isNotEmpty) {
          addNotification(
            NotificationItem(
              id: notificationId,
              kind: kind.isEmpty ? 'general' : kind,
              message: message.isNotEmpty ? message : fallback,
              isRead: false,
              createdAt: 'Just now',
              payload: Map<String, dynamic>.from(payload),
            ),
          );
        }
      }
      if (conversationId.isNotEmpty &&
          (type.startsWith('message.') ||
              type.startsWith('messages.') ||
              type.startsWith('call.'))) {
        _conversationRevisions[conversationId] =
            conversationRevision(conversationId) + 1;
        notifyListeners();
      }
      if (type == 'property.changed' && payload is Map<String, dynamic>) {
        final rawProperty = payload['property'];
        if (rawProperty is Map<String, dynamic>) {
          final changedPayload = Map<String, dynamic>.from(rawProperty);
          PropertyListing? savedProperty;
          for (final property in snapshot.savedProperties) {
            if (property.id == '${rawProperty['id']}') {
              savedProperty = property;
              break;
            }
          }
          if (savedProperty != null) {
            changedPayload
              ..['saved'] = savedProperty.saved
              ..['reserved'] = savedProperty.reserved;
          }
          final changedProperty = PropertyListing.fromJson(changedPayload);
          _changedProperties[changedProperty.id] = changedProperty;
          notifyListeners();
        }
      }
      if (type == 'property.changed' ||
          type == 'comparison.changed' ||
          type == 'notification.created' ||
          type == 'account.changed' ||
          type.startsWith('message.') ||
          type.startsWith('messages.') ||
          type.startsWith('conversation.') ||
          type.startsWith('call.')) {
        unawaited(refresh(silent: true));
      }
    } catch (_) {
      // Polling remains the fallback for malformed or unsupported frames.
    }
  }

  bool sendLiveEvent(
    String type,
    String conversationId, {
    Map<String, dynamic> payload = const {},
  }) {
    final channel = _liveChannel;
    if (channel == null) return false;
    try {
      channel.sink.add(
        jsonEncode({
          'type': type,
          'conversation_id': conversationId,
          ...payload,
        }),
      );
      return true;
    } catch (_) {
      _scheduleLiveReconnect();
      return false;
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _liveReconnectTimer?.cancel();
    unawaited(_closeLiveSocket());
    unawaited(_callEvents.close());
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

  Future<void> signInWithGoogle(
    AccountRole? role, {
    List<String> marketplaceCapabilities = const [],
  }) async {
    await _authenticate(() async {
      final google = await _api.googleSignIn();
      return _api.loginWithGoogle(
        idToken: google,
        role: role,
        marketplaceCapabilities: marketplaceCapabilities,
      );
    });
  }

  Future<String> register({
    required AccountRole role,
    required String name,
    required String email,
    required String password,
    List<String> marketplaceCapabilities = const [],
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
        marketplaceCapabilities: marketplaceCapabilities,
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
      _replaceSnapshot(
        await _api.snapshot(
          token: session.token,
          isAdmin: session.user.role == AccountRole.admin,
        ),
      );
    } catch (_) {
      try {
        await _loadVerificationSnapshot();
      } catch (_) {
        _replaceSnapshot(PlatformSnapshot.empty());
      }
    }
    notifyListeners();
  }

  Future<String> resendRegistrationEmail(String challengeId) {
    return _api.resendRegistrationEmail(challengeId);
  }

  Future<void> enablePropertyListings() async {
    final session = await _api.updateMarketplaceCapabilities(
      token: _requireToken(),
      capabilities: const ['list_properties'],
    );
    user = session.user;
    account = session.account;
    notifyListeners();
    await refresh(silent: true);
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

  Future<String> requestPhoneVerification({required String phone}) async {
    final activeToken = _requireToken();
    return _api.requestPhoneVerification(
      token: activeToken,
      phone: phone,
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

  Future<VerificationItem> submitIdentityVerification({
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
    final activeToken = _requireToken();
    final activeUser = user;
    if (activeUser == null) {
      throw const ApiException('Sign in to verify your account.');
    }
    final verification = await _api.submitIdentityVerification(
      token: activeToken,
      role: activeUser.role.apiValue,
      name: activeUser.name,
      phone: phone,
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
    _replaceSnapshot(
      await _api.snapshot(
        token: activeToken,
        isAdmin: user?.role == AccountRole.admin,
      ),
    );
    notifyListeners();
    return verification;
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
        _replaceSnapshot(
          await _api.snapshot(
            token: session.token,
            isAdmin: session.user.role == AccountRole.admin,
          ),
        );
      } catch (exception) {
        if (!_isVerificationGate(exception)) rethrow;
        await _loadVerificationSnapshot();
      }
      await _refreshFollowedProperties();
    } catch (exception) {
      error = userFacingError(exception);
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
      if (signedIn) unawaited(_connectLiveSocket());
    }
  }

  Future<void> signOut() async {
    await _closeLiveSocket();
    await _clearToken();
    _changedProperties.clear();
    user = null;
    account = AccountContext.guest();
    followedProperties = <PropertyListing>[];
    try {
      _replaceSnapshot(await _api.snapshot());
    } catch (_) {
      _replaceSnapshot(PlatformSnapshot.empty());
    }
    notifyListeners();
  }

  Future<AiSearchResponse> searchWithAi(
    String query, {
    String scope = 'discover',
    String? sessionId,
  }) {
    return _api.aiPropertySearch(
      token: _token,
      query: query.trim(),
      scope: scope,
      sessionId: sessionId,
    );
  }

  Future<PropertyListing> saveProperty(
    PropertyDraft draft, {
    String? propertyId,
  }) async {
    final activeToken = _requireToken();
    loading = true;
    error = null;
    notifyListeners();
    try {
      final saved = propertyId == null
          ? await _api.createProperty(activeToken, draft)
          : await _api.updateProperty(activeToken, propertyId, draft);
      _replaceSnapshot(
        await _api.snapshot(
          token: activeToken,
          isAdmin: user?.role == AccountRole.admin,
        ),
      );
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
    _replaceSnapshot(
      await _api.snapshot(
        token: activeToken,
        isAdmin: user?.role == AccountRole.admin,
      ),
    );
    notifyListeners();
  }

  Future<ServiceListing> createService(Map<String, dynamic> payload) async {
    final activeToken = _requireToken();
    final service = await _api.createService(activeToken, payload);
    await refresh();
    return service;
  }

  Future<ServiceListing> updateService(
    ServiceListing service,
    Map<String, dynamic> payload,
  ) async {
    final activeToken = _requireToken();
    final updated = await _api.updateService(activeToken, service.id, payload);
    await refresh();
    return updated;
  }

  Future<void> deleteService(String serviceId) async {
    final activeToken = _requireToken();
    await _api.deleteService(activeToken, serviceId);
    await refresh();
  }

  Future<ServiceRequestItem> requestService(
    ServiceListing service,
    String message,
  ) async {
    final activeToken = _requireToken();
    final request = await _api.requestService(
      activeToken,
      service.id,
      message,
    );
    await refresh();
    return request;
  }

  Future<ServiceRequestItem> updateServiceRequest(
    ServiceRequestItem request,
    String status,
  ) async {
    final activeToken = _requireToken();
    final updated = await _api.updateServiceRequest(
      activeToken,
      request.id,
      status,
    );
    await refresh();
    return updated;
  }

  Future<JobPosting> createJob(Map<String, dynamic> payload) async {
    final activeToken = _requireToken();
    final job = await _api.createJob(activeToken, payload);
    await refresh();
    return job;
  }

  Future<JobPosting> updateJob(
    JobPosting job,
    Map<String, dynamic> payload,
  ) async {
    final activeToken = _requireToken();
    final updated = await _api.updateJob(activeToken, job.id, payload);
    await refresh();
    return updated;
  }

  Future<void> deleteJob(String jobId) async {
    final activeToken = _requireToken();
    await _api.deleteJob(activeToken, jobId);
    await refresh();
  }

  Future<JobApplicationItem> applyToJob(
    JobPosting job,
    String coverMessage,
  ) async {
    final activeToken = _requireToken();
    final application = await _api.applyToJob(
      activeToken,
      job.id,
      coverMessage,
    );
    await refresh();
    return application;
  }

  Future<JobApplicationItem> updateJobApplication(
    JobApplicationItem application,
    String status,
  ) async {
    final activeToken = _requireToken();
    final updated = await _api.updateJobApplication(
      activeToken,
      application.id,
      status,
    );
    await refresh();
    return updated;
  }

  Future<void> confirmPropertyAvailability(
    PropertyListing property, {
    String action = 'available',
    DateTime? availableFrom,
  }) async {
    final activeToken = _requireToken();
    final updatedProperty = await _api.confirmPropertyAvailability(
      activeToken,
      property.id,
      action: action,
      availableFrom: availableFrom,
    );
    _changedProperties[updatedProperty.id] = updatedProperty;
    await refresh();
  }

  Future<ConversationItem> messageAboutProperty(
    PropertyListing property,
  ) async {
    final activeToken = _requireToken();
    final conversation = await _api.startConversation(activeToken, property.id);
    _replaceSnapshot(
      await _api.snapshot(
        token: activeToken,
        isAdmin: user?.role == AccountRole.admin,
      ),
    );
    notifyListeners();
    return conversation;
  }

  Future<ViewingItem> requestViewing(
    PropertyListing property,
    DateTime scheduledFor,
  ) async {
    final activeToken = _requireToken();
    final viewing = await _api.requestViewing(
      activeToken,
      property.id,
      scheduledFor,
    );
    await refresh();
    return viewing;
  }

  Future<void> updateViewingStatus(
    ViewingItem viewing,
    String status,
  ) async {
    final activeToken = _requireToken();
    await _api.updateViewingStatus(activeToken, viewing.id, status);
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
    _replaceSnapshot(
      await _api.snapshot(
        token: activeToken,
        isAdmin: user?.role == AccountRole.admin,
      ),
    );
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
    await refresh();
  }

  Future<List<ChatMessageItem>> loadConversationMessages(
    String conversationId,
  ) async {
    final activeToken = _requireToken();
    final messages =
        await _api.conversationMessages(activeToken, conversationId);
    _replaceSnapshot(
      snapshot.copyWith(
        conversations: snapshot.conversations
            .map(
              (conversation) => conversation.id == conversationId
                  ? conversation.copyWith(unreadCount: 0)
                  : conversation,
            )
            .toList(growable: false),
      ),
    );
    notifyListeners();
    return messages;
  }

  Future<void> shareLocation(
    String conversationId, {
    required PropertyListing property,
    bool liveLocation = true,
  }) async {
    if (!property.hasCoordinates) return;
    final label = liveLocation ? 'Live location' : 'Location';
    await sendMessage(
      conversationId,
      '$label: ${property.address.isNotEmpty ? property.address : property.heroLocation} (${property.latitude}, ${property.longitude})',
    );
  }

  Future<CallLogItem> startCall(
    String conversationId, {
    required CallMode mode,
  }) async {
    final activeToken = _requireToken();
    final call = await _api.startCall(
      activeToken,
      conversationId,
      mode: mode,
    );
    await refresh();
    return call;
  }

  Future<CallLogItem> endCall(
    String conversationId,
    String callId, {
    String status = 'ended',
  }) async {
    final activeToken = _requireToken();
    final call = await _api.endCall(
      activeToken,
      conversationId,
      callId,
      status: status,
    );
    await refresh();
    return call;
  }

  Future<void> sendMessage(String conversationId, String body) async {
    final activeToken = _requireToken();
    await _api.sendMessage(activeToken, conversationId, body);
    await refresh();
  }

  Future<void> deleteConversationMessage(
    String conversationId,
    String messageId,
  ) async {
    final activeToken = _requireToken();
    await _api.deleteConversationMessage(
      activeToken,
      conversationId,
      messageId,
    );
    await refresh();
  }

  Future<void> editConversationMessage(
    String conversationId,
    String messageId,
    String body,
  ) async {
    final activeToken = _requireToken();
    await _api.editConversationMessage(
      activeToken,
      conversationId,
      messageId,
      body,
    );
    await refresh();
  }

  Future<void> blockConversationUser(
    String conversationId,
    String blockedUserId,
  ) async {
    final activeToken = _requireToken();
    await _api.blockConversationUser(
      activeToken,
      conversationId,
      blockedUserId,
    );
    await refresh();
  }

  Future<void> reportConversationMessage(
    String conversationId,
    String messageId,
  ) async {
    final activeToken = _requireToken();
    await _api.reportConversationMessage(
      activeToken,
      conversationId,
      messageId,
    );
  }

  Future<void> toggleSaved(PropertyListing property) async {
    final activeToken = _requireToken();
    final saved = !savedPropertyIds.contains(property.id);
    await _api.toggleSavedProperty(activeToken, property.id, saved: saved);
    if (saved) {
      savedPropertyIds.add(property.id);
      if (!snapshot.savedProperties.any((item) => item.id == property.id)) {
        snapshot = snapshot.copyWith(
          savedProperties: [...snapshot.savedProperties, property],
        );
      }
    } else {
      savedPropertyIds.remove(property.id);
      snapshot = snapshot.copyWith(
        savedProperties: snapshot.savedProperties
            .where((item) => item.id != property.id || item.reserved)
            .toList(growable: false),
      );
    }
    notifyListeners();
    await refresh();
  }

  Future<Map<String, dynamic>> togglePropertyLike(
    String propertyId, {
    required bool liked,
  }) async {
    final activeToken = _requireToken();
    final result = await _api.togglePropertyLike(
      activeToken,
      propertyId,
      liked: liked,
    );
    await refresh(silent: true);
    return result;
  }

  Future<Map<String, dynamic>> propertyLikeStatus(String propertyId) async {
    return _api.propertyLikeStatus(_requireToken(), propertyId);
  }

  Future<int> recordPropertyView(String propertyId) {
    return _api.recordPropertyView(propertyId);
  }

  Future<List<PropertyCommentItem>> loadPropertyComments(
    String propertyId,
  ) async {
    return _api.propertyComments(_requireToken(), propertyId);
  }

  Future<PropertyCommentItem> createPropertyComment(
    String propertyId,
    String body, {
    String? parentId,
  }) async {
    return _api.createPropertyComment(
      _requireToken(),
      propertyId,
      body,
      parentId: parentId,
    );
  }

  Future<PropertyCommentItem> editPropertyComment(
    String propertyId,
    String commentId,
    String body,
  ) async {
    final result = await _api.editPropertyComment(
      _requireToken(),
      propertyId,
      commentId,
      body,
    );
    return result;
  }

  Future<void> deletePropertyComment(
    String propertyId,
    String commentId,
  ) async {
    await _api.deletePropertyComment(
      _requireToken(),
      propertyId,
      commentId,
    );
  }

  Future<Map<String, dynamic>> toggleSupplierFollow(
    String supplierId, {
    required bool following,
  }) async {
    final result = await _api.toggleSupplierFollow(
      _requireToken(),
      supplierId,
      following: following,
    );
    await _refreshFollowedProperties();
    notifyListeners();
    return result;
  }

  Future<void> _refreshFollowedProperties() async {
    if (!signedIn) {
      followedProperties = <PropertyListing>[];
      return;
    }
    try {
      followedProperties = await _api.followedProperties(_requireToken());
    } catch (_) {
      followedProperties = <PropertyListing>[];
    }
  }

  Future<Map<String, dynamic>> supplierFollowStatus(String supplierId) async {
    return _api.supplierFollowStatus(_requireToken(), supplierId);
  }

  Future<List<PropertyListing>> loadFollowedProperties() async {
    return _api.followedProperties(_requireToken());
  }

  Future<void> toggleComparison(PropertyListing property) async {
    final activeToken = _requireToken();
    await _api.toggleComparison(token: activeToken, propertyId: property.id);
    await refresh();
  }

  Future<void> clearComparisons() async {
    final activeToken = _requireToken();
    await _api.clearComparisons(token: activeToken);
    await refresh();
  }

  Future<List<ComparisonSuggestion>> comparisonSuggestionsFor(
    String propertyId,
  ) async {
    return _api.propertyComparisonSuggestions(
      token: _requireToken(),
      propertyId: propertyId,
    );
  }

  Future<void> saveSearch(
    String query, {
    String? name,
    Map<String, dynamic>? criteria,
  }) async {
    final activeToken = _requireToken();
    await _api.saveSearch(
      token: activeToken,
      query: query,
      name: name,
      criteria: criteria,
    );
    await refresh();
  }

  Future<void> setSavedSearchActive(
    String searchId, {
    required bool isActive,
  }) async {
    final activeToken = _requireToken();
    await _api.updateSavedSearch(
      token: activeToken,
      searchId: searchId,
      isActive: isActive,
    );
    await refresh();
  }

  Future<void> deleteSavedSearch(String searchId) async {
    final activeToken = _requireToken();
    await _api.deleteSavedSearch(token: activeToken, searchId: searchId);
    await refresh();
  }

  Future<AffordabilityResult> calculateAffordability(
    PropertyListing property, {
    required String monthlyIncome,
    String monthlyCommitments = '0',
    String savingsAvailable = '0',
  }) {
    final activeToken = _requireToken();
    return _api.propertyAffordability(
      token: activeToken,
      propertyId: property.id,
      monthlyIncome: monthlyIncome,
      monthlyCommitments: monthlyCommitments,
      savingsAvailable: savingsAvailable,
    );
  }

  void addSmartAlert(String label) {
    if (!smartAlerts.contains(label)) {
      smartAlerts.add(label);
    }
    notifyListeners();
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

  void addNotification(NotificationItem notification) {
    if (snapshot.notifications.any((item) => item.id == notification.id)) {
      return;
    }
    _replaceSnapshot(
      snapshot.copyWith(
        notifications: [notification, ...snapshot.notifications],
      ),
    );
    notifyListeners();
  }

  Future<void> markNotificationRead(String notificationId) async {
    final activeToken = _requireToken();
    await _api.markNotificationRead(
      token: activeToken,
      notificationId: notificationId,
    );
    _replaceSnapshot(
      snapshot.copyWith(
        notifications: snapshot.notifications
            .map(
              (item) => item.id == notificationId
                  ? item.copyWith(isRead: true)
                  : item,
            )
            .toList(growable: false),
      ),
    );
    notifyListeners();
  }

  Future<void> markAllNotificationsRead() async {
    final activeToken = _requireToken();
    await _api.markAllNotificationsRead(token: activeToken);
    _replaceSnapshot(
      snapshot.copyWith(
        notifications: snapshot.notifications
            .map((item) => item.copyWith(isRead: true))
            .toList(growable: false),
      ),
    );
    notifyListeners();
  }

  Future<void> clearNotification(String notificationId) async {
    final activeToken = _requireToken();
    await _api.deleteNotification(
      token: activeToken,
      notificationId: notificationId,
    );
    _replaceSnapshot(
      snapshot.copyWith(
        notifications: snapshot.notifications
            .where((item) => item.id != notificationId)
            .toList(growable: false),
      ),
    );
    notifyListeners();
  }

  Future<void> clearAllNotifications() async {
    final activeToken = _requireToken();
    await _api.clearNotifications(token: activeToken);
    _replaceSnapshot(snapshot.copyWith(notifications: const []));
    notifyListeners();
  }

  String _requireToken() {
    final activeToken = _token;
    if (activeToken == null || activeToken.isEmpty) {
      throw const ApiException('Sign in is required for this action.');
    }
    return activeToken;
  }

  void _replaceSnapshot(PlatformSnapshot value) {
    snapshot = value;
    final visiblePropertyIds =
        value.properties.map((property) => property.id).toSet();
    _changedProperties.removeWhere(
      (propertyId, _) => visiblePropertyIds.contains(propertyId),
    );
    savedPropertyIds
      ..clear()
      ..addAll(
        value.savedProperties
            .where((property) => property.saved)
            .map((property) => property.id),
      );
    comparisonPropertyIds
      ..clear()
      ..addAll(value.comparisonProperties.map((property) => property.id));
    smartAlerts
      ..clear()
      ..addAll(
        value.savedSearches.where((search) => search.isActive).map(
              (search) => search.query,
            ),
      );
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
        .replaceAll(RegExp(r'^_|_$'), '');
    profileImageUrl = session.user.profilePicture;
    usernameVerified = session.user.verified;
  }

  Future<void> _loadVerificationSnapshot() async {
    final publicSnapshot = await _api.snapshot();
    final properties = await _api.searchProperties(token: _token);
    _replaceSnapshot(
      PlatformSnapshot(
        properties: properties,
        applications: publicSnapshot.applications,
        verifications: publicSnapshot.verifications,
        conversations: publicSnapshot.conversations,
        viewings: publicSnapshot.viewings,
        calls: publicSnapshot.calls,
        savedProperties: publicSnapshot.savedProperties,
        comparisonProperties: publicSnapshot.comparisonProperties,
        comparisonSuggestions: publicSnapshot.comparisonSuggestions,
        savedSearches: publicSnapshot.savedSearches,
        notifications: publicSnapshot.notifications,
        services: publicSnapshot.services,
        jobs: publicSnapshot.jobs,
      ),
    );
  }

  bool _isVerificationGate(Object exception) {
    return exception is ApiException &&
        exception.statusCode == 403 &&
        user != null &&
        !user!.accountOnboardingComplete;
  }
}
