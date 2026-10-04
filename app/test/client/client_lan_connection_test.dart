import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/client/host_connection/employee_discovery_controller.dart';
import 'package:tuyubooking/client/host_connection/employee_host_store.dart';
import 'package:tuyubooking/client/host_connection/mdns_discovery.dart';
import 'package:tuyubooking/client/employee_access/employee_session.dart';
import 'package:tuyubooking/shared/network/pinned_https_client.dart';

final _certificate = _Certificate(Uint8List.fromList([1, 2, 3]));
final _profile = EmployeeHostProfile(
  address: '192.168.1.20', port: 58460, instanceId: 'merchant-1',
  merchantName: 'Test merchant', certificateFingerprint: sha256.convert(_certificate.der).toString(),
  routes: const ['/restaurant'],
);
const _candidate = DiscoveredTuyuBookingHost(
  address: '192.168.1.20', port: 58460, instanceId: 'merchant-1',
  merchantName: 'Test merchant', apiVersion: '1',
);

void main() {
  late Directory directory;
  late File file;
  late EmployeeHostStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('booking-client-test-');
    file = File('${directory.path}/host.json');
    store = EmployeeHostStore(fileProvider: () async => file);
  });
  tearDown(() async { await directory.delete(recursive: true); });

  test('host storage distinguishes first use from corrupt saved identity', () async {
    expect(await store.load(), isNull);
    await file.writeAsString('null');
    await expectLater(store.load(), throwsFormatException);
    var discovered = 0;
    final controller = EmployeeDiscoveryController(store: store,
      discoverHosts: () async { discovered += 1; return [_candidate]; });
    addTearDown(controller.dispose);
    await controller.start();
    expect(controller.status, EmployeeDiscoveryStatus.failed);
    expect(controller.profile, isNull);
    expect(discovered, 0);
  });

  test('saved host validation rejects malformed pins ports and routes', () {
    for (final change in [
      {'certificate_sha256': 'invalid'}, {'port': 0}, {'address': 'https://other.example'},
      {'instance_id': ''}, {'routes': ['/unknown']}, {'routes': <String>[]},
      {'routes': ['/restaurant', '/restaurant']},
    ]) {
      expect(() => EmployeeHostProfile.fromJson({..._profile.toJson(), ...change}), throwsFormatException);
    }
    final restored = EmployeeHostProfile.fromJson(_profile.toJson());
    expect(() => restored.routes.add('/hotel'), throwsUnsupportedError);
  });

  test('concurrent saves leave one complete host record without shared temp files', () async {
    await Future.wait([store.save(_profile), store.save(_profile)]);
    expect((await store.load())!.toJson(), _profile.toJson());
    expect(await directory.list().length, 1);
  });

  test('saved fixed host reconnects without discovery and shares pending startup', () async {
    await store.save(_profile);
    final entered = Completer<void>();
    final response = Completer<EmployeeHostProfile>();
    var discovered = 0;
    final controller = EmployeeDiscoveryController(store: store,
      discoverHosts: () async { discovered += 1; return []; },
      reconnectHost: (host) { expect(host.address, _profile.address); entered.complete(); return response.future; });
    addTearDown(controller.dispose);
    final first = controller.start();
    expect(identical(first, controller.start()), isTrue);
    await entered.future;
    response.complete(_profile);
    await first;
    expect(controller.status, EmployeeDiscoveryStatus.ready);
    expect(controller.profile!.routes, ['/restaurant']);
    expect(discovered, 0);
  });

  test('connection failure retries the same saved host without fallback discovery', () async {
    await store.save(_profile);
    var attempts = 0, discovered = 0;
    final controller = EmployeeDiscoveryController(store: store,
      discoverHosts: () async { discovered += 1; return []; },
      reconnectHost: (host) async {
        expect(host.toJson(), _profile.toJson());
        if (++attempts == 1) throw const SocketException('Unavailable');
        return host;
      });
    addTearDown(controller.dispose);
    await controller.start();
    expect(controller.status, EmployeeDiscoveryStatus.failed);
    expect(controller.profile, isNull);
    await controller.start();
    expect(controller.status, EmployeeDiscoveryStatus.ready);
    expect(attempts, 2);
    expect(discovered, 0);
  });

  test('first initialization requires one host and persists it before ready', () async {
    final controller = EmployeeDiscoveryController(store: store,
      discoverHosts: () async => [_candidate], verifyHost: (_) async => _profile);
    addTearDown(controller.dispose);
    await controller.start();
    expect(controller.status, EmployeeDiscoveryStatus.ready);
    expect((await store.load())!.toJson(), _profile.toJson());
  });

  test('ambiguous first discovery does not verify or save either host', () async {
    var verified = 0;
    final controller = EmployeeDiscoveryController(store: store,
      discoverHosts: () async => [_candidate, _candidate],
      verifyHost: (_) async { verified += 1; return _profile; });
    addTearDown(controller.dispose);
    await controller.start();
    expect(controller.status, EmployeeDiscoveryStatus.failed);
    expect(verified, 0);
    expect(await store.load(), isNull);
  });

  test('failed persistence does not expose a business profile', () async {
    final blocker = File('${directory.path}/blocked');
    await blocker.writeAsString('fixture');
    final controller = EmployeeDiscoveryController(
      store: EmployeeHostStore(fileProvider: () async => File('${blocker.path}/host.json')),
      discoverHosts: () async => [_candidate], verifyHost: (_) async => _profile);
    addTearDown(controller.dispose);
    await controller.start();
    expect(controller.status, EmployeeDiscoveryStatus.failed);
    expect(controller.profile, isNull);
  });

  test('disposed discovery ignores a late network result without saving', () async {
    final entered = Completer<void>();
    final response = Completer<EmployeeHostProfile>();
    final controller = EmployeeDiscoveryController(store: store,
      discoverHosts: () async => [_candidate],
      verifyHost: (_) { entered.complete(); return response.future; });
    var notifications = 0;
    controller.addListener(() => notifications += 1);
    final start = controller.start();
    await entered.future;
    controller.dispose();
    final before = notifications;
    response.complete(_profile);
    await start;
    expect(notifications, before);
    expect(await store.load(), isNull);
    expect(controller.profile, isNull);
  });

  test('status verification uses the actual response certificate', () async {
    final http = _Http(_Response(200, jsonEncode({'ok': true, ..._profile.toJson()})), checkHandshake: false);
    await HttpOverrides.runZoned(() async {
      final host = await const PinnedHttpsClient().verify(_candidate);
      expect(host.toJson(), _profile.toJson());
      expect(http.requests.single.followRedirects, isFalse);
      expect(http.closed, isTrue);
    }, createHttpClient: (_) => http);
  });

  test('a different certificate is rejected before sending employee credentials', () async {
    final http = _Http(_Response(200, '{}', certificate: _Certificate(Uint8List.fromList([4, 5, 6]))));
    await HttpOverrides.runZoned(() async {
      final transport = PinnedEmployeeHttpTransport(_profile);
      await expectLater(transport.send(EmployeeBusinessModule.restaurant, '/login',
        method: 'POST', body: 'fixture'), throwsA(isA<HandshakeException>()));
      expect(http.requests, isEmpty);
      expect(http.closed, isTrue);
    }, createHttpClient: (_) => http);
  });

  test('employee requests cannot redirect or escape into another module', () async {
    final http = _Http(_Response(302, ''));
    await HttpOverrides.runZoned(() async {
      final transport = PinnedEmployeeHttpTransport(_profile);
      for (final endpoint in ['/../hotel', '/%2e%2e/hotel', '//other.example/login', '/login?redirect=other']) {
        await expectLater(transport.send(EmployeeBusinessModule.restaurant, endpoint), throwsFormatException);
      }
      await expectLater(transport.send(EmployeeBusinessModule.hotel, '/login'), throwsStateError);
      expect(http.requests, isEmpty);
      await expectLater(transport.send(EmployeeBusinessModule.restaurant, '/login'), throwsA(isA<HttpException>()));
      expect(http.requests.single.followRedirects, isFalse);
      expect(http.closed, isTrue);
    }, createHttpClient: (_) => http);
  });

  test('oversized status responses fail and close the connection', () async {
    final http = _Http(_Response(200, 'x' * (64 * 1024 + 1)));
    await HttpOverrides.runZoned(() async {
      await expectLater(const PinnedHttpsClient().verify(_candidate), throwsFormatException);
      expect(http.closed, isTrue);
    }, createHttpClient: (_) => http);
  });
}

// 使用网络边界替身验证发送顺序，不生成或保存证书私钥，不连接真实商家网络。
final class _Certificate implements X509Certificate {
  _Certificate(this.der);
  @override final Uint8List der;
  @override dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('Unused certificate field');
}

final class _Headers implements HttpHeaders {
  final values = <String, List<String>>{};
  @override void set(String name, Object value, {bool preserveHeaderCase = false}) { values[name] = [value.toString()]; }
  @override void forEach(void Function(String, List<String>) action) => values.forEach(action);
  @override dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('Unused header operation');
}

final class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.statusCode, this.body, {X509Certificate? certificate}) : certificate = certificate ?? _certificate;
  final String body;
  @override final int statusCode;
  @override final X509Certificate certificate;
  @override final HttpHeaders headers = _Headers();
  @override final List<Cookie> cookies = [];
  @override StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(utf8.encode(body)).listen(onData, onError: onError,
          onDone: onDone, cancelOnError: cancelOnError);
  @override dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('Unused response field');
}

final class _Request implements HttpClientRequest {
  _Request(this.response);
  final _Response response;
  @override final HttpHeaders headers = _Headers();
  @override final List<Cookie> cookies = [];
  @override bool followRedirects = true;
  @override void write(Object? object) {}
  @override Future<HttpClientResponse> close() async => response;
  @override dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('Unused request field');
}

final class _Http implements HttpClient {
  _Http(this.response, {this.checkHandshake = true});
  final _Response response;
  final bool checkHandshake;
  final requests = <_Request>[];
  bool closed = false;
  @override Duration? connectionTimeout;
  @override String Function(Uri)? findProxy;
  @override bool Function(X509Certificate, String, int)? badCertificateCallback;
  @override Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (checkHandshake && badCertificateCallback?.call(response.certificate, url.host, url.port) != true) {
      throw const HandshakeException('Fixture rejected by pin policy');
    }
    final request = _Request(response);
    requests.add(request);
    return request;
  }
  @override void close({bool force = false}) { closed = true; }
  @override dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError('Unused client field');
}
