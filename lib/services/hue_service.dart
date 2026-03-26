import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Direct Philips Hue Bridge V2 API — bypasses HA completely.
/// Bridge: BSB002 at 192.168.1.203
/// API key: P8Fcsz0hqCLSRTvT0EzTBMyeldzFGE89rO81OWBL
class HueService {
  static const _bridgeIp = '192.168.1.203';
  static const _apiKey = 'P8Fcsz0hqCLSRTvT0EzTBMyeldzFGE89rO81OWBL';
  static const _baseUrl = 'http://$_bridgeIp/api/$_apiKey';

  /// Get all lights from the bridge
  static Future<Map<String, HueLight>> getLights() async {
    final resp = await http.get(Uri.parse('$_baseUrl/lights'))
        .timeout(const Duration(seconds: 5));
    if (resp.statusCode != 200) throw Exception('Hue getLights failed: ${resp.statusCode}');
    
    final data = json.decode(resp.body) as Map<String, dynamic>;
    final lights = <String, HueLight>{};
    
    data.forEach((id, info) {
      final state = info['state'] as Map<String, dynamic>;
      if (state['reachable'] == true) {
        lights[id] = HueLight(
          id: id,
          name: info['name'] as String,
          on: state['on'] as bool,
          brightness: state.containsKey('bri') ? ((state['bri'] as int) / 254 * 100).round() : 0,
          reachable: true,
          type: info['type'] as String,
          hasColor: state.containsKey('hue'),
          hasColorTemp: state.containsKey('ct'),
        );
      }
    });
    
    return lights;
  }

  /// Turn a light on or off
  static Future<void> setOn(String lightId, bool on) async {
    await http.put(
      Uri.parse('$_baseUrl/lights/$lightId/state'),
      body: json.encode({'on': on}),
    ).timeout(const Duration(seconds: 3));
  }

  /// Set brightness (0-100%)
  static Future<void> setBrightness(String lightId, int percent) async {
    final bri = (percent / 100 * 254).round().clamp(1, 254);
    await http.put(
      Uri.parse('$_baseUrl/lights/$lightId/state'),
      body: json.encode({'on': true, 'bri': bri}),
    ).timeout(const Duration(seconds: 3));
  }

  /// Set colour temperature (153-500 mirek)
  static Future<void> setColorTemp(String lightId, int mirek) async {
    await http.put(
      Uri.parse('$_baseUrl/lights/$lightId/state'),
      body: json.encode({'ct': mirek.clamp(153, 500)}),
    ).timeout(const Duration(seconds: 3));
  }

  /// Set colour by hue (0-65535) and saturation (0-254)
  static Future<void> setColor(String lightId, int hue, int sat) async {
    await http.put(
      Uri.parse('$_baseUrl/lights/$lightId/state'),
      body: json.encode({'on': true, 'hue': hue, 'sat': sat}),
    ).timeout(const Duration(seconds: 3));
  }

  /// Turn off a light and set brightness to 0
  static Future<void> turnOff(String lightId) async {
    await http.put(
      Uri.parse('$_baseUrl/lights/$lightId/state'),
      body: json.encode({'on': false}),
    ).timeout(const Duration(seconds: 3));
  }
}

class HueLight {
  final String id;
  final String name;
  bool on;
  int brightness; // 0-100
  final bool reachable;
  final String type;
  final bool hasColor;
  final bool hasColorTemp;

  HueLight({
    required this.id,
    required this.name,
    required this.on,
    required this.brightness,
    required this.reachable,
    required this.type,
    this.hasColor = false,
    this.hasColorTemp = false,
  });
}
