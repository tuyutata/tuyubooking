import 'package:flutter/foundation.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_bridge.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_models.dart';
import 'package:tuyubooking/host/authentication/auth_model.dart';

final class AuthController extends ChangeNotifier {
  AuthController({required this.nativeGateway});

  final NativeGateway nativeGateway;

  AuthStatus _status = AuthStatus.unchecked;
  AuthStatus get status => _status;
  bool get isBusy => const {
    AuthStatus.checking,
    AuthStatus.requestingChallenge,
    AuthStatus.verifying,
  }.contains(_status);
  bool get hasCheckedState => _status != AuthStatus.unchecked;

  AdministratorStateSnapshot? _administratorState;
  AdministratorStateSnapshot? get administratorState => _administratorState;
  QrLoginChallengeSnapshot? _challenge;
  QrLoginChallengeSnapshot? get challenge => _challenge;
  NativeSessionSnapshot? _nativeSession;
  NativeSessionSnapshot? get nativeSession => _nativeSession;
  Object? _error;
  Object? get error => _error;

  Future<void> loadAdministratorState() async {
    if (_status != AuthStatus.unchecked && _status != AuthStatus.failed) return;
    _setStatus(AuthStatus.checking);
    _error = null;
    try {
      _administratorState = await nativeGateway.administratorState();
      _setStatus(
        _administratorState!.initialized
            ? AuthStatus.idle
            : AuthStatus.requiresInitialization,
      );
    } on Object catch (error) {
      _fail(error);
    }
  }

  Future<void> initializeAdministrator({
    required String signedResponseQr,
    String? name,
  }) async {
    if (isBusy ||
        _status != AuthStatus.awaitingSignature ||
        _administratorState?.initialized == true ||
        _challenge == null) {
      return;
    }
    _setStatus(AuthStatus.verifying);
    _error = null;
    try {
      final response = _responseForCurrentChallenge(signedResponseQr);
      _nativeSession = await nativeGateway.initializeAdministrator(
        response: response,
        name: name,
      );
      _challenge = null;
      _administratorState = const AdministratorStateSnapshot(
        initialized: true,
        total: 1,
        active: 1,
      );
      _setStatus(AuthStatus.authenticated);
    } on Object catch (error) {
      _fail(error);
    }
  }

  Future<void> createInitializationChallenge() async {
    if (isBusy || _status != AuthStatus.requiresInitialization) return;
    await _requestChallenge();
  }

  Future<void> createLoginChallenge() async {
    if (isBusy || _administratorState?.initialized != true) return;
    await _requestChallenge();
  }

  Future<void> _requestChallenge() async {
    _setStatus(AuthStatus.requestingChallenge);
    _error = null;
    try {
      _challenge = await nativeGateway.createQrLoginChallenge();
      _setStatus(AuthStatus.awaitingSignature);
    } on Object catch (error) {
      _fail(error);
    }
  }

  Future<void> completeLoginQr(String rawQr) async {
    if (isBusy || _challenge == null) return;
    _setStatus(AuthStatus.verifying);
    _error = null;
    try {
      final response = _responseForCurrentChallenge(rawQr);
      _nativeSession = await nativeGateway.completeQrLogin(response);
      _challenge = null;
      _setStatus(AuthStatus.authenticated);
    } on Object catch (error) {
      _fail(error);
    }
  }

  QrLoginResponse _responseForCurrentChallenge(String rawQr) {
    final challenge = _challenge;
    if (challenge == null) {
      throw StateError('A current TUYU challenge is required');
    }
    final response = QrLoginResponse.fromQrPayload(rawQr);
    if (response.requestId != challenge.requestId ||
        response.expiresAtMilliseconds != challenge.expiresAtMilliseconds) {
      throw const FormatException(
        'The TUYU response does not belong to the current challenge',
      );
    }
    return response;
  }

  Future<AdministratorAssertionSnapshot> createAdministratorAssertion() {
    final gateway = nativeGateway;
    if (_nativeSession == null || gateway is! AdministratorAssertionGateway) {
      throw StateError('A verified administrator session is required');
    }
    return gateway.createAdministratorAssertion();
  }

  void invalidateSession() {
    _nativeSession = null;
    _challenge = null;
    _error = null;
    _setStatus(AuthStatus.idle);
  }

  void retry() {
    _error = null;
    if (_administratorState?.initialized == true) {
      _setStatus(AuthStatus.idle);
    } else {
      _setStatus(AuthStatus.requiresInitialization);
    }
  }

  void _fail(Object error) {
    _error = error;
    _setStatus(AuthStatus.failed);
  }

  void _setStatus(AuthStatus value) {
    _status = value;
    notifyListeners();
  }
}
