import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_bridge.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_models.dart';
import 'package:tuyubooking/host/infrastructure/runtime/postgres_socket.dart';

enum RuntimeStatus { idle, starting, ready, degraded, failed }

abstract interface class RuntimeConfigurationProvider {
  Future<NativeRuntimeRequest> create();
}

final class DesktopRuntimeConfiguration
    implements RuntimeConfigurationProvider {
  DesktopRuntimeConfiguration({RuntimeSecretStore? secretStore})
    : _secretStore = secretStore ?? const FileRuntimeSecretStore();

  final RuntimeSecretStore _secretStore;

  @override
  Future<NativeRuntimeRequest> create() async {
    final support = await getApplicationSupportDirectory();
    final executableDir = File(Platform.resolvedExecutable).parent;
    final installationDir = Platform.isMacOS
        ? executableDir.parent
        : executableDir;
    final resourcesDir = Platform.isMacOS
        ? Directory('${installationDir.path}/Resources')
        : executableDir;
    final secrets = await _secretStore.readOrCreate(support);
    return NativeRuntimeRequest(
      binDir: '${resourcesDir.path}/postgresql/bin',
      installationDir: installationDir.path,
      dataDir: '${support.path}/postgresql',
      logFile: '${support.path}/logs/postgresql.log',
      socketDir: postgresSocketDirectory(),
      port: 55432,
      username: 'tuyubooking',
      database: 'tuyubooking',
      databasePassword: secrets.databasePassword,
      installationName: Platform.localHostname,
      merchantName: 'TuyuLove Merchant',
      timezone: DateTime.now().timeZoneName,
      currencyCode: 'CNY',
      businessRuntimeDir: '${resourcesDir.path}/business',
      businessDataRoot: '${support.path}/business',
      businessLogRoot: '${support.path}/logs/business',
      availableModules: MerchantSubsystem.values
          .map((module) => module.name)
          .toList(growable: false),
      publicHostname: Platform.localHostname,
      hotelAdministratorPassword: secrets.hotelAdministratorPassword,
      restaurantAdministratorPassword: secrets.restaurantAdministratorPassword,
    );
  }
}

abstract interface class RuntimeSecretStore {
  Future<RuntimeSecrets> readOrCreate(Directory applicationSupport);
}

final class RuntimeSecrets {
  const RuntimeSecrets({
    required this.databasePassword,
    required this.hotelAdministratorPassword,
    required this.restaurantAdministratorPassword,
  });

  final String databasePassword;
  final String hotelAdministratorPassword;
  final String restaurantAdministratorPassword;
}

/// Persists machine-internal bootstrap credentials without invoking an
/// interactive user credential store. These are not Tuyu user accounts.
final class FileRuntimeSecretStore implements RuntimeSecretStore {
  const FileRuntimeSecretStore();

  static const _database = 'database';
  static const _hotel = 'hotel_bootstrap';
  static const _restaurant = 'restaurant_bootstrap';

  @override
  Future<RuntimeSecrets> readOrCreate(Directory applicationSupport) async {
    final directory = Directory('${applicationSupport.path}/runtime');
    final file = File('${directory.path}/internal-secrets.json');
    if (await file.exists()) return _decode(await file.readAsString());

    await directory.create(recursive: true);
    await _restrict(directory.path, '700');
    final values = <String, String>{
      _database: _randomSecret(),
      _hotel: _randomSecret(),
      _restaurant: _randomSecret(),
    };
    final temporary = File('${file.path}.tmp-$pid');
    try {
      await temporary.writeAsString(jsonEncode(values), flush: true);
      await _restrict(temporary.path, '600');
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
    return _decode(jsonEncode(values));
  }

  static RuntimeSecrets _decode(String encoded) {
    final value = jsonDecode(encoded);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid internal runtime credential file');
    }
    String requiredSecret(String key) {
      final secret = value[key];
      if (secret is! String || secret.length < 32) {
        throw const FormatException('Invalid internal runtime credential file');
      }
      return secret;
    }

    return RuntimeSecrets(
      databasePassword: requiredSecret(_database),
      hotelAdministratorPassword: requiredSecret(_hotel),
      restaurantAdministratorPassword: requiredSecret(_restaurant),
    );
  }

  static String _randomSecret() {
    final random = Random.secure();
    return base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
  }

  static Future<void> _restrict(String path, String mode) async {
    if (Platform.isWindows) return;
    final result = await Process.run('/bin/chmod', [mode, path]);
    if (result.exitCode != 0) {
      throw FileSystemException(
        'Unable to protect internal runtime data',
        path,
      );
    }
  }
}

final class RuntimeController extends ChangeNotifier {
  RuntimeController({
    required this._gateway,
    required this._configuration,
  });

  final NativeGateway _gateway;
  final RuntimeConfigurationProvider _configuration;
  RuntimeStatus _status = RuntimeStatus.idle;
  RuntimeStatus get status => _status;
  Object? _error;
  Object? get error => _error;
  String? _httpsOrigin;
  String? get httpsOrigin => _httpsOrigin;
  Map<String, NativeModuleRuntimeState> _modules = const {};
  bool _refreshing = false;
  bool _stopping = false;
  bool _disposed = false;
  int _generation = 0;
  Future<void> _pending = Future<void>.value();
  Future<void>? _startFuture;
  Future<void>? _stopFuture;
  final Set<MerchantSubsystem> _restartingModules = {};
  Timer? _statusTimer;
  bool _moduleConfigurationComplete = false;
  bool get moduleConfigurationComplete => _moduleConfigurationComplete;
  Set<MerchantSubsystem> _enabledModules = const {};
  Set<MerchantSubsystem> get enabledModules => Set.unmodifiable(_enabledModules);
  bool _configuringModules = false;
  bool get isConfiguringModules => _configuringModules;

  NativeModuleRuntimeState? moduleState(MerchantSubsystem module) =>
      _modules[module.name];
  String? moduleOrigin(MerchantSubsystem module) => moduleState(module)?.httpsOrigin;
  bool isRestarting(MerchantSubsystem module) => _restartingModules.contains(module);

  bool get _canRun => !_disposed && !_stopping &&
      (_status == RuntimeStatus.ready || _status == RuntimeStatus.degraded);
  bool _current(int generation) =>
      !_disposed && !_stopping && generation == _generation;
  void _notify() { if (!_disposed) notifyListeners(); }

  // 本机生命周期按调用顺序执行；停止等待已发出的请求，不让旧响应覆盖新状态。
  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    return result;
  }

  Future<void> start() {
    if (_startFuture != null) return _startFuture!;
    if (_disposed || _stopping || _canRun) return Future<void>.value();
    return _startFuture = _start(++_generation);
  }

  Future<void> _start(int generation) async {
    _status = RuntimeStatus.starting;
    _error = null;
    _notify();
    try {
      final snapshot = await _enqueue<NativeRuntimeSnapshot?>(() async {
        if (!_current(generation)) return null;
        final request = await _configuration.create();
        if (!_current(generation)) return null;
        return _gateway.start(request);
      });
      if (_current(generation) && snapshot != null) {
        _apply(snapshot);
        _statusTimer ??= Timer.periodic(
          const Duration(seconds: 2), (_) => unawaited(refresh()),
        );
      }
    } on Object catch (error) {
      if (_current(generation)) _fail(error);
    } finally {
      _startFuture = null;
      _notify();
    }
  }

  Future<void> configureBusinessModules(Set<MerchantSubsystem> modules) async {
    if (!_canRun || modules.isEmpty || _configuringModules) return;
    // 调用方随后修改 UI 选择集合，不得改变已提交的启用配置。
    final selection = Set<MerchantSubsystem>.unmodifiable(modules);
    final generation = _generation;
    _configuringModules = true;
    _notify();
    try {
      final snapshot = await _enqueue<NativeRuntimeSnapshot?>(() async =>
          _current(generation) ? _gateway.configureBusinessModules(selection) : null);
      if (_current(generation) && snapshot != null) {
        _apply(snapshot);
        _error = null;
      }
    } on Object catch (error) {
      if (_current(generation)) _fail(error);
      rethrow;
    } finally {
      _configuringModules = false;
      _notify();
    }
  }

  Future<void> refresh() async {
    if (!_canRun || _refreshing || _configuringModules || _restartingModules.isNotEmpty) return;
    final generation = _generation;
    _refreshing = true;
    try {
      final snapshot = await _enqueue<NativeRuntimeSnapshot?>(() async =>
          _current(generation) ? _gateway.runtimeSnapshot() : null);
      if (_current(generation) && snapshot != null) {
        _apply(snapshot);
        _error = null;
      }
    } on Object catch (error) {
      // 无法确认核心数据库健康时回到启动错误页，不能假装仅业务模块降级。
      if (_current(generation)) _fail(error);
    } finally {
      _refreshing = false;
      _notify();
    }
  }

  Future<void> restartModule(MerchantSubsystem module) async {
    if (!_canRun || _configuringModules || !_enabledModules.contains(module) ||
        !_restartingModules.add(module)) {
      return;
    }
    final generation = _generation;
    _notify();
    try {
      final snapshot = await _enqueue<NativeRuntimeSnapshot?>(() async =>
          _current(generation) ? _gateway.restartModule(module) : null);
      if (_current(generation) && snapshot != null) {
        _apply(snapshot);
        _error = null;
      }
    } on Object catch (error) {
      if (_current(generation)) _fail(error);
    } finally {
      _restartingModules.remove(module);
      _notify();
    }
  }

  Future<void> stop() {
    if (_stopFuture != null) return _stopFuture!;
    if (_status == RuntimeStatus.idle && _startFuture == null) return Future<void>.value();
    _stopping = true;
    _generation += 1;
    _statusTimer?.cancel();
    _statusTimer = null;
    return _stopFuture = _stop();
  }

  Future<void> _stop() async {
    try {
      await _enqueue(_gateway.stop);
      _modules = const {};
      _enabledModules = const {};
      _moduleConfigurationComplete = false;
      _httpsOrigin = null;
      _error = null;
      _status = RuntimeStatus.idle;
    } on Object catch (error) {
      _fail(error);
      rethrow;
    } finally {
      _stopping = false;
      _stopFuture = null;
      _notify();
    }
  }

  void _fail(Object error) {
    _error = error;
    _status = RuntimeStatus.failed;
    _httpsOrigin = null;
    _modules = const {};
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  void _apply(NativeRuntimeSnapshot snapshot) {
    if (!snapshot.ready || !snapshot.schemas.contains('tuyu_core')) {
      throw const NativeBridgeException(
        code: 'startup.database_unavailable',
        zh: '本地数据库暂不可用，请检查本机数据服务后重试',
        en: 'The local database is unavailable. Check the local data service and retry',
      );
    }
    _httpsOrigin = snapshot.httpsOrigin;
    _modules = {for (final module in snapshot.modules) module.id: module};
    _moduleConfigurationComplete = snapshot.moduleConfigurationComplete;
    _enabledModules = snapshot.enabledModules.toSet();
    final degraded = _enabledModules.any((module) {
      final state = moduleState(module);
      return state == null || const {
        NativeModuleRuntimeStatus.disabled,
        NativeModuleRuntimeStatus.payloadMissing,
        NativeModuleRuntimeStatus.degraded,
        NativeModuleRuntimeStatus.failed,
        NativeModuleRuntimeStatus.stopping,
        NativeModuleRuntimeStatus.stopped,
      }.contains(state.status);
    });
    // 核心可用即可进入系统，业务模块仍可处于启动中；停用模块不影响核心就绪。
    _status = degraded ? RuntimeStatus.degraded : RuntimeStatus.ready;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    _statusTimer?.cancel();
    super.dispose();
  }
}
