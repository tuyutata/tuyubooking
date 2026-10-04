import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_models.dart';

typedef _NativeNoInput = Pointer<Utf8> Function();
typedef _DartNoInput = Pointer<Utf8> Function();
typedef _NativeWithInput = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _DartWithInput = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _NativeFree = Void Function(Pointer<Utf8>);
typedef _DartFree = void Function(Pointer<Utf8>);

abstract interface class NativeGateway {
  Future<NativeRuntimeSnapshot> start(NativeRuntimeRequest request);
  Future<NativeRuntimeSnapshot> runtimeSnapshot();
  Future<NativeRuntimeSnapshot> restartModule(MerchantSubsystem module);
  Future<NativeRuntimeSnapshot> configureBusinessModules(
    Set<MerchantSubsystem> modules,
  );
  Future<EmployeeGatewaySnapshot> employeeGatewaySnapshot();
  Future<EmployeeGatewaySnapshot> enableEmployeeGateway();
  Future<EmployeeGatewaySnapshot> disableEmployeeGateway();
  Future<void> stop();
  Future<Map<String, Object?>> contract();
  Future<AdministratorAssertionSnapshot> createAdministratorAssertion();
  Future<AdministratorStateSnapshot> administratorState();
  Future<NativeSessionSnapshot> initializeAdministrator({
    required QrLoginResponse response,
    String? name,
  });
  Future<List<AdministratorSnapshot>> listAdministrators();
  Future<AdministratorSnapshot> addAdministrator({
    required String publicKeyQr,
    String? name,
  });
  Future<AdministratorSnapshot> renameAdministrator({
    required String administratorId,
    String? name,
  });
  Future<AdministratorSnapshot> setAdministratorStatus({
    required String administratorId,
    required String status,
  });
  Future<void> deleteAdministrator(String administratorId);
  Future<QrLoginChallengeSnapshot> createQrLoginChallenge();
  Future<NativeSessionSnapshot> completeQrLogin(QrLoginResponse response);
}

abstract interface class AdministratorAssertionGateway {
  Future<AdministratorAssertionSnapshot> createAdministratorAssertion();
}

final class FfiNativeGateway
    implements NativeGateway, AdministratorAssertionGateway {
  const FfiNativeGateway();

  @override
  Future<AdministratorAssertionSnapshot> createAdministratorAssertion() async {
    final data = _map(
      await _invokeWithoutInput('tuyubooking_administrator_assertion'),
    );
    return AdministratorAssertionSnapshot(
      token: data['token'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        data['expires_at_millis'] as int,
        isUtc: true,
      ),
    );
  }

  @override
  Future<Map<String, Object?>> contract() async =>
      _map(await _invokeWithoutInput('tuyubooking_contract'));

  @override
  Future<NativeRuntimeSnapshot> start(NativeRuntimeRequest request) async =>
      _runtimeSnapshot(
        _map(
          await _invokeWithInput('tuyubooking_start', jsonEncode(request.toJson())),
        ),
      );

  @override
  Future<NativeRuntimeSnapshot> runtimeSnapshot() async => _runtimeSnapshot(
    _map(await _invokeWithoutInput('tuyubooking_runtime_snapshot')),
  );

  @override
  Future<NativeRuntimeSnapshot> restartModule(MerchantSubsystem module) async =>
      _runtimeSnapshot(
        _map(
          await _invokeWithInput(
            'tuyubooking_restart_module',
            jsonEncode({'module': module.name}),
          ),
        ),
      );

  @override
  Future<NativeRuntimeSnapshot> configureBusinessModules(
    Set<MerchantSubsystem> modules,
  ) async => _runtimeSnapshot(
    _map(
      await _invokeWithInput(
        'tuyubooking_configure_modules',
        jsonEncode({
          'modules': modules.map((module) => module.name).toList()..sort(),
        }),
      ),
    ),
  );

  @override
  Future<EmployeeGatewaySnapshot> employeeGatewaySnapshot() async =>
      EmployeeGatewaySnapshot.fromJson(
        _map(await _invokeWithoutInput('tuyubooking_employee_gateway_snapshot')),
      );

  @override
  Future<EmployeeGatewaySnapshot> enableEmployeeGateway() async =>
      EmployeeGatewaySnapshot.fromJson(
        _map(await _invokeWithoutInput('tuyubooking_enable_employee_gateway')),
      );

  @override
  Future<EmployeeGatewaySnapshot> disableEmployeeGateway() async =>
      EmployeeGatewaySnapshot.fromJson(
        _map(await _invokeWithoutInput('tuyubooking_disable_employee_gateway')),
      );

  @override
  Future<void> stop() async {
    _map(await _invokeWithoutInput('tuyubooking_stop'));
  }

  @override
  Future<AdministratorStateSnapshot> administratorState() async =>
      AdministratorStateSnapshot.fromJson(
        _map(await _invokeWithoutInput('tuyubooking_administrator_state')),
      );

  @override
  Future<NativeSessionSnapshot> initializeAdministrator({
    required QrLoginResponse response,
    String? name,
  }) async => _session(
    _map(
      await _invokeWithInput(
        'tuyubooking_initialize_administrator',
        jsonEncode({'response': response.toJson(), 'name': name}),
      ),
    ),
  );

  @override
  Future<List<AdministratorSnapshot>> listAdministrators() async => _list(
    await _invokeWithoutInput('tuyubooking_list_administrators'),
  ).map(AdministratorSnapshot.fromJson).toList(growable: false);

  @override
  Future<AdministratorSnapshot> addAdministrator({
    required String publicKeyQr,
    String? name,
  }) async => AdministratorSnapshot.fromJson(
    _map(
      await _invokeWithInput(
        'tuyubooking_add_administrator',
        jsonEncode({'public_key_qr': publicKeyQr, 'name': name}),
      ),
    ),
  );

  @override
  Future<AdministratorSnapshot> renameAdministrator({
    required String administratorId,
    String? name,
  }) async => AdministratorSnapshot.fromJson(
    _map(
      await _invokeWithInput(
        'tuyubooking_update_administrator_name',
        jsonEncode({'administrator_id': administratorId, 'name': name}),
      ),
    ),
  );

  @override
  Future<AdministratorSnapshot> setAdministratorStatus({
    required String administratorId,
    required String status,
  }) async => AdministratorSnapshot.fromJson(
    _map(
      await _invokeWithInput(
        'tuyubooking_update_administrator_status',
        jsonEncode({'administrator_id': administratorId, 'status': status}),
      ),
    ),
  );

  @override
  Future<void> deleteAdministrator(String administratorId) async {
    _map(
      await _invokeWithInput(
        'tuyubooking_delete_administrator',
        jsonEncode({'administrator_id': administratorId}),
      ),
    );
  }

  @override
  Future<QrLoginChallengeSnapshot> createQrLoginChallenge() async =>
      QrLoginChallengeSnapshot.fromJson(
        _map(await _invokeWithoutInput('tuyubooking_qr_login_challenge')),
      );

  @override
  Future<NativeSessionSnapshot> completeQrLogin(
    QrLoginResponse response,
  ) async => _session(
    _map(
      await _invokeWithInput(
        'tuyubooking_qr_login_complete',
        jsonEncode(response.toJson()),
      ),
    ),
  );

  NativeRuntimeSnapshot _runtimeSnapshot(Map<String, Object?> data) =>
      NativeRuntimeSnapshot(
        ready: data['ready'] == true,
        schemas: _strings(data['schemas']),
        businessReady: data['business_ready'] == true,
        httpsOrigin: data['https_origin'] as String? ?? '',
        modules: (data['modules'] as List<Object?>? ?? const [])
            .map(
              (value) => NativeModuleRuntimeState.fromJson(
                (value as Map).cast<String, Object?>(),
              ),
            )
            .toList(growable: false),
        moduleConfigurationComplete:
            data['module_configuration_complete'] == true,
        enabledModules: _strings(
          data['enabled_modules'] ?? const <String>[],
        ).map(MerchantSubsystem.values.byName).toList(growable: false),
      );

  NativeSessionSnapshot _session(Map<String, Object?> data) =>
      NativeSessionSnapshot(
        sessionId: data['session_id'] as String,
        administratorId: data['administrator_id'] as String,
        administratorName: data['administrator_name'] as String?,
        publicKeyFingerprint: data['public_key_fingerprint'] as String,
        subsystems: data['subsystems'] == null
            ? MerchantSubsystem.values
            : _strings(
                data['subsystems'],
              ).map(MerchantSubsystem.values.byName).toList(growable: false),
      );
}

Object? _data(String encoded) {
  final envelope = jsonDecode(encoded);
  if (envelope is! Map) {
    throw const FormatException('Native response is not a JSON object');
  }
  final map = envelope.cast<String, Object?>();
  if (map['ok'] != true) {
    final error = map['error'];
    final errorMap = error is Map
        ? error.cast<String, Object?>()
        : const <String, Object?>{};
    final message = errorMap['message'];
    final localized = message is Map
        ? message.cast<String, Object?>()
        : const <String, Object?>{};
    throw NativeBridgeException(
      code: '${errorMap['code'] ?? 'internal'}',
      zh: '${localized['zh_cn'] ?? '途遇商家端本地服务不可用'}',
      en: '${localized['en_us'] ?? 'The TuyuBooking native service is unavailable'}',
    );
  }
  return map['data'];
}

Map<String, Object?> _map(String encoded) {
  final value = _data(encoded);
  if (value is! Map) {
    throw const FormatException('Native response data is not an object');
  }
  return value.cast<String, Object?>();
}

List<Map<String, Object?>> _list(String encoded) {
  final value = _data(encoded);
  if (value is! List) {
    throw const FormatException('Native response data is not an array');
  }
  return value
      .map((item) => (item as Map).cast<String, Object?>())
      .toList(growable: false);
}

List<String> _strings(Object? value) {
  if (value is! List) throw const FormatException('Expected a JSON array');
  return value.map((item) => item as String).toList(growable: false);
}

// Rust 使用进程级互斥状态；所有调用在后台 isolate 内开库、分配并释放指针。
// 主 isolate 只排队和解析 JSON，数据库启动或关闭不会阻塞二维码与重绘。
Future<void> _nativeCalls = Future<void>.value();

Future<String> _invokeWithoutInput(String symbol) => _invokeNative(symbol, null);
Future<String> _invokeWithInput(String symbol, String payload) => _invokeNative(symbol, payload);

Future<String> _invokeNative(String symbol, String? payload) {
  final result = _nativeCalls.then((_) => Isolate.run(() {
    final library = _openNativeLibrary();
    if (payload == null) {
      final call = library.lookupFunction<_NativeNoInput, _DartNoInput>(symbol);
      return _takeNativeString(library, call());
    }
    final call = library.lookupFunction<_NativeWithInput, _DartWithInput>(symbol);
    final input = payload.toNativeUtf8();
    try {
      return _takeNativeString(library, call(input));
    } finally {
      malloc.free(input);
    }
  }));
  // 单次失败必须传给调用方，但不能使后续重试和停止请求永久跳过。
  _nativeCalls = result.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
  return result;
}

String _takeNativeString(DynamicLibrary library, Pointer<Utf8> pointer) {
  if (pointer == nullptr) {
    throw const FormatException('Native response is null');
  }
  final free = library.lookupFunction<_NativeFree, _DartFree>(
    'tuyubooking_string_free',
  );
  try {
    return pointer.toDartString();
  } finally {
    free(pointer);
  }
}

DynamicLibrary _openNativeLibrary() {
  final names = switch (Platform.operatingSystem) {
    'macos' => [
      '${File(Platform.resolvedExecutable).parent.path}/../Frameworks/libtuyubooking_native.dylib',
      'libtuyubooking_native.dylib',
    ],
    'windows' => ['tuyubooking_native.dll'],
    'linux' => [
      '${File(Platform.resolvedExecutable).parent.path}/lib/libtuyubooking_native.so',
      'libtuyubooking_native.so',
    ],
    _ => const <String>[],
  };
  final candidates = <DynamicLibrary>[DynamicLibrary.process()];
  for (final name in names) {
    try {
      candidates.add(DynamicLibrary.open(name));
    } on ArgumentError {
      // Continue to the next packaged-library location.
    }
  }
  for (final library in candidates) {
    try {
      library.lookup<NativeFunction<_NativeNoInput>>('tuyubooking_contract');
      return library;
    } on ArgumentError {
      // The runner may not statically link the native archive in development.
    }
  }
  throw UnsupportedError(
    'TuyuBooking native library is not packaged for this platform',
  );
}
