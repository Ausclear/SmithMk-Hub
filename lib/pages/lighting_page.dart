import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/smithmk_theme.dart';
import '../widgets/glass_card.dart';

class LightingPage extends StatefulWidget {
  const LightingPage({super.key});

  @override
  State<LightingPage> createState() => _LightingPageState();
}

class _LightingPageState extends State<LightingPage> {
  final List<_LightData> _lights = [
    _LightData('Bedroom Downlights', 0.75, true),
    _LightData('Reading Light', 0.0, false),
    _LightData('Bedside Lamp', 0.40, true),
    _LightData('Kitchen Spots', 0.60, true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmithMkColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LIGHTING', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SmithMkColors.textTertiary, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  const Text('Bedroom', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: SmithMkColors.textPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                itemCount: _lights.length,
                itemBuilder: (ctx, i) => _buildLightCard(i),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLightCard(int index) {
    final light = _lights[index];
    final col = light.on ? SmithMkColors.accent : SmithMkColors.inactive;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SmithMkColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SmithMkColors.glassBorder),
      ),
      child: Column(
        children: [
          // Header: icon + name + percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Light icon with glow
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: light.on
                          ? SmithMkColors.accent.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: light.on
                          ? [BoxShadow(color: SmithMkColors.accent.withValues(alpha: 0.1), blurRadius: 12)]
                          : null,
                    ),
                    child: Icon(
                      PhosphorIcons.lightbulb(light.on ? PhosphorIconsStyle.fill : PhosphorIconsStyle.light),
                      color: col, size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(light.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: SmithMkColors.textPrimary)),
                ],
              ),
              Text(
                light.on ? '${(light.brightness * 100).round()}%' : 'Off',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: col),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Body: vertical slider + controls
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Vertical slider
                _VerticalDimmerSlider(
                  value: light.brightness,
                  isOn: light.on,
                  onChanged: (v) {
                    setState(() {
                      light.brightness = v;
                      light.on = v > 0;
                    });
                  },
                ),
                const SizedBox(width: 18),
                // Controls column
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Toggle switch
                      Row(
                        children: [
                          const Text('Power', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SmithMkColors.textTertiary, letterSpacing: 0.5)),
                          const SizedBox(width: 12),
                          _ToggleSwitch(
                            value: light.on,
                            onChanged: (v) {
                              HapticFeedback.lightImpact();
                              setState(() {
                                light.on = v;
                                if (v && light.brightness == 0) light.brightness = 0.75;
                                if (!v) light.brightness = 0;
                              });
                            },
                          ),
                        ],
                      ),
                      // +/- buttons
                      Row(
                        children: [
                          Expanded(child: _PremiumButton(label: '−', onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              light.brightness = (light.brightness - 0.05).clamp(0.0, 1.0);
                              light.on = light.brightness > 0;
                            });
                          })),
                          const SizedBox(width: 8),
                          Expanded(child: _PremiumButton(label: '+', onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              light.brightness = (light.brightness + 0.05).clamp(0.0, 1.0);
                              light.on = light.brightness > 0;
                            });
                          })),
                        ],
                      ),
                      // Preset buttons
                      Row(
                        children: [
                          for (final pct in [25, 50, 75, 100]) ...[
                            if (pct > 25) const SizedBox(width: 6),
                            Expanded(child: _PremiumButton(
                              label: '$pct%',
                              small: true,
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                setState(() {
                                  light.brightness = pct / 100;
                                  light.on = true;
                                });
                              },
                            )),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── VERTICAL DIMMER SLIDER ───
class _VerticalDimmerSlider extends StatefulWidget {
  final double value;
  final bool isOn;
  final ValueChanged<double> onChanged;

  const _VerticalDimmerSlider({
    required this.value,
    required this.isOn,
    required this.onChanged,
  });

  @override
  State<_VerticalDimmerSlider> createState() => _VerticalDimmerSliderState();
}

class _VerticalDimmerSliderState extends State<_VerticalDimmerSlider> {
  int _lastDetent = -1;

  void _handleDrag(Offset localPosition, double height) {
    final frac = 1 - (localPosition.dy / height);
    final clamped = frac.clamp(0.0, 1.0);
    final rounded = (clamped * 100).round() / 100;

    // Haptic detent points
    final detent = (rounded * 4).round(); // 0, 25, 50, 75, 100
    if (detent != _lastDetent) {
      if (rounded == 0 || rounded == 1) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
      _lastDetent = detent;
    }

    widget.onChanged(rounded);
  }

  @override
  Widget build(BuildContext context) {
    final fillPct = widget.isOn ? widget.value : 0.0;
    final alpha = 0.3 + fillPct * 0.55;

    return GestureDetector(
      onVerticalDragStart: (d) => _handleDrag(d.localPosition, 180),
      onVerticalDragUpdate: (d) => _handleDrag(d.localPosition, 180),
      child: SizedBox(
        width: 52,
        height: 180,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Track — recessed
            Container(
              width: 36,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 6, offset: const Offset(0, 2)),
                  const BoxShadow(color: Color(0xFF0A0A0A), blurRadius: 4, spreadRadius: -2),
                ],
              ),
            ),
            // Fill — starts dim amber, gets brighter as it rises
            Positioned(
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 60),
                width: 36,
                height: (180 * fillPct).clamp(0.0, 180.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      SmithMkColors.accent.withValues(alpha: 0.15 + fillPct * 0.15),
                      SmithMkColors.accent.withValues(alpha: 0.3 + fillPct * 0.55),
                    ],
                  ),
                ),
              ),
            ),
            // Thumb — clamped so it never disappears
            Positioned(
              bottom: (158 * fillPct).clamp(0.0, 158.0),
              child: Container(
                width: 44, height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: widget.isOn
                        ? [const Color(0xFF4A3800), const Color(0xFF332600)]
                        : [const Color(0xFF3A3A3A), const Color(0xFF222222)],
                  ),
                  border: Border.all(
                    color: widget.isOn
                        ? SmithMkColors.accent.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 6, offset: const Offset(0, 3)),
                    if (widget.isOn)
                      BoxShadow(color: SmithMkColors.accent.withValues(alpha: 0.1), blurRadius: 10),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 18, height: 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      color: widget.isOn
                          ? SmithMkColors.accent.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 3D TOGGLE SWITCH ───
class _ToggleSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleSwitch({required this.value, required this.onChanged});

  @override
  State<_ToggleSwitch> createState() => _ToggleSwitchState();
}

class _ToggleSwitchState extends State<_ToggleSwitch> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _position = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    if (widget.value) _controller.value = 1;
  }

  @override
  void didUpdateWidget(_ToggleSwitch old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      child: AnimatedBuilder(
        animation: _position,
        builder: (ctx, _) {
          final t = _position.value;
          final trackColor = Color.lerp(
            const Color(0xFF1A1A1A),
            const Color(0xFF3D3000),
            t,
          )!;
          final borderColor = Color.lerp(
            Colors.white.withValues(alpha: 0.08),
            SmithMkColors.accent.withValues(alpha: 0.35),
            t,
          )!;
          final knobColor = Color.lerp(
            const Color(0xFF3A3A3A),
            SmithMkColors.accent,
            t,
          )!;
          final knobLeft = 2 + t * 26;

          return Container(
            width: 56, height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: trackColor,
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 4, offset: const Offset(0, 2)),
                if (t > 0.5) BoxShadow(color: SmithMkColors.accent.withValues(alpha: 0.08), blurRadius: 10),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: knobLeft, top: 2,
                  child: Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: knobColor,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(0, 2)),
                        if (t > 0.5) BoxShadow(color: SmithMkColors.accent.withValues(alpha: 0.2), blurRadius: 8),
                      ],
                    ),
                    child: Align(
                      alignment: const Alignment(0, -0.4),
                      child: Container(
                        width: 10, height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: Colors.white.withValues(alpha: 0.1 + t * 0.15),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── 3D PREMIUM BUTTON ───
class _PremiumButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool small;

  const _PremiumButton({required this.label, required this.onTap, this.small = false});

  @override
  State<_PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<_PremiumButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: widget.small ? 34 : 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.small ? 8 : 10),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _pressed
                ? [const Color(0xFF1A1A1A), const Color(0xFF222222)]
                : [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: _pressed
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 2, offset: const Offset(0, 1))]
              : [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 6, offset: const Offset(0, 3)),
                  BoxShadow(color: Colors.white.withValues(alpha: 0.04), blurRadius: 0, offset: const Offset(0, -1)),
                ],
        ),
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: widget.small ? 11 : 13,
              fontWeight: FontWeight.w600,
              color: SmithMkColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── DATA MODEL ───
class _LightData {
  String name;
  double brightness; // 0.0 to 1.0
  bool on;
  _LightData(this.name, this.brightness, this.on);
}
