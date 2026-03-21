import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/smithmk_theme.dart';
import '../pages/home_page.dart';
import '../pages/placeholder_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    PlaceholderPage(title: 'Rooms', icon: Icons.room_preferences_outlined),
    PlaceholderPage(title: 'Lighting', icon: Icons.lightbulb_outlined),
    PlaceholderPage(title: 'Media', icon: Icons.music_note_outlined),
    PlaceholderPage(title: 'Settings', icon: Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: SmithMkColors.glassBorder,
              width: 0.5,
            ),
          ),
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
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: SmithMkColors.textTertiary),
              selectedIcon: Icon(Icons.home, color: SmithMkColors.accentPrimary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.room_preferences_outlined, color: SmithMkColors.textTertiary),
              selectedIcon: Icon(Icons.room_preferences, color: SmithMkColors.accentPrimary),
              label: 'Rooms',
            ),
            NavigationDestination(
              icon: Icon(Icons.lightbulb_outlined, color: SmithMkColors.textTertiary),
              selectedIcon: Icon(Icons.lightbulb, color: SmithMkColors.accentPrimary),
              label: 'Lights',
            ),
            NavigationDestination(
              icon: Icon(Icons.music_note_outlined, color: SmithMkColors.textTertiary),
              selectedIcon: Icon(Icons.music_note, color: SmithMkColors.accentPrimary),
              label: 'Media',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, color: SmithMkColors.textTertiary),
              selectedIcon: Icon(Icons.settings, color: SmithMkColors.accentPrimary),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
