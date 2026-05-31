import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strata/theme/app_theme.dart';
import 'package:strata/providers/providers.dart';
import 'package:strata/database/database_service.dart';
import 'package:strata/screens/tabs/history_tab.dart'; // Implements scansProvider
import 'package:strata/services/ble_service.dart';
import 'dart:convert';

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  int _debugTapCount = 0;

  void _recordHealthyScan() async {
    final now = DateTime.now();
    final timestamp = now.toIso8601String();

    final healthyScan = ScanRecord(
      plotName: 'Debug Healthy Plot',
      soilType: 'Loamy',
      timestamp: timestamp,
      soilPh: 6.8,
      moisture: 42.0,
      temperature: 25.0,
      ecLevel: 1.1,
      nitrogen: 145,
      phosphorus: 45,
      potassium: 190,
      healthStatus: 'Healthy',
      cropRecommendation: jsonEncode([
        {'name': 'Tomato', 'confidence': 95.0},
        {'name': 'Maize', 'confidence': 88.5},
        {'name': 'Onion', 'confidence': 76.2},
      ]),
      mlDeficiencies: [],
      mlFlags: [],
      rehabRecommendations: '',
    );

    await DatabaseService.instance.insertScan(healthyScan);
    ref.invalidate(scansProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debug: Healthy scan recorded!'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  void _recordUnhealthyScan() async {
    final now = DateTime.now();
    final timestamp = now.toIso8601String();

    final unhealthyScan = ScanRecord(
      plotName: 'Debug Unhealthy Plot',
      soilType: 'Clay',
      timestamp: timestamp,
      soilPh: 5.0,
      moisture: 15.0,
      temperature: 30.0,
      ecLevel: 0.5,
      nitrogen: 40,
      phosphorus: 15,
      potassium: 80,
      healthStatus: 'Unhealthy',
      cropRecommendation: jsonEncode([
        {'name': 'Wheat', 'confidence': 16.0},
        {'name': 'Millet', 'confidence': 15.0},
        {'name': 'Cotton', 'confidence': 11.67},
      ]),
      mlDeficiencies: ['N is LOW: 40 mg/kg (need > 50)', 'P is LOW: 15 mg/kg (need > 20)'],
      mlFlags: ['Moisture LOW: 15.0% — consider irrigation/mulching'],
      rehabRecommendations: 'FPJ, FAA, CalPhos',
    );

    await DatabaseService.instance.insertScan(unhealthyScan);
    ref.invalidate(scansProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debug: Unhealthy scan recorded!'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _wipeDatabase() async {
    await DatabaseService.instance.wipeDatabase();
    ref.invalidate(scansProvider);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Local database cleared.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // Evaluate Theme Mode for the settings UI exclusively
    final currentThemeMode = ref.watch(themeModeProvider);
    final isDark =
        currentThemeMode == ThemeMode.dark ||
        (currentThemeMode == ThemeMode.system &&
            Theme.of(context).brightness == Brightness.dark);

    // Watch precise Connection state
    final bleState = ref.watch(bleConnectionProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          // ── Hardware Setup ────────────────────────────────────
          const _SectionHeader(label: 'Hardware Setup'),
          _SettingsTile(
            icon: Icons.bluetooth_outlined,
            label: bleState.isConnected ? 'Strata' : 'Connect to Strata',
            subtitle: bleState.isConnected ? 'Connected' : 'Disconnected',
            isDark: isDark,
            trailing:
                bleState.isConnected
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(80, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        context.push('/pairing');
                      },
                      child: const Text(
                        'Connect',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            onTap: () {
              if (!bleState.isConnected) {
                context.push('/pairing');
              }
            },
          ),

          const SizedBox(height: 8),

          // ── App Preferences ────────────────────────────────────
          const _SectionHeader(label: 'App Preferences'),

          // Primary Dark Mode Toggle tied into ThemeModeNotifier architecture
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            label: 'Dark Mode',
            isDark: isDark,
            trailing: Switch(
              value: isDark,
              activeThumbColor: AppColors.primary,
              onChanged: (bool val) {
                // Instantly flips the entire ecosystem tree layout
                ref.read(themeModeProvider.notifier).setDarkMode(val);
              },
            ),
          ),

          const SizedBox(height: 8),

          // ── Data Management ────────────────────────────────────
          const _SectionHeader(label: 'Data Integrity'),
          _SettingsTile(
            icon: Icons.delete_outline_rounded,
            label: 'Clear Local Database',
            isDark: isDark,
            trailing: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 20,
            ),
            onTap: () {
              showDialog(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      backgroundColor:
                          isDark ? AppColors.cardDark : AppColors.surfaceLight,
                      title: const Text('Clear Database'),
                      content: const Text(
                        'Are you sure you want to delete all local scan records? This cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _wipeDatabase();
                          },
                          child: const Text(
                            'Delete All',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
              );
            },
          ),

          const SizedBox(height: 8),

          // ── About ──────────────────────────────────
          const _SectionHeader(label: 'About'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'App Version',
            isDark: isDark,
            trailing: Text('1.0.4', style: textTheme.bodyMedium),
            onTap: () {
              setState(() {
                _debugTapCount++;
                if (_debugTapCount >= 3) {
                  _debugTapCount = 0;
                  _recordHealthyScan();
                }
              });
            },
            onLongPress: () {
              _recordUnhealthyScan();
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Settings tile ─────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.trailing,
    this.subtitle,
    this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isDark;
  final Widget trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(label, style: Theme.of(context).textTheme.titleSmall),
        subtitle:
            subtitle != null
                ? Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)
                : null,
        trailing: trailing,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

