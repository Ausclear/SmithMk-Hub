import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'spotify_auth.dart';

/// Direct Spotify Web API player controls — no HA, no proxy
/// Handles play, pause, skip, seek, volume, device switching, now playing
class SpotifyPlayer {
  static const _base = 'https://api.spotify.com/v1/me/player';

  static Future<Map<String, String>?> _headers() async {
    final token = await SpotifyAuth.getToken();
    if (token == null) return null;
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  /// Get all Spotify Connect devices (including Echo speakers)
  static Future<List<SpotifyDevice>> getDevices() async {
    final h = await _headers();
    if (h == null) return [];
    final r = await http.get(Uri.parse('$_base/devices'), headers: h).timeout(const Duration(seconds: 5));
    if (r.statusCode != 200) return [];
    final d = json.decode(r.body);
    return (d['devices'] as List? ?? []).map((e) => SpotifyDevice.fromJson(e)).toList();
  }

  /// Get current playback state
  static Future<SpotifyPlaybackState?> getPlaybackState() async {
    final h = await _headers();
    if (h == null) return null;
    final r = await http.get(Uri.parse(_base), headers: h).timeout(const Duration(seconds: 5));
    if (r.statusCode == 204 || r.statusCode != 200) return null;
    return SpotifyPlaybackState.fromJson(json.decode(r.body));
  }

  /// Transfer playback to a device
  static Future<bool> transferPlayback(String deviceId, {bool play = true}) async {
    final h = await _headers();
    if (h == null) return false;
    final r = await http.put(Uri.parse(_base), headers: h,
      body: json.encode({'device_ids': [deviceId], 'play': play}));
    return r.statusCode == 204;
  }

  /// Play a track/album/playlist on a device
  static Future<bool> play({String? deviceId, String? contextUri, List<String>? uris}) async {
    final h = await _headers();
    if (h == null) return false;
    final query = deviceId != null ? '?device_id=$deviceId' : '';
    final body = <String, dynamic>{};
    if (contextUri != null) body['context_uri'] = contextUri;
    if (uris != null) body['uris'] = uris;
    final r = await http.put(Uri.parse('$_base/play$query'), headers: h,
      body: body.isNotEmpty ? json.encode(body) : null);
    return r.statusCode == 204 || r.statusCode == 202;
  }

  /// Resume playback
  static Future<bool> resume({String? deviceId}) async {
    final h = await _headers();
    if (h == null) return false;
    final query = deviceId != null ? '?device_id=$deviceId' : '';
    final r = await http.put(Uri.parse('$_base/play$query'), headers: h);
    return r.statusCode == 204 || r.statusCode == 202;
  }

  /// Pause
  static Future<bool> pause({String? deviceId}) async {
    final h = await _headers();
    if (h == null) return false;
    final query = deviceId != null ? '?device_id=$deviceId' : '';
    final r = await http.put(Uri.parse('$_base/pause$query'), headers: h);
    return r.statusCode == 204 || r.statusCode == 202;
  }

  /// Next track
  static Future<bool> next({String? deviceId}) async {
    final h = await _headers();
    if (h == null) return false;
    final query = deviceId != null ? '?device_id=$deviceId' : '';
    final r = await http.post(Uri.parse('$_base/next$query'), headers: h);
    return r.statusCode == 204;
  }

  /// Previous track
  static Future<bool> previous({String? deviceId}) async {
    final h = await _headers();
    if (h == null) return false;
    final query = deviceId != null ? '?device_id=$deviceId' : '';
    final r = await http.post(Uri.parse('$_base/previous$query'), headers: h);
    return r.statusCode == 204;
  }

  /// Seek to position (milliseconds)
  static Future<bool> seek(int positionMs, {String? deviceId}) async {
    final h = await _headers();
    if (h == null) return false;
    final query = 'position_ms=$positionMs${deviceId != null ? '&device_id=$deviceId' : ''}';
    final r = await http.put(Uri.parse('$_base/seek?$query'), headers: h);
    return r.statusCode == 204;
  }

  /// Set volume (0-100)
  static Future<bool> setVolume(int percent, {String? deviceId}) async {
    final h = await _headers();
    if (h == null) return false;
    final query = 'volume_percent=$percent${deviceId != null ? '&device_id=$deviceId' : ''}';
    final r = await http.put(Uri.parse('$_base/volume?$query'), headers: h);
    return r.statusCode == 204;
  }

  /// Toggle shuffle
  static Future<bool> setShuffle(bool state, {String? deviceId}) async {
    final h = await _headers();
    if (h == null) return false;
    final query = 'state=$state${deviceId != null ? '&device_id=$deviceId' : ''}';
    final r = await http.put(Uri.parse('$_base/shuffle?$query'), headers: h);
    return r.statusCode == 204;
  }
}

class SpotifyDevice {
  final String id, name, type;
  final bool isActive, isRestricted;
  final int? volumePercent;
  final bool supportsVolume;

  SpotifyDevice({required this.id, required this.name, required this.type,
    this.isActive = false, this.isRestricted = false, this.volumePercent, this.supportsVolume = true});

  factory SpotifyDevice.fromJson(Map<String, dynamic> j) => SpotifyDevice(
    id: j['id']?.toString() ?? '', name: j['name']?.toString() ?? '',
    type: j['type']?.toString() ?? '', isActive: j['is_active'] == true,
    isRestricted: j['is_restricted'] == true, volumePercent: j['volume_percent'] as int?,
    supportsVolume: j['supports_volume'] != false);
}

class SpotifyPlaybackState {
  final String? deviceId, deviceName;
  final bool isPlaying, shuffleState;
  final int? progressMs, durationMs, volumePercent;
  final String? trackName, artistName, albumName, albumArt, trackUri;

  SpotifyPlaybackState({this.deviceId, this.deviceName, this.isPlaying = false,
    this.shuffleState = false, this.progressMs, this.durationMs, this.volumePercent,
    this.trackName, this.artistName, this.albumName, this.albumArt, this.trackUri});

  factory SpotifyPlaybackState.fromJson(Map<String, dynamic> j) {
    final device = j['device'] as Map<String, dynamic>? ?? {};
    final item = j['item'] as Map<String, dynamic>? ?? {};
    final album = item['album'] as Map<String, dynamic>? ?? {};
    final images = album['images'] as List? ?? [];
    final artists = item['artists'] as List? ?? [];

    return SpotifyPlaybackState(
      deviceId: device['id']?.toString(),
      deviceName: device['name']?.toString(),
      isPlaying: j['is_playing'] == true,
      shuffleState: j['shuffle_state'] == true,
      progressMs: j['progress_ms'] as int?,
      durationMs: item['duration_ms'] as int?,
      volumePercent: device['volume_percent'] as int?,
      trackName: item['name']?.toString(),
      artistName: artists.isNotEmpty ? artists[0]['name']?.toString() : null,
      albumName: album['name']?.toString(),
      albumArt: images.length > 1 ? images[1]['url']?.toString() : (images.isNotEmpty ? images[0]['url']?.toString() : null),
      trackUri: item['uri']?.toString(),
    );
  }
}
