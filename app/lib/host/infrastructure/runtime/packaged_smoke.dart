import 'dart:convert';
import 'dart:io';

import 'package:tuyubooking/host/infrastructure/native_bridge/native_bridge.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_models.dart';
import 'package:tuyubooking/host/infrastructure/runtime/postgres_socket.dart';

/// Runs only when the signed macOS app is launched by the Release smoke test.
/// The host bundle never contains an administrator private key, so this smoke
/// verifies the core database and clean first-install state. Signed
/// initialization and module activation are covered by external protocol and
/// native-runtime tests. The smoke still crosses the real FFI account boundary
/// so a dropped PostgreSQL reactor cannot masquerade as a successful startup.
Future<int> runPackagedSmoke() async {
  final environment = Platform.environment;
  final rootValue = environment['TUYU_PACKAGED_SMOKE_ROOT'];
  final resultValue = environment['TUYU_PACKAGED_SMOKE_RESULT'];
  if (rootValue == null || resultValue == null) {
    stderr.writeln('Packaged smoke paths were not provided.');
    return 64;
  }

  final root = Directory(rootValue)..createSync(recursive: true);
  final resultFile = File(resultValue);
  final executableDirectory = File(Platform.resolvedExecutable).parent;
  final contents = executableDirectory.parent;
  final resources = Directory('${contents.path}/Resources');
  const password = 'step6-local-database-password';
  const gateway = FfiNativeGateway();
  final socketDir = postgresSocketDirectory();
  if (socketDir == null) {
    stderr.writeln('The macOS smoke test requires a Unix socket directory.');
    return 64;
  }
  Map<String, Object?> result;

  final request = NativeRuntimeRequest(
    binDir: '${resources.path}/postgresql/bin',
    installationDir: contents.path,
    dataDir: '${root.path}/postgresql',
    logFile: '${root.path}/logs/postgresql.log',
    socketDir: socketDir,
    port: 55432,
    username: 'tuyubooking',
    database: 'tuyubooking',
    databasePassword: password,
    installationName: 'Step 6 cold start',
    merchantName: 'Step 6 merchant',
    timezone: 'UTC',
    currencyCode: 'CNY',
    businessRuntimeDir: '${resources.path}/business',
    businessDataRoot: '${root.path}/business',
    businessLogRoot: '${root.path}/logs/business',
    availableModules: MerchantSubsystem.values
        .map((module) => module.name)
        .toList(growable: false),
    publicHostname: 'localhost',
    hotelAdministratorPassword: 'step6-hotel-administrator',
    restaurantAdministratorPassword: 'step6-restaurant-administrator',
  );

  try {
    final first = await gateway.start(request);
    _assertCleanCore(first);
    await _assertUninitializedAccountReady(gateway);
    final firstInstallationId = await _installationId(
      resources: resources,
      socketDir: socketDir,
      password: password,
    );

    await gateway.stop();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final second = await gateway.start(request);
    _assertCleanCore(second);
    await _assertUninitializedAccountReady(gateway);
    final secondInstallationId = await _installationId(
      resources: resources,
      socketDir: socketDir,
      password: password,
    );
    if (secondInstallationId != firstInstallationId) {
      throw StateError(
        'PostgreSQL installation identity changed across restart.',
      );
    }
    await gateway.stop();
    result = <String, Object?>{
      'ok': true,
      'installation_id': firstInstallationId,
    };
  } on Object catch (error, stackTrace) {
    final nativeError = error is NativeBridgeException ? error : null;
    result = <String, Object?>{
      'ok': false,
      'error': '$error',
      if (nativeError != null) 'native_code': nativeError.code,
      if (nativeError != null) 'native_zh': nativeError.zh,
      if (nativeError != null) 'native_en': nativeError.en,
      'stack': '$stackTrace',
    };
  } finally {
    try {
      await gateway.stop();
    } on Object {
      // A failed or already stopped runtime needs no additional cleanup.
    }
  }

  resultFile.parent.createSync(recursive: true);
  resultFile.writeAsStringSync(jsonEncode(result), flush: true);
  return result['ok'] == true ? 0 : 1;
}

Future<void> _assertUninitializedAccountReady(FfiNativeGateway gateway) async {
  final administratorState = await gateway.administratorState();
  if (administratorState.initialized ||
      administratorState.total != 0 ||
      administratorState.active != 0) {
    throw StateError(
      'A clean first installation already contains an administrator.',
    );
  }
  final challenge = await gateway.createQrLoginChallenge();
  if (challenge.protocol != tuyuAccountProtocol ||
      challenge.version != tuyuAccountProtocolVersion ||
      challenge.kind != 1 ||
      challenge.operation != 2 ||
      challenge.audience != 'tuyubooking') {
    throw StateError('The packaged TUYU initialization challenge is invalid.');
  }
}

void _assertCleanCore(NativeRuntimeSnapshot snapshot) {
  if (!snapshot.ready || !snapshot.schemas.contains('tuyu_core')) {
    throw StateError('The packaged core database did not become ready.');
  }
  if (snapshot.moduleConfigurationComplete ||
      snapshot.enabledModules.isNotEmpty ||
      snapshot.modules.any(
        (module) => module.status != NativeModuleRuntimeStatus.disabled,
      )) {
    throw StateError(
      'A clean first installation started a business subsystem before selection.',
    );
  }
}

Future<String> _installationId({
  required Directory resources,
  required String socketDir,
  required String password,
}) async {
  final process = await Process.run(
    '${resources.path}/postgresql/bin/psql',
    <String>[
      '--no-psqlrc',
      '--host',
      socketDir,
      '--port',
      '55432',
      '--username',
      'tuyubooking',
      '--dbname',
      'tuyubooking',
      '--tuples-only',
      '--no-align',
      '--command',
      'SELECT id::text FROM tuyu_core.installation '
          'ORDER BY created_at ASC LIMIT 1',
    ],
    environment: <String, String>{'PGPASSWORD': password},
  );
  if (process.exitCode != 0) {
    throw ProcessException(
      '${resources.path}/postgresql/bin/psql',
      const <String>[],
      '${process.stderr}',
      process.exitCode,
    );
  }
  final installationId = '${process.stdout}'.trim();
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  ).hasMatch(installationId)) {
    throw StateError('Invalid PostgreSQL installation identity.');
  }
  return installationId;
}
