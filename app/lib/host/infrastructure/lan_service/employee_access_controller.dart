import 'package:flutter/foundation.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_bridge.dart';
import 'package:tuyubooking/host/infrastructure/native_bridge/native_models.dart';

final class EmployeeAccessController extends ChangeNotifier {
  EmployeeAccessController({NativeGateway? nativeGateway})
    : _nativeGateway = nativeGateway ?? const FfiNativeGateway();

  final NativeGateway _nativeGateway;
  EmployeeGatewaySnapshot? _snapshot;
  EmployeeGatewaySnapshot? get snapshot => _snapshot;
  Object? _error;
  Object? get error => _error;
  bool _busy = false;
  bool get busy => _busy;

  Future<void> refresh() => _run(_nativeGateway.employeeGatewaySnapshot);

  Future<void> enable() => _run(_nativeGateway.enableEmployeeGateway);

  Future<void> disable() => _run(_nativeGateway.disableEmployeeGateway);

  Future<void> _run(Future<EmployeeGatewaySnapshot> Function() action) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _snapshot = await action();
    } on Object catch (error) {
      _error = error;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
