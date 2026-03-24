import 'dart:convert';
import 'package:http/http.dart' as http;

/// Spotify search — direct client credentials, no Vercel proxy
class SpotifyService {
  static const _clientId = '1bf984dbd8a84110bb6e1b29a589136c';
  static const _clientSecret = 'bc9a9b510e5a484b82285033297584f7';
  static String? _token;
  static DateTime? _tokenExpiry;

  static Future<String> _getToken() async {
    if (_token != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) return _token!;
    final resp = await http.post(Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'grant_type=client_credentials&client_id=$_clientId&client_secret=$_clientSecret')
      .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('Spotify token failed: ${resp.statusCode}');
    final d = json.decode(resp.body);
    _token = d['access_token'];
    _tokenExpiry = DateTime.now().add(Duration(seconds: (d['expires_in'] as int) - 60));
    return _token!;
  }

  static Future<SpotifyResults> search(String query) async {
    if (query.trim().isEmpty) return SpotifyResults.empty();
    final token = await _getToken();
    final q = Uri.encodeComponent(query.trim());
    final resp = await http.get(Uri.parse('https://api.spotify.com/v1/search?q=$q&type=track,album,artist,playlist&limit=10&market=AU'),
      headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('Spotify search failed: ${resp.statusCode}');
    final d = json.decode(resp.body);
    return SpotifyResults(
      tracks: ((d['tracks']?['items'] as List?) ?? []).map((t) => SpotifyTrack(
        id: t['id'] ?? '', uri: t['uri'] ?? '', name: t['name'] ?? '',
        artist: t['artists']?[0]?['name'], album: t['album']?['name'],
        art: t['album']?['images']?[1]?['url'] ?? t['album']?['images']?[0]?['url'],
        duration: t['duration_ms'])).toList(),
      albums: ((d['albums']?['items'] as List?) ?? []).map((a) => SpotifyAlbum(
        id: a['id'] ?? '', uri: a['uri'] ?? '', name: a['name'] ?? '',
        artist: a['artists']?[0]?['name'], art: a['images']?[1]?['url'] ?? a['images']?[0]?['url'],
        year: (a['release_date'] ?? '').toString().substring(0, 4))).toList(),
      artists: ((d['artists']?['items'] as List?) ?? []).map((a) => SpotifyArtist(
        id: a['id'] ?? '', uri: a['uri'] ?? '', name: a['name'] ?? '',
        art: a['images']?.isNotEmpty == true ? (a['images'][1]?['url'] ?? a['images'][0]?['url']) : null)).toList(),
      playlists: ((d['playlists']?['items'] as List?) ?? []).where((p) => p != null).map((p) => SpotifyPlaylist(
        id: p['id'] ?? '', uri: p['uri'] ?? '', name: p['name'] ?? '',
        owner: p['owner']?['display_name'], art: p['images']?[0]?['url'])).toList(),
    );
  }
}

class SpotifyResults {
  final List<SpotifyTrack> tracks;
  final List<SpotifyAlbum> albums;
  final List<SpotifyArtist> artists;
  final List<SpotifyPlaylist> playlists;
  SpotifyResults({required this.tracks, required this.albums, required this.artists, required this.playlists});
  factory SpotifyResults.empty() => SpotifyResults(tracks: [], albums: [], artists: [], playlists: []);
}

class SpotifyTrack {
  final String id, uri, name;
  final String? artist, album, art;
  final int? duration;
  SpotifyTrack({required this.id, required this.uri, required this.name, this.artist, this.album, this.art, this.duration});
  String get durationStr { if (duration == null) return ''; final m = duration! ~/ 60000; final s = (duration! % 60000) ~/ 1000; return '$m:${s.toString().padLeft(2, '0')}'; }
}

class SpotifyAlbum {
  final String id, uri, name;
  final String? artist, art, year;
  SpotifyAlbum({required this.id, required this.uri, required this.name, this.artist, this.art, this.year});
}

class SpotifyArtist {
  final String id, uri, name;
  final String? art;
  SpotifyArtist({required this.id, required this.uri, required this.name, this.art});
}

class SpotifyPlaylist {
  final String id, uri, name;
  final String? owner, art;
  SpotifyPlaylist({required this.id, required this.uri, required this.name, this.owner, this.art});
}
