import 'dart:io';
import 'package:yaml/yaml.dart';

/// 合同输入读取原始产品源码；源码外测试工程通过 TUYUBOOKING_ROOT 明确来源。
/// 仅在实际 app 目录运行时允许按父目录定位，禁止猜测外部工程的父路径。
Directory resolveBookingSource({
  Map<String, String>? environment,
  Directory? workingDirectory,
}) {
  final env = environment ?? Platform.environment;
  final current = workingDirectory ?? Directory.current;
  final configured = env['TUYUBOOKING_ROOT'];
  final Directory product;
  if (configured != null) {
    if (configured.isEmpty || !Directory(configured).isAbsolute) {
      throw StateError('TUYUBOOKING_ROOT must identify the absolute original TuyuBooking product');
    }
    product = Directory(configured);
  } else {
    if (current.uri.pathSegments.where((part) => part.isNotEmpty).last != 'app') {
      throw StateError('Contract tests require the original TUYUBOOKING_ROOT');
    }
    product = current.parent;
  }
  final manifest = File('${product.path}/app/pubspec.yaml');
  if (!manifest.existsSync() ||
      !Directory('${product.path}/host').existsSync() ||
      !Directory('${product.path}/scripts').existsSync() ||
      (loadYaml(manifest.readAsStringSync()) as Map)['name'] != 'tuyubooking') {
    throw StateError('Contract source is not the original TuyuBooking product');
  }
  return Directory(product.resolveSymbolicLinksSync());
}

Directory get bookingSource => resolveBookingSource();
Directory get bookingAppSource => Directory('${bookingSource.path}/app');

File bookingSourceFile(String relative) {
  if (relative.isEmpty || File(relative).isAbsolute ||
      relative.split(RegExp(r'[/\\]')).any((part) => part == '..')) {
    throw ArgumentError.value(relative, 'relative', 'Must stay inside the product');
  }
  return File('${bookingSource.path}/$relative');
}

File bookingAppFile(String relative) => bookingSourceFile('app/$relative');
Directory bookingAppDirectory(String relative) =>
    Directory(bookingAppFile(relative).path);
