import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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

  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late AnimationController _sceneFlashController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat();
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
    _shimmerController.dispose();
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
                color: SmithMkColors.accentPrimary.withValues(
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
          _statusItem(PhosphorIcons.lockSimple(PhosphorIconsStyle.light), _frontDoorLocked ? 'Locked' : 'Open', _frontDoorLocked ? SmithMkColors.success : SmithMkColors.warning),
          _divider(),
          _statusItem(PhosphorIcons.lightbulb(PhosphorIconsStyle.light), '${_activeLightCount} On', _activeLightCount > 0 ? SmithMkColors.accentPrimary : SmithMkColors.textTertiary),
          _divider(),
          _statusItem(PhosphorIcons.sunDim(PhosphorIconsStyle.light), '${_solarKw}kW', SmithMkColors.accentPrimary),
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
          color: active ? SmithMkColors.accentPrimary.withValues(alpha: 0.1) : SmithMkColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? SmithMkColors.accentPrimary.withValues(alpha: 0.4) : SmithMkColors.glassBorder,
            width: active ? 1.5 : 1,
          ),
          boxShadow: active ? [BoxShadow(color: SmithMkColors.accentPrimary.withValues(alpha: 0.15), blurRadius: 12)] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? SmithMkColors.accentPrimary : SmithMkColors.textSecondary),
            const SizedBox(width: 8),
            Text(name, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: active ? SmithMkColors.accentPrimary : SmithMkColors.textSecondary)),
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
    return GlassCard(
      padding: const EdgeInsets.all(24),
      glowColor: _heatingOn ? SmithMkColors.heatingActive : null,
      child: Column(
        children: [
          // 3D Glass thermostat ring
          SizedBox(
            width: 230, height: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer shadow ring — depth behind the glass
                Container(
                  width: 230, height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      // Deep shadow below
                      BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 40, offset: const Offset(0, 12), spreadRadius: -8),
                      // Subtle ambient
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: -4),
                    ],
                  ),
                ),
                // Outer bevel ring — raised edge
                Container(
                  width: 228, height: 228,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.02),
                        Colors.black.withValues(alpha: 0.15),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
                // Main glass body
                Container(
                  width: 220, height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.25, -0.35),
                      radius: 0.85,
                      colors: [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.03),
                        SmithMkColors.cardSurface.withValues(alpha: 0.9),
                        SmithMkColors.background.withValues(alpha: 0.95),
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                    boxShadow: [
                      // Inner light edge top-left
                      BoxShadow(color: Colors.white.withValues(alpha: 0.06), blurRadius: 1, spreadRadius: 0),
                    ],
                  ),
                ),
                // Inner inset shadow ring — concave illusion
                Container(
                  width: 210, height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black.withValues(alpha: 0.2), width: 1.5),
                  ),
                ),
                // Glass highlight — specular reflection top-left
                Positioned(
                  top: 18, left: 30,
                  child: Container(
                    width: 80, height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.14),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Shimmer sweep animation
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (ctx, _) {
                    final v = _shimmerController.value;
                    return ClipOval(
                      child: SizedBox(
                        width: 220, height: 220,
                        child: CustomPaint(
                          painter: _ShimmerPainter(progress: v),
                        ),
                      ),
                    );
                  },
                ),
                // Inner ring border — subtle chrome edge
                Container(
                  width: 195, height: 195,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                      width: 0.5,
                    ),
                  ),
                ),
                // Temperature arc + drag
                GestureDetector(
                  onPanUpdate: (details) {
                    final dx = details.localPosition.dx - 115;
                    final dy = details.localPosition.dy - 115;
                    var angle = atan2(dy, dx) * (180 / pi);
                    if (angle < 0) angle += 360;
                    var arcDeg = angle - 135;
                    if (arcDeg < 0) arcDeg += 360;
                    if (arcDeg > 270) {
                      arcDeg = arcDeg > 315 ? 0 : 270;
                    }
                    final frac = arcDeg / 270;
                    final newTemp = (16 + frac * 14);
                    final snapped = (newTemp * 2).round() / 2;
                    if (snapped != _targetTemp) HapticFeedback.selectionClick();
                    setState(() => _targetTemp = snapped.clamp(16, 30));
                  },
                  child: SizedBox(
                    width: 230, height: 230,
                    child: CustomPaint(
                      painter: _ThermostatPainter(
                        currentTemp: _temperature,
                        targetTemp: _targetTemp,
                        isHeating: _heatingOn,
                      ),
                    ),
                  ),
                ),
                // Centre text
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_targetTemp.toStringAsFixed(1)}°',
                        style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w200, color: SmithMkColors.textPrimary, height: 1),
                      ),
                      Text(
                        _heatingOn ? 'HEATING' : 'OFF',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: _heatingOn ? SmithMkColors.heatingActive : SmithMkColors.textTertiary),
                      ),
                      const SizedBox(height: 4),
                      Text('Currently ${_temperature}°', style: const TextStyle(fontSize: 11, color: SmithMkColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _thermoBtn('−', () { HapticFeedback.selectionClick(); setState(() => _targetTemp = (_targetTemp - 0.5).clamp(16, 30)); }),
              const SizedBox(width: 36),
              GestureDetector(
                onTap: () { HapticFeedback.mediumImpact(); setState(() => _heatingOn = !_heatingOn); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: _heatingOn ? SmithMkColors.heatingActive.withValues(alpha: 0.15) : SmithMkColors.cardSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: _heatingOn ? SmithMkColors.heatingActive.withValues(alpha: 0.4) : SmithMkColors.glassBorder),
                  ),
                  child: Icon(PhosphorIcons.power(PhosphorIconsStyle.bold), color: _heatingOn ? SmithMkColors.heatingActive : SmithMkColors.textTertiary, size: 22),
                ),
              ),
              const SizedBox(width: 36),
              _thermoBtn('+', () { HapticFeedback.selectionClick(); setState(() => _targetTemp = (_targetTemp + 0.5).clamp(16, 30)); }),
            ],
          ),
        ],
      ),
    );
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
      glowColor: on ? SmithMkColors.accentPrimary : null,
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: (on ? SmithMkColors.accentPrimary : SmithMkColors.textTertiary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: on ? SmithMkColors.accentPrimary : SmithMkColors.textTertiary, size: 18),
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
                    Text('${(value * 100).round()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: on ? SmithMkColors.accentPrimary : SmithMkColors.textTertiary)),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: SmithMkColors.accentPrimary,
                    inactiveTrackColor: SmithMkColors.glassBorder,
                    thumbColor: SmithMkColors.accentPrimary,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayColor: SmithMkColors.accentPrimary.withValues(alpha: 0.1),
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
      glowColor: isOpen ? SmithMkColors.blindOpen : null,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(PhosphorIcons.slidersHorizontal(PhosphorIconsStyle.light), color: isOpen ? SmithMkColors.blindOpen : SmithMkColors.textTertiary, size: 20),
                const SizedBox(width: 10),
                const Text('Living Room', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
              Text('${(_blindPosition * 100).round()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isOpen ? SmithMkColors.blindOpen : SmithMkColors.textTertiary)),
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
                        activeTrackColor: SmithMkColors.blindOpen,
                        inactiveTrackColor: SmithMkColors.glassBorder,
                        thumbColor: SmithMkColors.blindOpen,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayColor: SmithMkColors.blindOpen.withValues(alpha: 0.1),
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
    final c = locked ? SmithMkColors.success : SmithMkColors.warning;
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
      glowColor: SmithMkColors.accentPrimary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _energyNode(PhosphorIcons.sunDim(PhosphorIconsStyle.light), 'Solar', '${_solarKw}kW', SmithMkColors.accentPrimary),
          Column(
            children: [
              Icon(exporting ? PhosphorIcons.arrowRight(PhosphorIconsStyle.bold) : PhosphorIcons.arrowLeft(PhosphorIconsStyle.bold), color: SmithMkColors.textTertiary, size: 18),
              const SizedBox(height: 4),
              Text(exporting ? 'Exporting' : 'Importing', style: const TextStyle(fontSize: 9, color: SmithMkColors.textTertiary)),
              Text('${net}kW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: exporting ? SmithMkColors.success : SmithMkColors.warning)),
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

// ─── THERMOSTAT PAINTER ───
class _ThermostatPainter extends CustomPainter {
  final double currentTemp;
  final double targetTemp;
  final bool isHeating;

  _ThermostatPainter({required this.currentTemp, required this.targetTemp, required this.isHeating});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = min(size.width, size.height) / 2 - 18;
    const startAngle = 135 * pi / 180;
    const totalSweep = 270 * pi / 180;

    // Background arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle, totalSweep, false,
      Paint()..color = Colors.white.withValues(alpha: 0.07)..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round,
    );

    // Active arc
    final frac = (targetTemp - 16) / 14;
    final sweep = frac * totalSweep;
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + totalSweep,
      colors: const [Color(0xFF48CAE4), Color(0xFFFFC107), Color(0xFFFF6B35)],
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle, sweep, false,
      Paint()
        ..shader = gradient.createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
        ..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round,
    );

    // Thumb
    final thumbAngle = startAngle + sweep;
    final tx = cx + r * cos(thumbAngle);
    final ty = cy + r * sin(thumbAngle);
    canvas.drawCircle(Offset(tx, ty), 8, Paint()..color = isHeating ? const Color(0xFFFF6B35) : const Color(0xFF55556A));
    canvas.drawCircle(Offset(tx, ty), 4.5, Paint()..color = const Color(0xFFE8E8ED));
  }

  @override
  bool shouldRepaint(covariant _ThermostatPainter old) =>
      old.targetTemp != targetTemp || old.isHeating != isHeating;
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

// ─── SHIMMER PAINTER ───
class _ShimmerPainter extends CustomPainter {
  final double progress;
  _ShimmerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Sweep a highlight band across the glass
    final angle = progress * 2 * pi;
    final dx = cos(angle) * cx * 0.6;
    final dy = sin(angle) * cy * 0.6;
    
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(dx / cx, dy / cy),
        radius: 0.5,
        colors: [
          Colors.white.withValues(alpha: 0.07),
          Colors.white.withValues(alpha: 0.02),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter old) => old.progress != progress;
}
