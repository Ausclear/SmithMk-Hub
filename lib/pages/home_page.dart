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
    _HomeTile('Dashboard', PhosphorIcons.chartBar(PhosphorIconsStyle.fill), SmithMkColors.accent),
    _HomeTile('Lights', PhosphorIcons.lightbulbFilament(PhosphorIconsStyle.fill), SmithMkColors.accent),
    _HomeTile('Security', PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill), const Color(0xFFEF5350)),
    _HomeTile('Climate', PhosphorIcons.thermometerSimple(PhosphorIconsStyle.fill), SmithMkColors.heatingMode),
    _HomeTile('Blinds', PhosphorIcons.slidersHorizontal(PhosphorIconsStyle.fill), SmithMkColors.accent),
    _HomeTile('Energy', PhosphorIcons.lightning(PhosphorIconsStyle.fill), SmithMkColors.accent),
    _HomeTile('Media', PhosphorIcons.speakerHigh(PhosphorIconsStyle.fill), SmithMkColors.accent),
    _HomeTile('Rooms', PhosphorIcons.door(PhosphorIconsStyle.fill), SmithMkColors.gold),
    _HomeTile('Settings', PhosphorIcons.gear(PhosphorIconsStyle.fill), SmithMkColors.textSecondary),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SmithMkColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;

            // Three layouts:
            // Phone (< 600px): centred 3-col grid, fills the screen
            // Tablet (600-1000px): centred content, 3-col grid with bigger tiles
            // Desktop (1000px+): two-panel — header/info left, tile grid right

            if (w >= 1000) {
              return _buildDesktopLayout(constraints);
            } else {
              return _buildMobileLayout(constraints);
            }
          },
        ),
      ),
    );
  }

  // ─── MOBILE / TABLET LAYOUT ───
  Widget _buildMobileLayout(BoxConstraints constraints) {
    final w = constraints.maxWidth;
    final isTablet = w >= 600;
    final pad = isTablet ? 32.0 : 20.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pad),
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
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildTileGrid(3),
              ),
            ),
          ),
          if (_selectedTile != null) _buildSelectedLabel(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── DESKTOP LAYOUT ───
  Widget _buildDesktopLayout(BoxConstraints constraints) {
    return Row(
      children: [
        // Left panel — header, status, info
        SizedBox(
          width: 340,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 28, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SMITHMK HOME',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: SmithMkColors.gold, letterSpacing: 4),
                ),
                const SizedBox(height: 4),
                Text(_dateStr, style: const TextStyle(fontSize: 13, color: SmithMkColors.textTertiary)),
                const SizedBox(height: 24),
                Text(
                  _timeStr,
                  style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w200, color: SmithMkColors.textPrimary, letterSpacing: -3, height: 1),
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Text('☁ ', style: TextStyle(fontSize: 16)),
                    Text('14°C  Partly cloudy', style: TextStyle(fontSize: 14, color: SmithMkColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 32),
                _buildConnectionPills(),
                const Spacer(),
                if (_selectedTile != null) ...[
                  _buildSelectedLabel(),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
        // Divider
        Container(width: 1, color: SmithMkColors.glassBorder),
        // Right panel — tile grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _buildTileGrid(3),
              ),
            ),
          ),
        ),
      ],
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

  Widget _buildTileGrid(int columns) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 14.0;
        final availableWidth = constraints.maxWidth - (spacing * (columns - 1));
        final tileSize = availableWidth / columns;
        final rows = (_tiles.length / columns).ceil();
        final totalHeight = rows * tileSize + (rows - 1) * spacing;

        return SizedBox(
          height: totalHeight.clamp(0.0, constraints.maxHeight),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
    final isSelected = _selectedTile == index;
    // Scale icon size relative to tile — bigger tile, bigger icon
    final iconSize = (tileSize * 0.28).clamp(28.0, 48.0);
    final fontSize = (tileSize * 0.08).clamp(9.0, 12.0);

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
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6), spreadRadius: -4),
            BoxShadow(color: Colors.white.withValues(alpha: 0.03), blurRadius: 1, offset: const Offset(0, -1)),
            if (isSelected)
              BoxShadow(color: SmithMkColors.gold.withValues(alpha: 0.15), blurRadius: 20, spreadRadius: -4),
          ],
        ),
        child: Stack(
          children: [
            // Top shine
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
                  Icon(tile.icon, size: iconSize, color: isSelected ? tile.color : tile.color.withValues(alpha: 0.65)),
                  SizedBox(height: tileSize * 0.06),
                  Text(
                    tile.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: fontSize, fontWeight: FontWeight.w600,
                      color: isSelected ? SmithMkColors.textPrimary : SmithMkColors.textSecondary,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isSelected)
                    Container(
                      margin: EdgeInsets.only(top: tileSize * 0.04),
                      width: 20, height: 2,
                      decoration: BoxDecoration(color: SmithMkColors.gold, borderRadius: BorderRadius.circular(1)),
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SmithMkColors.textPrimary, letterSpacing: 2),
                ),
                const SizedBox(width: 10),
                Container(width: 3, height: 16, color: SmithMkColors.gold),
              ],
            ),
            const SizedBox(height: 6),
            const Text('TAP TO OPEN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: SmithMkColors.textTertiary, letterSpacing: 1)),
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
