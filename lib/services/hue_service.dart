import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Direct Philips Hue Bridge V2 API — bypasses HA completely.
/// Bridge: BSB002 at 192.168.1.203
/// API key: P8Fcsz0hqCLSRTvT0EzTBMyeldzFGE89rO81OWBL
/// Uses V1 API for control, V2 SSE for real-time events.
class HueService {
  static const _bridgeIp = '192.168.1.203';
  static const _apiKey = 'P8Fcsz0hqCLSRTvT0EzTBMyeldzFGE89rO81OWBL';
  static const _baseUrl = 'http://$_bridgeIp/api/$_apiKey';
  static const _sseUrl = 'https://$_bridgeIp/eventstream/clip/v2';

  // ─── V1 REST — get all lights ───
  static Future<Map<String, HueLight>> getLights() async {
    final resp = await http.get(Uri.parse('$_baseUrl/lights'))
        .timeout(const Duration(seconds: 5));
    if (resp.statusCode != 200) throw Exception('Hue getLights failed: ${resp.statusCode}');
    final data = json.decode(resp.body) as Map<String, dynamic>;
    final lights = <String, HueLight>{};
    data.forEach((id, info) {
      final state = info['state'] as Map<String, dynamic>;
      lights[id] = HueLight(
        id: id,
        name: info['name'] as String,
        on: state['on'] as bool,
        brightness: state.containsKey('bri') ? ((state['bri'] as int) / 254 * 100).round() : 0,
        reachable: state['reachable'] as bool,
        type: info['type'] as String,
        hasColor: state.containsKey('hue'),
        hasColorTemp: state.containsKey('ct'),
        uniqueId: info['uniqueid'] as String? ?? '',
      );
    });
    return lights;
  }

  // ─── V1 REST — control ───
  static Future<void> setOn(String lightId, bool on) async {
    await http.put(Uri.parse('$_baseUrl/lights/$lightId/state'),
        body: json.encode({'on': on})).timeout(const Duration(seconds: 3));
  }

  static Future<void> setBrightness(String lightId, int percent) async {
    final bri = (percent / 100 * 254).round().clamp(1, 254);
    await http.put(Uri.parse('$_baseUrl/lights/$lightId/state'),
        body: json.encode({'on': true, 'bri': bri})).timeout(const Duration(seconds: 3));
  }

  static Future<void> setColorTemp(String lightId, int mirek) async {
    await http.put(Uri.parse('$_baseUrl/lights/$lightId/state'),
        body: json.encode({'ct': mirek.clamp(153, 500)})).timeout(const Duration(seconds: 3));
  }

  static Future<void> setColor(String lightId, int hue, int sat) async {
    await http.put(Uri.parse('$_baseUrl/lights/$lightId/state'),
        body: json.encode({'on': true, 'hue': hue, 'sat': sat})).timeout(const Duration(seconds: 3));
  }

  static Future<void> turnOff(String lightId) async {
    await http.put(Uri.parse('$_baseUrl/lights/$lightId/state'),
        body: json.encode({'on': false})).timeout(const Duration(seconds: 3));
  }

  // ─── V2 SSE — real-time events from bridge ───
  // The Hue V2 SSE stream pushes all state changes and device additions.
  // We parse light events and fire callbacks.
  static StreamController<HueEvent>? _eventController;
  static http.Client? _sseClient;
  static bool _sseRunning = false;

  /// Start listening to the Hue bridge event stream.
  /// Returns a broadcast stream of HueEvent.
  static Stream<HueEvent> startEventStream() {
    _eventController ??= StreamController<HueEvent>.broadcast();
    if (!_sseRunning) {
      _sseRunning = true;
      _connectSSE();
    }
    return _eventController!.stream;
  }

  static void stopEventStream() {
    _sseRunning = false;
    _sseClient?.close();
    _sseClient = null;
  }

  static Future<void> _connectSSE() async {
    while (_sseRunning) {
      try {
        _sseClient = http.Client();
        final request = http.Request('GET', Uri.parse(_sseUrl));
        request.headers['hue-application-key'] = _apiKey;
        request.headers['Accept'] = 'text/event-stream';

        final response = await _sseClient!.send(request).timeout(const Duration(seconds: 10));
        
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          if (!_sseRunning) break;
          _parseSSEChunk(chunk);
        }
      } catch (_) {
        // Connection failed or dropped — reconnect after delay
      }
      if (_sseRunning) {
        await Future.delayed(const Duration(seconds: 3));
      }
    }
  }

  static void _parseSSEChunk(String chunk) {
    // SSE format: "id: ...\ndata: [...]\n\n"
    for (final line in chunk.split('\n')) {
      if (!line.startsWith('data: ')) continue;
      final jsonStr = line.substring(6).trim();
      if (jsonStr.isEmpty) continue;
      try {
        final events = json.decode(jsonStr) as List;
        for (final event in events) {
          final type = event['type'] as String?;
          final data = event['data'] as List?;
          if (data == null) continue;
          
          for (final item in data) {
            final rtype = item['type'] as String?;
            final id = item['id'] as String?;
            final owner = item['owner'] as Map<String, dynamic>?;
            
            if (rtype == 'light') {
              // Light state change
              final on = item['on']?['on'] as bool?;
              final dimming = item['dimming']?['brightness'] as num?;
              _eventController?.add(HueEvent(
                type: type == 'add' ? HueEventType.lightAdded 
                    : type == 'delete' ? HueEventType.lightRemoved 
                    : HueEventType.lightChanged,
                resourceId: id ?? '',
                ownerId: owner?['rid'] as String? ?? '',
                on: on,
                brightness: dimming?.round(),
              ));
            } else if (rtype == 'device' && type == 'add') {
              // New device added — could be a new bulb
              _eventController?.add(HueEvent(
                type: HueEventType.deviceAdded,
                resourceId: id ?? '',
              ));
            }
          }
        }
      } catch (_) {
        // Ignore parse errors
      }
    }
  }

  // ─── V2 ID mapping ───
  // V2 uses different IDs than V1. We need to map between them.
  // Fetch V2 lights to build a mapping of V2 resource ID → V1 light ID.
  static Future<Map<String, String>> getV2ToV1Map() async {
    try {
      final client = http.Client();
      final resp = await client.get(
        Uri.parse('https://$_bridgeIp/clip/v2/resource/light'),
        headers: {'hue-application-key': _apiKey},
      ).timeout(const Duration(seconds: 5));
      client.close();
      
      if (resp.statusCode != 200) return {};
      
      final data = json.decode(resp.body);
      final lights = data['data'] as List? ?? [];
      final v1Lights = await getLights();
      
      // Map by matching unique IDs or names
      final map = <String, String>{};
      for (final v2Light in lights) {
        final v2Id = v2Light['id'] as String;
        final v2Name = v2Light['metadata']?['name'] as String? ?? '';
        // Find matching V1 light by name
        for (final entry in v1Lights.entries) {
          if (entry.value.name == v2Name) {
            map[v2Id] = entry.key;
            break;
          }
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }
}

class HueLight {
  final String id;
  final String name;
  bool on;
  int brightness;
  final bool reachable;
  final String type;
  final bool hasColor;
  final bool hasColorTemp;
  final String uniqueId;

  HueLight({
    required this.id,
    required this.name,
    required this.on,
    required this.brightness,
    required this.reachable,
    required this.type,
    this.hasColor = false,
    this.hasColorTemp = false,
    this.uniqueId = '',
  });
}

enum HueEventType {
  lightChanged,
  lightAdded,
  lightRemoved,
  deviceAdded,
}

class HueEvent {
  final HueEventType type;
  final String resourceId;
  final String ownerId;
  final bool? on;
  final int? brightness;

  HueEvent({
    required this.type,
    this.resourceId = '',
    this.ownerId = '',
    this.on,
    this.brightness,
  });
}
