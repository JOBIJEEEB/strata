import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strata/theme/app_theme.dart';
import 'package:strata/providers/providers.dart';
import 'tabs/home_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/concoctions_tab.dart';
import 'tabs/settings_tab.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    HomeTab(),
    HistoryTab(),
    ConcoctionsTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bleState = ref.watch(bleConnectionProvider);
    final isConnected = bleState.isConnected;

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 64,
        height: 64,
        child: FloatingActionButton(
          onPressed: () {
            if (!isConnected) {
              context.push('/pairing');
            } else {
              context.push('/scan');
            }
          },
          tooltip: 'New Scan',
          elevation: 8,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 36),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 8,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        height: 65,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildTabItem(
                  index: 0,
                  icon: Icons.grass_rounded,
                  activeIcon: Icons.grass_rounded,
                  label: 'Home',
                ),
                const SizedBox(width: 24),
                _buildTabItem(
                  index: 1,
                  icon: Icons.timeline_outlined,
                  activeIcon: Icons.timeline_rounded,
                  label: 'History',
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildTabItem(
                  index: 2,
                  icon: Icons.science_outlined,
                  activeIcon: Icons.science_rounded,
                  label: 'Guide',
                ),
                const SizedBox(width: 24),
                _buildTabItem(
                  index: 3,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Settings',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;
    final color = isSelected 
        ? AppColors.primary 
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.5);

    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
