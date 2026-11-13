import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/core/monitoring/error_reporting.dart';
import 'package:sentry/sentry.dart';

void main() {
  test('reporting is off unless the build sets SENTRY_DSN', () {
    expect(errorReportingEnabled, isFalse);
  });

  test('texts lose e-mails, phone numbers and tokens, and are capped', () {
    expect(
      scrubText('Échec pour ali@example.tn au +216 20 123 456'),
      'Échec pour [email] au [number]',
    );
    expect(
      scrubText('jwt eyJhbGciOi.eyJzdWIiOi.c2lnbmF0dXJl and Bearer abc.def'),
      'jwt [token] and [token]',
    );
    expect(scrubText('key sb_secret_abcdef123456'), 'key [token]');
    expect(scrubText('Request 42 failed'), 'Request 42 failed');
    expect(scrubText('x' * 400).length, 301);
  });

  test('events leave without user, request, breadcrumbs or server name', () {
    final event = SentryEvent(
      message: SentryMessage('Login failed for ali@example.tn'),
      exceptions: [
        SentryException(
          type: 'PostgrestException',
          value: 'phone 21620123456 taken',
        ),
      ],
      user: SentryUser(id: 'u1', email: 'ali@example.tn'),
      request: SentryRequest(
        url: 'https://x.supabase.co/rest/v1/profiles?phone=eq.2162012',
      ),
      breadcrumbs: [Breadcrumb(message: 'tapped')],
      serverName: 'iPhone de Ali',
    );
    final out = scrubEvent(event);
    expect(out.user, isNull);
    expect(out.request, isNull);
    expect(out.breadcrumbs, isNull);
    expect(out.serverName, isNull);
    expect(out.message!.formatted, 'Login failed for [email]');
    expect(out.exceptions!.single.value, 'phone [number] taken');
    expect(out.exceptions!.single.type, 'PostgrestException');
  });
}
