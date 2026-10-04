import 'dart:convert';

enum MerchantSubsystem { hotel, restaurant, tour, ticket }

const tuyuAccountProtocol = 'TUYU';
const tuyuAccountProtocolVersion = 1;

final class NativeRuntimeRequest {
  const NativeRuntimeRequest({
    required this.binDir,
    required this.installationDir,
    required this.dataDir,
    required this.logFile,
    required this.socketDir,
    required this.port,
    required this.username,
    required this.database,
    required this.databasePassword,
    required this.installationName,
    required this.merchantName,
    required this.timezone,
    required this.currencyCode,
    required this.businessRuntimeDir,
    required this.businessDataRoot,
    required this.businessLogRoot,
    required this.availableModules,
    required this.publicHostname,
    required this.hotelAdministratorPassword,
    required this.restaurantAdministratorPassword,
  });

  final String binDir;
  final String installationDir;
  final String dataDir;
  final String logFile;
  final String? socketDir;
  final int port;
  final String username;
  final String database;
  final String databasePassword;
  final String installationName;
  final String merchantName;
  final String timezone;
  final String currencyCode;
  final String businessRuntimeDir;
  final String businessDataRoot;
  final String businessLogRoot;
  final List<String> availableModules;
  final String publicHostname;
  final String hotelAdministratorPassword;
  final String restaurantAdministratorPassword;

  Map<String, Object?> toJson() => {
    'bin_dir': binDir,
    'installation_dir': installationDir,
    'data_dir': dataDir,
    'log_file': logFile,
    'socket_dir': socketDir,
    'port': port,
    'username': username,
    'database': database,
    'database_password': databasePassword,
    'installation_name': installationName,
    'merchant_name': merchantName,
    'timezone': timezone,
    'currency_code': currencyCode,
    'business_runtime_dir': businessRuntimeDir,
    'business_data_root': businessDataRoot,
    'business_log_root': businessLogRoot,
    'available_modules': availableModules,
    'public_hostname': publicHostname,
    'hotel_administrator_password': hotelAdministratorPassword,
    'restaurant_administrator_password': restaurantAdministratorPassword,
  };
}

final class NativeRuntimeSnapshot {
  const NativeRuntimeSnapshot({
    required this.ready,
    required this.schemas,
    this.businessReady = false,
    this.httpsOrigin = '',
    this.modules = const [],
    this.moduleConfigurationComplete = false,
    this.enabledModules = const [],
  });
  final bool ready;
  final List<String> schemas;
  final bool businessReady;
  final String httpsOrigin;
  final List<NativeModuleRuntimeState> modules;
  final bool moduleConfigurationComplete;
  final List<MerchantSubsystem> enabledModules;
}

enum NativeModuleRuntimeStatus {
  disabled,
  payloadMissing,
  installed,
  starting,
  ready,
  degraded,
  failed,
  stopping,
  stopped;

  static NativeModuleRuntimeStatus parse(String value) => switch (value) {
    'DISABLED' => disabled,
    'PAYLOAD_MISSING' => payloadMissing,
    'INSTALLED' => installed,
    'STARTING' => starting,
    'READY' => ready,
    'DEGRADED' => degraded,
    'FAILED' => failed,
    'STOPPING' => stopping,
    'STOPPED' => stopped,
    _ => throw FormatException('Unknown module runtime status: $value'),
  };
}

final class NativeModuleRuntimeState {
  const NativeModuleRuntimeState({
    required this.id,
    required this.status,
    required this.schema,
    this.httpsOrigin,
    this.error,
  });

  factory NativeModuleRuntimeState.fromJson(Map<String, Object?> json) =>
      NativeModuleRuntimeState(
        id: json['id'] as String,
        status: NativeModuleRuntimeStatus.parse(json['status'] as String),
        schema: json['schema'] as String,
        httpsOrigin: json['https_origin'] as String?,
        error: json['error'] as String?,
      );

  final String id;
  final NativeModuleRuntimeStatus status;
  final String schema;
  final String? httpsOrigin;
  final String? error;
}

final class AdministratorStateSnapshot {
  const AdministratorStateSnapshot({
    required this.initialized,
    required this.total,
    required this.active,
  });

  factory AdministratorStateSnapshot.fromJson(Map<String, Object?> json) =>
      AdministratorStateSnapshot(
        initialized: json['initialized'] == true,
        total: json['total'] as int,
        active: json['active'] as int,
      );

  final bool initialized;
  final int total;
  final int active;
}

final class AdministratorSnapshot {
  const AdministratorSnapshot({
    required this.id,
    required this.publicKey,
    required this.name,
    required this.status,
  });

  factory AdministratorSnapshot.fromJson(Map<String, Object?> json) =>
      AdministratorSnapshot(
        id: json['id'] as String,
        publicKey: json['public_key'] as String,
        name: json['name'] as String?,
        status: json['status'] as String,
      );

  final String id;
  final String publicKey;
  final String? name;
  final String status;
  bool get isActive => status == 'active';
}

final class QrLoginChallengeSnapshot {
  const QrLoginChallengeSnapshot({
    required this.protocol,
    required this.version,
    required this.kind,
    required this.requestId,
    required this.expiresAtMilliseconds,
    required this.operation,
    required this.audience,
    required this.target,
    required this.subject,
    required this.device,
    required this.keyRevision,
    required this.nonce,
  });

  factory QrLoginChallengeSnapshot.fromJson(Map<String, Object?> json) {
    const fields = {'p', 'v', 'k', 'i', 'e', 'b'};
    if (json.length != fields.length ||
        json.keys.any((field) => !fields.contains(field)) ||
        json['b'] is! Map) {
      throw const FormatException('TUYU login challenge fields are invalid');
    }
    final body = (json['b']! as Map).cast<String, Object?>();
    const bodyFields = {'o', 'a', 't', 'j', 'd', 'r', 'n'};
    if (body.length != bodyFields.length ||
        body.keys.any((field) => !bodyFields.contains(field))) {
      throw const FormatException('TUYU login challenge body is invalid');
    }
    final value = QrLoginChallengeSnapshot(
      protocol: json['p'] as String,
      version: json['v'] as int,
      kind: json['k'] as int,
      requestId: json['i'] as String,
      expiresAtMilliseconds: json['e'] as int,
      operation: body['o'] as int,
      audience: body['a'] as String,
      target: body['t'] as String,
      subject: body['j'] as String,
      device: body['d'] as String,
      keyRevision: body['r'] as int,
      nonce: body['n'] as String,
    );
    if (value.protocol != tuyuAccountProtocol ||
        value.version != tuyuAccountProtocolVersion ||
        value.kind != 1 ||
        value.operation != 2 ||
        value.audience != 'tuyubooking' ||
        value.target.isEmpty ||
        !RegExp(r'^tyc_[0-9a-f]{32}$').hasMatch(value.requestId) ||
        !_isCanonicalHex(value.nonce, 32)) {
      throw const FormatException(
        'TUYU login challenge constraints are invalid',
      );
    }
    return value;
  }

  final String protocol;
  final int version;
  final int kind;
  final String requestId;
  final int expiresAtMilliseconds;
  final int operation;
  final String audience;
  final String target;
  final String subject;
  final String device;
  final int keyRevision;
  final String nonce;

  Map<String, Object?> toJson() => {
    'p': protocol,
    'v': version,
    'k': kind,
    'i': requestId,
    'e': expiresAtMilliseconds,
    'b': {
      'o': operation,
      'a': audience,
      't': target,
      'j': subject,
      'd': device,
      'r': keyRevision,
      'n': nonce,
    },
  };

  String toQrPayload() => jsonEncode(toJson());
}

final class QrLoginResponse {
  const QrLoginResponse({
    required this.protocol,
    required this.version,
    required this.kind,
    required this.requestId,
    required this.expiresAtMilliseconds,
    required this.publicKey,
    required this.signature,
  });

  factory QrLoginResponse.fromQrPayload(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('QR login response must be an object');
    }
    final json = decoded.cast<String, Object?>();
    const fields = {'p', 'v', 'k', 'i', 'e', 'b'};
    if (json.length != fields.length ||
        json.keys.any((field) => !fields.contains(field)) ||
        json['b'] is! Map) {
      throw const FormatException('QR login response fields are invalid');
    }
    final body = (json['b']! as Map).cast<String, Object?>();
    const bodyFields = {'u', 's'};
    if (body.length != bodyFields.length ||
        body.keys.any((field) => !bodyFields.contains(field))) {
      throw const FormatException('QR login response body is invalid');
    }
    final value = QrLoginResponse(
      protocol: json['p'] as String,
      version: json['v'] as int,
      kind: json['k'] as int,
      requestId: json['i'] as String,
      expiresAtMilliseconds: json['e'] as int,
      publicKey: body['u'] as String,
      signature: body['s'] as String,
    );
    if (value.protocol != tuyuAccountProtocol ||
        value.version != tuyuAccountProtocolVersion ||
        value.kind != 2 ||
        !_isCanonicalHex(value.publicKey, 32) ||
        !_isCanonicalHex(value.signature, 64)) {
      throw const FormatException('QR login response constraints are invalid');
    }
    return value;
  }

  final String protocol;
  final int version;
  final int kind;
  final String requestId;
  final int expiresAtMilliseconds;
  final String publicKey;
  final String signature;

  Map<String, Object?> toJson() => {
    'p': protocol,
    'v': version,
    'k': kind,
    'i': requestId,
    'e': expiresAtMilliseconds,
    'b': {'u': publicKey, 's': signature},
  };
}

bool _isCanonicalHex(String value, int bytes) =>
    RegExp('^0x[0-9a-f]{${bytes * 2}}\$').hasMatch(value);

final class NativeSessionSnapshot {
  const NativeSessionSnapshot({
    required this.sessionId,
    required this.administratorId,
    required this.administratorName,
    required this.publicKeyFingerprint,
    required this.subsystems,
  });

  final String sessionId;
  final String administratorId;
  final String? administratorName;
  final String publicKeyFingerprint;
  final List<MerchantSubsystem> subsystems;
}

enum NativeEmployeeGatewayStatus {
  disabled,
  starting,
  ready,
  failed,
  stopping;

  static NativeEmployeeGatewayStatus parse(String value) => switch (value) {
    'DISABLED' => disabled,
    'STARTING' => starting,
    'READY' => ready,
    'FAILED' => failed,
    'STOPPING' => stopping,
    _ => throw FormatException('Unknown employee gateway status: $value'),
  };
}

final class EmployeeGatewayRouteSnapshot {
  const EmployeeGatewayRouteSnapshot({
    required this.module,
    required this.path,
  });

  factory EmployeeGatewayRouteSnapshot.fromJson(Map<String, Object?> json) =>
      EmployeeGatewayRouteSnapshot(
        module: json['module'] as String,
        path: json['path'] as String,
      );

  final String module;
  final String path;
}

final class EmployeeGatewaySnapshot {
  const EmployeeGatewaySnapshot({
    required this.enabled,
    required this.status,
    required this.httpsOrigin,
    required this.certificateFingerprint,
    required this.routes,
    required this.error,
  });

  factory EmployeeGatewaySnapshot.fromJson(Map<String, Object?> json) =>
      EmployeeGatewaySnapshot(
        enabled: json['enabled'] == true,
        status: NativeEmployeeGatewayStatus.parse(json['status'] as String),
        httpsOrigin: json['https_origin'] as String,
        certificateFingerprint: json['certificate_fingerprint'] as String?,
        routes: (json['routes'] as List<Object?>? ?? const [])
            .map(
              (value) => EmployeeGatewayRouteSnapshot.fromJson(
                (value as Map).cast<String, Object?>(),
              ),
            )
            .toList(growable: false),
        error: json['error'] as String?,
      );

  final bool enabled;
  final NativeEmployeeGatewayStatus status;
  final String httpsOrigin;
  final String? certificateFingerprint;
  final List<EmployeeGatewayRouteSnapshot> routes;
  final String? error;
}

final class NativeBridgeException implements Exception {
  const NativeBridgeException({
    required this.code,
    required this.zh,
    required this.en,
  });
  final String code;
  final String zh;
  final String en;

  String localized(String languageCode) => languageCode == 'zh' ? zh : en;
}

final class AdministratorAssertionSnapshot {
  const AdministratorAssertionSnapshot({
    required this.token,
    required this.expiresAt,
  });

  final String token;
  final DateTime expiresAt;
}
