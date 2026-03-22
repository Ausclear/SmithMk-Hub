import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/smithmk_theme.dart';
import '../pages/home_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/lighting_page.dart';
import '../pages/placeholder_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const DashboardPage(),
    const LightingPage(),
    PlaceholderPage(title: 'Media', icon: PhosphorIcons.musicNotes(PhosphorIconsStyle.light)),
    PlaceholderPage(title: 'Settings', icon: PhosphorIcons.gear(PhosphorIconsStyle.light)),
  ];

  final List<_NavItem> _navItems = [
    _NavItem('Home', PhosphorIcons.house(PhosphorIconsStyle.light), PhosphorIcons.house(PhosphorIconsStyle.fill)),
    _NavItem('Dashboard', PhosphorIcons.squaresFour(PhosphorIconsStyle.light), PhosphorIcons.squaresFour(PhosphorIconsStyle.fill)),
    _NavItem('Lights', PhosphorIcons.lightbulb(PhosphorIconsStyle.light), PhosphorIcons.lightbulb(PhosphorIconsStyle.fill)),
    _NavItem('Media', PhosphorIcons.musicNotes(PhosphorIconsStyle.light), PhosphorIcons.musicNotes(PhosphorIconsStyle.fill)),
    _NavItem('Settings', PhosphorIcons.gear(PhosphorIconsStyle.light), PhosphorIcons.gear(PhosphorIconsStyle.fill)),
  ];

  void _onNavTap(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final useSideNav = isWide || isLandscape;

        if (useSideNav) {
          return _buildSideNavLayout();
        } else {
          return _buildBottomNavLayout();
        }
      },
    );
  }

  // ─── BOTTOM NAV (portrait phone/small tablet) ───
  Widget _buildBottomNavLayout() {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: SmithMkColors.cardSurface,
          border: Border(top: BorderSide(color: SmithMkColors.glassBorder, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (i) => _buildBottomNavItem(i)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index) {
    final item = _navItems[index];
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onNavTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? SmithMkColors.accent.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isActive ? item.activeIcon : item.icon,
                color: isActive ? SmithMkColors.accent : SmithMkColors.textTertiary,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? SmithMkColors.accent : SmithMkColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SIDE NAV (landscape / tablet / desktop) ───
  Widget _buildSideNavLayout() {
    return Scaffold(
      body: Row(
        children: [
          // Side rail
          Container(
            width: 72,
            decoration: BoxDecoration(
              color: SmithMkColors.cardSurface,
              border: Border(right: BorderSide(color: SmithMkColors.glassBorder, width: 0.5)),
            ),
            child: SafeArea(
              right: false,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // SmithMk logo/brand mark
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: SmithMkColors.accent.withValues(alpha: 0.1),
                    ),
                    child: const Center(
                      child: Text('S', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: SmithMkColors.gold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Nav items
                  ...List.generate(_navItems.length, (i) => _buildSideNavItem(i)),
                  const Spacer(),
                ],
              ),
            ),
          ),
          // Page content
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _pages),
          ),
        ],
      ),
    );
  }

  Widget _buildSideNavItem(int index) {
    final item = _navItems[index];
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onNavTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 32,
              decoration: BoxDecoration(
                color: isActive ? SmithMkColors.accent.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isActive ? item.activeIcon : item.icon,
                color: isActive ? SmithMkColors.accent : SmithMkColors.textTertiary,
                size: 20,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? SmithMkColors.accent : SmithMkColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem(this.label, this.icon, this.activeIcon);
}
