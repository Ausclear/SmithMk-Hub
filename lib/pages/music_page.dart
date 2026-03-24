import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/smithmk_theme.dart';
import '../services/ha_service.dart';
import '../services/spotify_service.dart';

/// Hardcoded Echo device list — matches PWA exactly
const _ECHOS = [
  ('media_player.meals_echo', 'Meals Echo'),
  ('media_player.mark_s_echo_dot', "Mark's Echo Dot"),
  ('media_player.mark_s_echo_spot', "Mark's Echo Spot"),
  ('media_player.guest_echo_show', 'Guest Echo Show'),
  ('media_player.mark_s_2nd_echo_show', "Mark's 2nd Echo Show"),
  ('media_player.cerise_echo_show', 'Cerise Echo Show'),
  ('media_player.family_room', 'Family Room'),
  ('media_player.lounge', 'Lounge'),
  ('media_player.kitchen', 'Kitchen'),
  ('media_player.kitchen_echo', 'Kitchen Echo'),
  ('media_player.cerise_s_room', "Cerise's Room"),
  ('media_player.xendan_s_room', "Xendan's Room"),
  ('media_player.patio_sonos', 'Patio Sonos'),
];

/// Spotify Connect source names for each Echo
const _SPOTIFY_SOURCES = {
  'media_player.meals_echo': 'Meals Echo',
  'media_player.mark_s_echo_dot': "Mark's Echo Dot",
  'media_player.mark_s_echo_spot': "Mark's Echo Spot",
  'media_player.guest_echo_show': 'Guest Echo Show',
  'media_player.mark_s_2nd_echo_show': "Mark's 2nd Echo Show",
  'media_player.cerise_echo_show': 'Cerise Echo Show',
  'media_player.family_room': 'Family Room',
  'media_player.lounge': 'Lounge',
  'media_player.kitchen': 'Kitchen',
  'media_player.kitchen_echo': 'Kitchen Echo',
  'media_player.cerise_s_room': "Cerise's Room",
  'media_player.xendan_s_room': "Xendan's Room",
};

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
  String? _playingUri;
  String _selectedEcho = _ECHOS[0].$1;
  Map<String, String> _deviceStates = {}; // entity_id -> state
  Map<String, Map<String, dynamic>> _deviceAttrs = {}; // entity_id -> attributes
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollDevices();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollDevices());
  }

  @override
  void dispose() { _searchCtrl.dispose(); _debounce?.cancel(); _pollTimer?.cancel(); super.dispose(); }

  Future<void> _pollDevices() async {
    try {
      final entities = await HAService.getEntities('media_player');
      final states = <String, String>{};
      final attrs = <String, Map<String, dynamic>>{};
      for (final e in entities) {
        final id = e['entity_id'] as String;
        states[id] = e['state'] as String? ?? 'unavailable';
        attrs[id] = (e['attributes'] as Map<String, dynamic>?) ?? {};
      }
      if (mounted) setState(() { _deviceStates = states; _deviceAttrs = attrs; });
    } catch (_) {}
  }

  void _onSearch(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) { setState(() { _results = null; _searching = false; }); return; }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final r = await SpotifyService.search(query);
        if (mounted) setState(() { _results = r; _searching = false; });
      } catch (e) {
        if (mounted) setState(() { _searching = false; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    });
  }

  Future<void> _playTrack(SpotifyTrack track) async {
    HapticFeedback.mediumImpact();
    setState(() => _playingUri = track.uri);
    final source = _SPOTIFY_SOURCES[_selectedEcho];
    if (source == null) {
      // Direct play on entity (Sonos etc)
      try {
        await HAService.callService('media_player', 'play_media', {
          'entity_id': _selectedEcho, 'media_content_id': track.uri, 'media_content_type': 'music'});
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Play failed: $e')));
      }
    } else {
      try {
        await HAService.playSpotify(track.uri, source);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Play failed: $e')));
      }
    }
    if (mounted) {
      final echoName = _ECHOS.firstWhere((e) => e.$1 == _selectedEcho).$2;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('▶ ${track.name} → $echoName'), backgroundColor: const Color(0xFF1C1C1E), duration: const Duration(seconds: 2)));
      setState(() => _playingUri = null);
      Future.delayed(const Duration(seconds: 2), () => _pollDevices());
    }
  }

  // Shortcuts for selected device
  void _play() { HAService.mediaPlayPause(_selectedEcho); Future.delayed(const Duration(seconds: 1), _pollDevices); }
  void _stop() { HAService.mediaStop(_selectedEcho); Future.delayed(const Duration(seconds: 1), _pollDevices); }
  void _next() { HAService.mediaNext(_selectedEcho); Future.delayed(const Duration(seconds: 1), _pollDevices); }
  void _prev() { HAService.mediaPrev(_selectedEcho); Future.delayed(const Duration(seconds: 1), _pollDevices); }
  void _vol(double v) { HAService.mediaVolume(_selectedEcho, v); }

  String get _selState => _deviceStates[_selectedEcho] ?? 'idle';
  Map<String, dynamic> get _selAttrs => _deviceAttrs[_selectedEcho] ?? {};
  bool get _isPlaying => _selState == 'playing';
  String? get _nowTitle => _selAttrs['media_title']?.toString();
  String? get _nowArtist => _selAttrs['media_artist']?.toString();
  String? get _nowArt => _selAttrs['entity_picture']?.toString();
  double get _nowVol => (_selAttrs['volume_level'] as num?)?.toDouble() ?? 0.3;
  int? get _nowDuration => (_selAttrs['media_duration'] as num?)?.toInt();
  int? get _nowPosition => (_selAttrs['media_position'] as num?)?.toInt();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(children: [
          // Header
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: Row(children: [
            GestureDetector(onTap: () => Navigator.pop(context),
              child: Icon(PhosphorIcons.caretLeft(PhosphorIconsStyle.light), size: 20, color: SmithMkColors.textTertiary)),
            const SizedBox(width: 8),
            Icon(PhosphorIcons.headphones(PhosphorIconsStyle.light), size: 22, color: SmithMkColors.gold),
            const SizedBox(width: 10),
            const Text('Music', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ])),
          const SizedBox(height: 14),

          // Scrollable content
          Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), physics: const BouncingScrollPhysics(), children: [

            // ─── DEVICES — horizontal wrap, tap to select ───
            _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('DEVICES'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final echo in _ECHOS) _deviceChip(echo.$1, echo.$2),
              ]),
            ])),
            const SizedBox(height: 12),

            // ─── NOW PLAYING ───
            _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('NOW PLAYING'),
              Row(children: [
                // Art
                Container(width: 64, height: 64, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFF111111)),
                  clipBehavior: Clip.antiAlias,
                  child: _nowArt != null
                    ? Image.network(_nowArt!.startsWith('http') ? _nowArt! : '${HAService.haUrl}$_nowArt',
                        fit: BoxFit.cover, filterQuality: FilterQuality.high, errorBuilder: (_, __, ___) => _artIcon())
                    : _artIcon()),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_nowTitle ?? 'Not Playing', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(_nowArtist ?? 'Search or pick a track', style: const TextStyle(fontSize: 12, color: Color(0xBFFF9900)), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('🔊 ${_ECHOS.firstWhere((e) => e.$1 == _selectedEcho).$2}',
                    style: const TextStyle(fontSize: 10, color: Color(0x33FFFFFF))),
                ])),
              ]),
              if (_nowDuration != null && _nowDuration! > 0) ...[
                const SizedBox(height: 12),
                _progressBar(_nowPosition ?? 0, _nowDuration!),
              ],
              const SizedBox(height: 12),
              // Controls
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _ctrlBtn(PhosphorIcons.shuffle(PhosphorIconsStyle.bold), () {}),
                const SizedBox(width: 10),
                _ctrlBtn(PhosphorIcons.skipBack(PhosphorIconsStyle.fill), _prev),
                const SizedBox(width: 10),
                _playPauseBtn(),
                const SizedBox(width: 10),
                _ctrlBtn(PhosphorIcons.stop(PhosphorIconsStyle.fill), _stop),
                const SizedBox(width: 10),
                _ctrlBtn(PhosphorIcons.skipForward(PhosphorIconsStyle.fill), _next),
              ]),
              const SizedBox(height: 12),
              // Volume
              Row(children: [
                Icon(PhosphorIcons.speakerSimpleLow(PhosphorIconsStyle.light), size: 16, color: const Color(0x4DFFFFFF)),
                const SizedBox(width: 8),
                Expanded(child: SliderTheme(
                  data: SliderThemeData(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    activeTrackColor: const Color(0xFFFF9900), inactiveTrackColor: const Color(0x14FFFFFF),
                    thumbColor: const Color(0xFFFF9900), overlayColor: const Color(0x1AFF9900)),
                  child: Slider(value: _nowVol.clamp(0.0, 1.0), onChanged: (v) { setState(() {}); _vol(v); }))),
                const SizedBox(width: 8),
                Text('${(_nowVol * 100).round()}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0x40FFFFFF))),
              ]),
            ])),
            const SizedBox(height: 12),

            // ─── SEARCH ───
            _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Tabs
              Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0x0AFFFFFF),
                border: Border.all(color: const Color(0x12FFFFFF))),
                child: Row(children: [
                  _tabBtn('Search', true), Container(width: 1, height: 36, color: const Color(0x12FFFFFF)), _tabBtn('Announce', false),
                ])),
              const SizedBox(height: 14),
              // Service selector
              Row(children: [
                _svcBtn('Spotify', const Color(0xFF1DB954), true), const SizedBox(width: 6),
                _svcBtn('Amazon', const Color(0xFFFF9900), false), const SizedBox(width: 6),
                _svcBtn('TuneIn', const Color(0xFF00B4D8), false),
              ]),
              const SizedBox(height: 12),
              // Search input
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0x0FFFFFFF),
                  border: Border.all(color: const Color(0x1AFFFFFF))),
                child: TextField(controller: _searchCtrl, onChanged: _onSearch,
                  style: const TextStyle(fontSize: 14, color: Color(0xE6FFFFFF)),
                  decoration: InputDecoration(
                    hintText: 'Search artists, songs, albums…', hintStyle: const TextStyle(color: Color(0x40FFFFFF)),
                    prefixIcon: _searching
                      ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1DB954))))
                      : Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.light), size: 14, color: const Color(0x40FFFFFF)),
                    border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13)))),
              const SizedBox(height: 12),
              // Results
              if (_results != null && _results!.tracks.isNotEmpty) ...[
                // Result type tabs
                Wrap(spacing: 6, children: [
                  _resTab('Tracks', true), _resTab('Albums', false), _resTab('Artists', false), _resTab('Playlists', false),
                ]),
                const SizedBox(height: 12),
                ..._results!.tracks.take(10).map((t) => _trackRow(t)),
              ] else if (_results != null) ...[
                const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No results', style: TextStyle(color: Color(0x40FFFFFF))))),
              ],
            ])),
            const SizedBox(height: 80),
          ])),
        ])))),
    );
  }

  // ─── Widgets ───

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x14FFC107))),
    child: child);

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.7, color: Color(0x80FFC107))));

  Widget _deviceChip(String entityId, String name) {
    final sel = entityId == _selectedEcho;
    final state = _deviceStates[entityId] ?? 'unavailable';
    final online = state != 'unavailable';
    final playing = state == 'playing';
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); setState(() => _selectedEcho = entityId); },
      child: AnimatedContainer(duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
          color: sel ? const Color(0x12FF9900) : const Color(0x08FFFFFF),
          border: Border.all(color: sel ? const Color(0x38FF9900) : const Color(0x0FFFFFFF))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle,
            color: playing ? const Color(0xFFFF9900) : online ? const Color(0xFF4ADE80) : const Color(0xFF555555),
            boxShadow: [if (online) BoxShadow(color: playing ? const Color(0x66FF9900) : const Color(0x664ADE80), blurRadius: 4)])),
          const SizedBox(width: 6),
          Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: sel ? const Color(0xE6FFFFFF) : const Color(0x66FFFFFF))),
        ])));
  }

  Widget _progressBar(int pos, int dur) {
    final frac = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
    return Column(children: [
      Container(height: 6, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: const Color(0x14FFFFFF)),
        child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: frac,
          child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: const Color(0xFFFF9900))))),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(_fmt(pos), style: const TextStyle(fontSize: 10, color: Color(0x33FFFFFF), fontFeatures: [FontFeature.tabularFigures()])),
        Text(_fmt(dur), style: const TextStyle(fontSize: 10, color: Color(0x33FFFFFF), fontFeatures: [FontFeature.tabularFigures()])),
      ]),
    ]);
  }

  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  Widget _ctrlBtn(IconData icon, VoidCallback onTap) {
    return _Pressable(onTap: () { HapticFeedback.lightImpact(); onTap(); },
      builder: (pressed) => Container(width: 42, height: 42,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
          color: pressed ? const Color(0x8CFFC107) : const Color(0x0DFFFFFF),
          border: Border.all(color: pressed ? const Color(0xCCFFC107) : const Color(0x17FFFFFF)),
          boxShadow: pressed ? [const BoxShadow(color: Color(0x80000000), blurRadius: 8, offset: Offset(0, 2))] : null),
        child: Icon(icon, size: 16, color: pressed ? Colors.white : const Color(0x99FFFFFF))));
  }

  Widget _playPauseBtn() {
    return _Pressable(onTap: () { HapticFeedback.mediumImpact(); _play(); },
      builder: (pressed) => Container(width: 50, height: 50,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
          color: pressed ? const Color(0x8CFF9900) : const Color(0x1FFF9900),
          border: Border.all(color: pressed ? const Color(0xCCFF9900) : const Color(0x59FF9900)),
          boxShadow: pressed ? [const BoxShadow(color: Color(0x80000000), blurRadius: 8, offset: Offset(0, 2))] : null),
        child: Icon(_isPlaying ? PhosphorIcons.pause(PhosphorIconsStyle.fill) : PhosphorIcons.play(PhosphorIconsStyle.fill),
          size: 20, color: pressed ? Colors.white : const Color(0xFFFF9900))));
  }

  Widget _tabBtn(String label, bool active) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(color: active ? const Color(0x1AFFC107) : Colors.transparent, borderRadius: BorderRadius.circular(active ? 12 : 0)),
    child: Text(label.toUpperCase(), textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.7, color: active ? const Color(0xFFFFC107) : const Color(0x4DFFFFFF)))));

  Widget _svcBtn(String label, Color col, bool active) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
      color: active ? col.withValues(alpha: 0.14) : const Color(0x0AFFFFFF),
      border: Border.all(color: active ? col.withValues(alpha: 0.4) : const Color(0x12FFFFFF))),
    child: Text(label, textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? col : const Color(0x4DFFFFFF)))));

  Widget _resTab(String label, bool active) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
      color: active ? const Color(0x1AFFC107) : const Color(0x0AFFFFFF),
      border: Border.all(color: active ? const Color(0x4DFFC107) : const Color(0x0FFFFFFF))),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? const Color(0xFFFFC107) : const Color(0x4DFFFFFF))));

  Widget _artIcon() => Container(color: const Color(0xFF111111),
    child: Center(child: Icon(PhosphorIcons.vinylRecord(PhosphorIconsStyle.light), size: 24, color: const Color(0xFF333333))));

  Widget _trackRow(SpotifyTrack track) {
    final loading = _playingUri == track.uri;
    return _Pressable(
      onTap: () => _playTrack(track),
      builder: (pressed) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
          color: pressed ? const Color(0x0FFFFFFF) : const Color(0x08FFFFFF),
          border: Border.all(color: pressed ? const Color(0x1AFFC107) : const Color(0x0FFFFFFF))),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF1A1A1A)),
            clipBehavior: Clip.antiAlias,
            child: track.art != null ? Image.network(track.art!, fit: BoxFit.cover, filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => _artIcon()) : _artIcon()),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(track.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xE0FFFFFF)), overflow: TextOverflow.ellipsis),
            Text('${track.artist ?? ''} · ${track.album ?? ''}', style: const TextStyle(fontSize: 12, color: Color(0x4DFFFFFF)), overflow: TextOverflow.ellipsis),
          ])),
          if (track.durationStr.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 8),
            child: Text(track.durationStr, style: const TextStyle(fontSize: 12, color: Color(0x33FFFFFF), fontFeatures: [FontFeature.tabularFigures()]))),
          Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle,
            color: loading ? const Color(0x381DB954) : const Color(0x1F1DB954),
            border: Border.all(color: loading ? const Color(0x801DB954) : const Color(0x4D1DB954))),
            child: loading
              ? const Padding(padding: EdgeInsets.all(7), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1DB954)))
              : const Icon(PhosphorIconsFill.play, size: 12, color: Color(0xFF1DB954))),
        ])));
  }
}

/// Generic pressable wrapper — fires on pointerDown for zero latency
class _Pressable extends StatefulWidget {
  final VoidCallback onTap;
  final Widget Function(bool pressed) builder;
  const _Pressable({required this.onTap, required this.builder});
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _p = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _p = true),
    onTapUp: (_) { setState(() => _p = false); widget.onTap(); },
    onTapCancel: () => setState(() => _p = false),
    child: widget.builder(_p));
}
