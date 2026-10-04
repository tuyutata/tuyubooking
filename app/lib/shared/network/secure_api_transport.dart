import 'dart:convert';
import 'dart:io';

final class SecureApiTransport {
  SecureApiTransport(String endpoint, {HttpClient? client})
    : _endpoint = _parseEndpoint(endpoint),
      _client = client ?? HttpClient();

  final Uri _endpoint;
  final HttpClient _client;

  Future<Map<String, Object?>> post(
    String path,
    Map<String, Object?> body,
  ) async {
    final uri = _endpoint.resolve(path);
    if (uri.scheme != 'https') {
      throw const SecureTransportException('HTTPS is required');
    }
    final request = await _client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SecureTransportException(
        'TuyuServe rejected the request (${response.statusCode})',
      );
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('TuyuServe response is not a JSON object');
    }
    return decoded;
  }

  static Uri _parseEndpoint(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw const SecureTransportException(
        'A valid HTTPS TuyuServe endpoint is required',
      );
    }
    return uri;
  }
}

final class SecureTransportException implements Exception {
  const SecureTransportException(this.message);
  final String message;

  @override
  String toString() => message;
}
