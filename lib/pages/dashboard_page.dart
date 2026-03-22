import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../theme/smithmk_theme.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();
  double _targetTemp = 22.0;
  final double _currentTemp = 19.0;
  bool _heatingOn = true;
  bool _heatingMode = true; // true=heating, false=cooling
  int _activeScene = 1; // Day
  final Map<String, double> _lightLevels = {'Master Bedroom': 0.0, 'Lounge': 0.0, 'Office': 0.0};
  String? _expandedRoom;

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
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmithMkColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(isWide ? 24 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  if (isWide)
                    _buildTwoColumnLayout()
                  else
                    _buildSingleColumnLayout(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── HEADER ───
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_greeting, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: SmithMkColors.gold)),
            const SizedBox(height: 2),
            Text(_dateStr, style: const TextStyle(fontSize: 12, color: SmithMkColors.textTertiary)),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_timeStr, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w200, color: SmithMkColors.textPrimary, letterSpacing: -1, height: 1, fontFeatures: [FontFeature.tabularFigures()])),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('☀️ ', style: TextStyle(fontSize: 14)),
                Text('${_currentTemp.round()}°', style: const TextStyle(fontSize: 13, color: SmithMkColors.textSecondary)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ─── TWO COLUMN LAYOUT (tablet/desktop) ───
  Widget _buildTwoColumnLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column
        Expanded(
          child: Column(
            children: [
              _buildWeatherCard(),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _buildClimateCard()),
                const SizedBox(width: 12),
                Expanded(child: _buildSecurityCard()),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _buildLightsCard()),
                const SizedBox(width: 12),
                Expanded(child: _buildEVCard()),
              ]),
              const SizedBox(height: 12),
              _buildEnergyCard(),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Right column
        Expanded(
          child: Column(
            children: [
              _buildScenesCard(),
              const SizedBox(height: 12),
              _buildRoomsCard(),
              const SizedBox(height: 12),
              _buildActivityCard(),
            ],
          ),
        ),
      ],
    );
  }

  // ─── SINGLE COLUMN LAYOUT (phone) ───
  Widget _buildSingleColumnLayout() {
    return Column(
      children: [
        _buildWeatherCard(),
        const SizedBox(height: 12),
        _buildScenesCard(),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildClimateCard()),
          const SizedBox(width: 12),
          Expanded(child: _buildSecurityCard()),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildLightsCard()),
          const SizedBox(width: 12),
          Expanded(child: _buildEVCard()),
        ]),
        const SizedBox(height: 12),
        _buildEnergyCard(),
        const SizedBox(height: 12),
        _buildRoomsCard(),
        const SizedBox(height: 12),
        _buildActivityCard(),
      ],
    );
  }

  // ─── CARD WRAPPER ───
  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SmithMkColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SmithMkColors.glassBorder),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SmithMkColors.textTertiary, letterSpacing: 1.5));
  }

  // ─── WEATHER CARD ───
  Widget _buildWeatherCard() {
    final forecast = [
      _Forecast('Sun', '☀️', 29, 16),
      _Forecast('Mon', '🌤️', 30, 15),
      _Forecast('Tue', '🌙', 31, 18),
      _Forecast('Wed', '❄️', 23, 16),
      _Forecast('Thu', '☁️', 17, 14),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('☀️', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_currentTemp.round()}° Clearsky', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: SmithMkColors.textPrimary)),
                  Text('Feels ${_currentTemp.round()}° · 💧 68% · 💨 6 km/h', style: const TextStyle(fontSize: 11, color: SmithMkColors.textTertiary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: forecast.map((f) => Column(
              children: [
                Text(f.day, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: SmithMkColors.textTertiary)),
                const SizedBox(height: 4),
                Text(f.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 4),
                Text('${f.high}°', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SmithMkColors.textPrimary)),
                Text('${f.low}°', style: const TextStyle(fontSize: 10, color: SmithMkColors.textTertiary)),
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ─── CLIMATE CARD with THERMOSTAT DIAL ───
  Color _getTempColour(double temp) {
    final f = (temp - 12) / 18;
    if (f <= 0.3) return Color.lerp(const Color(0xFF48CAE4), const Color(0xFF78D6B0), f / 0.3)!;
    if (f <= 0.55) return Color.lerp(const Color(0xFF78D6B0), const Color(0xFFFFB300), (f - 0.3) / 0.25)!;
    if (f <= 0.78) return Color.lerp(const Color(0xFFFFB300), const Color(0xFFFF8C00), (f - 0.55) / 0.23)!;
    return Color.lerp(const Color(0xFFFF8C00), const Color(0xFFFF5722), (f - 0.78) / 0.22)!;
  }

  Widget _buildClimateCard() {
    final tempCol = _getTempColour(_targetTemp);
    final modeCol = _heatingMode ? SmithMkColors.heatingMode : const Color(0xFF48CAE4);

    return _card(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('CLIMATE'),
              // Heating / Cooling toggle
              Flexible(
                child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _heatingMode = !_heatingMode);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: modeCol.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: modeCol.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_heatingMode ? '🔥' : '❄️', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        _heatingMode ? 'HEATING' : 'COOLING',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: modeCol, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
              ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Syncfusion thermostat dial
          SizedBox(
            height: 180,
            child: SfRadialGauge(
              axes: <RadialAxis>[
                RadialAxis(
                  minimum: 12,
                  maximum: 30,
                  startAngle: 135,
                  endAngle: 45,
                  showLabels: true,
                  showTicks: true,
                  labelOffset: 18,
                  interval: 3,
                  axisLabelStyle: const GaugeTextStyle(fontSize: 8, color: Color(0xFF707070), fontWeight: FontWeight.w500),
                  axisLineStyle: const AxisLineStyle(thickness: 6, color: Color(0xFF1A1A1A), cornerStyle: CornerStyle.bothCurve),
                  majorTickStyle: const MajorTickStyle(length: 8, thickness: 1.2, color: Color(0xFF333333)),
                  minorTickStyle: const MinorTickStyle(length: 4, thickness: 0.6, color: Color(0xFF222222)),
                  minorTicksPerInterval: 5,
                  ranges: <GaugeRange>[
                    GaugeRange(
                      startValue: 12,
                      endValue: _targetTemp,
                      startWidth: 6,
                      endWidth: 6,
                      gradient: const SweepGradient(
                        colors: <Color>[Color(0xFF48CAE4), Color(0xFF78D6B0), Color(0xFFFFB300), Color(0xFFFF8C00), Color(0xFFFF5722)],
                        stops: <double>[0.0, 0.3, 0.55, 0.78, 1.0],
                      ),
                    ),
                  ],
                  pointers: <GaugePointer>[
                    MarkerPointer(
                      value: _targetTemp,
                      markerType: MarkerType.circle,
                      markerWidth: 16,
                      markerHeight: 16,
                      color: tempCol,
                      borderColor: const Color(0xFFEEEEEE),
                      borderWidth: 2.5,
                      enableDragging: true,
                      onValueChanged: (value) {
                        final snapped = (value * 2).round() / 2;
                        if (snapped != _targetTemp) HapticFeedback.selectionClick();
                        setState(() => _targetTemp = snapped.clamp(12, 30));
                      },
                    ),
                  ],
                  annotations: <GaugeAnnotation>[
                    GaugeAnnotation(
                      widget: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${_targetTemp.toStringAsFixed(1)}°', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w200, color: Color(0xFFEEEEEE), height: 1)),
                          const SizedBox(height: 2),
                          Text('Currently ${_currentTemp}°', style: const TextStyle(fontSize: 10, color: Color(0xFF707070))),
                        ],
                      ),
                      angle: 90,
                      positionFactor: 0.0,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // +/- and power row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _tapButton('−', () { HapticFeedback.selectionClick(); setState(() => _targetTemp = (_targetTemp - 0.5).clamp(12, 30)); }),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () { HapticFeedback.mediumImpact(); setState(() => _heatingOn = !_heatingOn); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _heatingOn ? modeCol.withValues(alpha: 0.15) : SmithMkColors.cardSurfaceAlt,
                    shape: BoxShape.circle,
                    border: Border.all(color: _heatingOn ? modeCol.withValues(alpha: 0.4) : SmithMkColors.glassBorder),
                  ),
                  child: Icon(Icons.power_settings_new, color: _heatingOn ? modeCol : SmithMkColors.textTertiary, size: 18),
                ),
              ),
              const SizedBox(width: 24),
              _tapButton('+', () { HapticFeedback.selectionClick(); setState(() => _targetTemp = (_targetTemp + 0.5).clamp(12, 30)); }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tapButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: SmithMkColors.cardSurfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(color: SmithMkColors.glassBorder),
        ),
        child: Center(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFB0B0B0)))),
      ),
    );
  }

  // ─── SECURITY CARD ───
  Widget _buildSecurityCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('SECURITY'),
              const Text('🛡️', style: TextStyle(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Disarmed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF4ADE80))),
          const Text('1 open · 10 zones', style: TextStyle(fontSize: 11, color: SmithMkColors.textTertiary)),
        ],
      ),
    );
  }

  // ─── LIGHTS CARD ───
  Widget _buildLightsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('LIGHTS'),
              const Text('💡', style: TextStyle(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('0/4', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: SmithMkColors.textPrimary)),
          const Text('0 rooms active', style: TextStyle(fontSize: 11, color: SmithMkColors.textTertiary)),
        ],
      ),
    );
  }

  // ─── EV CARD ───
  Widget _buildEVCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('EV'),
              const Text('⚡', style: TextStyle(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Disconnected', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: SmithMkColors.textPrimary)),
          const Text('No EV plugged in', style: TextStyle(fontSize: 11, color: SmithMkColors.textTertiary)),
        ],
      ),
    );
  }

  // ─── ENERGY CARD ───
  Widget _buildEnergyCard() {
    final items = [
      _EnergyItem('Solar', '0', 'W'),
      _EnergyItem('Battery', '0', '%'),
      _EnergyItem('Home', '0', 'W'),
      _EnergyItem('EV', '0', 'W'),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('ENERGY'),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((e) => Column(
              children: [
                Text('${e.value}${e.unit}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: SmithMkColors.textPrimary)),
                const SizedBox(height: 4),
                Text(e.label, style: const TextStyle(fontSize: 10, color: SmithMkColors.textTertiary)),
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ─── SCENES CARD ───
  Widget _buildScenesCard() {
    final scenes = [
      _Scene('Morning', '🌅', 0),
      _Scene('Day', '☀️', 1),
      _Scene('Evening', '🏠', 2),
      _Scene('Night', '🌙', 3),
      _Scene('Away', '🏖️', 4),
      _Scene('Movie', '🎬', 5),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('SCENES'),
              const Text('Tap to activate', style: TextStyle(fontSize: 10, color: SmithMkColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: scenes.map((s) {
                final isActive = _activeScene == s.index;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _activeScene = s.index);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive ? SmithMkColors.accent.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive ? SmithMkColors.accent.withValues(alpha: 0.3) : SmithMkColors.glassBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(s.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(s.name, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isActive ? SmithMkColors.accent : SmithMkColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ROOMS CARD with EXPANDABLE LIGHTS ───
  Widget _buildRoomsCard() {
    final rooms = [
      _Room('Master Bedroom', '🛏️', 0, 2),
      _Room('Lounge', '🛋️', 0, 2),
      _Room('Office', '💻', 0, 0),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('ROOMS'),
              const Text('All →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SmithMkColors.accent)),
            ],
          ),
          const SizedBox(height: 10),
          ...rooms.map((r) => _buildRoomRow(r)),
        ],
      ),
    );
  }

  Widget _buildRoomRow(_Room room) {
    final isExpanded = _expandedRoom == room.name;
    final level = _lightLevels[room.name] ?? 0.0;
    final isOn = level > 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _expandedRoom = isExpanded ? null : room.name;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubicEmphasized,
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(isExpanded ? 14 : 10),
        decoration: BoxDecoration(
          color: isExpanded
              ? SmithMkColors.accent.withValues(alpha: 0.06)
              : SmithMkColors.cardSurfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: isExpanded
              ? Border.all(color: SmithMkColors.accent.withValues(alpha: 0.15))
              : null,
        ),
        child: Column(
          children: [
            // Room header row
            Row(
              children: [
                Text(room.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(child: Text(room.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: SmithMkColors.textPrimary))),
                Text('${room.lightsOn}/${room.lightsTotal}', style: const TextStyle(fontSize: 12, color: SmithMkColors.textTertiary)),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _lightLevels[room.name] = isOn ? 0.0 : 0.75;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOn ? SmithMkColors.accent.withValues(alpha: 0.15) : SmithMkColors.inactive.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                      border: isOn ? Border.all(color: SmithMkColors.accent.withValues(alpha: 0.3)) : null,
                    ),
                    child: Text(isOn ? 'ON' : 'OFF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isOn ? SmithMkColors.accent : SmithMkColors.textTertiary)),
                  ),
                ),
              ],
            ),
            // Expanded dimmer slider
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: SizedBox(
                  height: 160,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Vertical dimmer slider — matching lighting page
                      GestureDetector(
                        onVerticalDragUpdate: (d) {
                          final frac = 1 - (d.localPosition.dy / 160);
                          final clamped = frac.clamp(0.0, 1.0);
                          final rounded = (clamped * 100).round() / 100;
                          if ((rounded * 4).round() != (level * 4).round()) {
                            if (rounded == 0 || rounded == 1) {
                              HapticFeedback.mediumImpact();
                            } else {
                              HapticFeedback.selectionClick();
                            }
                          }
                          setState(() => _lightLevels[room.name] = rounded);
                        },
                        child: SizedBox(
                          width: 52,
                          height: 160,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.bottomCenter,
                            children: [
                              // Track
                              Container(
                                width: 36, height: 160,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161616),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 6, offset: const Offset(0, 2)),
                                  ],
                                ),
                              ),
                              // Fill — starts dim amber, gets brighter
                              Positioned(
                                bottom: 0,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 60),
                                  width: 36,
                                  height: (160 * level).clamp(0.0, 160.0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        SmithMkColors.accent.withValues(alpha: 0.15 + level * 0.15),
                                        SmithMkColors.accent.withValues(alpha: 0.3 + level * 0.55),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Thumb — clamped, never disappears
                              Positioned(
                                bottom: (138 * level).clamp(0.0, 138.0),
                                child: Container(
                                  width: 44, height: 22,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(11),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: isOn
                                          ? [const Color(0xFF4A3800), const Color(0xFF332600)]
                                          : [const Color(0xFF3A3A3A), const Color(0xFF222222)],
                                    ),
                                    border: Border.all(color: isOn ? SmithMkColors.accent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1)),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 6, offset: const Offset(0, 3)),
                                      if (isOn) BoxShadow(color: SmithMkColors.accent.withValues(alpha: 0.1), blurRadius: 10),
                                    ],
                                  ),
                                  child: Center(
                                    child: Container(width: 18, height: 2, decoration: BoxDecoration(borderRadius: BorderRadius.circular(1), color: isOn ? SmithMkColors.accent.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.15))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Info + presets
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${(level * 100).round()}%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: isOn ? SmithMkColors.accent : SmithMkColors.textTertiary)),
                            const Text('Brightness', style: TextStyle(fontSize: 10, color: SmithMkColors.textTertiary)),
                            const Spacer(),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [25, 50, 75, 100].map((p) => GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _lightLevels[room.name] = p / 100);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: (level * 100).round() == p ? SmithMkColors.accent.withValues(alpha: 0.15) : SmithMkColors.cardSurface,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: (level * 100).round() == p ? SmithMkColors.accent.withValues(alpha: 0.3) : SmithMkColors.glassBorder),
                                  ),
                                  child: Text('$p%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: (level * 100).round() == p ? SmithMkColors.accent : SmithMkColors.textTertiary)),
                                ),
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ACTIVITY CARD ───
  Widget _buildActivityCard() {
    final events = [
      _ActivityEvent('💡', 'Entrance 2 → off', '11:28'),
      _ActivityEvent('💡', 'Alfresco → off', '11:19'),
      _ActivityEvent('💡', 'Entrance 2 → off', '11:16'),
      _ActivityEvent('💡', 'Entrance 1 → off', '11:16'),
      _ActivityEvent('💡', 'Alfresco → off', '11:14'),
      _ActivityEvent('💡', 'Entrance 1 → off', '11:13'),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('ACTIVITY'),
          const SizedBox(height: 12),
          ...events.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                // Timeline dot
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: SmithMkColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: SmithMkColors.accent.withValues(alpha: 0.3), blurRadius: 4)],
                  ),
                ),
                const SizedBox(width: 12),
                Text(e.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(child: Text(e.description, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: SmithMkColors.textPrimary))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: SmithMkColors.cardSurfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(e.time, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: SmithMkColors.textTertiary, fontFeatures: [FontFeature.tabularFigures()])),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ─── DATA MODELS ───
class _Forecast {
  final String day, emoji;
  final int high, low;
  const _Forecast(this.day, this.emoji, this.high, this.low);
}

class _EnergyItem {
  final String label, value, unit;
  const _EnergyItem(this.label, this.value, this.unit);
}

class _Scene {
  final String name, emoji;
  final int index;
  const _Scene(this.name, this.emoji, this.index);
}

class _Room {
  final String name, emoji;
  final int lightsOn, lightsTotal;
  const _Room(this.name, this.emoji, this.lightsOn, this.lightsTotal);
}

class _ActivityEvent {
  final String emoji, description, time;
  const _ActivityEvent(this.emoji, this.description, this.time);
}
