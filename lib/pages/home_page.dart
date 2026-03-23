import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/smithmk_theme.dart';

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
    _Tile('Media', PhosphorIconsBold.musicNotes, 'Not playing'),
    _Tile('Rooms', PhosphorIconsBold.door, 'Loading…'),
    _Tile('Energy', PhosphorIconsBold.lightning, 'Loading…'),
    _Tile('Dashboard', PhosphorIconsBold.squaresFour, 'Overview'),
    _Tile('Lights', PhosphorIconsBold.lightbulb, 'Loading…'),
    _Tile('Security', PhosphorIconsBold.shieldCheck, 'Loading…'),
    _Tile('Blinds', PhosphorIconsBold.slidersHorizontal, 'Loading…'),
    _Tile('Climate', PhosphorIconsBold.thermometerSimple, 'Loading…'),
    _Tile('Irrigation', PhosphorIconsBold.drop, 'Loading…'),
  ];
  static const _count = 9;
  static const _tileW = 110.0;
  static const _gap = 12.0;
  static const _step = _tileW + _gap;

  double _offset = 3 * _step; // Start on Dashboard (index 3)
  int _activeIdx = 3;
  bool _dragging = false;
  double _startX = 0, _startOff = 0, _lastX = 0, _vel = 0;
  int _lastT = 0;
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
    final projected = _offset + vel * 80;
    final nearest = (_step * (projected / _step).roundToDouble());
    _snapFrom = _offset;
    _snapTo = nearest;
    _snapCtrl!.forward(from: 0);
  }

  void _onPointerDown(PointerDownEvent e) {
    _snapCtrl?.stop();
    _dragging = true;
    _didDrag = false;
    _startX = e.position.dx;
    _startOff = _offset;
    _lastX = e.position.dx;
    _lastT = e.timeStamp.inMilliseconds;
    _vel = 0;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_dragging) return;
    final dx = e.position.dx - _startX;
    if (dx.abs() > 4) _didDrag = true;
    setState(() => _offset = _startOff - dx);
    final now = e.timeStamp.inMilliseconds;
    final dt = now - _lastT;
    if (dt > 0) _vel = (_lastX - e.position.dx) / dt;
    _lastX = e.position.dx;
    _lastT = now;
  }

  void _onPointerUp(PointerUpEvent e) {
    if (!_dragging) return;
    _dragging = false;
    if (!_didDrag) {
      final idx = ((_offset / _step).round() % _count + _count) % _count;
      HapticFeedback.mediumImpact();
      widget.onTileTap(_tiles[idx].label);
      return;
    }
    _snapToNearest(_vel);
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
            Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              child: SizedBox(height: 160, width: double.infinity, child: Stack(clipBehavior: Clip.none, children: [
                ..._buildTiles(),
              ])),
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

  List<Widget> _buildTiles() {
    final centreIdx = (_offset / _step).round();
    const range = 5;
    final tiles = <Widget>[];
    final screenW = MediaQuery.of(context).size.width;

    for (var i = centreIdx - range; i <= centreIdx + range; i++) {
      final realIdx = ((i % _count) + _count) % _count;
      final tile = _tiles[realIdx];
      final dist = i - centreIdx;
      final tileOff = i * _step - _offset;
      final scale = max(0.6, 1.0 - dist.abs() * 0.12);
      final opacity = max(0.15, 1.0 - dist.abs() * 0.22);
      final isActive = dist == 0;

      // 3D pop — active tile lifts up and has perspective tilt
      final yShift = isActive ? -12.0 : 0.0;

      tiles.add(Positioned(
        left: screenW / 2 + tileOff - _tileW / 2,
        top: 20 + yShift,
        child: Transform.scale(scale: scale, child: Opacity(opacity: opacity,
          child: _tileWidget(tile, isActive))),
      ));
    }
    return tiles;
  }

  Widget _tileWidget(_Tile tile, bool isActive) {
    return Container(
      width: _tileW - 10, height: _tileW - 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(begin: Alignment(-0.5, -0.5), end: Alignment(0.5, 0.5),
          colors: [Color(0x1AFFFFFF), Color(0x08FFFFFF), Color(0x12FFFFFF)]),
        border: Border.all(color: isActive ? const Color(0x61FFB84D) : const Color(0x1AFFFFFF)),
        boxShadow: [
          // 3D raised shadow
          const BoxShadow(color: Color(0x26FFFFFF), blurRadius: 0, offset: Offset(0, -1)), // top inset highlight
          const BoxShadow(color: Color(0x80000000), blurRadius: 0, offset: Offset(0, 2)),  // bottom shadow
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 40, offset: const Offset(0, 20)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4)),
          // Active glow
          if (isActive) BoxShadow(color: const Color(0xFFFFB84D).withValues(alpha: 0.25), blurRadius: 30),
        ],
      ),
      child: Stack(children: [
        // Top edge
        Positioned(top: 0, left: 0, right: 0, height: 1, child: Container(
          decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            color: Colors.white.withValues(alpha: 0.22)))),
        // Bottom edge
        Positioned(bottom: 0, left: 0, right: 0, height: 2, child: Container(
          decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            color: Colors.black.withValues(alpha: 0.4)))),
        // Glow overlay for active
        if (isActive) Positioned.fill(child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
            gradient: const RadialGradient(center: Alignment(0, -0.6), radius: 0.9,
              colors: [Color(0x28FFB84D), Colors.transparent])))),
        // Active indicator bar
        if (isActive) Positioned(bottom: 6, left: 0, right: 0, child: Center(child: Container(
          width: 20, height: 2, decoration: BoxDecoration(borderRadius: BorderRadius.circular(1),
            color: const Color(0xFFFFB84D), boxShadow: [BoxShadow(color: const Color(0xFFFFB84D).withValues(alpha: 0.6), blurRadius: 8)])))),
        // Icon + label
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(tile.icon, size: 36, color: isActive ? const Color(0xFFFFB84D) : const Color(0x73FFFFFF),
            shadows: isActive ? [Shadow(color: const Color(0xFFFFB84D).withValues(alpha: 0.6), blurRadius: 12)] : null),
          const SizedBox(height: 6),
          Text(tile.label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1,
            color: isActive ? const Color(0xFFFFB84D) : const Color(0x47FFFFFF))),
        ])),
      ]),
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
  final IconData icon;
  final String summary;
  const _Tile(this.label, this.icon, this.summary);
}
