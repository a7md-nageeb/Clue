import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Waits for Supabase OAuth to redirect back to a local loopback URL.
///
/// Desktop OAuth cannot rely on custom URL schemes unless they are registered
/// in Supabase Auth redirect URLs. A loopback HTTP server is the standard fix.
Future<AuthSessionUrlResponse> waitForMacOsOAuthCallback({
  required GoTrueClient auth,
  required Uri redirectUri,
  Duration timeout = const Duration(minutes: 5),
}) async {
  final port = redirectUri.port;
  final expectedPath = redirectUri.path.isEmpty ? '/' : redirectUri.path;

  final server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    port,
    shared: true,
  );

  try {
    final request = await server.first.timeout(timeout);
    final uri = request.requestedUri;

    if (uri.path != expectedPath) {
      throw AuthException('Unexpected OAuth callback path: ${uri.path}');
    }

    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html
      ..write(
        '<!DOCTYPE html><html><body style="font-family:system-ui;text-align:center;padding:48px;">'
        '<h2>Signed in successfully</h2>'
        '<p>You can close this tab and return to Clue.</p>'
        '</body></html>',
      );
    await request.response.close();

    return auth.getSessionFromUrl(uri);
  } on TimeoutException {
    throw AuthException(
      'Google Sign-In timed out. Complete sign-in in your browser and try again.',
    );
  } finally {
    await server.close(force: true);
  }
}
