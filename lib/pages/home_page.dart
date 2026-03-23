import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/smithmk_theme.dart';

const _iconBase = 'https://smarthome-eight-livid.vercel.app/icons/';

class HomePage extends StatefulWidget {
  final void Function(String tileName) onTileTap;
  const HomePage({super.key, required this.onTileTap});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late Timer _clock;
  DateTime _now = DateTime.now();

  static const _tiles = [
    _Tile('Media', '${_iconBase}media.png', 'Not playing'),
    _Tile('Rooms', '${_iconBase}rooms.png', 'Loading…'),
    _Tile('Energy', '${_iconBase}energy.png', 'Loading…'),
    _Tile('Dashboard', '${_iconBase}dashboard.png', 'Overview'),
    _Tile('Lights', '${_iconBase}lighting.png', 'Loading…'),
    _Tile('Security', '${_iconBase}security.png', 'Loading…'),
    _Tile('Blinds', '${_iconBase}blinds.png', 'Loading…'),
    _Tile('Climate', '${_iconBase}climate.png', 'Loading…'),
    _Tile('Irrigation', '${_iconBase}energy_solar.png', 'Loading…'),
  ];
  static const _count = 9;
  static const _tileW = 110.0;
  static const _gap = 12.0;
  static const _step = _tileW + _gap;

  double _offset = 3 * _step; // Start on Dashboard (index 3)
  int _activeIdx = 3;
  double _startOff = 0;
  double _vel = 0;
  bool _didDrag = false;
  AnimationController? _snapCtrl;
  double _snapFrom = 0, _snapTo = 0;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 10), (_) => setState(() => _now = DateTime.now()));
    _now = DateTime.now();
    _snapCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))
      ..addListener(() {
        final ease = Curves.easeOutCubic.transform(_snapCtrl!.value);
        setState(() {
          _offset = _snapFrom + (_snapTo - _snapFrom) * ease;
          if (_snapCtrl!.isCompleted) {
            _offset = _snapTo;
            _activeIdx = ((_snapTo / _step).round() % _count + _count) % _count;
          }
        });
      });
  }

  @override
  void dispose() { _clock.cancel(); _snapCtrl?.dispose(); super.dispose(); }

  String get _timeStr => '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
  String get _dateStr {
    const d = ['MON','TUE','WED','THU','FRI','SAT','SUN'];
    const m = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    return '${d[_now.weekday - 1]} ${_now.day} ${m[_now.month - 1]}';
  }

  void _snapToNearest(double vel) {
    final projected = _offset + vel * 120;
    final nearest = (_step * (projected / _step).roundToDouble());
    _snapFrom = _offset;
    _snapTo = nearest;
    _snapCtrl!.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(colors: [Color(0xFF8A6A2A), Color(0xFFC4A96B), Color(0xFFF0D080), Color(0xFFC4A96B), Color(0xFF8A6A2A)]).createShader(r),
                child: const Text('SMITHMK HOME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 3, color: Colors.white)),
              ),
              const SizedBox(height: 2),
              Text(_dateStr, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1, color: Color(0x4DFFFFFF))),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_timeStr, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w100, color: Color(0xEBFFFFFF), letterSpacing: -1, height: 1)),
              const SizedBox(height: 2),
              const Text('☀️ 19°C Clear', style: TextStyle(fontSize: 11, color: Color(0x73FFFFFF))),
            ]),
          ])),

          // Pills
          Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0), child: Row(children: [
            _statusPill('HA', false), const SizedBox(width: 6),
            _statusPill('SUPABASE', true), const SizedBox(width: 6),
            _statusPill('SOLAR', false),
          ])),

          // Carousel
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
              onHorizontalDragStart: (d) {
                _snapCtrl?.stop();
                _startOff = _offset;
                _didDrag = false;
                _vel = 0;
              },
              onHorizontalDragUpdate: (d) {
                _didDrag = true;
                setState(() => _offset = _startOff - d.localPosition.dx + d.localPosition.dx - d.delta.dx + _offset.sign * 0);
                // Simpler: just subtract delta
                setState(() => _offset -= d.delta.dx);
                _vel = -d.delta.dx / 16; // approximate velocity
              },
              onHorizontalDragEnd: (d) {
                final v = -d.velocity.pixelsPerSecond.dx / 1000;
                _snapToNearest(v);
              },
              onTap: () {
                final idx = ((_offset / _step).round() % _count + _count) % _count;
                HapticFeedback.mediumImpact();
                widget.onTileTap(_tiles[idx].label);
              },
              child: SizedBox(height: 160, width: double.infinity, child: LayoutBuilder(builder: (ctx, c) {
                return Stack(clipBehavior: Clip.none, children: _buildTiles(c.maxWidth));
              })),
            ),
            const SizedBox(height: 20),
            // Active label
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 3, height: 14, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: SmithMkColors.accent)),
              const SizedBox(width: 8),
              Text(_tiles[_activeIdx].label.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 3, color: Color(0x99FFFFFF))),
              const SizedBox(width: 8),
              Container(width: 3, height: 14, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: SmithMkColors.accent)),
            ]),
            const SizedBox(height: 6),
            Text(_tiles[_activeIdx].summary, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SmithMkColors.accent, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            const Text('TAP TO OPEN', style: TextStyle(fontSize: 10, color: Color(0x26FFFFFF), letterSpacing: 1)),
          ])),
        ]),
      ),
    );
  }

  List<Widget> _buildTiles(double screenW) {
    final centreIdx = (_offset / _step).round();
    const range = 5;
    final tiles = <Widget>[];

    for (var i = centreIdx - range; i <= centreIdx + range; i++) {
      final realIdx = ((i % _count) + _count) % _count;
      final tile = _tiles[realIdx];
      final dist = (i * _step - _offset) / _step; // fractional distance from centre
      final absDist = dist.abs();
      final scale = max(0.6, 1.0 - absDist * 0.12);
      final opacity = max(0.15, 1.0 - absDist * 0.22);
      final isActive = absDist < 0.5;

      // 3D pop — active tile lifts up
      final yShift = isActive ? -14.0 * (1.0 - absDist * 2) : 0.0;
      final tileOff = i * _step - _offset;

      tiles.add(Positioned(
        left: screenW / 2 + tileOff - _tileW / 2,
        top: 20 + yShift.clamp(-14.0, 0.0),
        child: Transform.scale(scale: scale, child: Opacity(opacity: opacity,
          child: _tileWidget(tile, isActive, absDist))),
      ));
    }
    return tiles;
  }

  Widget _tileWidget(_Tile tile, bool isActive, double absDist) {
    return Container(
      width: _tileW - 10, height: _tileW - 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(begin: Alignment(-0.5, -0.5), end: Alignment(0.5, 0.5),
          colors: [Color(0x1AFFFFFF), Color(0x08FFFFFF), Color(0x12FFFFFF)]),
        border: Border.all(color: isActive ? const Color(0x61FFB84D) : const Color(0x1AFFFFFF)),
        boxShadow: [
          const BoxShadow(color: Color(0x26FFFFFF), blurRadius: 0, offset: Offset(0, -1)),
          const BoxShadow(color: Color(0x80000000), blurRadius: 0, offset: Offset(0, 2)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 40, offset: const Offset(0, 20)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4)),
          if (isActive) BoxShadow(color: const Color(0xFFFFB84D).withValues(alpha: 0.25), blurRadius: 30),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Stack(children: [
          // Top edge highlight
          Positioned(top: 0, left: 0, right: 0, height: 1, child: Container(color: Colors.white.withValues(alpha: 0.22))),
          // Bottom edge shadow
          Positioned(bottom: 0, left: 0, right: 0, height: 2, child: Container(color: Colors.black.withValues(alpha: 0.4))),
          // Glow for active
          if (isActive) Positioned.fill(child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(center: const Alignment(0, -0.6), radius: 0.9,
                colors: [Color.lerp(const Color(0xFFFFB84D), Colors.transparent, 0.75)!, Colors.transparent])))),
          // Active indicator bar
          if (isActive) Positioned(bottom: 6, left: 0, right: 0, child: Center(child: Container(
            width: 20, height: 2, decoration: BoxDecoration(borderRadius: BorderRadius.circular(1),
              color: const Color(0xFFFFB84D), boxShadow: [BoxShadow(color: const Color(0xFFFFB84D).withValues(alpha: 0.6), blurRadius: 8)])))),
          // Icon + label
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.network(tile.iconUrl, width: 40, height: 40, fit: BoxFit.contain,
              color: isActive ? null : const Color(0x99FFFFFF),
              colorBlendMode: isActive ? null : BlendMode.modulate,
              errorBuilder: (_, __, ___) => Icon(Icons.home, size: 40, color: isActive ? const Color(0xFFFFB84D) : const Color(0x73FFFFFF))),
            const SizedBox(height: 6),
            Text(tile.label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1,
              color: isActive ? const Color(0xFFFFB84D) : const Color(0x47FFFFFF))),
          ])),
        ]),
      )),
    );
  }

  Widget _statusPill(String label, bool online) {
    final col = online ? const Color(0xFF4CAF50) : const Color(0xFFEF4444);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: const Color(0x0AFFFFFF),
        border: Border.all(color: online ? const Color(0x4D4CAF50) : const Color(0x4DEF4444))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: col,
          boxShadow: [BoxShadow(color: col, blurRadius: 6)])),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: Color(0x66FFFFFF))),
      ]));
  }
}

class _Tile {
  final String label;
  final String iconUrl;
  final String summary;
  const _Tile(this.label, this.iconUrl, this.summary);
}
