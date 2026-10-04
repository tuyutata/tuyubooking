import 'package:flutter/foundation.dart';

/// The two independently installed applications produced by TuyuBooking.
///
/// This guard fails immediately when a scripts command selects an entrypoint
/// for the wrong platform. It does not add a runtime mode switch: host and
/// client remain separate build inputs with separate dependency boundaries.
enum TuyuBookingApplicationTarget {
  host,
  client;

  bool supports(TargetPlatform platform) => switch (this) {
    host => const {
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }.contains(platform),
    client => const {
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    }.contains(platform),
  };

  void requireSupportedPlatform([TargetPlatform? platform]) {
    final resolved = platform ?? defaultTargetPlatform;
    if (supports(resolved)) return;
    throw UnsupportedError(
      'TuyuBooking $name cannot run on ${resolved.name}.',
    );
  }
}
