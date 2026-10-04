import 'package:flutter/foundation.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_bridge.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_models.dart';
import 'package:tuyubooking/host/authentication/auth_controller.dart';

enum AdministratorManagementStatus { idle, loading, working, failed }

final class AdministratorController extends ChangeNotifier {
  AdministratorController({required this.nativeGateway, required this.auth});

  final NativeGateway nativeGateway;
  final AuthController auth;

  AdministratorManagementStatus _status = AdministratorManagementStatus.idle;
  AdministratorManagementStatus get status => _status;
  bool get isBusy => const {
    AdministratorManagementStatus.loading,
    AdministratorManagementStatus.working,
  }.contains(_status);
  List<AdministratorSnapshot> _administrators = const [];
  List<AdministratorSnapshot> get administrators => _administrators;
  Object? _error;
  Object? get error => _error;

  Future<void> load() async {
    _setStatus(AdministratorManagementStatus.loading);
    _error = null;
    try {
      _administrators = await nativeGateway.listAdministrators();
      _setStatus(AdministratorManagementStatus.idle);
    } on Object catch (error) {
      _fail(error);
    }
  }

  Future<void> add({required String publicKeyQr, String? name}) async {
    await _run(() async {
      final added = await nativeGateway.addAdministrator(
        publicKeyQr: publicKeyQr,
        name: name,
      );
      _administrators = [..._administrators, added];
    });
  }

  Future<void> rename(String administratorId, String? name) async {
    await _run(() async {
      final updated = await nativeGateway.renameAdministrator(
        administratorId: administratorId,
        name: name,
      );
      _replace(updated);
    });
  }

  Future<void> setStatus(String administratorId, bool active) async {
    await _run(() async {
      final updated = await nativeGateway.setAdministratorStatus(
        administratorId: administratorId,
        status: active ? 'active' : 'disabled',
      );
      _replace(updated);
      if (!active && auth.nativeSession?.administratorId == administratorId) {
        auth.invalidateSession();
      }
    });
  }

  Future<void> delete(String administratorId) async {
    await _run(() async {
      await nativeGateway.deleteAdministrator(administratorId);
      _administrators = _administrators
          .where((value) => value.id != administratorId)
          .toList(growable: false);
      if (auth.nativeSession?.administratorId == administratorId) {
        auth.invalidateSession();
      }
    });
  }

  void _replace(AdministratorSnapshot updated) {
    _administrators = _administrators
        .map((value) => value.id == updated.id ? updated : value)
        .toList(growable: false);
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (isBusy) return;
    _setStatus(AdministratorManagementStatus.working);
    _error = null;
    try {
      await operation();
      _setStatus(AdministratorManagementStatus.idle);
    } on Object catch (error) {
      _fail(error);
    }
  }

  void _fail(Object error) {
    _error = error;
    _setStatus(AdministratorManagementStatus.failed);
  }

  void _setStatus(AdministratorManagementStatus value) {
    _status = value;
    notifyListeners();
  }
}
