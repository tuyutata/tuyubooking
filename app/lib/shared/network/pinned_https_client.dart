import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:tuyubooking/client/host_connection/mdns_discovery.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';

const _businessRoutes = {'/hotel', '/restaurant', '/tour', '/ticket'};

void _validateAddress(String address, int port) {
  if (InternetAddress.tryParse(address) == null || port < 1 || port > 65535) {
    throw const FormatException('Invalid fixed merchant address');
  }
}

void _validateFingerprint(String fingerprint) {
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint)) {
    throw const FormatException('Invalid merchant certificate fingerprint');
  }
}

final class EmployeeHostProfile {
  const EmployeeHostProfile({
    required this.address,
    required this.port,
    required this.instanceId,
    required this.merchantName,
    required this.certificateFingerprint,
    required this.routes,
  });

  factory EmployeeHostProfile.fromJson(Map<String, Object?> json) {
    final profile = EmployeeHostProfile(
      address: json['address'] as String,
      port: json['port'] as int,
      instanceId: json['instance_id'] as String,
      merchantName: json['merchant_name'] as String,
      certificateFingerprint: json['certificate_sha256'] as String,
      routes: List<String>.unmodifiable((json['routes'] as List).cast<String>()),
    );
    _validateAddress(profile.address, profile.port);
    _validateFingerprint(profile.certificateFingerprint);
    if (profile.instanceId.trim().isEmpty || profile.routes.isEmpty ||
        profile.routes.any((route) => !_businessRoutes.contains(route)) ||
        profile.routes.toSet().length != profile.routes.length) {
      throw const FormatException('Invalid merchant identity or business routes');
    }
    return profile;
  }

  final String address;
  final int port;
  final String instanceId;
  final String merchantName;
  final String certificateFingerprint;
  final List<String> routes;

  Uri route(String path) => Uri(scheme: 'https', host: address, port: port, path: path);

  Map<String, Object?> toJson() => {
    'address': address, 'port': port, 'instance_id': instanceId,
    'merchant_name': merchantName, 'certificate_sha256': certificateFingerprint,
    'routes': routes,
  };
}

HttpClient _pinnedClient(String address, int port, String? fingerprint) {
  _validateAddress(address, port);
  if (fingerprint != null) _validateFingerprint(fingerprint);
  // 不加载系统信任根，确保受系统信任的其它证书也必须经过指纹判断。
  // 校验在 TLS 握手中完成，不能等员工密码发出后才检查响应证书。
  final client = HttpClient(context: SecurityContext(withTrustedRoots: false));
  client.connectionTimeout = const Duration(seconds: 5);
  client.findProxy = (_) => 'DIRECT';
  client.badCertificateCallback = (certificate, host, actualPort) =>
        host == address && actualPort == port &&
        (fingerprint == null || sha256.convert(certificate.der).toString() == fingerprint);
  return client;
}

Future<String> _readBody(HttpClientResponse response, int limit) async {
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in response) {
    if (bytes.length + chunk.length > limit) {
      throw const FormatException('Merchant response exceeds the size limit');
    }
    bytes.add(chunk);
  }
  return utf8.decode(bytes.takeBytes());
}

final class PinnedHttpsClient {
  const PinnedHttpsClient();

  Future<EmployeeHostProfile> reconnect(EmployeeHostProfile profile) => verify(
    DiscoveredTuyuBookingHost(
      address: profile.address, port: profile.port, instanceId: profile.instanceId,
      merchantName: profile.merchantName, apiVersion: '1',
    ),
    expectedFingerprint: profile.certificateFingerprint,
  );

  Future<EmployeeHostProfile> verify(
    DiscoveredTuyuBookingHost candidate, {String? expectedFingerprint}
  ) async {
    final client = _pinnedClient(candidate.address, candidate.port, expectedFingerprint);
    try {
      return await (() async {
        final uri = Uri(scheme: 'https', host: candidate.address,
            port: candidate.port, path: '/tuyu/status');
        final request = await client.getUrl(uri);
        request.followRedirects = false;
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          throw const HttpException('TuyuBooking status endpoint rejected');
        }
        final certificate = response.certificate;
        final fingerprint = certificate == null ? null : sha256.convert(certificate.der).toString();
        if (fingerprint == null ||
            (expectedFingerprint != null && fingerprint != expectedFingerprint)) {
          throw const HandshakeException('Merchant certificate pin mismatch');
        }
        final decoded = jsonDecode(await _readBody(response, 64 * 1024));
        if (decoded is! Map) throw const FormatException('Invalid host status');
        final status = decoded.cast<String, Object?>();
        if (status['ok'] != true || status['instance_id'] != candidate.instanceId ||
            status['certificate_sha256'] != fingerprint) {
          throw const FormatException('Host identity did not match discovery');
        }
        return EmployeeHostProfile.fromJson({
          'address': candidate.address, 'port': candidate.port,
          'instance_id': candidate.instanceId,
          'merchant_name': status['merchant_name'] ?? candidate.merchantName,
          'certificate_sha256': fingerprint, 'routes': status['routes'],
        });
      })().timeout(const Duration(seconds: 8));
    } finally {
      client.close(force: true);
    }
  }
}

/// 员工 Cookie 只在当前模块传输实例内存中保存，不跨模块共享。
final class PinnedEmployeeHttpTransport implements EmployeeHttpTransport {
  PinnedEmployeeHttpTransport(EmployeeHostProfile profile)
    : profile = EmployeeHostProfile.fromJson(profile.toJson()),
      _client = _pinnedClient(profile.address, profile.port, profile.certificateFingerprint);

  final EmployeeHostProfile profile;
  final HttpClient _client;
  final Map<String, String> _cookies = {};
  bool _closed = false;

  @override
  Future<EmployeeHttpResponse> send(
    EmployeeBusinessModule module, String endpoint, {
    String method = 'GET', Map<String, String> headers = const {},
    Map<String, String> queryParameters = const {}, String? body,
  }) async {
    if (_closed) throw StateError('Employee HTTPS transport is closed');
    if (!profile.routes.contains(module.route)) throw StateError('Merchant module is not enabled');
    final suffix = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final parsed = Uri.tryParse(suffix);
    final segments = suffix.split('/').skip(1).map(Uri.decodeComponent).toList();
    if (parsed == null || parsed.hasAuthority || parsed.hasQuery || parsed.hasFragment ||
        segments.any((part) => part == '.' || part == '..' || part.contains('/') ||
            part.contains(r'\') || part.contains('%') ||
            part.codeUnits.any((value) => value < 32 || value == 127))) {
      throw const FormatException('Employee endpoint must remain inside its business module');
    }
    final uri = profile.route('/').replace(
      pathSegments: [module.route.substring(1), ...segments],
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    try {
      return await _send(uri, method, headers, body).timeout(const Duration(seconds: 12));
    } on Object {
      close();
      rethrow;
    }
  }

  Future<EmployeeHttpResponse> _send(
    Uri uri, String method, Map<String, String> headers, String? body,
  ) async {
    final request = await _client.openUrl(method, uri);
    request.followRedirects = false;
    headers.forEach((name, value) => request.headers.set(name, value));
    for (final entry in _cookies.entries) {
      request.cookies.add(Cookie(entry.key, entry.value));
    }
    if (body != null) request.write(body);
    final response = await request.close();
    final certificate = response.certificate;
    if (certificate == null || sha256.convert(certificate.der).toString() != profile.certificateFingerprint) {
      throw const HandshakeException('Merchant certificate pin mismatch');
    }
    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw const HttpException('Merchant redirect is not allowed');
    }
    for (final cookie in response.cookies) {
      if (cookie.value.isEmpty || cookie.maxAge == 0) {
        _cookies.remove(cookie.name);
      } else {
        _cookies[cookie.name] = cookie.value;
      }
    }
    final responseHeaders = <String, List<String>>{};
    response.headers.forEach((name, values) => responseHeaders[name] = List.unmodifiable(values));
    return EmployeeHttpResponse(
      statusCode: response.statusCode, headers: Map.unmodifiable(responseHeaders),
      body: await _readBody(response, 8 * 1024 * 1024),
    );
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _cookies.clear();
    _client.close(force: true);
  }
}
