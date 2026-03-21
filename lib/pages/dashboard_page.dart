import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../theme/smithmk_theme.dart';
import '../widgets/glass_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
  double _temperature = 22.4;
  double _targetTemp = 22.0;
  bool _heatingOn = true;
  double _livingBrightness = 0.75;
  double _bedroomBrightness = 0.0;
  double _kitchenBrightness = 0.45;
  double _blindPosition = 0.65;
  bool _securityArmed = true;
  bool _frontDoorLocked = true;
  bool _garageLocked = true;
  String _currentScene = '';
  double _solarKw = 3.2;
  double _homeKw = 1.8;

  late AnimationController _pulseController;
  late AnimationController _sceneFlashController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _sceneFlashController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sceneFlashController.dispose();
    super.dispose();
  }

  int get _activeLightCount {
    int c = 0;
    if (_livingBrightness > 0) c++;
    if (_bedroomBrightness > 0) c++;
    if (_kitchenBrightness > 0) c++;
    return c;
  }

  void _activateScene(String scene) {
    HapticFeedback.heavyImpact();
    _sceneFlashController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 150), () => HapticFeedback.lightImpact());
    setState(() {
      _currentScene = scene;
      switch (scene) {
        case 'Morning':
          _livingBrightness = 0.8; _kitchenBrightness = 1.0; _bedroomBrightness = 0.3;
          _blindPosition = 1.0; _targetTemp = 22; _heatingOn = true;
        case 'Movie':
          _livingBrightness = 0.15; _kitchenBrightness = 0; _bedroomBrightness = 0;
          _blindPosition = 0;
        case 'Good Night':
          _livingBrightness = 0; _kitchenBrightness = 0; _bedroomBrightness = 0.05;
          _blindPosition = 0; _targetTemp = 18; _securityArmed = true;
          _frontDoorLocked = true; _garageLocked = true;
        case 'Away':
          _livingBrightness = 0; _kitchenBrightness = 0; _bedroomBrightness = 0;
          _blindPosition = 0; _securityArmed = true; _frontDoorLocked = true;
          _garageLocked = true; _heatingOn = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: SmithMkColors.background),
          // Scene flash
          AnimatedBuilder(
            animation: _sceneFlashController,
            builder: (ctx, _) => IgnorePointer(
              child: Container(
                color: SmithMkColors.accent.withValues(
                  alpha: _sceneFlashController.value * 0.06 * (1 - _sceneFlashController.value) * 4,
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildStatusBar(),
                  const SizedBox(height: 22),
                  _buildSceneRow(),
                  const SizedBox(height: 26),
                  _sectionTitle('CLIMATE'),
                  const SizedBox(height: 12),
                  _buildThermostat(),
                  const SizedBox(height: 26),
                  _sectionTitle('LIGHTING'),
                  const SizedBox(height: 12),
                  _buildLightSlider('Living Room', PhosphorIcons.armchair(PhosphorIconsStyle.light), _livingBrightness, (v) => setState(() => _livingBrightness = v)),
                  const SizedBox(height: 10),
                  _buildLightSlider('Bedroom', PhosphorIcons.bed(PhosphorIconsStyle.light), _bedroomBrightness, (v) => setState(() => _bedroomBrightness = v)),
                  const SizedBox(height: 10),
                  _buildLightSlider('Kitchen', PhosphorIcons.cookingPot(PhosphorIconsStyle.light), _kitchenBrightness, (v) => setState(() => _kitchenBrightness = v)),
                  const SizedBox(height: 26),
                  _sectionTitle('BLINDS'),
                  const SizedBox(height: 12),
                  _buildBlinds(),
                  const SizedBox(height: 26),
                  _sectionTitle('SECURITY'),
                  const SizedBox(height: 12),
                  _buildSecurity(),
                  const SizedBox(height: 26),
                  _sectionTitle('ENERGY'),
                  const SizedBox(height: 12),
                  _buildEnergy(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HEADER ───
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SmithMk', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300, color: SmithMkColors.gold, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text('Dashboard', style: TextStyle(fontSize: 12, color: SmithMkColors.textTertiary, letterSpacing: 0.5)),
          ],
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          borderRadius: 10,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (ctx, _) => Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: SmithMkColors.success.withValues(alpha: 0.3 + _pulseController.value * 0.7),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: SmithMkColors.success.withValues(alpha: _pulseController.value * 0.4), blurRadius: 6)],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text('Connected', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: SmithMkColors.success)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── STATUS BAR ───
  Widget _buildStatusBar() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statusItem(PhosphorIcons.shieldCheck(PhosphorIconsStyle.light), _securityArmed ? 'Armed' : 'Off', _securityArmed ? SmithMkColors.success : SmithMkColors.error),
          _divider(),
          _statusItem(PhosphorIcons.lockSimple(PhosphorIconsStyle.light), _frontDoorLocked ? 'Locked' : 'Open', _frontDoorLocked ? SmithMkColors.success : SmithMkColors.accent),
          _divider(),
          _statusItem(PhosphorIcons.lightbulb(PhosphorIconsStyle.light), '${_activeLightCount} On', _activeLightCount > 0 ? SmithMkColors.accent : SmithMkColors.textTertiary),
          _divider(),
          _statusItem(PhosphorIcons.sunDim(PhosphorIconsStyle.light), '${_solarKw}kW', SmithMkColors.accent),
        ],
      ),
    );
  }

  Widget _statusItem(IconData icon, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _divider() => Container(width: 1, height: 28, color: SmithMkColors.glassBorder);

  // ─── SCENES ───
  Widget _buildSceneRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _sceneBtn('Morning', PhosphorIcons.sun(PhosphorIconsStyle.light)),
          _sceneBtn('Movie', PhosphorIcons.filmSlate(PhosphorIconsStyle.light)),
          _sceneBtn('Good Night', PhosphorIcons.moonStars(PhosphorIconsStyle.light)),
          _sceneBtn('Away', PhosphorIcons.signOut(PhosphorIconsStyle.light)),
        ],
      ),
    );
  }

  Widget _sceneBtn(String name, IconData icon) {
    final active = _currentScene == name;
    return GestureDetector(
      onTap: () => _activateScene(name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? SmithMkColors.accent.withValues(alpha: 0.1) : SmithMkColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? SmithMkColors.accent.withValues(alpha: 0.4) : SmithMkColors.glassBorder,
            width: active ? 1.5 : 1,
          ),
          boxShadow: active ? [BoxShadow(color: SmithMkColors.accent.withValues(alpha: 0.15), blurRadius: 12)] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? SmithMkColors.accent : SmithMkColors.textSecondary),
            const SizedBox(width: 8),
            Text(name, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? SmithMkColors.accent : SmithMkColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SmithMkColors.textTertiary, letterSpacing: 1.5));
  }

  // ─── THERMOSTAT ───
  Widget _buildThermostat() {
    final tempColour = _getTemperatureColour(_targetTemp);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      glowColor: _heatingOn ? SmithMkColors.heatingMode : null,
      child: Column(
        children: [
          SizedBox(
            width: 260,
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer shadow ring for 3D depth
                Container(
                  width: 260, height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 30, offset: const Offset(0, 10), spreadRadius: -5),
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12),
                    ],
                  ),
                ),
                // Bevelled bezel ring
                Container(
                  width: 258, height: 258,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2A2A2A), Color(0xFF0A0A0A)],
                    ),
                  ),
                ),
                // Inner face
                Container(
                  width: 238, height: 238,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF111111),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.5), width: 1),
                  ),
                ),
                // Top specular highlight
                Positioned(
                  top: 6, left: 55, right: 55,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.white.withValues(alpha: 0.1), Colors.transparent],
                      ),
                    ),
                  ),
                ),
                // Syncfusion radial gauge
                SizedBox(
                  width: 240, height: 240,
                  child: SfRadialGauge(
                    axes: <RadialAxis>[
                      RadialAxis(
                        minimum: 12,
                        maximum: 30,
                        startAngle: 135,
                        endAngle: 45,
                        showLabels: true,
                        showTicks: true,
                        labelOffset: 20,
                        interval: 3,
                        axisLabelStyle: const GaugeTextStyle(
                          fontSize: 9,
                          color: Color(0xFF55556A),
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w500,
                        ),
                        axisLineStyle: const AxisLineStyle(
                          thickness: 8,
                          color: Color(0xFF1A1A1A),
                          cornerStyle: CornerStyle.bothCurve,
                        ),
                        majorTickStyle: const MajorTickStyle(
                          length: 10,
                          thickness: 1.5,
                          color: Color(0xFF333333),
                        ),
                        minorTickStyle: const MinorTickStyle(
                          length: 5,
                          thickness: 0.8,
                          color: Color(0xFF222222),
                        ),
                        minorTicksPerInterval: 5,
                        ranges: <GaugeRange>[
                          GaugeRange(
                            startValue: 12,
                            endValue: _targetTemp,
                            startWidth: 8,
                            endWidth: 8,
                            gradient: const SweepGradient(
                              colors: <Color>[
                                Color(0xFF48CAE4),  // Cool blue 12°
                                Color(0xFF78D6B0),  // Neutral 18°
                                Color(0xFFFFC107),  // Amber 22°
                                Color(0xFFFF8C00),  // Deep orange 26°
                                Color(0xFFFF5722),  // Hot 30°
                              ],
                              stops: <double>[0.0, 0.3, 0.55, 0.78, 1.0],
                            ),
                          ),
                        ],
                        pointers: <GaugePointer>[
                          MarkerPointer(
                            value: _targetTemp,
                            markerType: MarkerType.circle,
                            markerWidth: 20,
                            markerHeight: 20,
                            color: tempColour,
                            borderColor: const Color(0xFFE8E8ED),
                            borderWidth: 3,
                            enableDragging: true,
                            onValueChanged: (value) {
                              final snapped = (value * 2).round() / 2;
                              if (snapped != _targetTemp) {
                                HapticFeedback.selectionClick();
                              }
                              setState(() => _targetTemp = snapped.clamp(12, 30));
                            },
                          ),
                        ],
                        annotations: <GaugeAnnotation>[],
                      ),
                    ],
                  ),
                ),
                // Centre text overlay
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_targetTemp.toStringAsFixed(1)}°',
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w200, color: SmithMkColors.textPrimary, height: 1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _heatingOn ? 'HEATING' : 'OFF',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2,
                          color: _heatingOn ? SmithMkColors.heatingMode : SmithMkColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Currently $_temperature°',
                        style: const TextStyle(fontSize: 11, color: SmithMkColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _thermoBtn('−', () { HapticFeedback.selectionClick(); setState(() => _targetTemp = (_targetTemp - 0.5).clamp(12, 30)); }),
              const SizedBox(width: 36),
              GestureDetector(
                onTap: () { HapticFeedback.mediumImpact(); setState(() => _heatingOn = !_heatingOn); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: _heatingOn ? SmithMkColors.heatingMode.withValues(alpha: 0.15) : SmithMkColors.cardSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: _heatingOn ? SmithMkColors.heatingMode.withValues(alpha: 0.4) : SmithMkColors.glassBorder),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Icon(PhosphorIcons.power(PhosphorIconsStyle.bold), color: _heatingOn ? SmithMkColors.heatingMode : SmithMkColors.textTertiary, size: 22),
                ),
              ),
              const SizedBox(width: 36),
              _thermoBtn('+', () { HapticFeedback.selectionClick(); setState(() => _targetTemp = (_targetTemp + 0.5).clamp(12, 30)); }),
            ],
          ),
        ],
      ),
    );
  }

  Color _getTemperatureColour(double temp) {
    final f = (temp - 12) / 18;
    if (f <= 0.3) return Color.lerp(const Color(0xFF48CAE4), const Color(0xFF78D6B0), f / 0.3)!;
    if (f <= 0.55) return Color.lerp(const Color(0xFF78D6B0), const Color(0xFFFFC107), (f - 0.3) / 0.25)!;
    if (f <= 0.78) return Color.lerp(const Color(0xFFFFC107), const Color(0xFFFF8C00), (f - 0.55) / 0.23)!;
    return Color.lerp(const Color(0xFFFF8C00), const Color(0xFFFF5722), (f - 0.78) / 0.22)!;
  }

  Widget _thermoBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: SmithMkColors.cardSurface,
          shape: BoxShape.circle,
          border: Border.all(color: SmithMkColors.glassBorder),
        ),
        child: Center(child: Text(label, style: const TextStyle(fontSize: 18, color: SmithMkColors.textPrimary))),
      ),
    );
  }

  // ─── LIGHTING ───
  Widget _buildLightSlider(String name, IconData icon, double value, ValueChanged<double> onChanged) {
    final on = value > 0;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      glowColor: on ? SmithMkColors.accent : null,
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: (on ? SmithMkColors.accent : SmithMkColors.textTertiary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: on ? SmithMkColors.accent : SmithMkColors.textTertiary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: on ? SmithMkColors.textPrimary : SmithMkColors.textSecondary)),
                    Text('${(value * 100).round()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: on ? SmithMkColors.accent : SmithMkColors.textTertiary)),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: SmithMkColors.accent,
                    inactiveTrackColor: SmithMkColors.glassBorder,
                    thumbColor: SmithMkColors.accent,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayColor: SmithMkColors.accent.withValues(alpha: 0.1),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: value,
                    onChanged: (v) {
                      final oldS = (value * 20).round();
                      final newS = (v * 20).round();
                      if (oldS != newS) HapticFeedback.selectionClick();
                      onChanged(v);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── BLINDS ───
  Widget _buildBlinds() {
    final isOpen = _blindPosition > 0;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      glowColor: isOpen ? SmithMkColors.accent : null,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(PhosphorIcons.slidersHorizontal(PhosphorIconsStyle.light), color: isOpen ? SmithMkColors.accent : SmithMkColors.textTertiary, size: 20),
                const SizedBox(width: 10),
                const Text('Living Room', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
              Text('${(_blindPosition * 100).round()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isOpen ? SmithMkColors.accent : SmithMkColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Blind visual SVG
              CustomPaint(
                size: const Size(72, 72),
                painter: _BlindPainter(position: _blindPosition),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        activeTrackColor: SmithMkColors.accent,
                        inactiveTrackColor: SmithMkColors.glassBorder,
                        thumbColor: SmithMkColors.accent,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayColor: SmithMkColors.accent.withValues(alpha: 0.1),
                      ),
                      child: Slider(
                        value: _blindPosition,
                        onChanged: (v) {
                          final oldS = (_blindPosition * 10).round();
                          final newS = (v * 10).round();
                          if (oldS != newS) HapticFeedback.selectionClick();
                          setState(() => _blindPosition = v);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _blindBtn('Close', PhosphorIcons.caretDown(PhosphorIconsStyle.bold), () { HapticFeedback.mediumImpact(); setState(() => _blindPosition = 0); }),
                        _blindBtn('Stop', PhosphorIcons.stop(PhosphorIconsStyle.fill), () => HapticFeedback.lightImpact()),
                        _blindBtn('Open', PhosphorIcons.caretUp(PhosphorIconsStyle.bold), () { HapticFeedback.mediumImpact(); setState(() => _blindPosition = 1); }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _blindBtn(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: SmithMkColors.cardSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: SmithMkColors.glassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: SmithMkColors.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: SmithMkColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ─── SECURITY ───
  Widget _buildSecurity() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      glowColor: _securityArmed ? SmithMkColors.success : null,
      child: Column(
        children: [
          GestureDetector(
            onTap: () { HapticFeedback.heavyImpact(); setState(() => _securityArmed = !_securityArmed); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: 76, height: 76,
              decoration: BoxDecoration(
                color: (_securityArmed ? SmithMkColors.success : SmithMkColors.error).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: (_securityArmed ? SmithMkColors.success : SmithMkColors.error).withValues(alpha: 0.35), width: 2),
              ),
              child: Icon(
                _securityArmed ? PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill) : PhosphorIcons.shieldSlash(PhosphorIconsStyle.light),
                color: _securityArmed ? SmithMkColors.success : SmithMkColors.error, size: 34,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(_securityArmed ? 'System Armed' : 'System Disarmed', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _securityArmed ? SmithMkColors.success : SmithMkColors.error)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _lockTile('Front Door', _frontDoorLocked, () { HapticFeedback.mediumImpact(); setState(() => _frontDoorLocked = !_frontDoorLocked); })),
              const SizedBox(width: 10),
              Expanded(child: _lockTile('Garage', _garageLocked, () { HapticFeedback.mediumImpact(); setState(() => _garageLocked = !_garageLocked); })),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lockTile(String name, bool locked, VoidCallback onTap) {
    final c = locked ? SmithMkColors.success : SmithMkColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(locked ? PhosphorIcons.lockSimple(PhosphorIconsStyle.fill) : PhosphorIcons.lockSimpleOpen(PhosphorIconsStyle.light), color: c, size: 18),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                Text(locked ? 'Locked' : 'Unlocked', style: TextStyle(fontSize: 10, color: c)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── ENERGY ───
  Widget _buildEnergy() {
    final exporting = _solarKw > _homeKw;
    final net = (_solarKw - _homeKw).abs().toStringAsFixed(1);
    return GlassCard(
      padding: const EdgeInsets.all(20),
      glowColor: SmithMkColors.accent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _energyNode(PhosphorIcons.sunDim(PhosphorIconsStyle.light), 'Solar', '${_solarKw}kW', SmithMkColors.accent),
          Column(
            children: [
              Icon(exporting ? PhosphorIcons.arrowRight(PhosphorIconsStyle.bold) : PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold), color: SmithMkColors.textTertiary, size: 18),
              const SizedBox(height: 4),
              Text(exporting ? 'Exporting' : 'Importing', style: const TextStyle(fontSize: 9, color: SmithMkColors.textTertiary)),
              Text('${net}kW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: exporting ? SmithMkColors.success : SmithMkColors.accent)),
            ],
          ),
          _energyNode(PhosphorIcons.house(PhosphorIconsStyle.light), 'Home', '${_homeKw}kW', SmithMkColors.gold),
        ],
      ),
    );
  }

  Widget _energyNode(IconData icon, String label, String value, Color c) {
    return Column(
      children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: c.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: c, size: 26),
        ),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c)),
        Text(label, style: const TextStyle(fontSize: 10, color: SmithMkColors.textTertiary)),
      ],
    );
  }
}

// ─── BLIND PAINTER ───
class _BlindPainter extends CustomPainter {
  final double position; // 0 = closed, 1 = open

  _BlindPainter({required this.position});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    const pad = 4.0;
    final inner = s - pad * 2;
    final closedRatio = 1 - position;
    final fabricH = inner * closedRatio;
    const slats = 6;

    // Window glow
    if (closedRatio < 0.95) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(pad, pad, inner, inner), const Radius.circular(3)),
        Paint()..color = Color.fromRGBO(255, 220, 140, (1 - closedRatio) * 0.2),
      );
    }

    // Frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(2, 2, s - 4, s - 4), const Radius.circular(5)),
      Paint()..color = Colors.white.withValues(alpha: 0.08)..style = PaintingStyle.stroke..strokeWidth = 1,
    );

    // Fabric
    if (fabricH > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(pad, pad, inner, fabricH), const Radius.circular(2)),
        Paint()..color = Colors.white.withValues(alpha: 0.2),
      );
    }

    // Slat lines
    if (fabricH > 4) {
      for (int i = 0; i < slats; i++) {
        final y = pad + (fabricH / (slats + 1)) * (i + 1);
        if (y >= pad + fabricH - 1) continue;
        canvas.drawLine(
          Offset(pad + 2, y), Offset(s - pad - 2, y),
          Paint()..color = Colors.white.withValues(alpha: 0.45)..strokeWidth = 0.8,
        );
      }
    }

    // Bottom rail
    if (fabricH > 3) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(pad, pad + fabricH - 2, inner, 2.5), const Radius.circular(1)),
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BlindPainter old) => old.position != position;
}
