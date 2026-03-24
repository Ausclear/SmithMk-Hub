import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Home Assistant service — WebSocket for real-time state, REST for initial load
/// All controls route through HA's service calls (HA handles Spotify OAuth internally)
class HAService {
  static const haUrl = 'http://192.168.1.47:3000'; // Local PWA for REST (CORS safe)
  static const haWsUrl = 'ws://192.168.1.101:8123/api/websocket'; // Direct WebSocket (no CORS)
  static const haDirectUrl = 'http://192.168.1.101:8123'; // Direct HA for images
  static const haToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIwOWI5OTlmY2JmMWY0OWQwYTFiYzBiMmM1M2NiZTgyMiIsImlhdCI6MTc3MzExOTk5OSwiZXhwIjoyMDg4NDc5OTk5fQ.0HfaVvG4_Ld5xuxzejS5sWxi5jRGREkNrPXN3s-uM0k';

  // Spotify entity — all music controls go here
  static const spotifyEntity = 'media_player.spotify_smithmk';

  // ─── REST (initial state load via local PWA) ───
  static Future<List<Map<String, dynamic>>> getStates() async {
    final resp = await http.get(Uri.parse('$haUrl/api/ha/states')).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) return List<Map<String, dynamic>>.from(json.decode(resp.body));
    throw Exception('HA states failed: ${resp.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> getEntities(String domain) async {
    final all = await getStates();
    return all.where((e) => (e['entity_id'] as String).startsWith('$domain.')).toList();
  }

  // ─── REST (service calls via local PWA) ───
  static Future<void> callService(String domain, String service, Map<String, dynamic> data) async {
    final resp = await http.post(Uri.parse('$haUrl/api/ha/service'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'domain': domain, 'service': service, 'data': data})).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('HA $domain/$service failed: ${resp.statusCode}');
  }

  // ─── Spotify playback (via PWA play-spotify endpoint) ───
  static Future<void> playSpotify(String uri, String source) async {
    final resp = await http.post(Uri.parse('$haUrl/api/ha/play-spotify'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'uri': uri, 'source': source})).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('play-spotify failed: ${resp.statusCode}');
  }

  // ─── Music controls — ALL target Spotify entity ───
  static Future<void> musicPlayPause() => callService('media_player', 'media_play_pause', {'entity_id': spotifyEntity});
  static Future<void> musicNext() => callService('media_player', 'media_next_track', {'entity_id': spotifyEntity});
  static Future<void> musicPrev() => callService('media_player', 'media_previous_track', {'entity_id': spotifyEntity});
  static Future<void> musicStop() => callService('media_player', 'media_stop', {'entity_id': spotifyEntity});
  static Future<void> musicVolume(double level) => callService('media_player', 'volume_set', {'entity_id': spotifyEntity, 'volume_level': level});
  static Future<void> musicShuffle(bool on) => callService('media_player', 'shuffle_set', {'entity_id': spotifyEntity, 'shuffle': on});

  // ─── Echo device controls (for non-Spotify stuff like TTS) ───
  static Future<void> echoVolume(String entityId, double level) => callService('media_player', 'volume_set', {'entity_id': entityId, 'volume_level': level});
  static Future<void> echoPlayPause(String entityId) => callService('media_player', 'media_play_pause', {'entity_id': entityId});

  // ─── WebSocket — direct to HA, real-time state changes ───
  static WebSocketChannel? _ws;
  static int _msgId = 1;
  static final _stateController = StreamController<Map<String, dynamic>>.broadcast();
  static bool _connected = false;
  static Timer? _reconnectTimer;

  /// Stream of state_changed events — each event has entity_id, state, attributes
  static Stream<Map<String, dynamic>> get stateStream => _stateController.stream;

  /// Connect WebSocket to HA
  static void connect() {
    if (_connected) return;
    try {
      _ws = WebSocketChannel.connect(Uri.parse(haWsUrl));
      _ws!.stream.listen(_onMessage, onError: (_) => _reconnect(), onDone: _reconnect);
    } catch (_) {
      _reconnect();
    }
  }

  static void _onMessage(dynamic raw) {
    try {
      final msg = json.decode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;

      if (type == 'auth_required') {
        _ws?.sink.add(json.encode({'type': 'auth', 'access_token': haToken}));
      } else if (type == 'auth_ok') {
        _connected = true;
        // Subscribe to ALL state changes
        _ws?.sink.add(json.encode({'id': _msgId++, 'type': 'subscribe_events', 'event_type': 'state_changed'}));
      } else if (type == 'auth_invalid') {
        _connected = false;
      } else if (type == 'event') {
        final event = msg['event'] as Map<String, dynamic>?;
        final data = event?['data'] as Map<String, dynamic>?;
        if (data == null) return;
        final entityId = data['entity_id'] as String?;
        final newState = data['new_state'] as Map<String, dynamic>?;
        if (entityId == null || newState == null) return;
        // Only forward media_player entities
        if (!entityId.startsWith('media_player.')) return;
        _stateController.add({
          'entity_id': entityId,
          'state': newState['state'],
          'attributes': newState['attributes'] ?? {},
        });
      }
    } catch (_) {}
  }

  static void _reconnect() {
    _connected = false;
    _ws?.sink.close();
    _ws = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  static void disconnect() {
    _reconnectTimer?.cancel();
    _ws?.sink.close();
    _ws = null;
    _connected = false;
  }
}
