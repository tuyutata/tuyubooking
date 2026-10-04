import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tuyubooking/host/host_app.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_bridge.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_models.dart';
import 'package:tuyubooking/shared/qr/qr_scanner.dart';
import 'package:tuyubooking/host/infrastructure/runtime/runtime_controller.dart';
import 'package:tuyubooking/host/administrators/administrator_controller.dart';
import 'package:tuyubooking/host/authentication/auth_controller.dart';

final class FakeNativeGateway
    implements NativeGateway, AdministratorAssertionGateway {
  FakeNativeGateway({NativeRuntimeSnapshot? snapshot, bool initialized = true})
    : _snapshot =
          snapshot ?? (initialized ? readySnapshot : unconfiguredSnapshot),
      _initialized = initialized,
      _administrators = initialized
          ? [
              const AdministratorSnapshot(
                id: '019d-admin-0001',
                publicKey:
                    '0x1111111111111111111111111111111111111111111111111111111111111111',
                name: 'Test Administrator',
                status: 'active',
              ),
            ]
          : [];

  static const readySnapshot = NativeRuntimeSnapshot(
    ready: true,
    schemas: [
      'tuyu_core',
      'module_kamra',
      'module_ury',
      'module_voyant',
      'module_hi_events',
    ],
    businessReady: true,
    moduleConfigurationComplete: true,
    enabledModules: [
      MerchantSubsystem.hotel,
      MerchantSubsystem.restaurant,
      MerchantSubsystem.tour,
      MerchantSubsystem.ticket,
    ],
    httpsOrigin: 'https://merchant.local:58443',
    modules: [
      NativeModuleRuntimeState(
        id: 'hotel',
        status: NativeModuleRuntimeStatus.ready,
        schema: 'module_kamra',
        httpsOrigin: 'https://merchant.local:58443',
      ),
      NativeModuleRuntimeState(
        id: 'restaurant',
        status: NativeModuleRuntimeStatus.ready,
        schema: 'module_ury',
        httpsOrigin: 'https://merchant.local:58450',
      ),
      NativeModuleRuntimeState(
        id: 'tour',
        status: NativeModuleRuntimeStatus.ready,
        schema: 'module_voyant',
        httpsOrigin: 'https://merchant.local:58444',
      ),
      NativeModuleRuntimeState(
        id: 'ticket',
        status: NativeModuleRuntimeStatus.ready,
        schema: 'module_hi_events',
        httpsOrigin: 'https://merchant.local:58446',
      ),
    ],
  );

  static const unconfiguredSnapshot = NativeRuntimeSnapshot(
    ready: true,
    schemas: ['tuyu_core'],
    businessReady: true,
    modules: [
      NativeModuleRuntimeState(
        id: 'hotel',
        status: NativeModuleRuntimeStatus.disabled,
        schema: 'module_kamra',
      ),
      NativeModuleRuntimeState(
        id: 'restaurant',
        status: NativeModuleRuntimeStatus.disabled,
        schema: 'module_ury',
      ),
      NativeModuleRuntimeState(
        id: 'tour',
        status: NativeModuleRuntimeStatus.disabled,
        schema: 'module_voyant',
      ),
      NativeModuleRuntimeState(
        id: 'ticket',
        status: NativeModuleRuntimeStatus.disabled,
        schema: 'module_hi_events',
      ),
    ],
  );

  NativeRuntimeSnapshot _snapshot;
  EmployeeGatewaySnapshot _employeeGateway = const EmployeeGatewaySnapshot(
    enabled: false,
    status: NativeEmployeeGatewayStatus.disabled,
    httpsOrigin: 'https://merchant.local:58460',
    certificateFingerprint: null,
    routes: [],
    error: null,
  );
  bool _initialized;
  List<AdministratorSnapshot> _administrators;
  final List<MerchantSubsystem> restartedModules = [];
  final List<Set<MerchantSubsystem>> configuredModuleSets = [];
  int stopCount = 0;
  final List<QrLoginResponse> initializationResponses = [];

  static const qrChallenge = QrLoginChallengeSnapshot(
    protocol: 'TUYU',
    version: 1,
    kind: 1,
    requestId: 'tyc_00112233445566778899aabbccddeeff',
    expiresAtMilliseconds: 2000000000000,
    operation: 2,
    audience: 'tuyubooking',
    target: '018f6f50-6f68-7c18-8ef7-0d683f9d2c11',
    subject: '',
    device: '',
    keyRevision: 0,
    nonce: '0x2222222222222222222222222222222222222222222222222222222222222222',
  );

  @override
  Future<Map<String, Object?>> contract() async => {
    'product': 'TuyuBooking',
    'product_code': 'TuyuBooking',
    'contract_version': 8,
    'subsystems': ['hotel', 'restaurant', 'tour', 'ticket'],
  };

  @override
  Future<AdministratorAssertionSnapshot> createAdministratorAssertion() async =>
      AdministratorAssertionSnapshot(
        token: 'assertion-token',
        expiresAt: DateTime.utc(2026, 8, 27, 1),
      );

  @override
  Future<AdministratorStateSnapshot> administratorState() async =>
      AdministratorStateSnapshot(
        initialized: _initialized,
        total: _administrators.length,
        active: _administrators.where((value) => value.isActive).length,
      );

  @override
  Future<NativeSessionSnapshot> initializeAdministrator({
    required QrLoginResponse response,
    String? name,
  }) async {
    if (_initialized) throw StateError('Already initialized');
    initializationResponses.add(response);
    _initialized = true;
    final administrator = AdministratorSnapshot(
      id: '019d-admin-0001',
      publicKey: response.publicKey,
      name: name?.trim().isEmpty == true ? null : name?.trim(),
      status: 'active',
    );
    _administrators = [administrator];
    return _session(administrator);
  }

  @override
  Future<List<AdministratorSnapshot>> listAdministrators() async =>
      List.unmodifiable(_administrators);

  @override
  Future<AdministratorSnapshot> addAdministrator({
    required String publicKeyQr,
    String? name,
  }) async {
    final number = _administrators.length + 1;
    final administrator = AdministratorSnapshot(
      id: '019d-admin-${number.toString().padLeft(4, '0')}',
      publicKey: '0x${number.toRadixString(16).padLeft(64, '0')}',
      name: name?.trim().isEmpty == true ? null : name?.trim(),
      status: 'active',
    );
    _administrators = [..._administrators, administrator];
    return administrator;
  }

  @override
  Future<AdministratorSnapshot> renameAdministrator({
    required String administratorId,
    String? name,
  }) async => _update(
    administratorId,
    (value) => AdministratorSnapshot(
      id: value.id,
      publicKey: value.publicKey,
      name: name?.trim().isEmpty == true ? null : name?.trim(),
      status: value.status,
    ),
  );

  @override
  Future<AdministratorSnapshot> setAdministratorStatus({
    required String administratorId,
    required String status,
  }) async => _update(
    administratorId,
    (value) => AdministratorSnapshot(
      id: value.id,
      publicKey: value.publicKey,
      name: value.name,
      status: status,
    ),
  );

  @override
  Future<void> deleteAdministrator(String administratorId) async {
    _administrators = _administrators
        .where((value) => value.id != administratorId)
        .toList(growable: false);
  }

  AdministratorSnapshot _update(
    String id,
    AdministratorSnapshot Function(AdministratorSnapshot) update,
  ) {
    final current = _administrators.firstWhere((value) => value.id == id);
    final updated = update(current);
    _administrators = _administrators
        .map((value) => value.id == id ? updated : value)
        .toList(growable: false);
    return updated;
  }

  @override
  Future<QrLoginChallengeSnapshot> createQrLoginChallenge() async =>
      qrChallenge;

  @override
  Future<NativeSessionSnapshot> completeQrLogin(
    QrLoginResponse response,
  ) async => _session(_administrators.first);

  NativeSessionSnapshot _session(AdministratorSnapshot administrator) =>
      NativeSessionSnapshot(
        sessionId: 'session-1',
        administratorId: administrator.id,
        administratorName: administrator.name,
        publicKeyFingerprint: '22' * 32,
        subsystems: MerchantSubsystem.values,
      );

  @override
  Future<NativeRuntimeSnapshot> start(NativeRuntimeRequest request) async =>
      _snapshot;

  @override
  Future<NativeRuntimeSnapshot> runtimeSnapshot() async => _snapshot;

  @override
  Future<NativeRuntimeSnapshot> configureBusinessModules(
    Set<MerchantSubsystem> modules,
  ) async {
    configuredModuleSets.add(Set.of(modules));
    final states = MerchantSubsystem.values
        .map(
          (module) => NativeModuleRuntimeState(
            id: module.name,
            status: modules.contains(module)
                ? NativeModuleRuntimeStatus.ready
                : NativeModuleRuntimeStatus.disabled,
            schema: _schema(module),
            httpsOrigin: modules.contains(module) ? _origin(module) : null,
          ),
        )
        .toList(growable: false);
    _snapshot = NativeRuntimeSnapshot(
      ready: true,
      schemas: ['tuyu_core', ...modules.map(_schema)],
      businessReady: true,
      moduleConfigurationComplete: true,
      enabledModules: modules.toList(growable: false),
      httpsOrigin: modules.isEmpty ? '' : _origin(modules.first),
      modules: states,
    );
    return _snapshot;
  }

  @override
  Future<EmployeeGatewaySnapshot> employeeGatewaySnapshot() async =>
      _employeeGateway;

  @override
  Future<EmployeeGatewaySnapshot> enableEmployeeGateway() async {
    _employeeGateway = const EmployeeGatewaySnapshot(
      enabled: true,
      status: NativeEmployeeGatewayStatus.ready,
      httpsOrigin: 'https://merchant.local:58460',
      certificateFingerprint:
          '1111111111111111111111111111111111111111111111111111111111111111',
      routes: [
        EmployeeGatewayRouteSnapshot(module: 'hotel', path: '/hotel'),
        EmployeeGatewayRouteSnapshot(module: 'restaurant', path: '/restaurant'),
        EmployeeGatewayRouteSnapshot(module: 'tour', path: '/tour'),
        EmployeeGatewayRouteSnapshot(module: 'ticket', path: '/ticket'),
      ],
      error: null,
    );
    return _employeeGateway;
  }

  @override
  Future<EmployeeGatewaySnapshot> disableEmployeeGateway() async {
    _employeeGateway = const EmployeeGatewaySnapshot(
      enabled: false,
      status: NativeEmployeeGatewayStatus.disabled,
      httpsOrigin: 'https://merchant.local:58460',
      certificateFingerprint: null,
      routes: [],
      error: null,
    );
    return _employeeGateway;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }

  @override
  Future<NativeRuntimeSnapshot> restartModule(MerchantSubsystem module) async {
    restartedModules.add(module);
    final modules = _snapshot.modules
        .map(
          (state) => state.id == module.name
              ? NativeModuleRuntimeState(
                  id: state.id,
                  status: NativeModuleRuntimeStatus.ready,
                  schema: state.schema,
                  httpsOrigin: _origin(module),
                )
              : state,
        )
        .toList(growable: false);
    _snapshot = NativeRuntimeSnapshot(
      ready: true,
      schemas: _snapshot.schemas,
      businessReady: true,
      moduleConfigurationComplete: _snapshot.moduleConfigurationComplete,
      enabledModules: _snapshot.enabledModules,
      httpsOrigin: modules.first.httpsOrigin!,
      modules: modules,
    );
    return _snapshot;
  }

  static String _origin(MerchantSubsystem module) => switch (module) {
    MerchantSubsystem.hotel => 'https://merchant.local:58443',
    MerchantSubsystem.restaurant => 'https://merchant.local:58450',
    MerchantSubsystem.tour => 'https://merchant.local:58444',
    MerchantSubsystem.ticket => 'https://merchant.local:58446',
  };

  static String _schema(MerchantSubsystem module) => switch (module) {
    MerchantSubsystem.hotel => 'module_kamra',
    MerchantSubsystem.restaurant => 'module_ury',
    MerchantSubsystem.tour => 'module_voyant',
    MerchantSubsystem.ticket => 'module_hi_events',
  };
}

final class FakeQrScanner implements QrScanner, EmbeddedQrScanner {
  FakeQrScanner([Iterable<String> responses = const []])
    : _responses = List.of(responses);

  final List<String> _responses;
  int scanCount = 0;

  @override
  Widget buildEmbedded({
    Key? key,
    required EmbeddedQrScanCallback onScanned,
    required String preparingMessage,
    String? preparingSecondaryMessage,
    required String scanningMessage,
    String? scanningSecondaryMessage,
    required String recognizedMessage,
    String? recognizedSecondaryMessage,
    required String unavailableMessage,
    String? unavailableSecondaryMessage,
  }) => Builder(
    key: key,
    builder: (context) => FilledButton(
      key: const ValueKey('fake-embedded-qr-scan'),
      onPressed: _responses.isEmpty
          ? null
          : () async {
              scanCount += 1;
              await onScanned(_responses.removeAt(0));
            },
      child: Text(scanningMessage),
    ),
  );

  @override
  Future<String?> scan(
    BuildContext context, {
    required String title,
    required String instruction,
    required String unavailableMessage,
    required String cancelLabel,
  }) async {
    scanCount += 1;
    return _responses.isEmpty ? null : _responses.removeAt(0);
  }
}

final class FakeRuntimeConfiguration implements RuntimeConfigurationProvider {
  @override
  Future<NativeRuntimeRequest> create() async => const NativeRuntimeRequest(
    binDir: '/bundle/postgresql/bin',
    installationDir: '/bundle',
    dataDir: '/data/postgresql',
    logFile: '/data/postgresql.log',
    socketDir: '/data/socket',
    port: 55432,
    username: 'tuyubooking',
    database: 'tuyubooking',
    databasePassword: 'test-only',
    installationName: 'test',
    merchantName: 'test',
    timezone: 'UTC',
    currencyCode: 'CNY',
    businessRuntimeDir: '/bundle/business',
    businessDataRoot: '/data/business',
    businessLogRoot: '/data/logs/business',
    availableModules: ['hotel', 'restaurant', 'tour', 'ticket'],
    publicHostname: 'merchant.local',
    hotelAdministratorPassword: 'test-only-hotel-admin',
    restaurantAdministratorPassword: 'test-only-restaurant-admin',
  );
}

String fakeLoginResponse(QrLoginChallengeSnapshot challenge) => jsonEncode({
  'p': challenge.protocol,
  'v': challenge.version,
  'k': 2,
  'i': challenge.requestId,
  'e': challenge.expiresAtMilliseconds,
  'b': {
    'u': '0x7c0f469d3bd340bae718203fa30ca071a5e37c751e891dbded837b213d45d91d',
    's':
        '0x2abc1f9292ea9e9cd023fa66be59e59ada5ebbe93e483e97d7733a6a8b2c1023cb193142b795704b355f88c493fa521fdb5bea6198a75aca3f3fa17d777e6980',
  },
});

Future<void> authenticate(AppDependencies dependencies) async {
  await dependencies.auth.loadAdministratorState();
  await dependencies.auth.createLoginChallenge();
  await dependencies.auth.completeLoginQr(
    fakeLoginResponse(dependencies.auth.challenge!),
  );
}

AppDependencies testDependencies({
  FakeNativeGateway? nativeGateway,
  QrScanner? scanner,
}) {
  final native = nativeGateway ?? FakeNativeGateway();
  final auth = AuthController(nativeGateway: native);
  return AppDependencies(
    runtime: RuntimeController(
      gateway: native,
      configuration: FakeRuntimeConfiguration(),
    ),
    auth: auth,
    administrators: AdministratorController(nativeGateway: native, auth: auth),
    qrScanner: scanner ?? FakeQrScanner(),
  );
}
