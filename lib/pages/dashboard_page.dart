import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../theme/smithmk_theme.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  // Climate state
  double _targetTemp = 22.0;
  final double _currentTemp = 19.0;
  bool _hvacOn = true;
  bool _heatingMode = true;

  // Scenes
  int _activeScene = 1;

  // Room lights
  final Map<String, double> _lightLevels = {'Master Bedroom': 0.0, 'Lounge': 0.0, 'Office': 0.0};
  String? _expandedRoom;

  // Dashboard sections on screen
  final List<String> _activeSections = [
    'weather', 'scenes', 'climate', 'status', 'energy', 'rooms', 'activity',
  ];

  // All available sections
  static const List<_Section> _allSections = [
    _Section('weather', 'Weather', '🌤️'),
    _Section('scenes', 'Scenes', '🎬'),
    _Section('climate', 'Climate', '🌡️'),
    _Section('status', 'Status', '📊'),
    _Section('energy', 'Energy', '⚡'),
    _Section('rooms', 'Rooms', '🚪'),
    _Section('activity', 'Activity', '📋'),
    _Section('blinds', 'Blinds', '🪟'),
    _Section('alarm', 'Alarm', '🚨'),
    _Section('irrigation', 'Irrigation', '🌿'),
  ];

  // Entry animation
  late AnimationController _entryController;
  late Animation<double> _entryAnim;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
    _entryController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _entryAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic);
    _entryController.forward();
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _entryController.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = _now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _timeStr =>
      '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}';

  String get _dateStr {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${days[_now.weekday - 1]} ${_now.day} ${months[_now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmithMkColors.background,
      endDrawer: _buildWidgetDrawer(),
      body: Stack(
        children: [
          // Ambient gradient orbs behind everything
          _buildAmbientBackground(),
          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _entryAnim,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 800;
                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.all(isWide ? 28 : 16),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildHeader(),
                            const SizedBox(height: 24),
                            // Connection status
                            _buildStatusPills(),
                            const SizedBox(height: 20),
                            if (isWide)
                              _buildWideLayout()
                            else
                              _buildNarrowLayout(),
                            const SizedBox(height: 80),
                          ]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          // Floating edit button
          Positioned(
            bottom: 20, right: 20,
            child: _buildEditButton(),
          ),
        ],
      ),
    );
  }

  // ─── AMBIENT BACKGROUND ───
  Widget _buildAmbientBackground() {
    return Positioned.fill(
      child: CustomPaint(painter: _AmbientPainter()),
    );
  }

  // ─── HEADER ───
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: SmithMkColors.gold)),
              const SizedBox(height: 2),
              Text(_dateStr, style: const TextStyle(fontSize: 12, color: SmithMkColors.textTertiary)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_timeStr, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w200, color: SmithMkColors.textPrimary, letterSpacing: -1, height: 1, fontFeatures: [FontFeature.tabularFigures()])),
            const SizedBox(height: 4),
            Text('☀️ ${_currentTemp.round()}°', style: const TextStyle(fontSize: 13, color: SmithMkColors.textSecondary)),
          ],
        ),
      ],
    );
  }

  // ─── STATUS PILLS ───
  Widget _buildStatusPills() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _statusPill('HA', SmithMkColors.error),
        _statusPill('SUPABASE', SmithMkColors.success),
        _statusPill('SOLAR', SmithMkColors.error),
      ],
    );
  }

  Widget _statusPill(String label, Color dotColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: dotColor, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: dotColor.withValues(alpha: 0.5), blurRadius: 4)],
                ),
              ),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: SmithMkColors.textSecondary, letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── GLASSMORPHIC CARD ───
  Widget _glassCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(18)}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SmithMkColors.textTertiary, letterSpacing: 1.5));
  }

  // ─── WIDE LAYOUT (desktop/tablet) ───
  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildColumn(_activeSections.where((k) => ['weather', 'climate', 'status', 'energy'].contains(k)).toList())),
        const SizedBox(width: 16),
        Expanded(child: _buildColumn(_activeSections.where((k) => !['weather', 'climate', 'status', 'energy'].contains(k)).toList())),
      ],
    );
  }

  // ─── NARROW LAYOUT (phone) ───
  Widget _buildNarrowLayout() {
    return _buildColumn(_activeSections);
  }

  Widget _buildColumn(List<String> keys) {
    return Column(
      children: keys.asMap().entries.map((e) {
        final delay = e.key * 0.08;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 400 + (e.key * 80)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildSectionByKey(e.value),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionByKey(String key) {
    switch (key) {
      case 'weather': return _weatherCard();
      case 'scenes': return _scenesCard();
      case 'climate': return _climateCard();
      case 'status': return _statusCards();
      case 'energy': return _energyCard();
      case 'rooms': return _roomsCard();
      case 'activity': return _activityCard();
      case 'blinds': return _simpleCard('BLINDS', '🪟', 'All Closed', '3 blinds');
      case 'alarm': return _simpleCard('ALARM', '🚨', 'Disarmed', 'Risco · 10 zones');
      case 'irrigation': return _simpleCard('IRRIGATION', '🌿', 'Off', 'No schedule');
      default: return const SizedBox.shrink();
    }
  }

  // ─── WEATHER ───
  Widget _weatherCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('☀️', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_currentTemp.round()}° Clear sky', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: SmithMkColors.textPrimary)),
              Text('Feels ${_currentTemp.round()}° · 💧 68% · 💨 6 km/h', style: const TextStyle(fontSize: 11, color: SmithMkColors.textTertiary)),
            ])),
          ]),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final f in [('Sun', '☀️', 29, 16), ('Mon', '🌤️', 30, 15), ('Tue', '🌙', 31, 18), ('Wed', '❄️', 23, 16), ('Thu', '☁️', 17, 14)])
                Column(children: [
                  Text(f.$1, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: SmithMkColors.textTertiary)),
                  const SizedBox(height: 4),
                  Text(f.$2, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 4),
                  Text('${f.$3}°', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SmithMkColors.textPrimary)),
                  Text('${f.$4}°', style: const TextStyle(fontSize: 10, color: SmithMkColors.textTertiary)),
                ]),
            ],
          ),
        ],
      ),
    );
  }

  // ─── CLIMATE with THERMOSTAT ───
  Widget _climateCard() {
    final modeCol = _heatingMode ? SmithMkColors.heatingMode : const Color(0xFF48CAE4);
    final f = (_targetTemp - 12) / 18;
    final tempCol = f <= 0.4
        ? Color.lerp(const Color(0xFF48CAE4), const Color(0xFFFFB300), f / 0.4)!
        : Color.lerp(const Color(0xFFFFB300), const Color(0xFFFF5722), (f - 0.4) / 0.6)!;

    return _glassCard(
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _sectionLabel('CLIMATE'),
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); setState(() => _heatingMode = !_heatingMode); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: modeCol.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: modeCol.withValues(alpha: 0.3)),
                ),
                child: Text(_heatingMode ? '🔥 HEAT' : '❄️ COOL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: modeCol, letterSpacing: 1)),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: SfRadialGauge(axes: <RadialAxis>[
              RadialAxis(
                minimum: 12, maximum: 30, startAngle: 135, endAngle: 45,
                showLabels: true, showTicks: true, labelOffset: 16, interval: 3,
                axisLabelStyle: const GaugeTextStyle(fontSize: 8, color: Color(0xFF555555), fontWeight: FontWeight.w500),
                axisLineStyle: const AxisLineStyle(thickness: 6, color: Color(0xFF1A1A1A), cornerStyle: CornerStyle.bothCurve),
                majorTickStyle: const MajorTickStyle(length: 8, thickness: 1.2, color: Color(0xFF333333)),
                minorTickStyle: const MinorTickStyle(length: 4, thickness: 0.6, color: Color(0xFF222222)),
                minorTicksPerInterval: 5,
                ranges: <GaugeRange>[
                  GaugeRange(startValue: 12, endValue: _targetTemp, startWidth: 6, endWidth: 6,
                    gradient: const SweepGradient(colors: [Color(0xFF48CAE4), Color(0xFF78D6B0), Color(0xFFFFB300), Color(0xFFFF8C00), Color(0xFFFF5722)], stops: [0.0, 0.3, 0.55, 0.78, 1.0])),
                ],
                pointers: <GaugePointer>[
                  MarkerPointer(value: _targetTemp, markerType: MarkerType.circle, markerWidth: 16, markerHeight: 16,
                    color: tempCol, borderColor: const Color(0xFFEEEEEE), borderWidth: 2.5, enableDragging: true,
                    onValueChanged: (v) {
                      final s = (v * 2).round() / 2;
                      if (s != _targetTemp) HapticFeedback.selectionClick();
                      setState(() => _targetTemp = s.clamp(12, 30));
                    }),
                ],
                annotations: <GaugeAnnotation>[
                  GaugeAnnotation(widget: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('${_targetTemp.toStringAsFixed(1)}°', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w200, color: Color(0xFFEEEEEE), height: 1)),
                    const SizedBox(height: 2),
                    Text('Currently ${_currentTemp}°', style: const TextStyle(fontSize: 10, color: Color(0xFF707070))),
                  ]), angle: 90, positionFactor: 0.0),
                ],
              ),
            ]),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _circleBtn('−', () { HapticFeedback.selectionClick(); setState(() => _targetTemp = (_targetTemp - 0.5).clamp(12, 30)); }),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: () { HapticFeedback.mediumImpact(); setState(() => _hvacOn = !_hvacOn); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 40, height: 40,
                decoration: BoxDecoration(color: _hvacOn ? modeCol.withValues(alpha: 0.15) : const Color(0xFF252525), shape: BoxShape.circle, border: Border.all(color: _hvacOn ? modeCol.withValues(alpha: 0.4) : SmithMkColors.glassBorder)),
                child: Icon(Icons.power_settings_new, color: _hvacOn ? modeCol : SmithMkColors.textTertiary, size: 18),
              ),
            ),
            const SizedBox(width: 20),
            _circleBtn('+', () { HapticFeedback.selectionClick(); setState(() => _targetTemp = (_targetTemp + 0.5).clamp(12, 30)); }),
          ]),
        ],
      ),
    );
  }

  Widget _circleBtn(String label, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(color: const Color(0xFF252525), shape: BoxShape.circle, border: Border.all(color: SmithMkColors.glassBorder)),
      child: Center(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFB0B0B0)))),
    ));
  }

  // ─── STATUS CARDS (Security + Lights) ───
  Widget _statusCards() {
    return Row(children: [
      Expanded(child: _glassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_sectionLabel('SECURITY'), const Text('🛡️', style: TextStyle(fontSize: 18))]),
        const SizedBox(height: 8),
        const Text('Disarmed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF4ADE80))),
        const Text('1 open · 10 zones', style: TextStyle(fontSize: 10, color: SmithMkColors.textTertiary)),
      ]))),
      const SizedBox(width: 12),
      Expanded(child: _glassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_sectionLabel('LIGHTS'), const Text('💡', style: TextStyle(fontSize: 18))]),
        const SizedBox(height: 8),
        const Text('0/4', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: SmithMkColors.textPrimary)),
        const Text('0 rooms active', style: TextStyle(fontSize: 10, color: SmithMkColors.textTertiary)),
      ]))),
    ]);
  }

  // ─── ENERGY with SYNCFUSION RADIAL GAUGES ───
  Widget _energyCard() {
    return _glassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('ENERGY'),
      const SizedBox(height: 14),
      Wrap(alignment: WrapAlignment.spaceEvenly, spacing: 4, runSpacing: 8, children: [
        _energyGauge('Solar', 0, 5000, SmithMkColors.accent),
        _energyGauge('Battery', 0, 100, const Color(0xFF4ADE80)),
        _energyGauge('Home', 0, 5000, const Color(0xFF48CAE4)),
        _energyGauge('EV', 0, 7000, SmithMkColors.accent),
      ]),
    ]));
  }

  Widget _energyGauge(String label, double value, double max, Color col) {
    return SizedBox(width: 70, height: 80, child: Column(children: [
      SizedBox(width: 56, height: 56, child: SfRadialGauge(axes: [
        RadialAxis(minimum: 0, maximum: max, startAngle: 135, endAngle: 45, showLabels: false, showTicks: false,
          axisLineStyle: AxisLineStyle(thickness: 5, color: col.withValues(alpha: 0.1), cornerStyle: CornerStyle.bothCurve),
          pointers: [RangePointer(value: value, width: 5, color: col, cornerStyle: CornerStyle.bothCurve)],
          annotations: [GaugeAnnotation(widget: Text('${value.round()}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: col)), angle: 90, positionFactor: 0.0)],
        ),
      ])),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 9, color: SmithMkColors.textTertiary)),
    ]));
  }

  // ─── SCENES ───
  Widget _scenesCard() {
    final scenes = [('Morning', '🌅', 0), ('Day', '☀️', 1), ('Evening', '🏠', 2), ('Night', '🌙', 3), ('Away', '🏖️', 4), ('Movie', '🎬', 5)];
    return _glassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _sectionLabel('SCENES'), const Text('Tap to activate', style: TextStyle(fontSize: 10, color: SmithMkColors.textTertiary)),
      ]),
      const SizedBox(height: 12),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
        children: scenes.map((s) {
          final active = _activeScene == s.$3;
          return GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); setState(() => _activeScene = s.$3); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: active ? SmithMkColors.accent.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: active ? SmithMkColors.accent.withValues(alpha: 0.3) : SmithMkColors.glassBorder),
              ),
              child: Column(children: [
                Text(s.$2, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 4),
                Text(s.$1, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: active ? SmithMkColors.accent : SmithMkColors.textSecondary)),
              ]),
            ),
          );
        }).toList(),
      )),
    ]));
  }

  // ─── ROOMS with EXPANDABLE DIMMER ───
  Widget _roomsCard() {
    final rooms = [('Master Bedroom', '🛏️', 0, 2), ('Lounge', '🛋️', 0, 2), ('Office', '💻', 0, 0)];
    return _glassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _sectionLabel('ROOMS'), const Text('All →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SmithMkColors.accent)),
      ]),
      const SizedBox(height: 10),
      ...rooms.map((r) => _roomRow(r.$1, r.$2, r.$3, r.$4)),
    ]));
  }

  Widget _roomRow(String name, String emoji, int lightsOn, int lightsTotal) {
    final isExpanded = _expandedRoom == name;
    final level = _lightLevels[name] ?? 0.0;
    final isOn = level > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300), curve: Curves.easeInOutCubicEmphasized,
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isExpanded ? 14 : 10),
      decoration: BoxDecoration(
        color: isExpanded ? SmithMkColors.accent.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: isExpanded ? Border.all(color: SmithMkColors.accent.withValues(alpha: 0.12)) : null,
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); setState(() => _expandedRoom = isExpanded ? null : name); },
          behavior: HitTestBehavior.opaque,
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: SmithMkColors.textPrimary))),
            Text('$lightsOn/$lightsTotal', style: const TextStyle(fontSize: 12, color: SmithMkColors.textTertiary)),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); setState(() => _lightLevels[name] = isOn ? 0.0 : 0.75); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOn ? SmithMkColors.accent.withValues(alpha: 0.15) : const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(6),
                  border: isOn ? Border.all(color: SmithMkColors.accent.withValues(alpha: 0.3)) : null,
                ),
                child: Text(isOn ? 'ON' : 'OFF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isOn ? SmithMkColors.accent : SmithMkColors.textTertiary)),
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () { HapticFeedback.lightImpact(); setState(() => _expandedRoom = null); },
                child: Container(width: 24, height: 24, decoration: BoxDecoration(color: const Color(0xFF333333), borderRadius: BorderRadius.circular(6)),
                  child: const Center(child: Text('✕', style: TextStyle(fontSize: 11, color: SmithMkColors.textTertiary)))),
              ),
            ],
          ]),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: SizedBox(height: 150, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Vertical dimmer — sharp, no blur
              GestureDetector(
                onVerticalDragUpdate: (d) {
                  final frac = (1 - d.localPosition.dy / 150).clamp(0.0, 1.0);
                  final rounded = (frac * 100).round() / 100;
                  if ((rounded * 4).round() != (level * 4).round()) {
                    (rounded == 0 || rounded == 1) ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
                  }
                  setState(() => _lightLevels[name] = rounded);
                },
                child: SizedBox(width: 48, height: 150, child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
                  Container(width: 32, height: 150, decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.06)))),
                  Positioned(bottom: 0, child: AnimatedContainer(duration: const Duration(milliseconds: 50), width: 32, height: (150 * level).clamp(0.0, 150.0),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [SmithMkColors.accent.withValues(alpha: 0.15 + level * 0.15), SmithMkColors.accent.withValues(alpha: 0.3 + level * 0.55)])))),
                  Positioned(bottom: (128 * level).clamp(0.0, 128.0), child: Container(width: 40, height: 22,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(11),
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: isOn ? [const Color(0xFF4A3800), const Color(0xFF332600)] : [const Color(0xFF3A3A3A), const Color(0xFF222222)]),
                      border: Border.all(color: isOn ? SmithMkColors.accent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 1, offset: const Offset(0, 2))]),
                    child: Center(child: Container(width: 16, height: 2, decoration: BoxDecoration(borderRadius: BorderRadius.circular(1), color: isOn ? SmithMkColors.accent.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.15)))))),
                ])),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${(level * 100).round()}%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: isOn ? SmithMkColors.accent : SmithMkColors.textTertiary)),
                const Text('Brightness', style: TextStyle(fontSize: 10, color: SmithMkColors.textTertiary)),
                const Spacer(),
                Wrap(spacing: 6, runSpacing: 6, children: [25, 50, 75, 100].map((p) => GestureDetector(
                  onTap: () { HapticFeedback.selectionClick(); setState(() => _lightLevels[name] = p / 100); },
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: (level * 100).round() == p ? SmithMkColors.accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: (level * 100).round() == p ? SmithMkColors.accent.withValues(alpha: 0.3) : SmithMkColors.glassBorder)),
                    child: Text('$p%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: (level * 100).round() == p ? SmithMkColors.accent : SmithMkColors.textTertiary))),
                )).toList()),
              ])),
            ])),
          ),
        ),
      ]),
    );
  }

  // ─── ACTIVITY ───
  Widget _activityCard() {
    final events = [('💡', 'Entrance 2 → off', '11:28'), ('💡', 'Alfresco → off', '11:19'), ('💡', 'Entrance 2 → off', '11:16'), ('💡', 'Entrance 1 → off', '11:16'), ('💡', 'Alfresco → off', '11:14'), ('💡', 'Entrance 1 → off', '11:13')];
    return _glassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('ACTIVITY'),
      const SizedBox(height: 12),
      ...events.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: SmithMkColors.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: SmithMkColors.accent.withValues(alpha: 0.3), blurRadius: 4)])),
        const SizedBox(width: 12),
        Text(e.$1, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(child: Text(e.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: SmithMkColors.textPrimary))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(6)),
          child: Text(e.$3, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: SmithMkColors.textTertiary, fontFeatures: [FontFeature.tabularFigures()]))),
      ]))),
    ]));
  }

  // ─── SIMPLE CARD (for blinds, alarm, irrigation) ───
  Widget _simpleCard(String title, String emoji, String value, String subtitle) {
    return _glassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_sectionLabel(title), Text(emoji, style: const TextStyle(fontSize: 18))]),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: SmithMkColors.textPrimary)),
      Text(subtitle, style: const TextStyle(fontSize: 10, color: SmithMkColors.textTertiary)),
    ]));
  }

  // ─── EDIT BUTTON ───
  Widget _buildEditButton() {
    return GestureDetector(
      onTap: () { HapticFeedback.mediumImpact(); Scaffold.of(context).openEndDrawer(); },
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(color: SmithMkColors.accent, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: SmithMkColors.accent.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
        child: const Center(child: Text('✎', style: TextStyle(fontSize: 20, color: Color(0xFF121212)))),
      ),
    );
  }

  // ─── WIDGET DRAWER ───
  Widget _buildWidgetDrawer() {
    final drawerKeys = _allSections.map((s) => s.key).where((k) => !_activeSections.contains(k)).toList();
    return Drawer(backgroundColor: SmithMkColors.cardSurface, width: 260, child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('WIDGETS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SmithMkColors.gold, letterSpacing: 2)),
        GestureDetector(onTap: () => Navigator.of(context).pop(), child: const Text('Done', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SmithMkColors.accent))),
      ])),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Tap + to add, − to remove', style: TextStyle(fontSize: 10, color: SmithMkColors.textTertiary))),
      const SizedBox(height: 12),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('ON DASHBOARD', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: SmithMkColors.textTertiary, letterSpacing: 1))),
      const SizedBox(height: 6),
      ..._activeSections.map((k) { final s = _allSections.firstWhere((s) => s.key == k); return _drawerItem(s, true); }),
      const SizedBox(height: 16),
      if (drawerKeys.isNotEmpty) ...[
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('AVAILABLE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: SmithMkColors.textTertiary, letterSpacing: 1))),
        const SizedBox(height: 6),
        ...drawerKeys.map((k) { final s = _allSections.firstWhere((s) => s.key == k); return _drawerItem(s, false); }),
      ],
    ])));
  }

  Widget _drawerItem(_Section section, bool active) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); setState(() { active ? _activeSections.remove(section.key) : _activeSections.add(section.key); }); },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: active ? SmithMkColors.accent.withValues(alpha: 0.06) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Text(section.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(child: Text(section.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: active ? SmithMkColors.textPrimary : SmithMkColors.textTertiary))),
          Icon(active ? Icons.remove_circle_outline : Icons.add_circle_outline, size: 18, color: active ? SmithMkColors.error : SmithMkColors.accent),
        ]),
      ),
    );
  }
}

// ─── AMBIENT BACKGROUND PAINTER ───
class _AmbientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle warm orb top-right
    final paint1 = Paint()
      ..shader = RadialGradient(center: const Alignment(0.7, -0.3), radius: 0.6, colors: [
        const Color(0xFFFFB300).withValues(alpha: 0.03),
        Colors.transparent,
      ]).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint1);

    // Subtle cool orb bottom-left
    final paint2 = Paint()
      ..shader = RadialGradient(center: const Alignment(-0.5, 0.6), radius: 0.5, colors: [
        const Color(0xFF48CAE4).withValues(alpha: 0.02),
        Colors.transparent,
      ]).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Section {
  final String key, label, emoji;
  const _Section(this.key, this.label, this.emoji);
}
