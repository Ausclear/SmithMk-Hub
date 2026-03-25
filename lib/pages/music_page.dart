import 'dart:async';
import 'dart:ui';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/smithmk_theme.dart';
import '../services/spotify_service.dart';
import '../services/spotify_auth.dart';
import '../services/spotify_player.dart';

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

  // Spotify state — direct from Spotify API
  List<SpotifyDevice> _devices = [];
  SpotifyPlaybackState? _playback;
  String? _selectedDeviceId;
  Timer? _pollTimer;
  Timer? _tickTimer;
  int _livePos = 0;
  String? _lastTrack;

  // Volume anti-bounce
  int? _localVol;
  bool _volLocked = false;
  Timer? _volLockTimer;

  // Auth
  bool _loggedIn = false;
  bool _loggingIn = false;
  bool _showCodeInput = false;
  final _codeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _codeCtrl.dispose();
    _debounce?.cancel();
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    _volLockTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final token = await SpotifyAuth.getToken();
    if (token != null) {
      setState(() => _loggedIn = true);
      _startPolling();
    } else {
      setState(() => _loggedIn = false);
    }
  }

  void _startPolling() {
    _fetchState();
    _fetchDevices();
    // Poll playback state every 2s for live now-playing
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchState());
    // Tick progress every second
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _fetchDevices() async {
    final devs = await SpotifyPlayer.getDevices();
    if (mounted) setState(() {
      _devices = devs;
      // Auto-select active device or first
      if (_selectedDeviceId == null || !devs.any((d) => d.id == _selectedDeviceId)) {
        final active = devs.where((d) => d.isActive).toList();
        _selectedDeviceId = active.isNotEmpty ? active.first.id : (devs.isNotEmpty ? devs.first.id : null);
      }
    });
  }

  Future<void> _fetchState() async {
    final state = await SpotifyPlayer.getPlaybackState();
    if (!mounted) return;
    setState(() {
      _playback = state;
      if (state != null) {
        // Sync volume unless locked
        if (!_volLocked && state.volumePercent != null) {
          _localVol = null; // Use remote value
        }
        // Sync position
        final track = state.trackName;
        final pos = ((state.progressMs ?? 0) / 1000).round();
        if (track != _lastTrack) {
          _livePos = pos;
          _lastTrack = track;
        } else if ((pos - _livePos).abs() > 3) {
          _livePos = pos; // Resync if drifted >3s
        }
        // Update selected device if playback transferred
        if (state.deviceId != null && state.deviceId!.isNotEmpty) {
          _selectedDeviceId = state.deviceId;
        }
      }
    });
  }

  void _tick() {
    if (_playback?.isPlaying == true && _playback?.durationMs != null) {
      final maxSecs = (_playback!.durationMs! / 1000).round();
      if (_livePos < maxSecs) setState(() => _livePos++);
    }
  }

  Future<void> _login() async {
    // Open Spotify login in a new tab
    html.window.open(SpotifyAuth.getLoginUrl(), '_blank');
    // Show code input
    setState(() => _showCodeInput = true);
  }

  Future<void> _submitCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _loggingIn = true);
    final ok = await SpotifyAuth.exchangeCode(code);
    if (mounted) {
      setState(() { _loggedIn = ok; _loggingIn = false; _showCodeInput = false; });
      if (ok) {
        _startPolling();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid code — try again')));
      }
    }
  }

  // ─── Search (still uses client credentials — no user auth needed) ───
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

  // ─── Play a track ───
  Future<void> _playTrack(SpotifyTrack track) async {
    HapticFeedback.mediumImpact();
    setState(() { _playingUri = track.uri; _livePos = 0; });
    final ok = await SpotifyPlayer.play(deviceId: _selectedDeviceId, uris: [track.uri]);
    if (mounted) {
      if (ok) {
        final devName = _devices.firstWhere((d) => d.id == _selectedDeviceId, orElse: () => SpotifyDevice(id: '', name: 'Unknown', type: '')).name;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('▶ ${track.name} → $devName'), backgroundColor: const Color(0xFF1C1C1E), duration: const Duration(seconds: 2)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Play failed — try "Alexa, play Spotify" first')));
      }
      setState(() => _playingUri = null);
      Future.delayed(const Duration(seconds: 1), _fetchState);
    }
  }

  // ─── Controls — ALL direct to Spotify API ───
  void _togglePlay() {
    final playing = _playback?.isPlaying == true;
    setState(() { if (_playback != null) _playback = SpotifyPlaybackState(
      deviceId: _playback!.deviceId, deviceName: _playback!.deviceName,
      isPlaying: !playing, shuffleState: _playback!.shuffleState,
      progressMs: _playback!.progressMs, durationMs: _playback!.durationMs,
      volumePercent: _playback!.volumePercent, trackName: _playback!.trackName,
      artistName: _playback!.artistName, albumName: _playback!.albumName,
      albumArt: _playback!.albumArt, trackUri: _playback!.trackUri); });
    if (playing) { SpotifyPlayer.pause(); } else { SpotifyPlayer.resume(); }
  }

  void _stop() {
    setState(() => _livePos = 0);
    SpotifyPlayer.pause();
  }

  void _next() {
    setState(() => _livePos = 0);
    SpotifyPlayer.next();
    Future.delayed(const Duration(seconds: 1), _fetchState);
  }

  void _prev() {
    if (_livePos > 3) {
      setState(() => _livePos = 0);
      SpotifyPlayer.seek(0);
    } else {
      setState(() => _livePos = 0);
      SpotifyPlayer.previous();
      Future.delayed(const Duration(seconds: 1), _fetchState);
    }
  }

  void _shuffle() {
    final current = _playback?.shuffleState ?? false;
    SpotifyPlayer.setShuffle(!current);
  }

  // ─── Volume ───
  void _volChanged(int v) { setState(() { _localVol = v; _volLocked = true; }); }
  void _volCommit(int v) {
    setState(() { _localVol = v; _volLocked = true; });
    SpotifyPlayer.setVolume(v);
    _volLockTimer?.cancel();
    _volLockTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() { _volLocked = false; _localVol = null; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final pb = _playback;
    final isPlaying = pb?.isPlaying == true;
    final displayVol = _localVol ?? pb?.volumePercent ?? 30;
    final durSecs = pb?.durationMs != null ? (pb!.durationMs! / 1000).round() : null;

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

          if (!_loggedIn) ...[
            Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(PhosphorIcons.spotifyLogo(PhosphorIconsStyle.fill), size: 48, color: const Color(0xFF1DB954)),
              const SizedBox(height: 16),
              const Text('Connect Spotify', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Login to control music on your Echo devices', style: TextStyle(fontSize: 13, color: Color(0x66FFFFFF))),
              const SizedBox(height: 24),
              if (!_showCodeInput) ...[
                _Pressable(onTap: _login, builder: (p) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(30),
                    color: p ? const Color(0xFF169C46) : const Color(0xFF1DB954)),
                  child: const Text('Login with Spotify', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)))),
              ] else ...[
                const Text('After logging in, copy the code from the URL bar:', style: TextStyle(fontSize: 12, color: Color(0x66FFFFFF))),
                const SizedBox(height: 4),
                const Text('The URL will look like: open.spotify.com/?code=XXXXXX', style: TextStyle(fontSize: 11, color: Color(0x40FFFFFF))),
                const SizedBox(height: 4),
                const Text('Copy everything after "code=" and paste below:', style: TextStyle(fontSize: 12, color: Color(0x66FFFFFF))),
                const SizedBox(height: 12),
                Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0x0FFFFFFF),
                  border: Border.all(color: const Color(0x1AFFFFFF))),
                  child: TextField(controller: _codeCtrl,
                    style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF)),
                    decoration: const InputDecoration(hintText: 'Paste code here…', hintStyle: TextStyle(color: Color(0x40FFFFFF)),
                      border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13)))),
                const SizedBox(height: 12),
                _Pressable(onTap: _loggingIn ? () {} : _submitCode, builder: (p) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(30),
                    color: p ? const Color(0xFF169C46) : const Color(0xFF1DB954)),
                  child: _loggingIn
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Connect', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)))),
              ],
            ])))),
          ] else ...[
            Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), physics: const BouncingScrollPhysics(), children: [

              // ─── DEVICES (from Spotify Connect) ───
              _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _label('DEVICES'),
                  const Spacer(),
                  GestureDetector(onTap: _fetchDevices, child: Icon(PhosphorIcons.arrowsClockwise(PhosphorIconsStyle.light), size: 14, color: const Color(0x40FFFFFF))),
                ]),
                if (_devices.isEmpty)
                  const Padding(padding: EdgeInsets.all(12), child: Text('No devices found — say "Alexa, play Spotify" to wake one up',
                    style: TextStyle(fontSize: 12, color: Color(0x40FFFFFF))))
                else
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final dev in _devices) _deviceChip(dev),
                  ]),
              ])),
              const SizedBox(height: 12),

              // ─── NOW PLAYING ───
              _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('NOW PLAYING'),
                Row(children: [
                  Container(width: 64, height: 64, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFF111111)),
                    clipBehavior: Clip.antiAlias,
                    child: pb?.albumArt != null
                      ? Image.network(pb!.albumArt!, fit: BoxFit.cover, filterQuality: FilterQuality.high, errorBuilder: (_, __, ___) => _artIcon())
                      : _artIcon()),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(pb?.trackName ?? (isPlaying ? 'Playing…' : 'Not Playing'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    if (pb?.artistName != null) ...[const SizedBox(height: 2),
                      Text(pb!.artistName!, style: const TextStyle(fontSize: 12, color: Color(0xBFFF9900)), overflow: TextOverflow.ellipsis)],
                    const SizedBox(height: 4),
                    Text('🔊 ${pb?.deviceName ?? "No device"}', style: const TextStyle(fontSize: 10, color: Color(0x33FFFFFF))),
                  ])),
                ]),
                if (durSecs != null && durSecs > 0) ...[const SizedBox(height: 12), _progressBar(_livePos, durSecs)],
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
                  _ctrlBtn(PhosphorIcons.shuffle(PhosphorIconsStyle.bold), _shuffle),
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
                    child: Slider(value: displayVol.toDouble().clamp(0, 100), min: 0, max: 100,
                      onChanged: (v) => _volChanged(v.round()), onChangeEnd: (v) => _volCommit(v.round())))),
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
          ],
        ])))),
    );
  }

  // ─── Widgets ───
  Widget _card({required Widget child}) => Container(padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x14FFC107))),
    child: child);
  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 12),
    child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.7, color: Color(0x80FFC107))));

  Widget _deviceChip(SpotifyDevice dev) {
    final sel = dev.id == _selectedDeviceId;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() { _selectedDeviceId = dev.id; _localVol = dev.volumePercent; _livePos = 0; });
        // Transfer playback to this device
        SpotifyPlayer.transferPlayback(dev.id, play: _playback?.isPlaying ?? false);
        Future.delayed(const Duration(seconds: 1), _fetchState);
      },
      child: AnimatedContainer(duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
          color: sel ? const Color(0x12FF9900) : const Color(0x08FFFFFF),
          border: Border.all(color: sel ? const Color(0x38FF9900) : const Color(0x0FFFFFFF))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle,
            color: dev.isActive ? const Color(0xFFFF9900) : const Color(0xFF4ADE80),
            boxShadow: [BoxShadow(color: dev.isActive ? const Color(0x66FF9900) : const Color(0x664ADE80), blurRadius: 4)])),
          const SizedBox(width: 6),
          Text(dev.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: sel ? const Color(0xE6FFFFFF) : const Color(0x66FFFFFF))),
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
