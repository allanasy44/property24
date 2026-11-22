import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static String get apiBaseUrl {
    final configured = _configuredApiBaseUrl.trim();
    if (configured.isEmpty && kDebugMode) {
      return 'http://127.0.0.1:8010/api';
    }
    if (configured.isEmpty) {
      throw StateError(
        'Build release apps with --dart-define=API_BASE_URL=https://your-api-host/api.',
      );
    }
    if (!kDebugMode && !configured.startsWith('https://')) {
      throw StateError('Release API_BASE_URL must use HTTPS.');
    }
    return configured;
  }

  static const _turnUrls = String.fromEnvironment('WEBRTC_TURN_URLS');
  static const _turnUsername = String.fromEnvironment('WEBRTC_TURN_USERNAME');
  static const _turnCredential = String.fromEnvironment(
    'WEBRTC_TURN_CREDENTIAL',
  );

  static List<Map<String, dynamic>> get webrtcIceServers {
    final servers = <Map<String, dynamic>>[
      {'urls': 'stun:stun.l.google.com:19302'},
    ];
    final turnUrls = _turnUrls
        .split(',')
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    if (turnUrls.isNotEmpty) {
      if (_turnUsername.isEmpty || _turnCredential.isEmpty) {
        throw StateError(
          'Configure WEBRTC_TURN_USERNAME and WEBRTC_TURN_CREDENTIAL '
          'along with WEBRTC_TURN_URLS.',
        );
      }
      servers.add({
        'urls': turnUrls,
        'username': _turnUsername,
        'credential': _turnCredential,
      });
    }
    return servers;
  }

  static Uri liveSocketUri(String token) {
    final base = Uri.parse(apiBaseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    var root = base.path;
    if (root.endsWith('/api')) root = root.substring(0, root.length - 4);
    if (root.endsWith('/')) root = root.substring(0, root.length - 1);
    return base.replace(
      scheme: scheme,
      path: '$root/ws/live/',
      queryParameters: {'token': token},
    );
  }

  static Uri apiUri(String path, [Map<String, String?> query = const {}]) {
    final normalizedBase = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('$normalizedBase/$normalizedPath');
    final queryParameters = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value != null && value.trim().isNotEmpty) {
        queryParameters[entry.key] = value.trim();
      }
    }
    return queryParameters.isEmpty
        ? uri
        : uri.replace(queryParameters: queryParameters);
  }
}
