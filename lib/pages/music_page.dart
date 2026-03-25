import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/smithmk_theme.dart';
import '../services/ha_service.dart';
import '../services/spotify_service.dart';

// ─── Device list — matches PWA exactly ───
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

/// Per-device state — mirrors PWA's Dev type exactly
class _Dev {
  final String entity, name, state;
  final String? title, artist, album, art;
  final int? vol; // 0-100 (matches PWA)
  final bool? muted, shuffle;
  final num? duration, position;
  final String? positionUpdated;
  _Dev({required this.entity, required this.name, required this.state,
    this.title, this.artist, this.album, this.art,
    this.vol, this.muted, this.shuffle, this.duration, this.position, this.positionUpdated});
}

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

  // Device state — mirrors PWA
  List<_Dev> _devs = [];
  String? _sel; // selected entity_id
  Map<String, bool?> _optPlay = {}; // optimistic play state per entity
  int? _localVol; // 0-100, null = use HA value
  Timer? _tickTimer;
  int _livePos = 0;
  StreamSubscription? _wsSub;

  _Dev? get _active => _devs.firstWhere((d) => d.entity == _sel, orElse: () => _devs.isNotEmpty ? _devs.first : _Dev(entity: '', name: '', state: 'idle'));

  bool _getEffPlaying(String entity) {
    final opt = _optPlay[entity];
    if (opt != null) return opt;
    // Check Echo entity state
    if (_devs.any((d) => d.entity == entity && d.state == 'playing')) return true;
    // Also check if Spotify is playing on this Echo (Echo state may lag behind)
    final spState = _rawStates[HAService.spotifyEntity] ?? 'idle';
    final sp = _rawAttrs[HAService.spotifyEntity] ?? {};
    if (spState == 'playing' && sp['source'] == _SPOTIFY_SOURCES[entity]) return true;
    return false;
  }

  // Raw state from HA — updated by WebSocket in place
  Map<String, String> _rawStates = {};
  Map<String, Map<String, dynamic>> _rawAttrs = {};

  @override
  void initState() {
    super.initState();
    _loadState(); // ONE initial REST fetch
    HAService.connect();
    _wsSub = HAService.stateStream.listen(_onWsEvent); // Update in place
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() { _searchCtrl.dispose(); _debounce?.cancel(); _tickTimer?.cancel(); _wsSub?.cancel(); super.dispose(); }

  /// Handle individual WebSocket state_changed event — NO REST calls
  void _onWsEvent(Map<String, dynamic> data) {
    final entityId = data['entity_id'] as String?;
    if (entityId == null || !mounted) return;
    _rawStates[entityId] = data['state'] as String? ?? 'idle';
    _rawAttrs[entityId] = Map<String, dynamic>.from(data['attributes'] ?? {});
    _rebuildDevs();
  }

  /// ONE initial REST fetch — populates raw state, then builds device list
  Future<void> _loadState() async {
    try {
      final all = await HAService.getEntities('media_player');
      for (final e in all) {
        final id = e['entity_id'] as String;
        _rawStates[id] = e['state'] as String? ?? 'unavailable';
        _rawAttrs[id] = (e['attributes'] as Map<String, dynamic>?) ?? {};
      }
      _rebuildDevs();
    } catch (_) {}
  }

  /// Rebuild the _devs list from raw state — mirrors PWA poll() logic exactly
  void _rebuildDevs() {
    final spState = _rawStates[HAService.spotifyEntity] ?? 'idle';
    final sp = _rawAttrs[HAService.spotifyEntity] ?? {};
    final spOn = spState == 'playing' || spState == 'paused';

    final devs = <_Dev>[];
    for (final echo in _ECHOS) {
      final state = _rawStates[echo.$1] ?? 'unavailable';
      if (state == 'unavailable') {
        devs.add(_Dev(entity: echo.$1, name: echo.$2, state: 'unavailable'));
        continue;
      }
      final a = _rawAttrs[echo.$1] ?? {};
      final src = spOn && sp['source'] == _SPOTIFY_SOURCES[echo.$1];
      devs.add(_Dev(
        entity: echo.$1, name: echo.$2, state: state,
        title: (src ? sp['media_title'] : a['media_title'])?.toString(),
        artist: (src ? sp['media_artist'] : a['media_artist'])?.toString(),
        album: (src ? sp['media_album_name'] : a['media_album_name'])?.toString(),
        art: (src ? sp['entity_picture'] : a['entity_picture'])?.toString(),
        vol: a['volume_level'] is num ? ((a['volume_level'] as num) * 100).round() : null,
        muted: a['is_volume_muted'] as bool?,
        duration: src ? sp['media_duration'] as num? : a['media_duration'] as num?,
        position: src ? sp['media_position'] as num? : a['media_position'] as num?,
        positionUpdated: (src ? sp['media_position_updated_at'] : a['media_position_updated_at'])?.toString(),
        shuffle: (src ? sp['shuffle'] : a['shuffle']) as bool?,
      ));
    }

    if (!mounted) return;
    setState(() {
      _devs = devs;
      // Clear optimistic states that match reality
      final upd = Map<String, bool?>.from(_optPlay);
      for (final entry in _optPlay.entries) {
        if (entry.value == null) continue;
        final real = devs.firstWhere((d) => d.entity == entry.key, orElse: () => _Dev(entity: '', name: '', state: 'idle'));
        if ((real.state == 'playing') == entry.value) upd.remove(entry.key);
      }
      _optPlay = upd;
      // Clear localVol if HA matches (within 2%)
      if (_localVol != null && _active != null && _active!.vol != null) {
        if ((_localVol! - _active!.vol!).abs() <= 2) _localVol = null;
      }
      // Set selection if not set
      if (_sel == null || !devs.any((d) => d.entity == _sel)) {
        _sel = devs.firstWhere((d) => d.state == 'playing', orElse: () => devs.first).entity;
      }
    });
    _syncPosition();
  }

  void _syncPosition() {
    final a = _active;
    if (a == null) return;
    final pos = (a.position as num?)?.toInt() ?? 0;
    final updatedAt = a.positionUpdated;
    final isPlaying = _getEffPlaying(a.entity);
    int newPos = pos;
    if (updatedAt != null && isPlaying) {
      final t = DateTime.tryParse(updatedAt);
      if (t != null) newPos = (pos + DateTime.now().difference(t).inSeconds).clamp(0, (a.duration?.toInt() ?? 99999));
    }
    _livePos = newPos;
  }

  void _tick() {
    final a = _active;
    if (a == null) return;
    if (_getEffPlaying(a.entity) && a.duration != null && _livePos < a.duration!.toInt()) {
      setState(() => _livePos++);
    }
  }

  // ─── Search ───
  void _onSearch(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) { setState(() { _results = null; _searching = false; }); return; }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final r = await SpotifyService.search(query);
        if (mounted) setState(() { _results = r; _searching = false; });
      } catch (_) { if (mounted) setState(() => _searching = false); }
    });
  }

  // ─── Play a track — matches PWA playUri exactly ───
  Future<void> _playTrack(SpotifyTrack track) async {
    if (_sel == null) return;
    HapticFeedback.mediumImpact();
    setState(() { _playingUri = track.uri; _optPlay[_sel!] = true; });
    final src = _SPOTIFY_SOURCES[_sel!];
    try {
      if (track.uri.startsWith('spotify:') && src != null) {
        // PWA: fetch("/api/ha/play-spotify", {uri, source})
        await HAService.playSpotify(track.uri, src);
      } else {
        // PWA: svc("media_player","play_media",{entity_id:curSel,...})
        await HAService.callService('media_player', 'play_media', {
          'entity_id': _sel!, 'media_content_id': track.uri, 'media_content_type': 'music'});
      }
      if (mounted) {
        final name = _ECHOS.firstWhere((e) => e.$1 == _sel).$2;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('▶ ${track.name} → $name'), backgroundColor: const Color(0xFF1C1C1E), duration: const Duration(seconds: 2)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Play failed: $e')));
    }
    if (mounted) setState(() => _playingUri = null);
  }

  // ─── Controls — ALL target active.entity (the selected Echo) — matches PWA EXACTLY ───
  void _togglePlay() {
    final a = _active; if (a == null) return;
    final cur = _getEffPlaying(a.entity);
    setState(() => _optPlay[a.entity] = !cur);
    // PWA: svc("media_player","media_play_pause",{entity_id:entity})
    HAService.callService('media_player', 'media_play_pause', {'entity_id': a.entity});
  }

  void _stop() {
    final a = _active; if (a == null) return;
    setState(() { _optPlay[a.entity] = false; _livePos = 0; });
    // PWA: svc("media_player","media_stop",{entity_id:entity})
    HAService.callService('media_player', 'media_stop', {'entity_id': a.entity});
  }

  void _next() {
    final a = _active; if (a == null) return;
    setState(() => _livePos = 0);
    // PWA: svc("media_player","media_next_track",{entity_id:active.entity})
    HAService.callService('media_player', 'media_next_track', {'entity_id': a.entity});
  }

  void _prev() {
    final a = _active; if (a == null) return;
    // PWA: if(livePos>3) media_seek else media_previous_track — BOTH on active.entity
    if (_livePos > 3) {
      setState(() => _livePos = 0);
      HAService.callService('media_player', 'media_seek', {'entity_id': a.entity, 'seek_position': 0});
    } else {
      setState(() => _livePos = 0);
      HAService.callService('media_player', 'media_previous_track', {'entity_id': a.entity});
    }
  }

  // ─── Volume — matches PWA: localVol on drag, commit on release, entity_id: active.entity ───
  void _volChanged(int v) { setState(() => _localVol = v); }
  void _volCommit(int v) {
    final a = _active; if (a == null) return;
    setState(() => _localVol = v);
    // PWA: svc("media_player","volume_set",{entity_id:active.entity,volume_level:v/100})
    HAService.callService('media_player', 'volume_set', {'entity_id': a.entity, 'volume_level': v / 100});
  }

  @override
  Widget build(BuildContext context) {
    final a = _active;
    final isPlaying = a != null && _getEffPlaying(a.entity);
    final displayVol = _localVol ?? a?.vol ?? 30;
    final dur = a?.duration?.toInt();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: Row(children: [
            GestureDetector(onTap: () { if (Navigator.canPop(context)) Navigator.pop(context); },
              child: Icon(PhosphorIcons.caretLeft(PhosphorIconsStyle.light), size: 20, color: SmithMkColors.textTertiary)),
            const SizedBox(width: 8),
            Icon(PhosphorIcons.headphones(PhosphorIconsStyle.light), size: 22, color: SmithMkColors.gold),
            const SizedBox(width: 10),
            const Text('Music', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ])),
          const SizedBox(height: 14),
          Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), physics: const BouncingScrollPhysics(), children: [

            // ─── DEVICES ───
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
                Container(width: 64, height: 64, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFF111111)),
                  clipBehavior: Clip.antiAlias,
                  child: a?.art != null
                    ? Image.network(a!.art!.startsWith('http') ? a.art! : '${HAService.haDirectUrl}${a.art}',
                        fit: BoxFit.cover, filterQuality: FilterQuality.high, errorBuilder: (_, __, ___) => _artIcon())
                    : _artIcon()),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a?.title ?? (isPlaying ? 'Playing…' : a?.state == 'paused' ? 'Paused' : 'Idle'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  if (a?.artist != null) ...[const SizedBox(height: 2),
                    Text(a!.artist!, style: const TextStyle(fontSize: 12, color: Color(0xBFFF9900)), overflow: TextOverflow.ellipsis)],
                  const SizedBox(height: 4),
                  Text('🔊 ${a?.name ?? '—'}', style: const TextStyle(fontSize: 10, color: Color(0x33FFFFFF))),
                ])),
              ]),
              if (dur != null && dur > 0) ...[const SizedBox(height: 12), _progressBar(_livePos, dur)],
              const SizedBox(height: 12),
              // Transport
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _ctrlBtn(PhosphorIcons.skipBack(PhosphorIconsStyle.fill), _prev),
                const SizedBox(width: 10),
                _playPauseBtn(isPlaying),
                const SizedBox(width: 10),
                _ctrlBtn(PhosphorIcons.skipForward(PhosphorIconsStyle.fill), _next),
                const SizedBox(width: 10),
                _ctrlBtn(PhosphorIcons.stop(PhosphorIconsStyle.fill), _stop),
                const SizedBox(width: 10),
                _ctrlBtn(PhosphorIcons.shuffle(PhosphorIconsStyle.bold), () {
                  if (a != null) HAService.callService('media_player', 'shuffle_set', {'entity_id': a.entity, 'shuffle': !(a.shuffle ?? false)});
                }),
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
                  child: Slider(
                    value: displayVol.toDouble().clamp(0, 100),
                    min: 0, max: 100,
                    onChanged: (v) => _volChanged(v.round()),
                    onChangeEnd: (v) => _volCommit(v.round())))),
                const SizedBox(width: 8),
                Text('$displayVol%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0x40FFFFFF))),
              ]),
            ])),
            const SizedBox(height: 12),

            // ─── SEARCH ───
            _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0x0AFFFFFF),
                border: Border.all(color: const Color(0x12FFFFFF))),
                child: Row(children: [
                  _tabBtn('Search', true), Container(width: 1, height: 36, color: const Color(0x12FFFFFF)), _tabBtn('Announce', false),
                ])),
              const SizedBox(height: 14),
              Row(children: [
                _svcBtn('Spotify', const Color(0xFF1DB954), true), const SizedBox(width: 6),
                _svcBtn('Amazon', const Color(0xFFFF9900), false), const SizedBox(width: 6),
                _svcBtn('TuneIn', const Color(0xFF00B4D8), false),
              ]),
              const SizedBox(height: 12),
              Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0x0FFFFFFF),
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
              if (_results != null && _results!.tracks.isNotEmpty) ...[
                Wrap(spacing: 6, children: [_resTab('Tracks', true), _resTab('Albums', false), _resTab('Artists', false), _resTab('Playlists', false)]),
                const SizedBox(height: 12),
                ..._results!.tracks.take(10).map((t) => _trackRow(t)),
              ] else if (_results != null)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No results', style: TextStyle(color: Color(0x40FFFFFF))))),
            ])),
            const SizedBox(height: 80),
          ])),
        ])))),
    );
  }

  // ─── Widgets ───

  Widget _card({required Widget child}) => Container(padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x14FFC107))),
    child: child);
  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.7, color: Color(0x80FFC107))));

  Widget _deviceChip(String entityId, String name) {
    final sel = entityId == _sel;
    final playing = _getEffPlaying(entityId);
    final dev = _devs.firstWhere((d) => d.entity == entityId, orElse: () => _Dev(entity: entityId, name: name, state: 'unavailable'));
    final online = dev.state != 'unavailable';
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); setState(() { _sel = entityId; _localVol = null; _livePos = 0; }); _syncPosition(); },
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
          Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sel ? const Color(0xE6FFFFFF) : const Color(0x66FFFFFF))),
        ])));
  }

  Widget _progressBar(int pos, int dur) {
    final frac = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
    return Column(children: [
      SizedBox(height: 6, child: LayoutBuilder(builder: (_, c) => Stack(children: [
        Container(height: 6, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: const Color(0x14FFFFFF))),
        Container(height: 6, width: c.maxWidth * frac, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: const Color(0xFFFF9900))),
      ]))),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(_fmt(pos), style: const TextStyle(fontSize: 10, color: Color(0x33FFFFFF), fontFeatures: [FontFeature.tabularFigures()])),
        Text(_fmt(dur), style: const TextStyle(fontSize: 10, color: Color(0x33FFFFFF), fontFeatures: [FontFeature.tabularFigures()])),
      ]),
    ]);
  }

  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  Widget _artIcon() => Container(color: const Color(0xFF111111),
    child: Center(child: Icon(PhosphorIcons.vinylRecord(PhosphorIconsStyle.light), size: 24, color: const Color(0xFF333333))));

  Widget _ctrlBtn(IconData icon, VoidCallback onTap) => _Pressable(onTap: () { HapticFeedback.lightImpact(); onTap(); },
    builder: (p) => Container(width: 42, height: 42, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
      color: p ? const Color(0x8CFFC107) : const Color(0x0DFFFFFF),
      border: Border.all(color: p ? const Color(0xCCFFC107) : const Color(0x17FFFFFF))),
      child: Icon(icon, size: 16, color: p ? Colors.white : const Color(0x99FFFFFF))));

  Widget _playPauseBtn(bool isPlaying) => _Pressable(onTap: () { HapticFeedback.mediumImpact(); _togglePlay(); },
    builder: (p) => Container(width: 50, height: 50, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
      color: p ? const Color(0x8CFF9900) : const Color(0x1FFF9900),
      border: Border.all(color: p ? const Color(0xCCFF9900) : const Color(0x59FF9900))),
      child: Icon(isPlaying ? PhosphorIcons.pause(PhosphorIconsStyle.fill) : PhosphorIcons.play(PhosphorIconsStyle.fill),
        size: 20, color: p ? Colors.white : const Color(0xFFFF9900))));

  Widget _tabBtn(String l, bool a) => Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(color: a ? const Color(0x1AFFC107) : Colors.transparent, borderRadius: BorderRadius.circular(a ? 12 : 0)),
    child: Text(l.toUpperCase(), textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.7, color: a ? const Color(0xFFFFC107) : const Color(0x4DFFFFFF)))));

  Widget _svcBtn(String l, Color c, bool a) => Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: a ? c.withValues(alpha: 0.14) : const Color(0x0AFFFFFF),
      border: Border.all(color: a ? c.withValues(alpha: 0.4) : const Color(0x12FFFFFF))),
    child: Text(l, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: a ? c : const Color(0x4DFFFFFF)))));

  Widget _resTab(String l, bool a) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: a ? const Color(0x1AFFC107) : const Color(0x0AFFFFFF),
      border: Border.all(color: a ? const Color(0x4DFFC107) : const Color(0x0FFFFFFF))),
    child: Text(l, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: a ? const Color(0xFFFFC107) : const Color(0x4DFFFFFF))));

  Widget _trackRow(SpotifyTrack track) {
    final loading = _playingUri == track.uri;
    return _Pressable(onTap: () => _playTrack(track), builder: (p) => Container(
      margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
        color: p ? const Color(0x0FFFFFFF) : const Color(0x08FFFFFF),
        border: Border.all(color: p ? const Color(0x1AFFC107) : const Color(0x0FFFFFFF))),
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

class _Pressable extends StatefulWidget {
  final VoidCallback onTap;
  final Widget Function(bool) builder;
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
