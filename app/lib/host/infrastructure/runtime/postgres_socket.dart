import 'dart:io';

const int postgresUnixSocketPathLimit = 103;

/// Returns a short, process-scoped directory for PostgreSQL Unix sockets.
///
/// PostgreSQL appends `.s.PGSQL.<port>` to this value. Keeping the directory
/// under `/tmp` avoids macOS's 103-byte Unix-domain socket path limit while the
/// database itself remains in the merchant's application-support directory.
String? postgresSocketDirectory({int? processId}) {
  if (Platform.isWindows) return null;
  return '/tmp/tuyubooking-pg-${processId ?? pid}';
}
