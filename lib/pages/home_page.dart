import 'package:flutter/material.dart';
import '../theme/smithmk_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/status_tile.dart';
import '../widgets/scene_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0A14),
              Color(0xFF0F1020),
              Color(0xFF0A0F18),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildHeader(context),
                const SizedBox(height: 24),
                _buildStatusBar(context),
                const SizedBox(height: 28),
                _buildScenesRow(context),
                const SizedBox(height: 28),
                _buildSectionTitle('Rooms'),
                const SizedBox(height: 12),
                _buildRoomsGrid(context),
                const SizedBox(height: 28),
                _buildSectionTitle('Quick Controls'),
                const SizedBox(height: 12),
                _buildQuickControls(context),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SmithMk',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: SmithMkColors.accentWarm,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Smart Home Hub',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SmithMkColors.textTertiary,
                    letterSpacing: 0.5,
                  ),
            ),
          ],
        ),
        // Temperature display
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          borderRadius: 14,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.thermostat, color: SmithMkColors.accentWarm, size: 20),
              const SizedBox(width: 8),
              Text(
                '22.4°',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w300,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      borderRadius: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusItem(Icons.shield_outlined, 'Armed', SmithMkColors.success),
          _buildStatusDivider(),
          _buildStatusItem(Icons.lock_outlined, 'Locked', SmithMkColors.success),
          _buildStatusDivider(),
          _buildStatusItem(Icons.lightbulb_outlined, '4 On', SmithMkColors.lightOn),
          _buildStatusDivider(),
          _buildStatusItem(Icons.solar_power_outlined, '3.2kW', SmithMkColors.accentWarm),
        ],
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDivider() {
    return Container(
      width: 1,
      height: 30,
      color: SmithMkColors.glassBorder,
    );
  }

  Widget _buildScenesRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          SceneCard(
            icon: Icons.wb_sunny_outlined,
            label: 'Morning',
            color: SmithMkColors.accentWarm,
            onTap: () {},
          ),
          SceneCard(
            icon: Icons.movie_outlined,
            label: 'Movie',
            color: SmithMkColors.accentPurple,
            onTap: () {},
          ),
          SceneCard(
            icon: Icons.bedtime_outlined,
            label: 'Good Night',
            color: SmithMkColors.accentPrimary,
            onTap: () {},
          ),
          SceneCard(
            icon: Icons.directions_car_outlined,
            label: 'Away',
            color: SmithMkColors.error,
            onTap: () {},
          ),
          SceneCard(
            icon: Icons.home_outlined,
            label: 'Welcome',
            color: SmithMkColors.success,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: SmithMkColors.textTertiary,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildRoomsGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        StatusTile(
          icon: Icons.weekend_outlined,
          label: 'Living Room',
          value: '3 lights on',
          isActive: true,
          activeColor: SmithMkColors.lightOn,
          onTap: () {},
        ),
        StatusTile(
          icon: Icons.bed_outlined,
          label: 'Bedroom',
          value: 'All off',
          isActive: false,
          onTap: () {},
        ),
        StatusTile(
          icon: Icons.kitchen_outlined,
          label: 'Kitchen',
          value: '1 light on',
          isActive: true,
          activeColor: SmithMkColors.lightOn,
          onTap: () {},
        ),
        StatusTile(
          icon: Icons.garage_outlined,
          label: 'Garage',
          value: 'Closed',
          isActive: false,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildQuickControls(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        StatusTile(
          icon: Icons.thermostat,
          label: 'Climate',
          value: '22.4° → 22°',
          isActive: true,
          activeColor: SmithMkColors.heatingActive,
          onTap: () {},
        ),
        StatusTile(
          icon: Icons.blinds_outlined,
          label: 'Blinds',
          value: '2 open',
          isActive: true,
          activeColor: SmithMkColors.blindOpen,
          onTap: () {},
        ),
        StatusTile(
          icon: Icons.music_note_outlined,
          label: 'Media',
          value: 'Kitchen Echo',
          isActive: true,
          activeColor: SmithMkColors.accentPrimary,
          onTap: () {},
        ),
        StatusTile(
          icon: Icons.bolt_outlined,
          label: 'Energy',
          value: '3.2kW Solar',
          isActive: true,
          activeColor: SmithMkColors.accentWarm,
          onTap: () {},
        ),
      ],
    );
  }
}
