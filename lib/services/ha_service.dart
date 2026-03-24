import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HAService {
  static const apiBase = 'http://192.168.1.47:3000';
  static const haUrl = 'http://192.168.1.101:8123';

  static Future<List<Map<String, dynamic>>> getStates() async {
    final resp = await http.get(Uri.parse('$apiBase/api/ha/states')).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(resp.body));
    throw Exception('HA states failed: ${resp.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> getEntities(String domain) async {
    final all = await getStates();
    return all.where((e) => (e['entity_id'] as String).startsWith('$domain.')).toList();
  }

  static Future<void> callService(String domain, String service, Map<String, dynamic> data) async {
    final resp = await http.post(Uri.parse('$apiBase/api/ha/service'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'domain': domain, 'service': service, 'data': data})).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('HA $domain/$service failed: ${resp.statusCode}');
  }

  // Media shortcuts — play and pause are SEPARATE calls for Spotify
  static Future<void> mediaPlay(String entityId) => callService('media_player', 'media_play', {'entity_id': entityId});
  static Future<void> mediaPause(String entityId) => callService('media_player', 'media_pause', {'entity_id': entityId});
  static Future<void> mediaPlayPause(String entityId) => callService('media_player', 'media_play_pause', {'entity_id': entityId});
  static Future<void> mediaNext(String entityId) => callService('media_player', 'media_next_track', {'entity_id': entityId});
  static Future<void> mediaPrev(String entityId) => callService('media_player', 'media_previous_track', {'entity_id': entityId});
  static Future<void> mediaStop(String entityId) => callService('media_player', 'media_stop', {'entity_id': entityId});
  static Future<void> mediaVolume(String entityId, double level) => callService('media_player', 'volume_set', {'entity_id': entityId, 'volume_level': level});

  static Future<void> playSpotify(String uri, String source) async {
    final resp = await http.post(Uri.parse('$apiBase/api/ha/play-spotify'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'uri': uri, 'source': source})).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('play-spotify failed: ${resp.statusCode}');
  }

  /// SSE stream — connects to PWA's /api/ha/stream for real-time state updates
  static Stream<Map<String, dynamic>> stateStream() async* {
    final client = http.Client();
    final request = http.Request('GET', Uri.parse('$apiBase/api/ha/stream'));
    final response = await client.send(request);
    String buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      while (buffer.contains('\n\n')) {
        final idx = buffer.indexOf('\n\n');
        final message = buffer.substring(0, idx);
        buffer = buffer.substring(idx + 2);
        if (message.startsWith('data: ')) {
          try {
            final data = json.decode(message.substring(6)) as Map<String, dynamic>;
            yield data;
          } catch (_) {}
        }
      }
    }
  }
}
