import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/smithmk_theme.dart';
import '../pages/home_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/lighting_page.dart';
import '../pages/placeholder_page.dart';
import '../pages/rooms_page.dart';
import '../pages/music_page.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int? _currentPage; // null = home launcher

  final List<_NavPage> _pages = [
    _NavPage('Home', PhosphorIcons.house(PhosphorIconsStyle.light), PhosphorIcons.house(PhosphorIconsStyle.fill)),
    _NavPage('Dashboard', PhosphorIcons.squaresFour(PhosphorIconsStyle.light), PhosphorIcons.squaresFour(PhosphorIconsStyle.fill)),
    _NavPage('Rooms', PhosphorIcons.door(PhosphorIconsStyle.light), PhosphorIcons.door(PhosphorIconsStyle.fill)),
    _NavPage('Lights', PhosphorIcons.lightbulb(PhosphorIconsStyle.light), PhosphorIcons.lightbulb(PhosphorIconsStyle.fill)),
    _NavPage('Power', PhosphorIcons.plug(PhosphorIconsStyle.light), PhosphorIcons.plug(PhosphorIconsStyle.fill)),
    _NavPage('Blinds', PhosphorIcons.slidersHorizontal(PhosphorIconsStyle.light), PhosphorIcons.slidersHorizontal(PhosphorIconsStyle.fill)),
    _NavPage('Climate', PhosphorIcons.thermometerSimple(PhosphorIconsStyle.light), PhosphorIcons.thermometerSimple(PhosphorIconsStyle.fill)),
    _NavPage('Security', PhosphorIcons.shieldCheck(PhosphorIconsStyle.light), PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill)),
    _NavPage('Energy', PhosphorIcons.lightning(PhosphorIconsStyle.light), PhosphorIcons.lightning(PhosphorIconsStyle.fill)),
    _NavPage('Media', PhosphorIcons.musicNotes(PhosphorIconsStyle.light), PhosphorIcons.musicNotes(PhosphorIconsStyle.fill)),
    _NavPage('Irrigation', PhosphorIcons.drop(PhosphorIconsStyle.light), PhosphorIcons.drop(PhosphorIconsStyle.fill)),
    _NavPage('Settings', PhosphorIcons.gear(PhosphorIconsStyle.light), PhosphorIcons.gear(PhosphorIconsStyle.fill)),
  ];

  List<Widget> get _pageWidgets => [
    const DashboardPage(),
    const RoomsPage(),
    const LightingPage(),
    PlaceholderPage(title: 'Power', icon: PhosphorIcons.plug(PhosphorIconsStyle.light)),
    PlaceholderPage(title: 'Blinds', icon: PhosphorIcons.slidersHorizontal(PhosphorIconsStyle.light)),
    PlaceholderPage(title: 'Climate', icon: PhosphorIcons.thermometerSimple(PhosphorIconsStyle.light)),
    PlaceholderPage(title: 'Security', icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.light)),
    PlaceholderPage(title: 'Energy', icon: PhosphorIcons.lightning(PhosphorIconsStyle.light)),
    const MusicPage(), // Media → Music page (TV page separate later)
    PlaceholderPage(title: 'Irrigation', icon: PhosphorIcons.drop(PhosphorIconsStyle.light)),
    PlaceholderPage(title: 'Settings', icon: PhosphorIcons.gear(PhosphorIconsStyle.light)),
  ];

  void _goHome() {
    HapticFeedback.lightImpact();
    setState(() => _currentPage = null);
  }

  void _goToPage(int index) {
    HapticFeedback.selectionClick();
    setState(() => _currentPage = index);
  }

  void navigateToTile(String tileName) {
    final map = {
      'Dashboard': 0, 'Rooms': 1, 'Lights': 2, 'Power': 3,
      'Blinds': 4, 'Climate': 5, 'Security': 6, 'Energy': 7,
      'Media': 8, 'Irrigation': 9, 'Settings': 10,
    };
    final idx = map[tileName];
    if (idx != null) _goToPage(idx);
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPage == null) {
      return HomePage(onTileTap: navigateToTile);
    }

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

  // ─── SIDEBAR (matches PWA) ───
  Widget _buildSideNavLayout() {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 200,
            decoration: BoxDecoration(
              color: SmithMkColors.cardSurface,
              border: Border(right: BorderSide(color: SmithMkColors.glassBorder, width: 0.5)),
            ),
            child: SafeArea(
              right: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo header — matches PWA
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Row(
                      children: [
                        // House emoji as logo
                        Icon(PhosphorIcons.house(PhosphorIconsStyle.fill), size: 26, color: SmithMkColors.gold),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SmithMk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SmithMkColors.textPrimary)),
                            Text('Smart Home', style: TextStyle(fontSize: 11, color: SmithMkColors.gold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Nav items — scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: List.generate(_pages.length, (i) {
                          if (i == 0) {
                            return _buildSideNavItem(i, _pages[i], _currentPage == null);
                          }
                          return _buildSideNavItem(i, _pages[i], _currentPage == i - 1);
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(index: _currentPage!, children: _pageWidgets),
          ),
        ],
      ),
    );
  }

  Widget _buildSideNavItem(int index, _NavPage page, bool isActive) {
    return GestureDetector(
      onTap: () {
        if (index == 0) {
          _goHome();
        } else {
          _goToPage(index - 1);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? SmithMkColors.accent.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(isActive ? page.activeIcon : page.icon, size: 20, color: isActive ? SmithMkColors.accent : SmithMkColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                page.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? SmithMkColors.textPrimary : SmithMkColors.textSecondary,
                ),
              ),
            ),
            if (isActive)
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: SmithMkColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: SmithMkColors.accent.withValues(alpha: 0.4), blurRadius: 4)],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── BOTTOM NAV (portrait phone) ───
  Widget _buildBottomNavLayout() {
    // Show max 5 items in bottom nav — Home + 4 most used
    final bottomItems = [
      _pages[0], // Home
      _pages[1], // Dashboard
      _pages[3], // Lights
      _pages[9], // Media
      _pages[11], // Settings
    ];

    return Scaffold(
      body: IndexedStack(index: _currentPage!, children: _pageWidgets),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: SmithMkColors.cardSurface,
          border: Border(top: BorderSide(color: SmithMkColors.glassBorder, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: bottomItems.asMap().entries.map((entry) {
                final i = entry.key;
                final page = entry.value;
                final isActive = (i == 0 && _currentPage == null) ||
                    (i == 1 && _currentPage == 0) ||
                    (i == 2 && _currentPage == 2) ||
                    (i == 3 && _currentPage == 8) ||
                    (i == 4 && _currentPage == 10);

                return GestureDetector(
                  onTap: () {
                    if (i == 0) _goHome();
                    else if (i == 1) _goToPage(0);
                    else if (i == 2) _goToPage(2);
                    else if (i == 3) _goToPage(8);
                    else if (i == 4) _goToPage(10);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 60,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isActive ? page.activeIcon : page.icon, size: isActive ? 22 : 20, color: isActive ? SmithMkColors.accent : SmithMkColors.textTertiary),
                        const SizedBox(height: 2),
                        Text(page.label, style: TextStyle(
                          fontSize: 9,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                          color: isActive ? SmithMkColors.accent : SmithMkColors.textTertiary,
                        )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavPage {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavPage(this.label, this.icon, this.activeIcon);
}
