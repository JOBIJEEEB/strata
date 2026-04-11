import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:strata/theme/app_theme.dart';
import 'package:strata/theme/components.dart';
import 'package:strata/database/database_service.dart';

final scansProvider = FutureProvider.autoDispose<List<ScanRecord>>((ref) async {
  return await DatabaseService.instance.fetchScans();
});

class HistoryTab extends ConsumerStatefulWidget {
  const HistoryTab({super.key});

  @override
  ConsumerState<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<HistoryTab> {
  Future<void> _exportToCsvWithShare(
    BuildContext context,
    List<ScanRecord> scans,
  ) async {
    try {
      if (scans.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data available to export.')),
          );
        }
        return;
      }

      final csvStr = await DatabaseService.instance.exportToCsv();
      final directory = Directory.systemTemp;
      final path = '${directory.path}/strata_scans_export.csv';
      final file = File(path);
      await file.writeAsString(csvStr);

      if (context.mounted) {
        final xFile = XFile(path, mimeType: 'text/csv');
        // ignore: deprecated_member_use
        await Share.shareXFiles([xFile], subject: 'Strata Scan Data Export');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  /// Groups a flat list of scans into a map keyed by plotName.
  /// Each group is sorted newest-first.
  Map<String, List<ScanRecord>> _groupByPlot(List<ScanRecord> scans) {
    final Map<String, List<ScanRecord>> grouped = {};
    for (final scan in scans) {
      grouped.putIfAbsent(scan.plotName, () => []).add(scan);
    }
    // Sort each group newest-first
    for (final key in grouped.keys) {
      grouped[key]!.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    return grouped;
  }

  String _formatDate(String ts) {
    try {
      final dt = DateTime.parse(ts);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return ts.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scansAsyncValue = ref.watch(scansProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export All Data to CSV',
            onPressed: () {
              scansAsyncValue.whenData((scans) {
                _exportToCsvWithShare(context, scans);
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: scansAsyncValue.when(
          data: (scans) {
            if (scans.isEmpty) {
              return _buildEmptyState(textTheme, colorScheme);
            }

            final grouped = _groupByPlot(scans);
            // Sort plot cards: most recently scanned plot first
            final plotNames = grouped.keys.toList()
              ..sort((a, b) => grouped[b]!.first.timestamp
                  .compareTo(grouped[a]!.first.timestamp));

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(scansProvider),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: plotNames.length,
                itemBuilder: (context, index) {
                  final plotName = plotNames[index];
                  final plotScans = grouped[plotName]!;
                  final latest = plotScans.first;
                  final isHealthy = latest.healthStatus == 'Healthy';
                  final scanCount = plotScans.length;

                  return _PlotCard(
                    plotName: plotName,
                    latestScan: latest,
                    scanCount: scanCount,
                    isHealthy: isHealthy,
                    lastScannedDate: _formatDate(latest.timestamp),
                    isDark: isDark,
                    textTheme: textTheme,
                    colorScheme: colorScheme,
                    onViewHistory: () {
                      context.push('/plot-history', extra: {
                        'plotName': plotName,
                        'scans': plotScans,
                      });
                    },
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _buildEmptyState(TextTheme textTheme, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        const SizedBox(height: 64),
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text('No scans recorded yet', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Your scan history will appear here\nafter your first hardware scan.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Plot Card widget ──────────────────────────────────────────────────────────

class _PlotCard extends StatelessWidget {
  final String plotName;
  final ScanRecord latestScan;
  final int scanCount;
  final bool isHealthy;
  final String lastScannedDate;
  final bool isDark;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final VoidCallback onViewHistory;

  const _PlotCard({
    required this.plotName,
    required this.latestScan,
    required this.scanCount,
    required this.isHealthy,
    required this.lastScannedDate,
    required this.isDark,
    required this.textTheme,
    required this.colorScheme,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isHealthy ? AppColors.primary : Colors.redAccent;

    return Semantics(
      label: 'Plot: $plotName, $scanCount scans',
      hint: 'Double tap to view scan history',
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Coloured accent strip at top ──────────────────────────────
            Container(
              height: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isHealthy
                      ? [const Color(0xFF2BB673), const Color(0xFF1E8A55)]
                      : [const Color(0xFFFF5722), const Color(0xFFD32F2F)],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
            ),

            // ── Card body ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Plot icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.terrain_rounded,
                          color: accentColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plotName,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              latestScan.soilType,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // badges column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // health status
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isHealthy ? 'Healthy' : 'Rehab Needed',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // scan count
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$scanCount scan${scanCount == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Last scanned date
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Last scanned $lastScannedDate',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  // Quick stats strip
                  const SizedBox(height: 12),
                  _QuickStats(scan: latestScan),

                  const SizedBox(height: 16),

                  // Action button
                  StrataButton(
                    label: scanCount > 1
                        ? 'View History ($scanCount scans)'
                        : 'View Results',
                    icon: Icons.timeline_rounded,
                    onPressed: onViewHistory,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact quick-stats row ───────────────────────────────────────────────────

class _QuickStats extends StatelessWidget {
  final ScanRecord scan;

  const _QuickStats({required this.scan});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('pH', scan.soilPh.toStringAsFixed(1), Icons.speed_rounded),
          _divider(),
          _statItem(
              'N', '${scan.nitrogen}', Icons.eco_rounded),
          _divider(),
          _statItem('Moist',
              '${scan.moisture.toStringAsFixed(0)}%', Icons.water_drop_rounded),
          _divider(),
          _statItem('Temp',
              '${scan.temperature.toStringAsFixed(0)}°C', Icons.thermostat_rounded),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 14, color: AppColors.primary.withValues(alpha: 0.7)),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.primary.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 32,
        color: AppColors.primary.withValues(alpha: 0.12),
      );
}
