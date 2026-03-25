import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/ha_service.dart';
import '../services/spotify_service.dart';

// ─── Echo devices — matches PWA exactly ───
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

/// Per-device state — mirrors PWA Dev type
class _Dev {
  final String entity, name, state;
  final String? title, artist, album, art;
  final int? vol;
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

  // State
  Map<String, String> _rawStates = {};
  Map<String, Map<String, dynamic>> _rawAttrs = {};
  List<_Dev> _devs = [];
  String? _sel;
  Map<String, bool?> _optPlay = {};
  int? _localVol;
  bool _volLocked = false;
  Timer? _volLockTimer;
  Timer? _tickTimer;
  int _livePos = 0;
  String? _lastTrack;
  StreamSubscription? _wsSub;

  _Dev? get _active {
    if (_devs.isEmpty) return null;
    return _devs.firstWhere((d) => d.entity == _sel, orElse: () => _devs.first);
  }

  bool _getEffPlaying(String entity) {
    final opt = _optPlay[entity];
    if (opt != null) return opt;
    if (_devs.any((d) => d.entity == entity && d.state == 'playing')) return true;
    final spState = _rawStates[HAService.spotifyEntity] ?? 'idle';
    final sp = _rawAttrs[HAService.spotifyEntity] ?? {};
    if (spState == 'playing' && sp['source'] == _SPOTIFY_SOURCES[entity]) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadState();
    HAService.connect();
    _wsSub = HAService.stateStream.listen(_onWsEvent);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() { _searchCtrl.dispose(); _debounce?.cancel(); _tickTimer?.cancel(); _volLockTimer?.cancel(); _wsSub?.cancel(); super.dispose(); }

  void _onWsEvent(Map<String, dynamic> data) {
    final entityId = data['entity_id'] as String?;
    if (entityId == null || !mounted) return;
    _rawStates[entityId] = data['state'] as String? ?? 'idle';
    _rawAttrs[entityId] = Map<String, dynamic>.from(data['attributes'] ?? {});
    _rebuildDevs();
  }

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

  void _rebuildDevs() {
    final spState = _rawStates[HAService.spotifyEntity] ?? 'idle';
    final sp = _rawAttrs[HAService.spotifyEntity] ?? {};
    final spOn = spState == 'playing' || spState == 'paused';

    final devs = <_Dev>[];
    for (final echo in _ECHOS) {
      final state = _rawStates[echo.$1] ?? 'unavailable';
      if (state == 'unavailable') { devs.add(_Dev(entity: echo.$1, name: echo.$2, state: 'unavailable')); continue; }
      final a = _rawAttrs[echo.$1] ?? {};
      final src = spOn && sp['source'] == _SPOTIFY_SOURCES[echo.$1];
      devs.add(_Dev(entity: echo.$1, name: echo.$2, state: state,
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
      final upd = Map<String, bool?>.from(_optPlay);
      for (final e in _optPlay.entries) {
        if (e.value == null) continue;
        final real = devs.firstWhere((d) => d.entity == e.key, orElse: () => _Dev(entity: '', name: '', state: 'idle'));
        if ((real.state == 'playing') == e.value) upd.remove(e.key);
      }
      _optPlay = upd;
      if (!_volLocked && _active?.vol != null && _localVol != null && (_localVol! - _active!.vol!).abs() <= 2) _localVol = null;
      if (_sel == null || !devs.any((d) => d.entity == _sel)) {
        _sel = devs.firstWhere((d) => d.state == 'playing', orElse: () => devs.first).entity;
      }
    });
    _syncPosition();
  }

  void _syncPosition() {
    final a = _active; if (a == null) return;
    final pos = (a.position as num?)?.toInt() ?? 0;
    final updatedAt = a.positionUpdated;
    final playing = _getEffPlaying(a.entity);
    int newPos = pos;
    if (updatedAt != null && playing) {
      final t = DateTime.tryParse(updatedAt);
      if (t != null) newPos = (pos + DateTime.now().difference(t).inSeconds).clamp(0, (a.duration?.toInt() ?? 99999));
    }
    if (a.title != _lastTrack) { _livePos = newPos; _lastTrack = a.title; }
    else if ((newPos - _livePos).abs() > 3) _livePos = newPos;
  }

  void _tick() {
    final a = _active; if (a == null) return;
    if (_getEffPlaying(a.entity) && a.duration != null && _livePos < a.duration!.toInt()) setState(() => _livePos++);
  }

  // ─── Search ───
  void _onSearch(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) { setState(() { _results = null; _searching = false; }); return; }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try { final r = await SpotifyService.search(query); if (mounted) setState(() { _results = r; _searching = false; }); }
      catch (_) { if (mounted) setState(() => _searching = false); }
    });
  }

  // ─── Play track — uses play-spotify endpoint like PWA ───
  Future<void> _playTrack(SpotifyTrack track) async {
    if (_sel == null) return;
    HapticFeedback.mediumImpact();
    setState(() { _playingUri = track.uri; _optPlay[_sel!] = true; _livePos = 0; });
    final src = _SPOTIFY_SOURCES[_sel!];
    try {
      if (track.uri.startsWith('spotify:') && src != null) {
        await HAService.playSpotify(track.uri, src);
      } else {
        await HAService.callService('media_player', 'play_media', {'entity_id': _sel!, 'media_content_id': track.uri, 'media_content_type': 'music'});
      }
    } catch (_) {}
    if (mounted) setState(() => _playingUri = null);
  }

  // ─── Controls — ALL target active.entity ───
  void _togglePlay(String entity) {
    final cur = _getEffPlaying(entity);
    setState(() => _optPlay[entity] = !cur);
    HAService.callService('media_player', 'media_play_pause', {'entity_id': entity});
  }
  void _stop() { final a = _active; if (a == null) return; setState(() { _optPlay[a.entity] = false; _livePos = 0; }); HAService.callService('media_player', 'media_stop', {'entity_id': a.entity}); }
  void _next() { final a = _active; if (a == null) return; setState(() => _livePos = 0); HAService.callService('media_player', 'media_next_track', {'entity_id': a.entity}); }
  void _prev() {
    final a = _active; if (a == null) return;
    if (_livePos > 3) { setState(() => _livePos = 0); HAService.callService('media_player', 'media_seek', {'entity_id': a.entity, 'seek_position': 0}); }
    else { setState(() => _livePos = 0); HAService.callService('media_player', 'media_previous_track', {'entity_id': a.entity}); }
  }
  void _shuffle() { final a = _active; if (a == null) return; HAService.callService('media_player', 'shuffle_set', {'entity_id': a.entity, 'shuffle': !(a.shuffle ?? false)}); }

  // ─── Volume — target active.entity, anti-bounce ───
  void _volChanged(int v) { setState(() { _localVol = v; _volLocked = true; }); }
  void _volCommit(int v) {
    final a = _active; if (a == null) return;
    setState(() { _localVol = v; _volLocked = true; });
    HAService.callService('media_player', 'volume_set', {'entity_id': a.entity, 'volume_level': v / 100});
    _volLockTimer?.cancel();
    _volLockTimer = Timer(const Duration(seconds: 5), () { if (mounted) setState(() { _volLocked = false; _localVol = null; }); });
  }
  void _volAdj(int delta) { final cur = _localVol ?? _active?.vol ?? 30; _volCommit((cur + delta).clamp(0, 100)); }

  // ─── COLOURS ───
  static const _bg = Color(0xFF121212);
  static const _card = Color(0xFF1E1E1E);
  static const _amber = Color(0xFFFFB300);
  static const _gold = Color(0xFFC4A96B);

  @override
  Widget build(BuildContext context) {
    final a = _active;
    final isPlaying = a != null && _getEffPlaying(a.entity);
    final displayVol = _localVol ?? a?.vol ?? 30;
    final durSecs = a?.duration?.toInt();
    final isLandscape = MediaQuery.of(context).size.width > 700;

    return Scaffold(backgroundColor: _bg, body: SafeArea(child: Column(children: [
      // HEADER
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: Row(children: [
        _NeuBtn(w: 38, h: 38, onTap: () { if (Navigator.canPop(context)) Navigator.pop(context); },
          child: Icon(PhosphorIcons.caretLeft(PhosphorIconsStyle.bold), size: 16, color: Colors.white54)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MEDIA · MUSIC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.8, color: _gold.withOpacity(0.7))),
          const SizedBox(height: 2),
          const Text('Music', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ]),
        const Spacer(),
        if (_devs.any((d) => _getEffPlaying(d.entity)))
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20), color: _amber.withOpacity(0.1),
            border: Border.all(color: _amber.withOpacity(0.25)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: _amber, boxShadow: [BoxShadow(color: _amber, blurRadius: 8)])),
              const SizedBox(width: 6),
              Text('${_devs.where((d) => _getEffPlaying(d.entity)).length} playing',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _amber)),
            ])),
      ])),

      // CONTENT
      Expanded(child: ListView(padding: EdgeInsets.fromLTRB(16, 0, 16, 100), physics: const BouncingScrollPhysics(), children: [
        if (isLandscape) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 12, child: _buildNowPlaying(a, isPlaying, durSecs, displayVol)),
          const SizedBox(width: 14),
          Expanded(flex: 10, child: Column(children: [_buildDevices(), _buildSearch()])),
        ]) else ...[
          _buildNowPlaying(a, isPlaying, durSecs, displayVol),
          _buildDevices(),
          _buildSearch(),
        ],
      ])),

      // BOTTOM BAR
      if (a != null && (a.title != null || isPlaying)) _buildBottomBar(a, isPlaying),
    ])));
  }

  // ─── NOW PLAYING CARD ───
  Widget _buildNowPlaying(_Dev? a, bool isPlaying, int? durSecs, int displayVol) {
    return _NeuCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Accent bar
      Container(height: 3, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3),
        gradient: LinearGradient(colors: [isPlaying ? _amber : Colors.white10, Colors.transparent]))),
      const SizedBox(height: 14),
      Text('NOW PLAYING', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.8, color: _gold)),
      const SizedBox(height: 14),
      // Art + info
      Row(children: [
        // Album art
        Container(width: 80, height: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFF111111),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 16, offset: const Offset(6, 6)),
            BoxShadow(color: Colors.white.withOpacity(0.02), blurRadius: 8, offset: const Offset(-2, -2))]),
          clipBehavior: Clip.antiAlias,
          child: a?.art != null
            ? Image.network(a!.art!.startsWith('http') ? a.art! : '${HAService.haDirectUrl}${a.art}', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _artPlaceholder())
            : _artPlaceholder()),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(a?.name.toUpperCase() ?? '', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: _amber.withOpacity(0.6))),
          const SizedBox(height: 5),
          Text(a?.title ?? (isPlaying ? 'Playing…' : a?.state == 'paused' ? 'Paused' : 'Idle'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xF2FFFFFF)), overflow: TextOverflow.ellipsis),
          if (a?.artist != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(a!.artist!, style: const TextStyle(fontSize: 13, color: Color(0x73FFFFFF)), overflow: TextOverflow.ellipsis)),
          if (a?.album != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(a!.album!, style: const TextStyle(fontSize: 12, color: Color(0x40FFFFFF)), overflow: TextOverflow.ellipsis)),
        ])),
      ]),
      // Progress
      if (durSecs != null && durSecs > 0) ...[
        const SizedBox(height: 14),
        _buildProgress(_livePos, durSecs),
      ],
      const SizedBox(height: 14),
      // Transport
      Row(children: [
        Expanded(child: _NeuBtn(h: 48, onTap: _prev, child: Icon(PhosphorIcons.skipBack(PhosphorIconsStyle.fill), size: 16, color: Colors.white54))),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: _NeuBtn(h: 48, amber: true, onTap: () { if (a != null) _togglePlay(a.entity); },
          child: Icon(isPlaying ? PhosphorIcons.pause(PhosphorIconsStyle.fill) : PhosphorIcons.play(PhosphorIconsStyle.fill), size: 20, color: _amber))),
        const SizedBox(width: 8),
        Expanded(child: _NeuBtn(h: 48, onTap: _next, child: Icon(PhosphorIcons.skipForward(PhosphorIconsStyle.fill), size: 16, color: Colors.white54))),
        const SizedBox(width: 8),
        Expanded(child: _NeuBtn(h: 48, onTap: _stop, child: Icon(PhosphorIcons.stop(PhosphorIconsStyle.fill), size: 14, color: Colors.white54))),
        const SizedBox(width: 8),
        Expanded(child: _NeuBtn(h: 48, onTap: _shuffle, child: Icon(PhosphorIcons.shuffle(PhosphorIconsStyle.bold), size: 14, color: a?.shuffle == true ? _amber : Colors.white54))),
      ]),
      const SizedBox(height: 14),
      // Volume
      Row(children: [
        _NeuBtn(w: 44, h: 44, onTap: () => _volAdj(-5), child: const Text('−', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0x80FFFFFF)))),
        const SizedBox(width: 8),
        Expanded(child: Column(children: [
          SizedBox(height: 36, child: SliderTheme(data: SliderThemeData(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            activeTrackColor: _amber, inactiveTrackColor: const Color(0x0FFFFFFF), thumbColor: _amber,
            overlayColor: _amber.withOpacity(0.1)),
            child: Slider(value: displayVol.toDouble().clamp(0, 100), min: 0, max: 100,
              onChanged: (v) => _volChanged(v.round()), onChangeEnd: (v) => _volCommit(v.round())))),
          Text('$displayVol%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0x40FFFFFF), letterSpacing: 0.6)),
        ])),
        const SizedBox(width: 8),
        _NeuBtn(w: 44, h: 44, onTap: () => _volAdj(5), child: const Text('+', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0x80FFFFFF)))),
        const SizedBox(width: 8),
        _NeuBtn(w: 44, h: 44, onTap: () {}, child: Icon(PhosphorIcons.speakerSimpleHigh(PhosphorIconsStyle.fill), size: 16, color: Colors.white54)),
      ]),
    ]));
  }

  // ─── DEVICES CARD ───
  Widget _buildDevices() {
    return _NeuCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('DEVICES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.8, color: _gold)),
      const SizedBox(height: 14),
      ..._devs.map((d) => _buildDeviceRow(d)),
    ]));
  }

  Widget _buildDeviceRow(_Dev d) {
    final isSel = d.entity == _sel;
    final isPlaying = _getEffPlaying(d.entity);
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); setState(() { _sel = d.entity; _localVol = null; _volLocked = false; _livePos = 0; }); _syncPosition(); },
      child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: _card,
          border: Border.all(color: isSel ? _amber.withOpacity(0.15) : Colors.white.withOpacity(0.04)),
          gradient: isSel ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF2A2210), const Color(0xFF1E1A0E)]) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(4, 4)),
            BoxShadow(color: Colors.white.withOpacity(0.01), blurRadius: 6, offset: const Offset(-2, -2)),
            if (isSel) BoxShadow(color: _amber.withOpacity(0.02), blurRadius: 6, offset: const Offset(-2, -2))]),
        child: Row(children: [
          // Icon
          Container(width: 36, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFF161616),
            boxShadow: [const BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(2, 2))]),
            child: Center(child: Icon(PhosphorIcons.speakerSimpleHigh(PhosphorIconsStyle.fill), size: 14,
              color: isPlaying ? _amber : Colors.white24))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSel ? const Color(0xEBFFFFFF) : Colors.white54)),
            const SizedBox(height: 2),
            if (d.title != null) Text('${d.artist ?? ''} · ${d.title}', style: TextStyle(fontSize: 11, color: _amber.withOpacity(0.7)), overflow: TextOverflow.ellipsis)
            else Text(d.state, style: const TextStyle(fontSize: 11, color: Color(0x26FFFFFF))),
          ])),
          _NeuBtn(w: 34, h: 34, amber: isPlaying, onTap: () { HapticFeedback.mediumImpact(); _togglePlay(d.entity); },
            child: Icon(isPlaying ? PhosphorIcons.pause(PhosphorIconsStyle.fill) : PhosphorIcons.play(PhosphorIconsStyle.fill),
              size: 12, color: isPlaying ? _amber : Colors.white38)),
        ])));
  }

  // ─── SEARCH CARD ───
  Widget _buildSearch() {
    return _NeuCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Tabs
      Row(children: [
        Expanded(child: _NeuBtn(h: 44, amber: true, onTap: () {},
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold), size: 14, color: _amber),
            const SizedBox(width: 6),
            const Text('SEARCH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: _amber)),
          ]))),
        const SizedBox(width: 6),
        Expanded(child: _NeuBtn(h: 44, onTap: () {},
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(PhosphorIcons.megaphone(PhosphorIconsStyle.bold), size: 14, color: Colors.white30),
            const SizedBox(width: 6),
            const Text('ANNOUNCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Color(0x4DFFFFFF))),
          ]))),
      ]),
      const SizedBox(height: 14),
      // Services
      Row(children: [
        _svcBtn('Spotify', const Color(0xFF1DB954), true),
        const SizedBox(width: 6),
        _svcBtn('Amazon', _amber, false),
        const SizedBox(width: 6),
        _svcBtn('TuneIn', const Color(0xFF00B4D8), false),
      ]),
      const SizedBox(height: 14),
      // Search input — inset neumorphic
      Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFF161616),
        boxShadow: [const BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(3, 3)),
          const BoxShadow(color: Color(0x05FFFFFF), blurRadius: 3, offset: Offset(-1, -1))],
        border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: TextField(controller: _searchCtrl, onChanged: _onSearch,
          style: const TextStyle(fontSize: 14, color: Color(0xE6FFFFFF)),
          decoration: InputDecoration(hintText: 'Search artists, songs, albums…', hintStyle: const TextStyle(color: Color(0x33FFFFFF)),
            prefixIcon: _searching
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1DB954))))
              : Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.light), size: 14, color: const Color(0x40FFFFFF)),
            border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13)))),
      if (_results != null && _results!.tracks.isNotEmpty) ...[
        const SizedBox(height: 14),
        ..._results!.tracks.take(8).map((t) => _trackRow(t)),
      ],
    ]));
  }

  // ─── BOTTOM BAR ───
  Widget _buildBottomBar(_Dev a, bool isPlaying) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: _card, border: Border(top: BorderSide(color: _amber.withOpacity(0.1))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, -4))]),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFF111111),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(3, 3))]),
          clipBehavior: Clip.antiAlias,
          child: a.art != null
            ? Image.network(a.art!.startsWith('http') ? a.art! : '${HAService.haDirectUrl}${a.art}', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _artPlaceholder())
            : _artPlaceholder()),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(a.title ?? 'Idle', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          Text('${a.artist ?? ''} · ${a.name}', style: const TextStyle(fontSize: 11, color: Color(0x4DFFFFFF)), overflow: TextOverflow.ellipsis),
        ])),
        _NeuBtn(w: 36, h: 36, onTap: _prev, child: Icon(PhosphorIcons.skipBack(PhosphorIconsStyle.fill), size: 14, color: Colors.white38)),
        const SizedBox(width: 6),
        _NeuBtn(w: 36, h: 36, amber: true, onTap: () => _togglePlay(a.entity),
          child: Icon(isPlaying ? PhosphorIcons.pause(PhosphorIconsStyle.fill) : PhosphorIcons.play(PhosphorIconsStyle.fill), size: 14, color: _amber)),
        const SizedBox(width: 6),
        _NeuBtn(w: 36, h: 36, onTap: _next, child: Icon(PhosphorIcons.skipForward(PhosphorIconsStyle.fill), size: 14, color: Colors.white38)),
      ]));
  }

  // ─── Helpers ───
  Widget _buildProgress(int pos, int dur) {
    final frac = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
    return Column(children: [
      SizedBox(height: 5, child: LayoutBuilder(builder: (_, c) => Stack(children: [
        Container(height: 5, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: const Color(0x0FFFFFFF))),
        Container(height: 5, width: c.maxWidth * frac, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3),
          gradient: const LinearGradient(colors: [_amber, _gold]))),
      ]))),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(_fmt(pos), style: const TextStyle(fontSize: 11, color: Color(0x33FFFFFF), fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
        Text(_fmt(dur), style: const TextStyle(fontSize: 11, color: Color(0x33FFFFFF), fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
      ]),
    ]);
  }

  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  Widget _artPlaceholder() => Container(color: const Color(0xFF111111), child: Center(child: Icon(PhosphorIcons.vinylRecord(PhosphorIconsStyle.light), size: 24, color: const Color(0xFF333333))));

  Widget _svcBtn(String l, Color c, bool active) => Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: active ? c.withOpacity(0.12) : _card,
      border: Border.all(color: active ? c.withOpacity(0.3) : Colors.white.withOpacity(0.04)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(3, 3)),
        BoxShadow(color: Colors.white.withOpacity(0.01), blurRadius: 4, offset: const Offset(-1, -1))]),
    child: Text(l, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? c : const Color(0x4DFFFFFF)))));

  Widget _trackRow(SpotifyTrack track) {
    final loading = _playingUri == track.uri;
    return GestureDetector(onTap: () => _playTrack(track), child: Container(
      margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: _card,
        border: Border.all(color: Colors.white.withOpacity(0.04)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(3, 3))]),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFF1A1A1A)),
          clipBehavior: Clip.antiAlias,
          child: track.art != null ? Image.network(track.art!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _artPlaceholder()) : _artPlaceholder()),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(track.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xE0FFFFFF)), overflow: TextOverflow.ellipsis),
          Text('${track.artist ?? ''} · ${track.album ?? ''}', style: const TextStyle(fontSize: 12, color: Color(0x4DFFFFFF)), overflow: TextOverflow.ellipsis),
        ])),
        Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0x1F1DB954),
          border: Border.all(color: const Color(0x4D1DB954))),
          child: loading
            ? const Padding(padding: EdgeInsets.all(7), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1DB954)))
            : const Icon(PhosphorIconsFill.play, size: 12, color: Color(0xFF1DB954))),
      ])));
  }
}

// ─── 3D Neumorphic Card ───
class _NeuCard extends StatelessWidget {
  final Widget child;
  const _NeuCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.04)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 24, offset: const Offset(8, 8)),
        BoxShadow(color: Colors.white.withOpacity(0.02), blurRadius: 12, offset: const Offset(-4, -4))]),
    child: child);
}

// ─── 3D Neumorphic Button ───
class _NeuBtn extends StatefulWidget {
  final double? w, h;
  final bool amber;
  final VoidCallback onTap;
  final Widget child;
  const _NeuBtn({this.w, this.h, this.amber = false, required this.onTap, required this.child});
  @override
  State<_NeuBtn> createState() => _NeuBtnState();
}
class _NeuBtnState extends State<_NeuBtn> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _pressed = true),
    onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
    onTapCancel: () => setState(() => _pressed = false),
    child: AnimatedContainer(duration: const Duration(milliseconds: 50),
      width: widget.w, height: widget.h,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
        color: _pressed ? (widget.amber ? const Color(0xFF1A1608) : const Color(0xFF1A1A1A)) : const Color(0xFF1E1E1E),
        border: Border.all(color: widget.amber ? const Color(0x33FFB300) : Colors.white.withOpacity(0.05)),
        gradient: widget.amber && !_pressed ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A2210), Color(0xFF1E1A0E)]) : null,
        boxShadow: _pressed
          ? [const BoxShadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(3, 3), spreadRadius: -2)]
          : [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(4, 4)),
             BoxShadow(color: Colors.white.withOpacity(0.015), blurRadius: 6, offset: const Offset(-2, -2)),
             if (widget.amber) BoxShadow(color: const Color(0xFFFFB300).withOpacity(0.03), blurRadius: 6, offset: const Offset(-2, -2))]),
      child: Center(child: widget.child)));
}
