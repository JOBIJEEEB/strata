import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strata/theme/app_theme.dart';
import 'package:strata/providers/providers.dart';
import 'package:strata/database/database_service.dart';
import 'package:strata/screens/tabs/history_tab.dart'; // Implements scansProvider
import 'package:strata/services/ble_service.dart';

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  bool _notificationsEnabled = false;
  bool _devModeExpanded = false;

  void _wipeDatabase() async {
    await DatabaseService.instance.wipeDatabase();
    ref.invalidate(scansProvider);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Local database cleared.')));
    }
  }

  void _simulateBleScan() async {
    final record = SoilMockGenerator.generateMockScan(
      plotName: 'Simulated Debug Plot',
      soilType: 'Loam',
    );
    await DatabaseService.instance.insertScan(record);
    ref.invalidate(scansProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Simulated mock scan injected.')),
      );
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
            label: bleState.isConnected ? 'Raspberry Pi' : 'Connect to Pi',
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
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'App Notifications',
            isDark: isDark,
            trailing: Switch(
              value: _notificationsEnabled,
              activeThumbColor: AppColors.primary,
              onChanged: (v) => setState(() => _notificationsEnabled = v),
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

          // ── Developer Options ──────────────────────────────────
          const _SectionHeader(label: 'Developer Options'),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.code_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                  title: Text('Developer Mode', style: textTheme.titleSmall),
                  subtitle: Text(
                    _devModeExpanded ? 'Tap to collapse' : 'Tap to expand',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                  trailing: AnimatedRotation(
                    turns: _devModeExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more_rounded),
                  ),
                  onTap:
                      () =>
                          setState(() => _devModeExpanded = !_devModeExpanded),
                ),
                if (_devModeExpanded) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _DevOption(
                    label: 'Simulate Hardware Switch',
                    subtitle: 'Force a mock connection state',
                    icon: Icons.bluetooth_audio_rounded,
                    isDark: isDark,
                    trailingOverride: Switch(
                      value: bleState.isConnected,
                      activeThumbColor: AppColors.primary,
                    onChanged: (val) async {
                          if (!val) {
                            await BleService.instance.disconnect();
                          }
                        },
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _DevOption(
                    label: 'Simulate BLE Scan',
                    subtitle: 'Inject mock NPK and crop parameter data to DB',
                    icon: Icons.play_circle_outline_rounded,
                    isDark: isDark,
                    onTap: _simulateBleScan,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── About ──────────────────────────────────
          const _SectionHeader(label: 'About'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'App Version',
            isDark: isDark,
            trailing: Text('1.0.2', style: textTheme.bodyMedium),
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
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool isDark;
  final Widget trailing;
  final VoidCallback? onTap;

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
      ),
    );
  }
}

// ── Dev option row ─────────────────────────────────────────────────────────
class _DevOption extends StatelessWidget {
  const _DevOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isDark,
    this.trailingOverride,
    this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool isDark;
  final Widget? trailingOverride;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primary;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: color, size: 20),
      title: Text(label, style: textTheme.bodyMedium),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
      trailing:
          trailingOverride ??
          (onTap != null
              ? const Icon(Icons.chevron_right_rounded, size: 18)
              : null),
      onTap: onTap ?? () {},
    );
  }
}
