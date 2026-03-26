import 'dart:convert';
import 'package:http/http.dart' as http;

/// Tapo device control via local proxy on VM at 192.168.1.47:4500
/// Proxy handles the encrypted Tapo protocol.
/// P100 plugs: on/off only. L920/L930 strips: on/off + brightness + colour.
class TapoService {
  static const _proxyUrl = 'http://192.168.1.47:4500';

  /// Turn a Tapo device on
  static Future<void> turnOn(String ip) async {
    await http.post(Uri.parse('$_proxyUrl/api/tapo/on'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'ip': ip}),
    ).timeout(const Duration(seconds: 5));
  }

  /// Turn a Tapo device off
  static Future<void> turnOff(String ip) async {
    await http.post(Uri.parse('$_proxyUrl/api/tapo/off'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'ip': ip}),
    ).timeout(const Duration(seconds: 5));
  }

  /// Set brightness (lightstrips only, 1-100)
  static Future<void> setBrightness(String ip, int brightness) async {
    await http.post(Uri.parse('$_proxyUrl/api/tapo/brightness'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'ip': ip, 'brightness': brightness.clamp(1, 100)}),
    ).timeout(const Duration(seconds: 5));
  }

  /// Set colour (lightstrips only)
  static Future<void> setColour(String ip, int hue, int saturation, int brightness) async {
    await http.post(Uri.parse('$_proxyUrl/api/tapo/colour'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'ip': ip, 'hue': hue, 'saturation': saturation, 'brightness': brightness}),
    ).timeout(const Duration(seconds: 5));
  }

  /// Get all discovered Tapo devices
  static Future<Map<String, dynamic>> getDevices() async {
    final resp = await http.get(Uri.parse('$_proxyUrl/api/tapo/devices'))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) return json.decode(resp.body) as Map<String, dynamic>;
    throw Exception('Tapo devices failed: ${resp.statusCode}');
  }

  /// Get device info
  static Future<Map<String, dynamic>> getInfo(String ip) async {
    final resp = await http.post(Uri.parse('$_proxyUrl/api/tapo/info'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'ip': ip}),
    ).timeout(const Duration(seconds: 5));
    if (resp.statusCode == 200) return json.decode(resp.body) as Map<String, dynamic>;
    throw Exception('Tapo info failed: ${resp.statusCode}');
  }
}
