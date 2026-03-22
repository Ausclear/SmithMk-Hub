import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../theme/smithmk_theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
  late Timer _clock;
  DateTime _now = DateTime.now();

  // Climate
  double _targetTemp = 22.0;
  final double _currentTemp = 19.0;
  bool _hvacOn = true;
  bool _heatMode = true;

  // Scenes
  int _activeScene = 1;

  // Rooms
  final Map<String, double> _roomLevels = {'Master': 0.0, 'Lounge': 0.0, 'Office': 0.0};
  static const _roomData = [
    ('Master', 'Master Bedroom', '🛏️', 2),
    ('Lounge', 'Lounge', '🛋️', 2),
    ('Office', 'Office', '💻', 0),
  ];

  // Irrigation zones
  static const _zones = [
    ('Front Lawn', '15 min', false),
    ('Garden Beds', '20 min', false),
    ('Rear Lawn', '15 min', false),
    ('Veggie Patch', '10 min', false),
  ];

  // Sections
  final List<String> _sections = [
    'weather', 'scenes', 'climate', 'status', 'energy', 'rooms', 'irrigation', 'activity',
  ];

  // Entry animation
  late AnimationController _entryCtrl;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
    _entryCtrl = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..forward();
  }

  @override
  void dispose() {
    _clock.cancel();
    _entryCtrl.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = _now.hour;
    return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
  }

  String get _timeStr => '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}';

  String get _dateStr {
    const d = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const m = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${d[_now.weekday - 1]} ${_now.day} ${m[_now.month - 1]}';
  }

  Color _tempColor(double t) {
    final f = ((t - 12) / 18).clamp(0.0, 1.0);
    if (f <= 0.35) return Color.lerp(SmithMkColors.tempCool, const Color(0xFF78D6B0), f / 0.35)!;
    if (f <= 0.6) return Color.lerp(const Color(0xFF78D6B0), SmithMkColors.accent, (f - 0.35) / 0.25)!;
    if (f <= 0.8) return Color.lerp(SmithMkColors.accent, const Color(0xFFFF8C00), (f - 0.6) / 0.2)!;
    return Color.lerp(const Color(0xFFFF8C00), SmithMkColors.tempHot, (f - 0.8) / 0.2)!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmithMkColors.background,
      body: Stack(
        children: [
          // Ambient gradient background
          Positioned.fill(child: CustomPaint(painter: _AmbientBgPainter())),
          SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
              child: LayoutBuilder(builder: (ctx, constraints) {
                final wide = constraints.maxWidth >= 700;
                final landscape = constraints.maxWidth > constraints.maxHeight;
                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.all(wide ? 24 : 16),
                      sliver: SliverList(delegate: SliverChildListDelegate([
                        _buildHeader(),
                        const SizedBox(height: 10),
                        _buildPills(),
                        const SizedBox(height: 18),
                        if (wide) _buildWideGrid(landscape) else _buildNarrowGrid(),
                        const SizedBox(height: 80),
                      ])),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HEADER ───
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_greeting, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: SmithMkColors.gold)),
          const SizedBox(height: 2),
          Text(_dateStr, style: const TextStyle(fontSize: 11, color: SmithMkColors.textTertiary)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_timeStr, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w200, color: SmithMkColors.textPrimary, letterSpacing: -1.5, height: 1, fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 3),
          Text('☀️ ${_currentTemp.round()}°', style: const TextStyle(fontSize: 12, color: SmithMkColors.textSecondary)),
        ]),
      ],
    );
  }

  // ─── STATUS PILLS ───
  Widget _buildPills() {
    return Wrap(spacing: 8, runSpacing: 6, children: [
      _pill('HA', SmithMkColors.error),
      _pill('SUPABASE', SmithMkColors.success),
      _pill('SOLAR', SmithMkColors.error),
    ]);
  }

  Widget _pill(String label, Color dot) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(color: dot, shape: BoxShape.circle, boxShadow: [BoxShadow(color: dot.withValues(alpha: 0.5), blurRadius: 4)])),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: SmithMkColors.textSecondary, letterSpacing: 0.5)),
      ]),
    );
  }

  // ─── GLASS CARD ───
  Widget _glass({required Widget child, EdgeInsets padding = const EdgeInsets.all(20)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment(-0.5, -0.5), end: Alignment(0.5, 0.5), colors: [Color(0x0DFFFFFF), Color(0x05FFFFFF)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 32, offset: const Offset(0, 8))],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _sLabel(String t) => Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SmithMkColors.textTertiary, letterSpacing: 1.5));

  // ─── WIDE LAYOUT ───
  Widget _buildWideGrid(bool landscape) {
    final left = _sections.where((k) => ['weather', 'climate', 'status', 'energy'].contains(k)).toList();
    final right = _sections.where((k) => !['weather', 'climate', 'status', 'energy'].contains(k)).toList();
    // Landscape: swap scenes first
    if (landscape) {
      final si = right.indexOf('scenes');
      if (si > 0) { right.removeAt(si); right.insert(0, 'scenes'); }
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _buildCol(landscape ? right : left)),
      const SizedBox(width: 14),
      Expanded(child: _buildCol(landscape ? left : right)),
    ]);
  }

  Widget _buildNarrowGrid() => _buildCol(_sections);

  Widget _buildCol(List<String> keys) {
    return Column(children: keys.asMap().entries.map((e) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 350 + e.key * 60),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Transform.translate(offset: Offset(0, 16 * (1 - v)), child: Opacity(opacity: v, child: child)),
        child: Padding(padding: const EdgeInsets.only(bottom: 14), child: _buildSection(e.value)),
      );
    }).toList());
  }

  Widget _buildSection(String key) {
    switch (key) {
      case 'weather': return _weatherCard();
      case 'scenes': return _scenesCard();
      case 'climate': return _climateCard();
      case 'status': return _statusCards();
      case 'energy': return _energyCard();
      case 'rooms': return _roomsCard();
      case 'irrigation': return _irrigationCard();
      case 'activity': return _activityCard();
      default: return const SizedBox.shrink();
    }
  }

  // ─── WEATHER ───
  Widget _weatherCard() {
    return _glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [_sLabel('WEATHER'), const Spacer(), Icon(PhosphorIcons.sun(PhosphorIconsStyle.light), size: 24, color: SmithMkColors.textTertiary)]),
      const SizedBox(height: 10),
      Row(children: [
        const Text('☀️', style: TextStyle(fontSize: 36)),
        const SizedBox(width: 10),
        Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_currentTemp.round()}°', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w300, letterSpacing: -2)),
          const Text('Clear sky · Feels 19° · 💧68% · 💨6km/h', style: TextStyle(fontSize: 10, color: SmithMkColors.textTertiary)),
        ])),
      ]),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (final f in [('Sun', '☀️', 29, 16), ('Mon', '🌤️', 30, 15), ('Tue', '🌙', 31, 18), ('Wed', '❄️', 23, 16), ('Thu', '☁️', 17, 14)])
          Column(children: [
            Text(f.$1, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: SmithMkColors.textTertiary)),
            const SizedBox(height: 4),
            Text(f.$2, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 3),
            Text('${f.$3}°', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            Text('${f.$4}°', style: const TextStyle(fontSize: 9, color: SmithMkColors.textTertiary)),
          ]),
      ]),
    ]));
  }

  // ─── SCENES ───
  Widget _scenesCard() {
    const scenes = [('Morning', '🌅', 0), ('Day', '☀️', 1), ('Evening', '🏠', 2), ('Night', '🌙', 3), ('Away', '🏖️', 4), ('Movie', '🎬', 5)];
    return _glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [_sLabel('SCENES'), const Spacer(), Icon(PhosphorIcons.filmSlate(PhosphorIconsStyle.light), size: 24, color: SmithMkColors.textTertiary)]),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (ctx, c) {
        // Use grid if wide enough, otherwise scroll
        if (c.maxWidth > 360) {
          return Wrap(spacing: 8, runSpacing: 8, children: scenes.map((s) => _sceneChip(s.$1, s.$2, s.$3)).toList());
        }
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: scenes.map((s) => Padding(padding: const EdgeInsets.only(right: 8), child: _sceneChip(s.$1, s.$2, s.$3))).toList()));
      }),
    ]));
  }

  Widget _sceneChip(String name, String emoji, int idx) {
    final active = _activeScene == idx;
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); setState(() => _activeScene = idx); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? SmithMkColors.accent.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? SmithMkColors.accent.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 3),
          Text(name, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: active ? SmithMkColors.accent : SmithMkColors.textTertiary)),
        ]),
      ),
    );
  }

  // ─── CLIMATE ───
  Widget _climateCard() {
    final mCol = _heatMode ? SmithMkColors.heatingMode : SmithMkColors.tempCool;
    final tCol = _hvacOn ? _tempColor(_targetTemp) : SmithMkColors.inactive;

    return _glass(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: Column(children: [
      Row(children: [
        _sLabel('CLIMATE'),
        const Spacer(),
        GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); setState(() => _heatMode = !_heatMode); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: mCol.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: mCol.withValues(alpha: 0.3))),
            child: Text(_heatMode ? '🔥 HEAT' : '❄️ COOL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: mCol, letterSpacing: 1)),
          ),
        ),
      ]),
      const SizedBox(height: 4),
      LayoutBuilder(builder: (ctx, c) {
        final sz = min(c.maxWidth * 0.7, 220.0);
        return SizedBox(width: sz, height: sz, child: Stack(alignment: Alignment.center, children: [
          // 3D bezel
          Container(width: sz, height: sz, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 24, offset: const Offset(0, 8)),
          ])),
          Container(width: sz - 2, height: sz - 2, decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A2A2A), Color(0xFF0C0C0C)]))),
          Container(width: sz - 16, height: sz - 16, decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: RadialGradient(center: const Alignment(-0.2, -0.25), colors: [const Color(0xFF191919), const Color(0xFF0C0C0C)]))),
          // Syncfusion gauge
          SizedBox(width: sz - 8, height: sz - 8, child: SfRadialGauge(axes: [
            RadialAxis(
              minimum: 12, maximum: 30, startAngle: 135, endAngle: 45,
              showLabels: false, showTicks: true, labelOffset: 18, interval: 3,
              axisLabelStyle: const GaugeTextStyle(fontSize: 8, color: SmithMkColors.textTertiary),
              axisLineStyle: AxisLineStyle(thickness: 6, color: _hvacOn ? const Color(0xFF1A1A1A) : const Color(0xFF141414), cornerStyle: CornerStyle.bothCurve),
              majorTickStyle: MajorTickStyle(length: 8, thickness: 1, color: _hvacOn ? const Color(0xFF333333) : const Color(0xFF1E1E1E)),
              minorTickStyle: MinorTickStyle(length: 4, thickness: 0.5, color: _hvacOn ? const Color(0xFF222222) : const Color(0xFF181818)),
              minorTicksPerInterval: 5,
              ranges: _hvacOn ? [GaugeRange(startValue: 12, endValue: _targetTemp, startWidth: 6, endWidth: 6,
                gradient: const SweepGradient(colors: [Color(0xFF48CAE4), Color(0xFF78D6B0), Color(0xFFFFB300), Color(0xFFFF8C00), Color(0xFFFF5722)], stops: [0.0, 0.3, 0.55, 0.78, 1.0]))] : [],
              pointers: _hvacOn ? [MarkerPointer(value: _targetTemp, markerType: MarkerType.circle, markerWidth: 16, markerHeight: 16,
                color: tCol, borderColor: SmithMkColors.textPrimary, borderWidth: 2.5, enableDragging: true,
                onValueChanged: (v) { final s = (v * 2).round() / 2; if (s != _targetTemp) HapticFeedback.selectionClick(); setState(() => _targetTemp = s.clamp(12, 30)); })] : [],
              annotations: [],
            ),
          ])),
          // Centre text
          IgnorePointer(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${_targetTemp.toStringAsFixed(1)}°', style: TextStyle(fontSize: sz * 0.2, fontWeight: FontWeight.w200, color: _hvacOn ? SmithMkColors.textPrimary : SmithMkColors.inactive, height: 1)),
            const SizedBox(height: 2),
            Text(_hvacOn ? (_heatMode ? 'HEATING' : 'COOLING') : 'OFF', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: _hvacOn ? mCol : SmithMkColors.textTertiary)),
            const SizedBox(height: 2),
            Text('Currently ${_currentTemp.round()}°', style: TextStyle(fontSize: 10, color: _hvacOn ? SmithMkColors.textTertiary : SmithMkColors.inactive)),
          ])),
        ]));
      }),
      const SizedBox(height: 8),
      // Buttons
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _thermoBtn('−', () { HapticFeedback.selectionClick(); setState(() => _targetTemp = (_targetTemp - 0.5).clamp(12, 30)); }),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: () { HapticFeedback.mediumImpact(); setState(() => _hvacOn = !_hvacOn); },
          child: AnimatedContainer(duration: const Duration(milliseconds: 300), width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _hvacOn ? [const Color(0xFF3A2010), const Color(0xFF2A1508)] : [const Color(0xFF252525), const Color(0xFF1A1A1A)]),
              border: Border.all(color: _hvacOn ? SmithMkColors.heatingMode.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.06), width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 4)),
                if (_hvacOn) BoxShadow(color: SmithMkColors.heatingMode.withValues(alpha: 0.15), blurRadius: 16)]),
            child: Icon(Icons.power_settings_new, size: 20, color: _hvacOn ? SmithMkColors.heatingMode : SmithMkColors.textTertiary)),
        ),
        const SizedBox(width: 16),
        _thermoBtn('+', () { HapticFeedback.selectionClick(); setState(() => _targetTemp = (_targetTemp + 0.5).clamp(12, 30)); }),
      ]),
    ]));
  }

  Widget _thermoBtn(String label, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(width: 34, height: 34,
      decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF252525), Color(0xFF1A1A1A)]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Center(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: SmithMkColors.textSecondary)))));
  }

  // ─── STATUS CARDS ───
  Widget _statusCards() {
    return _glass(padding: EdgeInsets.zero, child: GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3, mainAxisSpacing: 1, crossAxisSpacing: 1,
      children: [
        _statCell('SECURITY', PhosphorIcons.shieldCheck(PhosphorIconsStyle.light), 'Disarmed', '1 open · 10 zones', SmithMkColors.success, 0),
        _statCell('LIGHTS', PhosphorIcons.lightbulb(PhosphorIconsStyle.light), '0/4', '0 rooms active', SmithMkColors.textPrimary, 2),
        _statCell('EV', PhosphorIcons.car(PhosphorIconsStyle.light), 'Disconnected', 'No EV plugged in', SmithMkColors.textPrimary, -1),
        _statCell('BLINDS', PhosphorIcons.slidersHorizontal(PhosphorIconsStyle.light), 'All Closed', '3 blinds', SmithMkColors.textPrimary, 4),
      ],
    ));
  }

  Widget _statCell(String title, IconData icon, String value, String sub, Color vCol, int pageIdx) {
    return GestureDetector(
      onTap: pageIdx >= 0 ? () { HapticFeedback.lightImpact(); _navigateToPage(pageIdx); } : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), border: Border.all(color: Colors.white.withValues(alpha: 0.03))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [_sLabel(title), const Spacer(), Icon(icon, size: 22, color: SmithMkColors.textTertiary)]),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: vCol)),
          const SizedBox(height: 2),
          Row(children: [
            Expanded(child: Text(sub, style: const TextStyle(fontSize: 9, color: SmithMkColors.textTertiary))),
            if (pageIdx >= 0) const Text('→', style: TextStyle(fontSize: 12, color: SmithMkColors.textTertiary)),
          ]),
        ]),
      ),
    );
  }

  void _navigateToPage(int pageIdx) {
    // Signal to parent AppShell to switch page
    // For now this is a placeholder — will wire up with callback/provider
  }

  // ─── ENERGY GAUGES ───
  Widget _energyCard() {
    return _glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [_sLabel('ENERGY'), const Spacer(), Icon(PhosphorIcons.lightning(PhosphorIconsStyle.light), size: 24, color: SmithMkColors.textTertiary)]),
      const SizedBox(height: 14),
      Wrap(alignment: WrapAlignment.spaceEvenly, spacing: 6, runSpacing: 10, children: [
        _eGauge('Solar', 0, 5000, SmithMkColors.accent),
        _eGauge('Battery', 0, 100, SmithMkColors.success),
        _eGauge('Home', 0, 5000, SmithMkColors.tempCool),
        _eGauge('EV', 0, 7000, SmithMkColors.accent),
      ]),
    ]));
  }

  Widget _eGauge(String label, double val, double max, Color col) {
    return SizedBox(width: 90, height: 100, child: Column(children: [
      SizedBox(width: 80, height: 80, child: SfRadialGauge(axes: [
        RadialAxis(minimum: 0, maximum: max, startAngle: 135, endAngle: 45, showLabels: false, showTicks: false,
          axisLineStyle: AxisLineStyle(thickness: 7, color: col.withValues(alpha: 0.08), cornerStyle: CornerStyle.bothCurve),
          pointers: [RangePointer(value: val, width: 7, color: col, cornerStyle: CornerStyle.bothCurve)],
          annotations: [GaugeAnnotation(widget: Text('${val.round()}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: col)), angle: 90, positionFactor: 0)]),
      ])),
      Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: SmithMkColors.textTertiary)),
    ]));
  }

  // ─── ROOMS ───
  Widget _roomsCard() {
    return _glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [_sLabel('ROOMS'), const Spacer(), Icon(PhosphorIcons.door(PhosphorIconsStyle.light), size: 24, color: SmithMkColors.textTertiary)]),
      const SizedBox(height: 10),
      ..._roomData.map((r) => _roomRow(r.$1, r.$2, r.$3, r.$4)),
    ]));
  }

  Widget _roomRow(String key, String name, String emoji, int total) {
    final lv = _roomLevels[key] ?? 0;
    final on = lv > 0;
    return GestureDetector(
      onTap: () => _openDimmer(key, name, emoji),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          Text('0/$total', style: const TextStyle(fontSize: 11, color: SmithMkColors.textTertiary)),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); setState(() => _roomLevels[key] = on ? 0 : 0.75); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: on ? SmithMkColors.accent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(6),
                border: on ? Border.all(color: SmithMkColors.accent.withValues(alpha: 0.2)) : null),
              child: Text(on ? 'ON' : 'OFF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: on ? SmithMkColors.accent : SmithMkColors.textTertiary)),
            ),
          ),
        ]),
      ),
    );
  }

  // ─── DIMMER MODAL ───
  void _openDimmer(String key, String name, String emoji) {
    showDialog(context: context, barrierColor: Colors.black54, builder: (ctx) {
      return _DimmerModal(key: ValueKey(key), roomKey: key, name: name, emoji: emoji, level: _roomLevels[key] ?? 0,
        onChanged: (v) => setState(() => _roomLevels[key] = v),
        onToggle: () => setState(() => _roomLevels[key] = (_roomLevels[key] ?? 0) > 0 ? 0 : 0.75));
    });
  }

  // ─── IRRIGATION ───
  Widget _irrigationCard() {
    return _glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [_sLabel('IRRIGATION'), const Spacer(), Icon(PhosphorIcons.drop(PhosphorIconsStyle.light), size: 24, color: SmithMkColors.textTertiary)]),
      const SizedBox(height: 10),
      Row(children: [
        const Text('Schedule', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(6)),
          child: const Text('RUN ALL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: SmithMkColors.textTertiary))),
      ]),
      const SizedBox(height: 8),
      ..._zones.map((z) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Text('🌱', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text(z.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
          Text(z.$2, style: const TextStyle(fontSize: 10, color: SmithMkColors.textTertiary)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: z.$3 ? SmithMkColors.success.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(5),
              border: z.$3 ? Border.all(color: SmithMkColors.success.withValues(alpha: 0.2)) : null),
            child: Text(z.$3 ? 'RUNNING' : 'IDLE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: z.$3 ? SmithMkColors.success : SmithMkColors.textTertiary))),
        ]),
      )),
    ]));
  }

  // ─── ACTIVITY ───
  Widget _activityCard() {
    const evts = [('💡', 'Entrance 2 → off', '11:28'), ('💡', 'Alfresco → off', '11:19'), ('💡', 'Entrance 2 → off', '11:16'), ('💡', 'Entrance 1 → off', '11:16'), ('💡', 'Alfresco → off', '11:14')];
    return _glass(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [_sLabel('ACTIVITY'), const Spacer(), Icon(PhosphorIcons.listBullets(PhosphorIconsStyle.light), size: 24, color: SmithMkColors.textTertiary)]),
      const SizedBox(height: 10),
      ...evts.map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: SmithMkColors.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: SmithMkColors.accent.withValues(alpha: 0.3), blurRadius: 4)])),
        const SizedBox(width: 10),
        Text(e.$1, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Expanded(child: Text(e.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(5)),
          child: Text(e.$3, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: SmithMkColors.textTertiary, fontFeatures: [FontFeature.tabularFigures()]))),
      ]))),
    ]));
  }
}

// ─── DIMMER MODAL ───
class _DimmerModal extends StatefulWidget {
  final String roomKey, name, emoji;
  final double level;
  final ValueChanged<double> onChanged;
  final VoidCallback onToggle;
  const _DimmerModal({super.key, required this.roomKey, required this.name, required this.emoji, required this.level, required this.onChanged, required this.onToggle});
  @override
  State<_DimmerModal> createState() => _DimmerModalState();
}

class _DimmerModalState extends State<_DimmerModal> {
  late double _lv;
  @override
  void initState() { super.initState(); _lv = widget.level; }

  void _setLevel(double v) {
    setState(() => _lv = v);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final on = _lv > 0;
    final pct = (_lv * 100).round();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment(-0.5, -0.5), end: Alignment(0.5, 0.5), colors: [Color(0xFA1E1E22), Color(0xFA141418)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(0, 16))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Row(children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            GestureDetector(
              onTap: () { widget.onToggle(); setState(() => _lv = _lv > 0 ? 0 : 0.75); },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: on ? SmithMkColors.accent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(6),
                  border: on ? Border.all(color: SmithMkColors.accent.withValues(alpha: 0.2)) : null),
                child: Text(on ? 'ON' : 'OFF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: on ? SmithMkColors.accent : SmithMkColors.textTertiary))),
            ),
            const SizedBox(width: 8),
            GestureDetector(onTap: () => Navigator.pop(context), child: Container(width: 28, height: 28,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
              child: const Center(child: Text('✕', style: TextStyle(fontSize: 13, color: SmithMkColors.textTertiary))))),
          ]),
          const SizedBox(height: 20),
          // Slider + info
          SizedBox(height: 200, child: Row(children: [
            // Vertical slider with pointer capture
            GestureDetector(
              onVerticalDragStart: (d) => _dragSlider(d.localPosition.dy, 200),
              onVerticalDragUpdate: (d) => _dragSlider(d.localPosition.dy, 200),
              child: SizedBox(width: 50, height: 200, child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
                Container(width: 32, height: 200, decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)))),
                // Fill
                Positioned(bottom: 0, child: AnimatedContainer(duration: const Duration(milliseconds: 50), width: 32, height: (200 * _lv).clamp(0.0, 200.0),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [
                      SmithMkColors.accent.withValues(alpha: 0.15 + _lv * 0.15),
                      SmithMkColors.accent.withValues(alpha: 0.3 + _lv * 0.55)])))),
                // Thumb
                Positioned(bottom: (_lv * 178).clamp(0.0, 178.0), child: Container(width: 42, height: 22,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(11),
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: on ? [const Color(0xFF4A3800), const Color(0xFF332600)] : [const Color(0xFF3A3A3A), const Color(0xFF222222)]),
                    border: Border.all(color: on ? SmithMkColors.accent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(0, 2))]),
                  child: Center(child: Container(width: 14, height: 2, decoration: BoxDecoration(borderRadius: BorderRadius.circular(1), color: on ? SmithMkColors.accent.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.15)))))),
              ])),
            ),
            const SizedBox(width: 18),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('$pct%', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w600, color: on ? SmithMkColors.accent : SmithMkColors.textTertiary)),
              const Text('Brightness', style: TextStyle(fontSize: 10, color: SmithMkColors.textTertiary)),
              const Spacer(),
              Wrap(spacing: 6, runSpacing: 6, children: [25, 50, 75, 100].map((p) => GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); _setLevel(p / 100); },
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: pct == p ? SmithMkColors.accent.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: pct == p ? SmithMkColors.accent.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06))),
                  child: Text('$p%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: pct == p ? SmithMkColors.accent : SmithMkColors.textTertiary))),
              )).toList()),
            ])),
          ])),
        ]),
      ),
    );
  }

  void _dragSlider(double localY, double h) {
    final frac = (1 - localY / h).clamp(0.0, 1.0);
    final rounded = (frac * 100).round() / 100;
    if ((rounded * 4).round() != (_lv * 4).round()) {
      (rounded == 0 || rounded == 1) ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
    }
    _setLevel(rounded);
  }
}

// ─── AMBIENT BACKGROUND ───
class _AmbientBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()
      ..shader = RadialGradient(center: const Alignment(0.7, -0.3), radius: 0.6, colors: [SmithMkColors.accent.withValues(alpha: 0.03), Colors.transparent])
        .createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()
      ..shader = RadialGradient(center: const Alignment(-0.5, 0.6), radius: 0.5, colors: [SmithMkColors.tempCool.withValues(alpha: 0.02), Colors.transparent])
        .createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
