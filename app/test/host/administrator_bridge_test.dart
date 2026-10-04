import 'package:flutter_test/flutter_test.dart';
import 'package:tuyubooking/host/infrastructure/runtime/external_url_launcher.dart';

void main() {
  test('administrator hand-off requires HTTPS and keeps token in fragment', () {
    final uri = ExternalUrlLauncher.validate(
      'https://merchant.local:58443/tuyu_admin#assertion=secret',
    );
    expect(uri.scheme, 'https');
    expect(uri.fragment, 'assertion=secret');
    expect(uri.query, isEmpty);
  });

  test('restaurant administrator target remains in the URL fragment', () {
    final uri = ExternalUrlLauncher.validate(
      'https://merchant.local:58443/tuyu_admin#assertion=secret&target=ury',
    );
    expect(Uri.splitQueryString(uri.fragment)['target'], 'ury');
    expect(uri.query, isEmpty);
  });

  test('Voyant administrator hand-off uses the dedicated HTTPS port', () {
    final uri = ExternalUrlLauncher.validate(
      'https://merchant.local:58444/tuyu_admin#assertion=secret',
    );
    expect(uri.port, 58444);
    expect(uri.fragment, 'assertion=secret');
    expect(uri.query, isEmpty);
  });

  test('Hi.Events administrator hand-off uses the ticket HTTPS port', () {
    final uri = ExternalUrlLauncher.validate(
      'https://merchant.local:58446/tuyu_admin#assertion=secret',
    );
    expect(uri.port, 58446);
    expect(uri.fragment, 'assertion=secret');
    expect(uri.query, isEmpty);
  });

  test('administrator hand-off rejects plaintext HTTP', () {
    expect(
      () => ExternalUrlLauncher.validate(
        'http://merchant.local:58443/tuyu_admin#assertion=secret',
      ),
      throwsFormatException,
    );
  });
}
