import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Spotify OAuth2 PKCE flow for Flutter Web
/// Handles login, token refresh, and secure storage via localStorage
class SpotifyAuth {
  static const clientId = '1bf984dbd8a84110bb6e1b29a589136c';
  static const _clientSecret = 'bc9a9b510e5a484b82285033297584f7';
  static const _scopes = 'user-modify-playback-state user-read-playback-state user-read-currently-playing';

  // Fixed HTTPS redirect URI — always works regardless of Flutter port
  static const _redirectUri = 'https://smithmk-demo.vercel.app/spotify-callback.html';

  static String? _accessToken;
  static DateTime? _expiresAt;
  static String? _refreshToken;

  /// Check if we have a valid token
  static bool get isAuthenticated => _accessToken != null && _expiresAt != null && DateTime.now().isBefore(_expiresAt!);

  /// Get valid access token, refreshing if needed
  static Future<String?> getToken() async {
    if (_accessToken != null && _expiresAt != null && DateTime.now().isBefore(_expiresAt!.subtract(const Duration(minutes: 2)))) {
      return _accessToken;
    }
    if (_refreshToken != null) {
      return await _refresh();
    }
    // Try loading from localStorage
    _loadFromStorage();
    if (_accessToken != null && _expiresAt != null && DateTime.now().isBefore(_expiresAt!)) return _accessToken;
    if (_refreshToken != null) return await _refresh();
    return null;
  }

  /// Start OAuth flow — opens Spotify login in a popup
  static Future<bool> login() async {
    final verifier = _generateVerifier();
    final challenge = _generateChallenge(verifier);
    final state = _randomString(16);

    // Store verifier for token exchange
    html.window.localStorage['spotify_verifier'] = verifier;
    html.window.localStorage['spotify_state'] = state;

    final authUrl = Uri.https('accounts.spotify.com', '/authorize', {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': _redirectUri,
      'scope': _scopes,
      'code_challenge_method': 'S256',
      'code_challenge': challenge,
      'state': state,
    });

    // Open popup
    final popup = html.window.open(authUrl.toString(), 'spotify_auth', 'width=500,height=700');
    if (popup == null) return false;

    // Listen for callback message from popup
    final completer = Completer<bool>();
    late StreamSubscription sub;
    sub = html.window.onMessage.listen((event) {
      if (event.data is String && (event.data as String).startsWith('spotify_code:')) {
        sub.cancel();
        final code = (event.data as String).replaceFirst('spotify_code:', '');
        _exchangeCode(code, verifier).then((ok) => completer.complete(ok));
      } else if (event.data == 'spotify_error') {
        sub.cancel();
        completer.complete(false);
      }
    });

    // Timeout after 2 minutes
    Timer(const Duration(minutes: 2), () {
      if (!completer.isCompleted) { sub.cancel(); completer.complete(false); }
    });

    return completer.future;
  }

  static Future<bool> _exchangeCode(String code, String verifier) async {
    try {
      final resp = await http.post(Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'grant_type=authorization_code&code=$code&redirect_uri=${Uri.encodeComponent(_redirectUri)}&client_id=$clientId&code_verifier=$verifier');
      if (resp.statusCode != 200) return false;
      final d = json.decode(resp.body);
      _accessToken = d['access_token'];
      _refreshToken = d['refresh_token'];
      _expiresAt = DateTime.now().add(Duration(seconds: d['expires_in'] as int));
      _saveToStorage();
      return true;
    } catch (_) { return false; }
  }

  static Future<String?> _refresh() async {
    if (_refreshToken == null) return null;
    try {
      final resp = await http.post(Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'grant_type=refresh_token&refresh_token=$_refreshToken&client_id=$clientId');
      if (resp.statusCode != 200) return null;
      final d = json.decode(resp.body);
      _accessToken = d['access_token'];
      if (d['refresh_token'] != null) _refreshToken = d['refresh_token'];
      _expiresAt = DateTime.now().add(Duration(seconds: d['expires_in'] as int));
      _saveToStorage();
      return _accessToken;
    } catch (_) { return null; }
  }

  static void _saveToStorage() {
    html.window.localStorage['spotify_access_token'] = _accessToken ?? '';
    html.window.localStorage['spotify_refresh_token'] = _refreshToken ?? '';
    html.window.localStorage['spotify_expires_at'] = _expiresAt?.toIso8601String() ?? '';
  }

  static void _loadFromStorage() {
    _accessToken = html.window.localStorage['spotify_access_token'];
    _refreshToken = html.window.localStorage['spotify_refresh_token'];
    final exp = html.window.localStorage['spotify_expires_at'];
    _expiresAt = exp != null && exp.isNotEmpty ? DateTime.tryParse(exp) : null;
    if (_accessToken?.isEmpty == true) _accessToken = null;
    if (_refreshToken?.isEmpty == true) _refreshToken = null;
  }

  static String _generateVerifier() {
    final r = Random.secure();
    final bytes = List<int>.generate(96, (_) => r.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '').substring(0, 128);
  }

  static String _generateChallenge(String verifier) {
    return base64UrlEncode(sha256.convert(utf8.encode(verifier)).bytes).replaceAll('=', '');
  }

  static String _randomString(int len) {
    final r = Random.secure();
    return base64UrlEncode(List<int>.generate(len, (_) => r.nextInt(256))).replaceAll('=', '').substring(0, len);
  }

  static void logout() {
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    html.window.localStorage.remove('spotify_access_token');
    html.window.localStorage.remove('spotify_refresh_token');
    html.window.localStorage.remove('spotify_expires_at');
  }
}
