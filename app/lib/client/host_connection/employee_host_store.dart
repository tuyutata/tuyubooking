import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:tuyubooking/shared/network/pinned_https_client.dart';

final class EmployeeHostStore {
  const EmployeeHostStore({this._fileProvider});

  final Future<File> Function()? _fileProvider;

  Future<File> _file() async {
    if (_fileProvider != null) return _fileProvider();
    final support = await getApplicationSupportDirectory();
    return File('${support.path}/employee/host.json');
  }

  Future<EmployeeHostProfile?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    if (await file.length() > 64 * 1024) {
      throw const FormatException('Saved merchant host record is too large');
    }
    final decoded = jsonDecode(await file.readAsString());
    // 只有文件不存在才是首次初始化；损坏记录不能触发发现另一台商家主机。
    if (decoded is! Map) throw const FormatException('Invalid saved merchant host');
    return EmployeeHostProfile.fromJson(decoded.cast<String, Object?>());
  }

  Future<void> save(EmployeeHostProfile profile) async {
    final validated = EmployeeHostProfile.fromJson(profile.toJson());
    final file = await _file();
    await file.parent.create(recursive: true);
    // 临时目录属于本次写入；并发保存不共用 .tmp 文件，失败保留旧主机记录。
    final temporaryDirectory = await file.parent.createTemp('.host-');
    final temporary = File('${temporaryDirectory.path}/host.json');
    try {
      await temporary.writeAsString(jsonEncode(validated.toJson()), flush: true);
      await temporary.rename(file.path);
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  }
}
