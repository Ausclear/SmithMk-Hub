import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/smithmk_theme.dart';
import '../pages/home_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/placeholder_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    PlaceholderPage(title: 'Rooms', icon: PhosphorIcons.door(PhosphorIconsStyle.light)),
    PlaceholderPage(title: 'Lighting', icon: PhosphorIcons.lightbulb(PhosphorIconsStyle.light)),
    PlaceholderPage(title: 'Media', icon: PhosphorIcons.musicNotes(PhosphorIconsStyle.light)),
    PlaceholderPage(title: 'Settings', icon: PhosphorIcons.gear(PhosphorIconsStyle.light)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: SmithMkColors.glassBorder, width: 0.5)),
        ),
        child: NavigationBar(
          backgroundColor: SmithMkColors.cardSurface,
          elevation: 0,
          height: 65,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            HapticFeedback.selectionClick();
            setState(() => _currentIndex = index);
          },
          indicatorColor: SmithMkColors.accentPrimary.withValues(alpha: 0.12),
          destinations: [
            NavigationDestination(
              icon: Icon(PhosphorIcons.house(PhosphorIconsStyle.light), color: SmithMkColors.textTertiary, size: 24),
              selectedIcon: Icon(PhosphorIcons.house(PhosphorIconsStyle.fill), color: SmithMkColors.accentPrimary, size: 24),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(PhosphorIcons.door(PhosphorIconsStyle.light), color: SmithMkColors.textTertiary, size: 24),
              selectedIcon: Icon(PhosphorIcons.door(PhosphorIconsStyle.fill), color: SmithMkColors.accentPrimary, size: 24),
              label: 'Rooms',
            ),
            NavigationDestination(
              icon: Icon(PhosphorIcons.lightbulb(PhosphorIconsStyle.light), color: SmithMkColors.textTertiary, size: 24),
              selectedIcon: Icon(PhosphorIcons.lightbulb(PhosphorIconsStyle.fill), color: SmithMkColors.accentPrimary, size: 24),
              label: 'Lights',
            ),
            NavigationDestination(
              icon: Icon(PhosphorIcons.musicNotes(PhosphorIconsStyle.light), color: SmithMkColors.textTertiary, size: 24),
              selectedIcon: Icon(PhosphorIcons.musicNotes(PhosphorIconsStyle.fill), color: SmithMkColors.accentPrimary, size: 24),
              label: 'Media',
            ),
            NavigationDestination(
              icon: Icon(PhosphorIcons.gear(PhosphorIconsStyle.light), color: SmithMkColors.textTertiary, size: 24),
              selectedIcon: Icon(PhosphorIcons.gear(PhosphorIconsStyle.fill), color: SmithMkColors.accentPrimary, size: 24),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
