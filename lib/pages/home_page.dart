import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          borderRadius: 14,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.thermometerSimple(PhosphorIconsStyle.light), color: SmithMkColors.accentWarm, size: 20),
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
          _buildStatusItem(PhosphorIcons.shieldCheck(PhosphorIconsStyle.light), 'Armed', SmithMkColors.success),
          _buildStatusDivider(),
          _buildStatusItem(PhosphorIcons.lockSimple(PhosphorIconsStyle.light), 'Locked', SmithMkColors.success),
          _buildStatusDivider(),
          _buildStatusItem(PhosphorIcons.lightbulb(PhosphorIconsStyle.light), '4 On', SmithMkColors.lightOn),
          _buildStatusDivider(),
          _buildStatusItem(PhosphorIcons.sunDim(PhosphorIconsStyle.light), '3.2kW', SmithMkColors.accentWarm),
        ],
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
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
            icon: PhosphorIcons.sun(PhosphorIconsStyle.light),
            label: 'Morning',
            color: SmithMkColors.accentWarm,
            onTap: () {},
          ),
          SceneCard(
            icon: PhosphorIcons.filmSlate(PhosphorIconsStyle.light),
            label: 'Movie',
            color: SmithMkColors.accentPurple,
            onTap: () {},
          ),
          SceneCard(
            icon: PhosphorIcons.moonStars(PhosphorIconsStyle.light),
            label: 'Good Night',
            color: SmithMkColors.accentPrimary,
            onTap: () {},
          ),
          SceneCard(
            icon: PhosphorIcons.signOut(PhosphorIconsStyle.light),
            label: 'Away',
            color: SmithMkColors.error,
            onTap: () {},
          ),
          SceneCard(
            icon: PhosphorIcons.house(PhosphorIconsStyle.light),
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
          icon: PhosphorIcons.armchair(PhosphorIconsStyle.light),
          label: 'Living Room',
          value: '3 lights on',
          isActive: true,
          activeColor: SmithMkColors.lightOn,
          onTap: () {},
        ),
        StatusTile(
          icon: PhosphorIcons.bed(PhosphorIconsStyle.light),
          label: 'Bedroom',
          value: 'All off',
          isActive: false,
          onTap: () {},
        ),
        StatusTile(
          icon: PhosphorIcons.cookingPot(PhosphorIconsStyle.light),
          label: 'Kitchen',
          value: '1 light on',
          isActive: true,
          activeColor: SmithMkColors.lightOn,
          onTap: () {},
        ),
        StatusTile(
          icon: PhosphorIcons.garage(PhosphorIconsStyle.light),
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
          icon: PhosphorIcons.thermometerSimple(PhosphorIconsStyle.light),
          label: 'Climate',
          value: '22.4° → 22°',
          isActive: true,
          activeColor: SmithMkColors.heatingActive,
          onTap: () {},
        ),
        StatusTile(
          icon: PhosphorIcons.blinds(PhosphorIconsStyle.light),
          label: 'Blinds',
          value: '2 open',
          isActive: true,
          activeColor: SmithMkColors.blindOpen,
          onTap: () {},
        ),
        StatusTile(
          icon: PhosphorIcons.musicNotes(PhosphorIconsStyle.light),
          label: 'Media',
          value: 'Kitchen Echo',
          isActive: true,
          activeColor: SmithMkColors.accentPrimary,
          onTap: () {},
        ),
        StatusTile(
          icon: PhosphorIcons.lightning(PhosphorIconsStyle.light),
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
