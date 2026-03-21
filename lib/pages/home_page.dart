import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/smithmk_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();
  int? _selectedTile;

  final List<_HomeTile> _tiles = [
    _HomeTile('Dashboard', PhosphorIcons.chartBar(PhosphorIconsStyle.duotone), SmithMkColors.accentPrimary),
    _HomeTile('Lights', PhosphorIcons.lightbulb(PhosphorIconsStyle.duotone), SmithMkColors.accentPrimary),
    _HomeTile('Security', PhosphorIcons.shieldCheck(PhosphorIconsStyle.duotone), SmithMkColors.error),
    _HomeTile('Climate', PhosphorIcons.thermometerSimple(PhosphorIconsStyle.duotone), SmithMkColors.heatingActive),
    _HomeTile('Blinds', PhosphorIcons.slidersHorizontal(PhosphorIconsStyle.duotone), SmithMkColors.accentPrimary),
    _HomeTile('Energy', PhosphorIcons.lightning(PhosphorIconsStyle.duotone), SmithMkColors.accentPrimary),
    _HomeTile('Media', PhosphorIcons.speakerHigh(PhosphorIconsStyle.duotone), SmithMkColors.accentPrimary),
    _HomeTile('Rooms', PhosphorIcons.door(PhosphorIconsStyle.duotone), SmithMkColors.gold),
    _HomeTile('Settings', PhosphorIcons.gear(PhosphorIconsStyle.duotone), SmithMkColors.textSecondary),
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

  String get _greeting {
    final h = _now.hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _timeStr {
    return '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
  }

  String get _dateStr {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return '${days[_now.weekday - 1]} ${_now.day} ${months[_now.month - 1]}';
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
              Expanded(child: _buildTileGrid()),
              if (_selectedTile != null) _buildSelectedLabel(),
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
            Text(
              'SMITHMK HOME',
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: SmithMkColors.gold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _dateStr,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: SmithMkColors.textTertiary),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _timeStr,
              style: TextStyle(
                fontSize: 42, fontWeight: FontWeight.w200,
                color: SmithMkColors.textPrimary,
                letterSpacing: -2,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('☁ ', style: TextStyle(fontSize: 13)),
                Text(
                  '14°C  Partly cloudy',
                  style: TextStyle(fontSize: 12, color: SmithMkColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectionPills() {
    return Row(
      children: [
        _pill('HA', SmithMkColors.error),
        const SizedBox(width: 8),
        _pill('SUPABASE', SmithMkColors.success),
        const SizedBox(width: 8),
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
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.5), blurRadius: 4)],
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: SmithMkColors.textSecondary, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildTileGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = 3;
        final spacing = 14.0;
        final availableWidth = constraints.maxWidth - (spacing * (cols - 1));
        final tileSize = availableWidth / cols;
        final rows = (_tiles.length / cols).ceil();
        final totalHeight = rows * tileSize + (rows - 1) * spacing;

        return Center(
          child: SizedBox(
            height: totalHeight.clamp(0, constraints.maxHeight),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: 1,
              ),
              itemCount: _tiles.length,
              itemBuilder: (ctx, i) => _buildTile(i),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTile(int index) {
    final tile = _tiles[index];
    final isSelected = _selectedTile == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() => _selectedTile = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: SmithMkColors.cardSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? SmithMkColors.gold.withValues(alpha: 0.5) : SmithMkColors.glassBorder,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            // Main drop shadow for 3D depth
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: -4,
            ),
            // Subtle highlight on top edge
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.03),
              blurRadius: 1,
              offset: const Offset(0, -1),
            ),
            // Selected glow
            if (isSelected)
              BoxShadow(
                color: SmithMkColors.gold.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: -4,
              ),
          ],
        ),
        child: Stack(
          children: [
            // Top shine
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tile.icon, size: 36, color: isSelected ? tile.color : tile.color.withValues(alpha: 0.7)),
                  const SizedBox(height: 10),
                  Text(
                    tile.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? SmithMkColors.textPrimary : SmithMkColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  // Amber underline for selected
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 24, height: 2,
                      decoration: BoxDecoration(
                        color: SmithMkColors.gold,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedLabel() {
    final tile = _tiles[_selectedTile!];
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 3, height: 16, color: SmithMkColors.gold),
                const SizedBox(width: 10),
                Text(
                  tile.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: SmithMkColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 10),
                Container(width: 3, height: 16, color: SmithMkColors.gold),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'TAP TO OPEN',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: SmithMkColors.textTertiary, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTile {
  final String name;
  final IconData icon;
  final Color color;
  const _HomeTile(this.name, this.icon, this.color);
}
