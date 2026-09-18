class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8010/api',
  );

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
