import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;

/// Spotify Auth — simple manual code paste flow
/// No callback servers, no redirects, no external domains
class SpotifyAuth {
  static const clientId = '1bf984dbd8a84110bb6e1b29a589136c';
  static const _clientSecret = 'bc9a9b510e5a484b82285033297584f7';
  static const _scopes = 'user-modify-playback-state user-read-playback-state user-read-currently-playing';
  // Spotify's own domain — always valid as redirect
  static const _redirectUri = 'https://open.spotify.com/';

  static String? _accessToken;
  static DateTime? _expiresAt;
  static String? _refreshToken;

  static bool get isAuthenticated => _accessToken != null && _expiresAt != null && DateTime.now().isBefore(_expiresAt!);

  /// Get valid token, refresh if needed
  static Future<String?> getToken() async {
    if (_accessToken != null && _expiresAt != null && DateTime.now().isBefore(_expiresAt!.subtract(const Duration(minutes: 2)))) {
      return _accessToken;
    }
    if (_refreshToken != null) return await _refresh();
    _loadFromStorage();
    if (_accessToken != null && _expiresAt != null && DateTime.now().isBefore(_expiresAt!)) return _accessToken;
    if (_refreshToken != null) return await _refresh();
    return null;
  }

  /// Get the login URL — user opens this, logs in, copies code from resulting URL
  static String getLoginUrl() {
    return Uri.https('accounts.spotify.com', '/authorize', {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': _redirectUri,
      'scope': _scopes,
      'show_dialog': 'true',
    }).toString();
  }

  /// Exchange the code the user pasted for tokens
  static Future<bool> exchangeCode(String code) async {
    try {
      final resp = await http.post(Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'grant_type=authorization_code&code=${Uri.encodeComponent(code.trim())}&redirect_uri=${Uri.encodeComponent(_redirectUri)}&client_id=$clientId&client_secret=$_clientSecret');
      if (resp.statusCode != 200) return false;
      final d = json.decode(resp.body);
      if (d['access_token'] == null) return false;
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
        body: 'grant_type=refresh_token&refresh_token=$_refreshToken&client_id=$clientId&client_secret=$_clientSecret');
      if (resp.statusCode != 200) { _refreshToken = null; return null; }
      final d = json.decode(resp.body);
      _accessToken = d['access_token'];
      if (d['refresh_token'] != null) _refreshToken = d['refresh_token'];
      _expiresAt = DateTime.now().add(Duration(seconds: d['expires_in'] as int));
      _saveToStorage();
      return _accessToken;
    } catch (_) { return null; }
  }

  static void _saveToStorage() {
    html.window.localStorage['sp_at'] = _accessToken ?? '';
    html.window.localStorage['sp_rt'] = _refreshToken ?? '';
    html.window.localStorage['sp_exp'] = _expiresAt?.toIso8601String() ?? '';
  }

  static void _loadFromStorage() {
    _accessToken = html.window.localStorage['sp_at'];
    _refreshToken = html.window.localStorage['sp_rt'];
    final exp = html.window.localStorage['sp_exp'];
    _expiresAt = exp != null && exp.isNotEmpty ? DateTime.tryParse(exp) : null;
    if (_accessToken?.isEmpty == true) _accessToken = null;
    if (_refreshToken?.isEmpty == true) _refreshToken = null;
  }

  static void logout() {
    _accessToken = null; _refreshToken = null; _expiresAt = null;
    html.window.localStorage.remove('sp_at');
    html.window.localStorage.remove('sp_rt');
    html.window.localStorage.remove('sp_exp');
  }
}
