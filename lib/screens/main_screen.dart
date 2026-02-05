import 'package:flutter/material.dart';
import 'prep_screen.dart';
import 'injector_screen.dart';
import 'settings_screen.dart';
import 'marketplace_screen.dart';

class MainScreen extends StatefulWidget {
  final ThemeMode currentMode;
  final Color? currentColor;
  final String? currentAccountId;
  final Function(ThemeMode) onThemeChanged;
  final Function(Color?) onColorChanged;
  final Function(String) onAccountIdChanged;

  const MainScreen({
    super.key, 
    required this.currentMode, 
    required this.currentColor,
    required this.currentAccountId,
    required this.onThemeChanged, 
    required this.onColorChanged,
    required this.onAccountIdChanged,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      PrepScreen(currentAccountId: widget.currentAccountId),
      InjectorScreen(currentAccountId: widget.currentAccountId),
      MarketplaceScreen(currentAccountId: widget.currentAccountId), // Tab Index 2
      SettingsScreen(
        currentMode: widget.currentMode,
        currentColor: widget.currentColor,
        currentAccountId: widget.currentAccountId,
        onThemeChanged: widget.onThemeChanged,
        onColorChanged: widget.onColorChanged,
        onAccountIdChanged: widget.onAccountIdChanged,
      ),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300), 
        child: pages[_index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.cleaning_services_outlined), 
            selectedIcon: Icon(Icons.cleaning_services), 
            label: 'Prep',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined), 
            selectedIcon: Icon(Icons.bolt), 
            label: 'Inject',
          ),
          // --- NEW MARKET TAB ---
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined), 
            selectedIcon: Icon(Icons.storefront), 
            label: 'Market',
          ),
          // ----------------------
          NavigationDestination(
            icon: Icon(Icons.settings_outlined), 
            selectedIcon: Icon(Icons.settings), 
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}