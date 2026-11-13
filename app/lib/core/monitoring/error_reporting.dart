import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry/sentry.dart';

/// Crash and error reporting to Sentry. Off unless the build passes
/// `--dart-define=SENTRY_DSN=...`; nothing is sent from other builds.
///
/// The pure Dart SDK is used on purpose: it reports Dart errors with no
/// native iOS code to build. Events carry no user, no request, no
/// breadcrumbs, and their texts are scrubbed of e-mails, phone numbers and
/// tokens (see [scrubEvent]).
const sentryDsn = String.fromEnvironment('SENTRY_DSN');
const _environment = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'production',
);

/// `--dart-define=SENTRY_TEST_EVENT=true` sends one message at startup, to
/// check that alerts reach the owner.
const _sendTestEvent = bool.fromEnvironment('SENTRY_TEST_EVENT');

bool get errorReportingEnabled => sentryDsn.isNotEmpty;

Future<void> initErrorReporting() async {
  if (!errorReportingEnabled) return;
  await Sentry.init((o) {
    o.dsn = sentryDsn;
    o.environment = _environment;
    o.sendDefaultPii = false;
    o.maxBreadcrumbs = 0;
    o.tracesSampleRate = 0;
    o.beforeSend = (event, hint) => scrubEvent(event);
  });
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    previous?.call(details);
    unawaited(
      Sentry.captureException(details.exception, stackTrace: details.stack),
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(Sentry.captureException(error, stackTrace: stack));
    return true;
  };
  if (_sendTestEvent) {
    unawaited(Sentry.captureMessage('Khidma test event'));
  }
}

final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
final _digits = RegExp(r'\+?\d[\d ]{6,}\d');
final _token = RegExp(
  r'(eyJ[\w-]+\.[\w-]+\.[\w-]+|sb_[a-z]+_[\w-]{8,}|Bearer\s+\S+)',
);

/// Removes anything personal from a text: e-mail addresses, phone-like
/// numbers (7+ digits) and tokens. Long texts are cut to 300 characters.
@visibleForTesting
String scrubText(String text) {
  final out = text
      .replaceAll(_token, '[token]')
      .replaceAll(_email, '[email]')
      .replaceAll(_digits, '[number]');
  return out.length > 300 ? '${out.substring(0, 300)}…' : out;
}

/// What leaves the device: the error type, scrubbed texts and the stack.
SentryEvent scrubEvent(SentryEvent event) {
  event
    ..user = null
    ..request = null
    ..breadcrumbs = null
    ..serverName = null;
  final message = event.message;
  if (message != null) {
    message.formatted = scrubText(message.formatted);
  }
  for (final e in event.exceptions ?? const <SentryException>[]) {
    final value = e.value;
    if (value != null) e.value = scrubText(value);
  }
  return event;
}
