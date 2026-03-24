import 'dart:convert';
import 'package:http/http.dart' as http;

class HAService {
  static const haUrl = 'http://192.168.1.101:8123';
  static const haToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIwOWI5OTlmY2JmMWY0OWQwYTFiYzBiMmM1M2NiZTgyMiIsImlhdCI6MTc3MzExOTk5OSwiZXhwIjoyMDg4NDc5OTk5fQ.0HfaVvG4_Ld5xuxzejS5sWxi5jRGREkNrPXN3s-uM0k';

  static Map<String, String> get _headers => {
    'Authorization': 'Bearer $haToken',
    'Content-Type': 'application/json',
  };

  static Future<List<Map<String, dynamic>>> getStates() async {
    final resp = await http.get(Uri.parse('$haUrl/api/states'), headers: _headers).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(resp.body));
    throw Exception('HA states failed: ${resp.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> getEntities(String domain) async {
    final all = await getStates();
    return all.where((e) => (e['entity_id'] as String).startsWith('$domain.')).toList();
  }

  static Future<void> callService(String domain, String service, Map<String, dynamic> data) async {
    final resp = await http.post(Uri.parse('$haUrl/api/services/$domain/$service'),
      headers: _headers, body: json.encode(data)).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('HA $domain/$service failed: ${resp.statusCode}');
  }

  static Future<void> mediaPlayPause(String entityId) => callService('media_player', 'media_play_pause', {'entity_id': entityId});
  static Future<void> mediaNext(String entityId) => callService('media_player', 'media_next_track', {'entity_id': entityId});
  static Future<void> mediaPrev(String entityId) => callService('media_player', 'media_previous_track', {'entity_id': entityId});
  static Future<void> mediaStop(String entityId) => callService('media_player', 'media_stop', {'entity_id': entityId});
  static Future<void> mediaVolume(String entityId, double level) => callService('media_player', 'volume_set', {'entity_id': entityId, 'volume_level': level});

  static Future<void> playSpotify(String uri, String source) async {
    // Select Spotify Connect source first
    await callService('media_player', 'select_source', {'entity_id': 'media_player.spotify_smithmk', 'source': source});
    // Wait for device switch
    await Future.delayed(const Duration(milliseconds: 900));
    // Play
    await callService('media_player', 'play_media', {
      'entity_id': 'media_player.spotify_smithmk',
      'media_content_id': uri,
      'media_content_type': 'music',
    });
  }
}
