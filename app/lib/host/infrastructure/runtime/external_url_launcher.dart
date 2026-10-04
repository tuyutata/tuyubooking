import 'dart:io';

final class ExternalUrlLauncher {
  const ExternalUrlLauncher();

  Future<void> open(String value) async {
    final uri = validate(value);
    final Process process;
    if (Platform.isMacOS) {
      process = await Process.start('open', [uri.toString()]);
    } else if (Platform.isWindows) {
      process = await Process.start('rundll32', [
        'url.dll,FileProtocolHandler',
        uri.toString(),
      ]);
    } else if (Platform.isLinux) {
      process = await Process.start('xdg-open', [uri.toString()]);
    } else {
      throw UnsupportedError('TuyuBooking supports desktop platforms only');
    }
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw ProcessException(
        'open',
        [uri.toString()],
        'Browser launch failed',
        exitCode,
      );
    }
  }

  static Uri validate(String value) {
    final uri = Uri.parse(value);
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.fragment.isEmpty) {
      throw const FormatException(
        'Administrator launch URL must use HTTPS and a fragment token',
      );
    }
    return uri;
  }
}
