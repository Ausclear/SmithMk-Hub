import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/smithmk_theme.dart';

class HomePage extends StatefulWidget {
  final void Function(String tileName) onTileTap;

  const HomePage({super.key, required this.onTileTap});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  static final List<_HomeTile> _tiles = [
    _HomeTile('Dashboard', '📊'),
    _HomeTile('Lights', '💡'),
    _HomeTile('Security', '🛡️'),
    _HomeTile('Climate', '🌡️'),
    _HomeTile('Blinds', '🪟'),
    _HomeTile('Energy', '⚡'),
    _HomeTile('Media', '🎵'),
    _HomeTile('Rooms', '🚪'),
    _HomeTile('Power', '🔌'),
    _HomeTile('Irrigation', '🌿'),
    _HomeTile('Settings', '⚙️'),
  ];

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

  String get _timeStr =>
      '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

  String get _dateStr {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return '${days[_now.weekday - 1]} ${_now.day} ${months[_now.month - 1]}';
  }

  Widget _buildEmoji(String emoji, double size) {
    return Text(emoji, style: TextStyle(fontSize: size * 0.85));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmithMkColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 14),
              _buildConnectionPills(),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _buildTileGrid(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SMITHMK HOME',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SmithMkColors.gold, letterSpacing: 3),
            ),
            const SizedBox(height: 2),
            Text(_dateStr, style: const TextStyle(fontSize: 12, color: SmithMkColors.textTertiary)),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _timeStr,
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w200, color: SmithMkColors.textPrimary, letterSpacing: -2, height: 1),
            ),
            const SizedBox(height: 4),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('☁ ', style: TextStyle(fontSize: 13)),
                Text('14°C  Partly cloudy', style: TextStyle(fontSize: 12, color: SmithMkColors.textSecondary)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectionPills() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _pill('HA', SmithMkColors.error),
        _pill('SUPABASE', SmithMkColors.success),
        _pill('SOLAR', SmithMkColors.error),
      ],
    );
  }

  Widget _pill(String label, Color statusColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: SmithMkColors.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SmithMkColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: statusColor, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.5), blurRadius: 4)],
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: SmithMkColors.textSecondary, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildTileGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 3;
        const spacing = 14.0;
        final availableWidth = constraints.maxWidth - (spacing * (columns - 1));
        final tileSize = availableWidth / columns;
        final rows = (_tiles.length / columns).ceil();
        final totalHeight = rows * tileSize + (rows - 1) * spacing;

        return SizedBox(
          height: totalHeight.clamp(0.0, constraints.maxHeight),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
            ),
            itemCount: _tiles.length,
            itemBuilder: (ctx, i) => _buildTile(i, tileSize),
          ),
        );
      },
    );
  }

  Widget _buildTile(int index, double tileSize) {
    final tile = _tiles[index];
    final emojiSize = (tileSize * 0.32).clamp(32.0, 56.0);
    final fontSize = (tileSize * 0.08).clamp(9.0, 12.0);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTileTap(tile.name);
      },
      child: Container(
        decoration: BoxDecoration(
          color: SmithMkColors.cardSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SmithMkColors.glassBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6), spreadRadius: -4),
            BoxShadow(color: Colors.white.withValues(alpha: 0.03), blurRadius: 1, offset: const Offset(0, -1)),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: tileSize * 0.3,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withValues(alpha: 0.04), Colors.transparent],
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildEmoji(tile.emoji, emojiSize),
                  SizedBox(height: tileSize * 0.05),
                  Text(
                    tile.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: fontSize, fontWeight: FontWeight.w600,
                      color: SmithMkColors.textSecondary,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTile {
  final String name;
  final String emoji;
  const _HomeTile(this.name, this.emoji);
}
