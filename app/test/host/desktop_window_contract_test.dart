import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../shared/source_paths.dart';

void main() {
  test('macOS, Linux, and Windows share the desktop window contract', () {
    final root = bookingAppSource.path;
    final macXib = File(
      '$root/macos/Runner/Base.lproj/MainMenu.xib',
    ).readAsStringSync();
    final macWindow = File(
      '$root/macos/Runner/MainFlutterWindow.swift',
    ).readAsStringSync();
    final macInfo = File('$root/macos/Runner/Info.plist').readAsStringSync();
    final linuxWindow = File(
      '$root/linux/runner/my_application.cc',
    ).readAsStringSync();
    final windowsMain = File(
      '$root/windows/runner/main.cpp',
    ).readAsStringSync();
    final windowsWindow = File(
      '$root/windows/runner/win32_window.cpp',
    ).readAsStringSync();

    expect(macXib, contains('width="1280" height="720"'));
    expect(macWindow, contains('NSSize(width: 1000, height: 680)'));
    expect(macWindow, contains('TuyuBookingMainWindow'));
    expect(macInfo, contains('<key>CFBundleDisplayName</key>'));
    expect(macInfo, contains('<key>CFBundleName</key>'));
    expect(
      macInfo,
      matches(RegExp(
        r'<key>CFBundleDisplayName</key>\s*<string>\$\(TUYU_BOOKING_PRODUCT_NAME\)</string>',
      )),
    );
    // 系统显示名称取产品的本地化名称，不再取安装包或主机/分机名称。
    expect(macInfo, matches(RegExp(
      r'<key>CFBundleName</key>\s*<string>\$\(TUYU_BOOKING_PRODUCT_NAME\)</string>',
    )));
    expect(macInfo, contains(r'<string>$(EXECUTABLE_NAME)</string>'));
    expect(
      linuxWindow,
      contains('gtk_window_set_default_size(window, 1280, 720)'),
    );
    expect(linuxWindow, contains('geometry.min_width = 1000'));
    expect(linuxWindow, contains('geometry.min_height = 680'));
    expect(windowsMain, contains('Win32Window::Size size(1280, 720)'));
    expect(windowsWindow, contains('MulDiv(1000, dpi'));
    expect(windowsWindow, contains('MulDiv(680, dpi'));
  });
}
