import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

/// Scopes requested for the Spotify integration. `user-read-recently-played`
/// powers the nightly poller; `user-read-private` is needed only to
/// resolve the Spotify user id on first connect.
const _scopes = 'user-read-recently-played user-read-private';

/// One-shot PKCE helper. Generates the verifier+challenge pair, opens
/// the system auth session via flutter_web_auth_2, and returns the
/// authorization code together with the verifier so the server can
/// complete the exchange.
class SpotifyAuthorization {
  const SpotifyAuthorization({required this.code, required this.codeVerifier});
  final String code;
  final String codeVerifier;
}

class SpotifyOAuth {
  SpotifyOAuth({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  /// Runs the user-facing PKCE leg of the OAuth flow. Throws
  /// [FormatException] if the user cancels or Spotify returns an error.
  Future<SpotifyAuthorization> authorize({
    required String clientId,
    required String redirectUri,
  }) async {
    final verifier = _generateCodeVerifier();
    final challenge = _challengeFor(verifier);
    final state = _generateState();

    final authorizeUrl = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'scope': _scopes,
      'state': state,
    });

    final callbackScheme = Uri.parse(redirectUri).scheme;
    final result = await FlutterWebAuth2.authenticate(
      url: authorizeUrl.toString(),
      callbackUrlScheme: callbackScheme,
    );

    final returned = Uri.parse(result);
    final returnedState = returned.queryParameters['state'];
    if (returnedState != state) {
      throw const FormatException('spotify state mismatch');
    }
    final error = returned.queryParameters['error'];
    if (error != null) {
      throw FormatException('spotify auth error: $error');
    }
    final code = returned.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const FormatException('spotify returned no code');
    }

    return SpotifyAuthorization(code: code, codeVerifier: verifier);
  }

  String _generateCodeVerifier() {
    // 32 random bytes → 43-char base64url, comfortably inside Spotify's
    // 43–128 length window.
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _challengeFor(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  String _generateState() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
