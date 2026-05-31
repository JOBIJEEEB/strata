import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

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
  bool _selectionMode = false;
  final Set<String> _selectedPlotNames = {};

  Future<void> _exportToCsv(
    BuildContext context,
    List<ScanRecord> scans,
  ) async {
    if (scans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export.')),
      );
      return;
    }

    final filenameController = TextEditingController(text: 'strata_scans_export');
    final render = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Scans'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter a name for the CSV file:'),
            const SizedBox(height: 12),
            TextField(
              controller: filenameController,
              decoration: const InputDecoration(
                suffixText: '.csv',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Export', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (render != true || !context.mounted) return;

    try {
      final csvStr = await DatabaseService.instance.exportScansToCsv(scans);
      String filename = filenameController.text.trim();
      if (filename.isEmpty) filename = 'strata_export';
      if (!filename.endsWith('.csv')) filename += '.csv';

      // Write directly to the Downloads folder (works reliably on Android)
      final downloadsDir = await getExternalStorageDirectory();
      final saveDir = downloadsDir != null
          ? Directory('${downloadsDir.path}')
              .parent.parent.parent.parent // go up to /storage/emulated/0
          : await getApplicationDocumentsDirectory();

      // Use the Downloads folder specifically
      final downloadPath = Directory('${saveDir.path}/Download');
      if (!await downloadPath.exists()) {
        await downloadPath.create(recursive: true);
      }

      final filePath = '${downloadPath.path}/$filename';
      final file = File(filePath);
      await file.writeAsString(csvStr);

      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: AppColors.primary, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text('Export Successful!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    'Your file has been saved to:',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      filePath,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelectedPlots(Map<String, List<ScanRecord>> grouped) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Plots'),
        content: Text('Are you sure you want to delete ${_selectedPlotNames.length} selected plot(s) and all their history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final plotName in _selectedPlotNames) {
        final plotScans = grouped[plotName];
        if (plotScans != null) {
          for (final s in plotScans) {
            if (s.id != null) await DatabaseService.instance.deleteScan(s.id!);
          }
        }
      }
      ref.invalidate(scansProvider);
      setState(() {
        _selectionMode = false;
        _selectedPlotNames.clear();
      });
    }
  }

  void _exportSelectedPlots(Map<String, List<ScanRecord>> grouped) {
    final List<ScanRecord> selectedScans = [];
    for (final plotName in _selectedPlotNames) {
      if (grouped.containsKey(plotName)) {
        selectedScans.addAll(grouped[plotName]!);
      }
    }
    _exportToCsv(context, selectedScans);
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
        title: Text(_selectionMode ? '${_selectedPlotNames.length} Selected' : 'Scan History'),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all_rounded),
              tooltip: 'Select All',
              onPressed: () {
                scansAsyncValue.whenData((scans) {
                  final grouped = _groupByPlot(scans);
                  setState(() {
                    if (_selectedPlotNames.length == grouped.keys.length) {
                      _selectedPlotNames.clear();
                    } else {
                      _selectedPlotNames.addAll(grouped.keys);
                    }
                  });
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _selectionMode = false;
                _selectedPlotNames.clear();
              }),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.checklist_rtl_rounded),
              tooltip: 'Select Plots',
              onPressed: () => setState(() => _selectionMode = true),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                color: Colors.transparent,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2BB673), Color(0xFF1A7A4C)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      scansAsyncValue.whenData((scans) {
                        _exportToCsv(context, scans);
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.file_download_outlined, color: Colors.white, size: 18),
                          SizedBox(width: 5),
                          Text(
                            'Export CSV',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: _selectionMode && _selectedPlotNames.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          scansAsyncValue.whenData((scans) => _deleteSelectedPlots(_groupByPlot(scans)));
                        },
                        label: const Text('Delete'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Material(
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        color: Colors.transparent,
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2BB673), Color(0xFF1A7A4C)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF2BB673),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () {
                              scansAsyncValue.whenData(
                                  (scans) => _exportSelectedPlots(_groupByPlot(scans)));
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.file_download_outlined,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Export CSV',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
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
                    isSelected: _selectedPlotNames.contains(plotName),
                    selectionMode: _selectionMode,
                    onTap: () {
                      if (_selectionMode) {
                        setState(() {
                          if (_selectedPlotNames.contains(plotName)) {
                            _selectedPlotNames.remove(plotName);
                          } else {
                            _selectedPlotNames.add(plotName);
                          }
                        });
                      } else {
                        context.push('/plot-history', extra: {
                          'plotName': plotName,
                          'scans': plotScans,
                        });
                      }
                    },
                    onViewHistory: () {
                      context.push('/plot-history', extra: {
                        'plotName': plotName,
                        'scans': plotScans,
                      });
                    },
                    onDelete: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Plot'),
                          content: const Text(
                            'Are you sure you want to delete this entire plot and its history?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        for (final s in plotScans) {
                          if (s.id != null) {
                            await DatabaseService.instance.deleteScan(s.id!);
                          }
                        }
                        ref.invalidate(scansProvider);
                      }
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
  final VoidCallback onViewHistory;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final bool isSelected;
  final bool selectionMode;
  final bool isHealthy;
  final String lastScannedDate;
  final bool isDark;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

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
    required this.onDelete,
    required this.onTap,
    required this.isSelected,
    required this.selectionMode,
  });

  Color _getSoilColor(String soil) {
    final s = soil.toLowerCase();
    if (s.contains('sandy') && s.contains('loamy')) return Colors.teal;
    if (s.contains('clay')) return Colors.orange;
    if (s.contains('loamy')) return Colors.green;
    if (s.contains('sandy')) return Colors.amber;
    if (s.contains('coarse')) return Colors.grey;
    if (s.contains('silt')) return Colors.blueGrey;
    if (s.contains('any')) return Colors.purple;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = isHealthy ? AppColors.primary : Colors.redAccent;

    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: 'Plot: $plotName, $scanCount scans',
        hint: selectionMode ? 'Tap to select' : 'Double tap to view scan history',
        selected: isSelected,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppColors.primary.withValues(alpha: 0.1)
                : (isDark ? AppColors.cardDark : Colors.white),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? AppColors.primary : accentColor.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              if (!isSelected)
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Column(
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
                                  selectionMode
                                      ? (isSelected ? Icons.check_circle_rounded : Icons.circle_outlined)
                                      : Icons.terrain_rounded,
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
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getSoilColor(latestScan.soilType).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        latestScan.soilType,
                                        style: TextStyle(
                                          color: _getSoilColor(latestScan.soilType),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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

                          // Action button
                          if (!selectionMode) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: StrataButton(
                                    label: scanCount > 1
                                        ? 'View History'
                                        : 'View Results',
                                    icon: Icons.timeline_rounded,
                                    onPressed: onViewHistory,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  height: 52,
                                  width: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: onDelete,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
