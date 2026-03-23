import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/smithmk_theme.dart';
import '../services/ha_service.dart';
import '../services/spotify_service.dart';

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});
  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  SpotifyResults? _results;
  bool _searching = false;
  String? _error;

  // Echo devices from HA
  List<_EchoDevice> _echos = [];
  String? _selectedEcho;
  bool _loadingDevices = true;

  // Now playing state from HA
  _NowPlaying? _nowPlaying;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadEchoDevices();
    _pollNowPlaying();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollNowPlaying());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEchoDevices() async {
    try {
      final entities = await HAService.getEntities('media_player');
      final echos = entities.where((e) {
        final id = e['entity_id'] as String;
        final attrs = e['attributes'] as Map<String, dynamic>? ?? {};
        // Echo devices typically have alexa in the integration or specific patterns
        return id.contains('echo') || id.contains('alexa') || id.contains('fire_tv') ||
          (attrs['friendly_name']?.toString().toLowerCase().contains('echo') ?? false);
      }).map((e) {
        final attrs = e['attributes'] as Map<String, dynamic>? ?? {};
        return _EchoDevice(
          entityId: e['entity_id'] as String,
          name: attrs['friendly_name']?.toString() ?? e['entity_id'].toString().split('.').last,
          state: e['state'] as String? ?? 'unavailable',
          source: attrs['source'] as String?,
          volume: (attrs['volume_level'] as num?)?.toDouble(),
        );
      }).toList();

      // Also check for Spotify Connect entity
      final spotifyEntity = entities.where((e) => (e['entity_id'] as String).contains('spotify')).toList();

      setState(() {
        _echos = echos;
        _loadingDevices = false;
        if (echos.isNotEmpty && _selectedEcho == null) {
          // Default to first available (not unavailable) echo
          final available = echos.where((e) => e.state != 'unavailable').toList();
          _selectedEcho = available.isNotEmpty ? available.first.entityId : echos.first.entityId;
        }
      });
    } catch (e) {
      setState(() { _loadingDevices = false; _error = 'Failed to load devices: $e'; });
    }
  }

  Future<void> _pollNowPlaying() async {
    try {
      if (_selectedEcho == null) return;
      final entities = await HAService.getEntities('media_player');
      final echo = entities.firstWhere(
        (e) => e['entity_id'] == _selectedEcho,
        orElse: () => <String, dynamic>{},
      );
      if (echo.isEmpty) return;
      final attrs = echo['attributes'] as Map<String, dynamic>? ?? {};
      final state = echo['state'] as String? ?? 'idle';

      setState(() {
        _nowPlaying = _NowPlaying(
          title: attrs['media_title']?.toString(),
          artist: attrs['media_artist']?.toString(),
          album: attrs['media_album_name']?.toString(),
          artUrl: attrs['entity_picture']?.toString(),
          state: state,
          volume: (attrs['volume_level'] as num?)?.toDouble() ?? 0.3,
          duration: (attrs['media_duration'] as num?)?.toInt(),
          position: (attrs['media_position'] as num?)?.toInt(),
          source: attrs['source']?.toString(),
        );
      });
    } catch (_) {}
  }

  void _onSearch(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() { _results = null; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final r = await SpotifyService.search(query);
        if (mounted) setState(() { _results = r; _searching = false; });
      } catch (e) {
        if (mounted) setState(() { _searching = false; _error = 'Search failed: $e'; });
      }
    });
  }

  Future<void> _playTrack(SpotifyTrack track) async {
    if (_selectedEcho == null) return;
    HapticFeedback.mediumImpact();
    try {
      // Get the friendly name of the selected echo for Spotify Connect source
      final echo = _echos.firstWhere((e) => e.entityId == _selectedEcho);
      await HAService.playSpotify(track.uri, echo.name);
      // Poll immediately to update now playing
      await Future.delayed(const Duration(seconds: 2));
      _pollNowPlaying();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play: $e'), backgroundColor: SmithMkColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      body: SafeArea(child: Column(children: [
        // Header
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: Row(children: [
          Icon(PhosphorIcons.headphones(PhosphorIconsStyle.light), size: 22, color: SmithMkColors.gold),
          const SizedBox(width: 10),
          const Text('Music', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ])),
        const SizedBox(height: 12),

        // Pills
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
          _pill('HA', _echos.isNotEmpty), _pill('SUPABASE', true), _pill('SPOTIFY', _results != null || !_searching),
        ].expand((w) => [w, const SizedBox(width: 6)]).toList()..removeLast())),
        const SizedBox(height: 14),

        // Search
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _searchBar()),
        const SizedBox(height: 12),

        // Device selector
        SizedBox(height: 38, child: _loadingDevices
          ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: SmithMkColors.accent)))
          : ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
              for (final echo in _echos) ...[_deviceChip(echo), const SizedBox(width: 8)],
            ])),
        const SizedBox(height: 14),

        // Content
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 20), physics: const BouncingScrollPhysics(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Now playing
          _nowPlayingCard(),
          const SizedBox(height: 16),

          // Search results or empty state
          if (_searching) const Center(child: Padding(padding: EdgeInsets.all(40),
            child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: SmithMkColors.accent))))
          else if (_results != null && _results!.tracks.isNotEmpty) ...[
            const Text('TRACKS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SmithMkColors.textTertiary, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            ...(_results!.tracks.take(10).map((t) => _trackRow(t))),
            if (_results!.albums.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('ALBUMS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SmithMkColors.textTertiary, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              SizedBox(height: 140, child: ListView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), children: [
                for (final a in _results!.albums.take(10)) ...[_albumCard(a), const SizedBox(width: 10)],
              ])),
            ],
            if (_results!.artists.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('ARTISTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SmithMkColors.textTertiary, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              SizedBox(height: 100, child: ListView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), children: [
                for (final a in _results!.artists.take(8)) ...[_artistChip(a), const SizedBox(width: 10)],
              ])),
            ],
          ] else if (_results != null) ...[
            const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No results', style: TextStyle(color: SmithMkColors.textTertiary)))),
          ],
          const SizedBox(height: 80),
        ]))),
      ])),
    );
  }

  // ─── WIDGETS ───

  Widget _searchBar() => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment(-0.5, -0.5), end: Alignment(0.5, 0.5), colors: [Color(0xFF1A1A22), Color(0xFF101016)]),
      borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 18, offset: const Offset(6, 6)),
        BoxShadow(color: Colors.white.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(-3, -3))]),
    child: TextField(controller: _searchCtrl, onChanged: _onSearch,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: SmithMkColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search Spotify…', hintStyle: const TextStyle(color: Color(0x40FFFFFF)),
        prefixIcon: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.light), size: 18, color: SmithMkColors.textTertiary),
        border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(
          icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.light), size: 16, color: SmithMkColors.textTertiary),
          onPressed: () { _searchCtrl.clear(); _onSearch(''); }) : null)),
  );

  Widget _deviceChip(_EchoDevice echo) {
    final selected = echo.entityId == _selectedEcho;
    final online = echo.state != 'unavailable';
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); setState(() => _selectedEcho = echo.entityId); _pollNowPlaying(); },
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: const Alignment(-0.5, -0.5), end: const Alignment(0.5, 0.5),
            colors: selected ? [const Color(0xFF2A2210), const Color(0xFF1E1A0E)] : [const Color(0xFF1A1A22), const Color(0xFF101016)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? SmithMkColors.accent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(4, 4))]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle,
            color: online ? SmithMkColors.success : SmithMkColors.textTertiary,
            boxShadow: online ? [BoxShadow(color: SmithMkColors.success.withValues(alpha: 0.5), blurRadius: 4)] : null)),
          const SizedBox(width: 6),
          Text(echo.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: selected ? SmithMkColors.accent : SmithMkColors.textTertiary)),
        ])));
  }

  Widget _nowPlayingCard() {
    final np = _nowPlaying;
    final playing = np != null && (np.state == 'playing' || np.state == 'paused');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment(-0.6, -0.6), end: Alignment(0.6, 0.6), colors: [Color(0xF21E1E26), Color(0xEB16161C)]),
        borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 32, offset: const Offset(8, 8)),
          BoxShadow(color: Colors.white.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(-3, -3))]),
      child: Column(children: [
        Row(children: [
          // Album art
          Container(width: 72, height: 72, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF111111),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(4, 4))]),
            clipBehavior: Clip.antiAlias,
            child: np?.artUrl != null
              ? Image.network(np!.artUrl!.startsWith('http') ? np.artUrl! : '${HAService.haUrl}${np.artUrl}',
                  fit: BoxFit.cover, filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => _artPlaceholder())
              : _artPlaceholder()),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(np?.title ?? 'Not Playing', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(np?.artist ?? 'Search or pick a track', style: const TextStyle(fontSize: 12, color: SmithMkColors.textSecondary), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('🔊 ${_echos.firstWhere((e) => e.entityId == _selectedEcho, orElse: () => _EchoDevice(entityId: '', name: '—', state: '')).name}',
              style: const TextStyle(fontSize: 9, color: SmithMkColors.textTertiary)),
          ])),
        ]),
        const SizedBox(height: 14),
        // Progress
        if (playing && np!.duration != null) ...[
          _progressBar(np.position ?? 0, np.duration!),
          const SizedBox(height: 12),
        ],
        // Controls
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _ctrlBtn(PhosphorIcons.skipBack(PhosphorIconsStyle.fill), () { if (_selectedEcho != null) HAService.mediaPrev(_selectedEcho!); _pollNowPlaying(); }),
          const SizedBox(width: 14),
          _ctrlBtn(PhosphorIcons.pause(PhosphorIconsStyle.fill), () { if (_selectedEcho != null) HAService.mediaPlayPause(_selectedEcho!); _pollNowPlaying(); }, large: false),
          const SizedBox(width: 10),
          _playBtn(np?.state == 'playing', () { if (_selectedEcho != null) HAService.mediaPlayPause(_selectedEcho!); _pollNowPlaying(); }),
          const SizedBox(width: 10),
          _ctrlBtn(PhosphorIcons.stop(PhosphorIconsStyle.fill), () { if (_selectedEcho != null) HAService.mediaStop(_selectedEcho!); _pollNowPlaying(); }, large: false),
          const SizedBox(width: 14),
          _ctrlBtn(PhosphorIcons.skipForward(PhosphorIconsStyle.fill), () { if (_selectedEcho != null) HAService.mediaNext(_selectedEcho!); _pollNowPlaying(); }),
        ]),
        const SizedBox(height: 12),
        // Volume
        Row(children: [
          Icon(PhosphorIcons.speakerSimpleLow(PhosphorIconsStyle.light), size: 16, color: SmithMkColors.textTertiary),
          const SizedBox(width: 8),
          Expanded(child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              activeTrackColor: SmithMkColors.accent, inactiveTrackColor: Colors.white.withValues(alpha: 0.06),
              thumbColor: const Color(0xFF3A3A3A), overlayColor: SmithMkColors.accent.withValues(alpha: 0.1)),
            child: Slider(value: np?.volume ?? 0.3, onChanged: (v) {
              setState(() { if (_nowPlaying != null) _nowPlaying = _nowPlaying!.copyWith(volume: v); });
              if (_selectedEcho != null) HAService.mediaVolume(_selectedEcho!, v);
            }))),
          const SizedBox(width: 8),
          Text('${((np?.volume ?? 0.3) * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SmithMkColors.textTertiary)),
        ]),
      ]),
    );
  }

  Widget _artPlaceholder() => Container(color: const Color(0xFF111111),
    child: Center(child: Icon(PhosphorIcons.vinylRecord(PhosphorIconsStyle.light), size: 28, color: const Color(0xFF333333))));

  Widget _progressBar(int pos, int dur) {
    final frac = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
    return Column(children: [
      Container(height: 4, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: Colors.white.withValues(alpha: 0.06)),
        child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: frac,
          child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(colors: [SmithMkColors.accent, SmithMkColors.gold]))))),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(_fmtTime(pos), style: const TextStyle(fontSize: 9, color: SmithMkColors.textTertiary, fontFeatures: [FontFeature.tabularFigures()])),
        Text(_fmtTime(dur), style: const TextStyle(fontSize: 9, color: SmithMkColors.textTertiary, fontFeatures: [FontFeature.tabularFigures()])),
      ]),
    ]);
  }

  String _fmtTime(int secs) => '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';

  Widget _ctrlBtn(IconData icon, VoidCallback onTap, {bool large = false}) => GestureDetector(onTap: () { HapticFeedback.lightImpact(); onTap(); },
    child: Container(width: large ? 48 : 38, height: large ? 48 : 38,
      decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A2A2A), Color(0xFF181818)]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(4, 4)),
          BoxShadow(color: Colors.white.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(-2, -2))]),
      child: Icon(icon, size: large ? 20 : 16, color: SmithMkColors.textSecondary)));

  Widget _playBtn(bool playing, VoidCallback onTap) => GestureDetector(onTap: () { HapticFeedback.mediumImpact(); onTap(); },
    child: Container(width: 52, height: 52,
      decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A2010), Color(0xFF1E1A0E)]),
        border: Border.all(color: SmithMkColors.accent.withValues(alpha: 0.3), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 16, offset: const Offset(5, 5)),
          BoxShadow(color: SmithMkColors.accent.withValues(alpha: 0.1), blurRadius: 16)]),
      child: Icon(playing ? PhosphorIcons.pause(PhosphorIconsStyle.fill) : PhosphorIcons.play(PhosphorIconsStyle.fill),
        size: 22, color: SmithMkColors.accent)));

  Widget _trackRow(SpotifyTrack track) => GestureDetector(onTap: () => _playTrack(track),
    child: Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.015), borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(2, 2))]),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF1A1A1A)),
          clipBehavior: Clip.antiAlias,
          child: track.art != null ? Image.network(track.art!, fit: BoxFit.cover, filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => _artPlaceholder()) : _artPlaceholder()),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(track.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          Text('${track.artist ?? ''} · ${track.album ?? ''}', style: const TextStyle(fontSize: 10, color: SmithMkColors.textTertiary), overflow: TextOverflow.ellipsis),
        ])),
        if (track.durationStr.isNotEmpty) Text(track.durationStr, style: const TextStyle(fontSize: 10, color: SmithMkColors.textTertiary, fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(width: 8),
        Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF222222), Color(0xFF181818)]),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(2, 2))]),
          child: Icon(PhosphorIcons.play(PhosphorIconsStyle.fill), size: 12, color: SmithMkColors.accent)),
      ])));

  Widget _albumCard(SpotifyAlbum album) => GestureDetector(
    onTap: () {}, // TODO: drill into album
    child: Container(width: 100,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white.withValues(alpha: 0.015),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(2, 2))]),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 100, height: 100, color: const Color(0xFF1A1A1A),
          child: album.art != null ? Image.network(album.art!, fit: BoxFit.cover, filterQuality: FilterQuality.high) : _artPlaceholder()),
        Padding(padding: const EdgeInsets.all(6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(album.name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          Text(album.artist ?? '', style: const TextStyle(fontSize: 9, color: SmithMkColors.textTertiary), overflow: TextOverflow.ellipsis),
        ])),
      ])));

  Widget _artistChip(SpotifyArtist artist) => GestureDetector(
    onTap: () {}, // TODO: drill into artist
    child: Column(children: [
      Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF1A1A1A),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(3, 3))]),
        clipBehavior: Clip.antiAlias,
        child: artist.art != null ? Image.network(artist.art!, fit: BoxFit.cover, filterQuality: FilterQuality.high) : _artPlaceholder()),
      const SizedBox(height: 4),
      SizedBox(width: 70, child: Text(artist.name, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
    ]));

  Widget _pill(String label, bool ok) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: const Color(0x0AFFFFFF),
      border: Border.all(color: ok ? const Color(0x4D4CAF50) : const Color(0x4DEF4444))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle,
        color: ok ? SmithMkColors.success : SmithMkColors.error,
        boxShadow: [BoxShadow(color: ok ? SmithMkColors.success : SmithMkColors.error, blurRadius: 6)])),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0x66FFFFFF))),
    ]));
}

class _EchoDevice {
  final String entityId, name, state;
  final String? source;
  final double? volume;
  _EchoDevice({required this.entityId, required this.name, required this.state, this.source, this.volume});
}

class _NowPlaying {
  final String? title, artist, album, artUrl, state, source;
  final double volume;
  final int? duration, position;
  _NowPlaying({this.title, this.artist, this.album, this.artUrl, this.state, this.volume = 0.3, this.duration, this.position, this.source});
  _NowPlaying copyWith({double? volume}) => _NowPlaying(
    title: title, artist: artist, album: album, artUrl: artUrl, state: state,
    volume: volume ?? this.volume, duration: duration, position: position, source: source);
}
