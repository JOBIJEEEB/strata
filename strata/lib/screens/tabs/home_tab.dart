import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strata/theme/app_theme.dart';
import 'package:strata/providers/providers.dart';
import 'package:strata/database/database_service.dart';
import 'package:strata/screens/tabs/history_tab.dart'; // To access scansProvider

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bleState = ref.watch(bleConnectionProvider);
    final isConnected = bleState.isConnected;

    final scansAsyncValue = ref.watch(scansProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: SizedBox(
        width: 68,
        height: 68,
        child: FloatingActionButton(
          onPressed: () {
            if (!isConnected) {
              // Launch pairing screen natively overlay instead of Snackbar
              context.push('/pairing');
            } else {
              context.push('/scan');
            }
          },
          tooltip: 'New Scan',
          elevation: 8,
          child: const Icon(Icons.add_rounded, size: 36),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Row(
              children: [
                Image.asset('assets/strata_logo.png', height: 28, errorBuilder: (c, e, s) => const Icon(Icons.agriculture_rounded, color: AppColors.primary)),
                const SizedBox(width: 12),
                const Text('Strata'),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.primary.withOpacity(0.04),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('System Overview', style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 20),

                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: (isConnected ? AppColors.primaryLight : Colors.redAccent).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded, 
                                color: isConnected ? AppColors.primary : Colors.redAccent,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isConnected ? 'Raspberry Pi Connected' : 'Pi Disconnected',
                                    style: textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isConnected ? 'System Normal' : 'Pairing required for scanning',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (!isConnected) ...[
                             const SizedBox(width: 8),
                             ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                minimumSize: const Size(0, 36),
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => ref.read(bleConnectionProvider.notifier).connectToPi(),
                              child: const Text('Connect', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                             )
                            ]
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Divider(height: 1),
                        ),
                        Row(
                          children: [
                            Expanded(child: _DiagnosticMetric(icon: Icons.battery_charging_full_rounded, label: 'UPS HAT', value: isConnected ? '85%' : '---', color: isConnected ? AppColors.primary : Colors.grey)),
                            Expanded(child: _DiagnosticMetric(icon: Icons.thermostat_rounded, label: 'Pi Temp', value: isConnected ? '42°C' : '---', color: isConnected ? Colors.orange : Colors.grey)),
                            Expanded(child: _DiagnosticMetric(icon: Icons.memory_rounded, label: 'CPU Load', value: isConnected ? '12%' : '---', color: isConnected ? Colors.blue : Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text('Recent Scans', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),

          scansAsyncValue.when(
            data: (scans) {
              if (scans.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'No recent scans. Tap the + icon to begin.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                );
              }
              
              final recentScans = scans.take(3).toList();
              
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final scan = recentScans[index];
                      final isHealthy = scan.healthStatus == 'Healthy';

                      return GestureDetector(
                        onTap: () {
                           context.push('/scan', extra: {
                             'scanRecord': scan, // Passing pure database record directly to bento bounds
                           });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Main Top Block
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: (isHealthy ? AppColors.primary : Colors.orange).withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  scan.soilType,
                                                  style: TextStyle(
                                                    color: isHealthy ? AppColors.primaryDark : Colors.orange[800],
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  scan.plotName,
                                                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            scan.timestamp.split('T').first,
                                            style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.5)),
                                          )
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                          onPressed: () async {
                                            final confirmed = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Delete Scan'),
                                                content: const Text('Are you sure you want to delete this scan record?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, true),
                                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirmed == true) {
                                              await DatabaseService.instance.deleteScan(scan.id!);
                                              ref.invalidate(scansProvider);
                                            }
                                          },
                                        ),
                                        Icon(Icons.chevron_right_rounded, color: colorScheme.onSurface.withOpacity(0.3)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Subtext Bottom Block
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isHealthy 
                                     ? AppColors.primary.withOpacity(0.08) 
                                     : Colors.orange.withOpacity(0.08),
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isHealthy ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                                      color: isHealthy ? AppColors.primaryDark : Colors.orange,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        scan.cropRecommendation.split(',').first,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: isHealthy ? AppColors.primaryDark : Colors.orange[800],
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: recentScans.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, st) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(child: Text('Error loading scans: $e')),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _DiagnosticMetric extends StatelessWidget {
  const _DiagnosticMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          maxLines: 1, 
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
