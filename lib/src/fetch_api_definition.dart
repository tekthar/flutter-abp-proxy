/// ABP Proxy Generator — API Definition Fetcher.
///
/// Fetches the ABP API definition JSON from a running backend
/// or loads it from a local file.
library;

import 'dart:convert';
import 'dart:io';

import 'config.dart';

/// Fetch the ABP API definition from a running backend.
Future<Map<String, dynamic>> fetchApiDefinition({
  required String url,
  String? token,
  bool skipSsl = false,
}) async {
  final fullUrl = Uri.parse(url).resolve(apiDefinitionPath);
  print('Fetching API definition from: $fullUrl');

  final client = HttpClient();
  if (skipSsl) {
    client.badCertificateCallback = (_, __, ___) => true;
  }

  try {
    final request = await client.getUrl(fullUrl);
    request.headers.set('Accept', 'application/json');
    if (token != null) {
      request.headers.set('Authorization', 'Bearer $token');
    }

    final response = await request.close().timeout(
          const Duration(seconds: 30),
        );

    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch API definition. '
        'HTTP ${response.statusCode}: ${body.substring(0, body.length.clamp(0, 500))}',
      );
    }

    final parsed = jsonDecode(body) as Map<String, dynamic>;
    print(
      '  Received API definition (${(body.length / 1024).toStringAsFixed(1)} KB)',
    );
    return parsed;
  } finally {
    client.close();
  }
}

/// Load API definition from a local JSON file (for testing/offline use).
Map<String, dynamic> loadApiDefinitionFromFile(String filePath) {
  final data = File(filePath).readAsStringSync();
  return jsonDecode(data) as Map<String, dynamic>;
}
