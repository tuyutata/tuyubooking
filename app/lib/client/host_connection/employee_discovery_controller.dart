import 'package:flutter/foundation.dart';
import 'package:tuyubooking/shared/network/pinned_https_client.dart';
import 'package:tuyubooking/client/host_connection/employee_host_store.dart';
import 'package:tuyubooking/client/host_connection/mdns_discovery.dart';

enum EmployeeDiscoveryStatus { idle, initializing, connecting, ready, failed }

final class EmployeeDiscoveryController extends ChangeNotifier {
  EmployeeDiscoveryController({
    this.discovery = const TuyuBookingMdnsDiscovery(),
    this.client = const PinnedHttpsClient(),
    this.store = const EmployeeHostStore(),
    this.discoverHosts,
    this.verifyHost,
    this.reconnectHost,
  });

  final TuyuBookingMdnsDiscovery discovery;
  final PinnedHttpsClient client;
  final EmployeeHostStore store;
  // 测试可替换网络边界，生产默认仍使用同一发现和 HTTPS 实现。
  final Future<List<DiscoveredTuyuBookingHost>> Function()? discoverHosts;
  final Future<EmployeeHostProfile> Function(DiscoveredTuyuBookingHost)? verifyHost;
  final Future<EmployeeHostProfile> Function(EmployeeHostProfile)? reconnectHost;
  EmployeeDiscoveryStatus status = EmployeeDiscoveryStatus.idle;
  EmployeeHostProfile? profile;
  Object? error;
  Future<void>? _starting;
  bool _disposed = false;

  Future<void> start() {
    if (_starting != null) return _starting!;
    if (_disposed || status == EmployeeDiscoveryStatus.ready) return Future<void>.value();
    return _starting = _connect();
  }

  Future<void> _connect() async {
    status = EmployeeDiscoveryStatus.connecting;
    profile = null;
    error = null;
    notifyListeners();
    try {
      final fixedHost = await store.load();
      if (_disposed) return;
      if (fixedHost != null) {
        // 已保存地址及证书是重连依据，失败只重试该主机，不退回局域网发现。
        final connected = await (reconnectHost?.call(fixedHost) ?? client.reconnect(fixedHost));
        if (_disposed) return;
        profile = connected;
      } else {
        status = EmployeeDiscoveryStatus.initializing;
        notifyListeners();
        final hosts = await (discoverHosts?.call() ?? discovery.discover());
        if (_disposed) return;
        if (hosts.length != 1) {
          throw StateError('TuyuBooking client initialization requires exactly one LAN host.');
        }
        final connected = await (verifyHost?.call(hosts.single) ?? client.verify(hosts.single));
        if (_disposed) return;
        await store.save(connected);
        if (_disposed) return;
        // 保存成功之前不发布 profile，防止失败状态仍进入业务页面。
        profile = connected;
      }
      status = EmployeeDiscoveryStatus.ready;
    } on Object catch (caught) {
      if (!_disposed) {
        profile = null;
        error = caught;
        status = EmployeeDiscoveryStatus.failed;
      }
    } finally {
      _starting = null;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
