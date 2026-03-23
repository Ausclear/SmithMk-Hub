import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Home Assistant REST API + SSE client for SmithMk Flutter app.
/// Calls the PWA's Next.js API proxy (same endpoints the web app uses)
/// OR directly hits HA when running on the local network.
class HAService {
  // PWA proxy base — used for Vercel-hosted API routes
  static const pwaBase = 'https://smarthome-eight-livid.vercel.app';

  // Direct HA — used when on local network
  static const haUrl = 'http://202.62.130.27:8123';
  static const _haToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIwOWI5OTlmY2JmMWY0OWQwYTFiYzBiMmM1M2NiZTgyMiIsImlhdCI6MTc3MzExOTk5OSwiZXhwIjoyMDg4NDc5OTk5fQ.0HfaVvG4_Ld5xuxzejS5sWxi5jRGREkNrPXN3s-uM0k';

  // Supabase for config lookup
  static const _sbUrl = 'https://qraxdkzmteogkbfatvir.supabase.co';
  static const _sbServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFyYXhka3ptdGVvZ2tiZmF0dmlyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzU5OTkyMSwiZXhwIjoyMDc5MTc1OTIxfQ.0HUnGAWyU0donigxUOoJSpeQNJMUP2HzaR3cID6yBFs';

  static String? _cachedHaUrl;
  static String? _cachedHaToken;
  static DateTime? _cacheTime;

  /// Get HA URL and token — tries Supabase first, falls back to constants
  static Future<({String url, String token})> getConfig() async {
    if (_cachedHaUrl != null && _cachedHaToken != null && _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inSeconds < 30) {
      return (url: _cachedHaUrl!, token: _cachedHaToken!);
    }

    try {
      final resp = await http.get(
        Uri.parse('$_sbUrl/rest/v1/smarthome_customisations?id=in.("system:ha_url","system:ha_token")&select=id,label'),
        headers: {'apikey': _sbServiceKey, 'Authorization': 'Bearer $_sbServiceKey'},
      ).timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        final List rows = json.decode(resp.body);
        final urlRow = rows.firstWhere((r) => r['id'] == 'system:ha_url', orElse: () => null);
        final tokenRow = rows.firstWhere((r) => r['id'] == 'system:ha_token', orElse: () => null);
        _cachedHaUrl = (urlRow?['label'] as String?)?.isNotEmpty == true ? urlRow['label'] : haUrl;
        _cachedHaToken = (tokenRow?['label'] as String?)?.isNotEmpty == true ? tokenRow['label'] : _haToken;
      } else {
        _cachedHaUrl = haUrl;
        _cachedHaToken = _haToken;
      }
    } catch (_) {
      _cachedHaUrl = haUrl;
      _cachedHaToken = _haToken;
    }
    _cacheTime = DateTime.now();
    return (url: _cachedHaUrl!, token: _cachedHaToken!);
  }

  /// Get all HA states
  static Future<List<Map<String, dynamic>>> getStates() async {
    final cfg = await getConfig();
    final resp = await http.get(
      Uri.parse('${cfg.url}/api/states'),
      headers: {'Authorization': 'Bearer ${cfg.token}', 'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(resp.body));
    throw Exception('HA states failed: ${resp.statusCode}');
  }

  /// Get states filtered by domain
  static Future<List<Map<String, dynamic>>> getEntities(String domain) async {
    final all = await getStates();
    return all.where((e) => (e['entity_id'] as String).startsWith('$domain.')).toList();
  }

  /// Call an HA service
  static Future<void> callService(String domain, String service, Map<String, dynamic> data) async {
    final cfg = await getConfig();
    final resp = await http.post(
      Uri.parse('${cfg.url}/api/services/$domain/$service'),
      headers: {'Authorization': 'Bearer ${cfg.token}', 'Content-Type': 'application/json'},
      body: json.encode(data),
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('HA service $domain/$service failed: ${resp.statusCode}');
  }

  // ─── Media player shortcuts ───

  static Future<void> mediaPlayPause(String entityId) =>
    callService('media_player', 'media_play_pause', {'entity_id': entityId});

  static Future<void> mediaNext(String entityId) =>
    callService('media_player', 'media_next_track', {'entity_id': entityId});

  static Future<void> mediaPrev(String entityId) =>
    callService('media_player', 'media_previous_track', {'entity_id': entityId});

  static Future<void> mediaStop(String entityId) =>
    callService('media_player', 'media_stop', {'entity_id': entityId});

  static Future<void> mediaVolume(String entityId, double level) =>
    callService('media_player', 'volume_set', {'entity_id': entityId, 'volume_level': level});

  static Future<void> mediaVolumeUp(String entityId) =>
    callService('media_player', 'volume_up', {'entity_id': entityId});

  static Future<void> mediaVolumeDown(String entityId) =>
    callService('media_player', 'volume_down', {'entity_id': entityId});

  /// Play Spotify URI on an Echo via Spotify Connect
  static Future<void> playSpotify(String uri, String source) async {
    // Use the PWA proxy which handles the select_source + delay + play_media sequence
    final resp = await http.post(
      Uri.parse('$pwaBase/api/ha/play-spotify'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'uri': uri, 'source': source}),
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('play-spotify failed: ${resp.statusCode} ${resp.body}');
  }
}
