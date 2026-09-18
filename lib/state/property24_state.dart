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
  final List<String> notifications = <String>[
    'Borrowdale garden flat is still available.',
    'A verified landlord replied to your viewing request.',
    'New trusted homes match your saved search.',
  ];
  final List<ChatMessageDraft> localChatMessages = <ChatMessageDraft>[
    const ChatMessageDraft(
      id: 'm1',
      body: 'Hi, is the house still available?',
      mine: true,
      attachmentType: AttachmentType.none,
    ),
    const ChatMessageDraft(
      id: 'm2',
      body: 'Yes, it is available. I can send a walkthrough video.',
      mine: false,
      attachmentType: AttachmentType.video,
    ),
  ];
  final List<CallLogItem> callHistory = <CallLogItem>[
    const CallLogItem(
      name: 'Tariro Moyo',
      property: 'Borrowdale garden flat',
      mode: CallMode.video,
      direction: 'Missed',
      when: 'Today, 09:42',
    ),
    const CallLogItem(
      name: 'Nyasha Properties',
      property: 'Avondale townhouse',
      mode: CallMode.voice,
      direction: 'Outgoing',
      when: 'Yesterday, 16:10',
    ),
  ];

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
      error = '$exception';
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
      error = '$exception';
    } finally {
      notifyListeners();
    }
  }

  Future<void> signIn(String username, String password) async {
    await _authenticate(
        () => _api.login(username: username, password: password));
  }

  Future<void> register({
    required AccountRole role,
    required String name,
    required String email,
    required String password,
  }) async {
    await _authenticate(
      () => _api.register(
        role: role,
        name: name,
        email: email,
        password: password,
      ),
    );
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
      error = '$exception';
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
      error = '$exception';
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

  Future<void> startConversation(PropertyListing property) async {
    final activeToken = _requireToken();
    await _api.startConversation(activeToken, property.id);
    await refresh();
  }

  Future<void> sendMessage(String conversationId, String body) async {
    final activeToken = _requireToken();
    await _api.sendMessage(activeToken, conversationId, body);
    await refresh();
  }

  void toggleSaved(PropertyListing property) {
    if (!savedPropertyIds.add(property.id)) {
      savedPropertyIds.remove(property.id);
    }
    notifyListeners();
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

enum CallMode { voice, video }

class CallLogItem {
  const CallLogItem({
    required this.name,
    required this.property,
    required this.mode,
    required this.direction,
    required this.when,
  });

  final String name;
  final String property;
  final CallMode mode;
  final String direction;
  final String when;
}

enum AttachmentType { none, image, video, audio }

class ChatMessageDraft {
  const ChatMessageDraft({
    required this.id,
    required this.body,
    required this.mine,
    required this.attachmentType,
  });

  final String id;
  final String body;
  final bool mine;
  final AttachmentType attachmentType;

  ChatMessageDraft copyWith({String? body}) {
    return ChatMessageDraft(
      id: id,
      body: body ?? this.body,
      mine: mine,
      attachmentType: attachmentType,
    );
  }
}
