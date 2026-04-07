import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

import 'package:strata/theme/app_theme.dart';
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
  String _sortBy = 'Date';

  Future<void> _exportToCsvWithShare(BuildContext context, List<ScanRecord> scans) async {
    try {
      if (scans.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data available to export.')),
          );
        }
        return;
      }

      String csvStr = await DatabaseService.instance.exportToCsv();
      final directory = Directory.systemTemp;
      final path = '${directory.path}/strata_scans_export.csv';
      final file = File(path);
      await file.writeAsString(csvStr);
      
      if (context.mounted) {
        final xFile = XFile(path, mimeType: 'text/csv');
        await Share.shareXFiles([xFile], subject: 'Strata Scan Data Export');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteScan(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Scan'),
        content: const Text('Are you sure you want to delete this scan record? This action cannot be undone.'),
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
      await DatabaseService.instance.deleteScan(id);
      ref.invalidate(scansProvider);
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
            tooltip: 'Export Data to CSV',
            onPressed: () {
              scansAsyncValue.whenData((scans) {
                _exportToCsvWithShare(context, scans);
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text('Sort By:', style: textTheme.titleSmall),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sortBy,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      filled: true,
                      fillColor: isDark ? AppColors.cardDark : AppColors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      )
                    ),
                    dropdownColor: isDark ? AppColors.cardDark : AppColors.surfaceLight,
                    items: ['Date', 'Plot Name'].map((String sortType) {
                      return DropdownMenuItem(
                        value: sortType,
                        child: Text(sortType, style: textTheme.bodyMedium),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _sortBy = newValue;
                        });
                      }
                    },
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: scansAsyncValue.when(
              data: (scans) {
                if (scans.isEmpty) {
                  return _buildEmptyState(textTheme, colorScheme);
                }

                List<ScanRecord> sortedScans = List.from(scans);
                if (_sortBy == 'Plot Name') {
                  sortedScans.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
                } else if (_sortBy == 'Date') {
                  sortedScans.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                } 

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(scansProvider);
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: sortedScans.length,
                    itemBuilder: (context, index) {
                      final scan = sortedScans[index];
                      final dateStr = scan.timestamp.split('T').first;
                      final isHealthy = scan.healthStatus == 'Healthy';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isHealthy ? AppColors.primary.withOpacity(0.05) : Colors.redAccent.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isHealthy ? AppColors.primary.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              scan.plotName,
                                              style: textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                              maxLines: 1, 
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                            onPressed: () => _deleteScan(scan.id!),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_month_rounded, size: 14, color: colorScheme.onSurface.withOpacity(0.5)),
                                          const SizedBox(width: 4),
                                          Text(
                                            dateStr,
                                            style: textTheme.bodySmall?.copyWith(
                                              color: colorScheme.onSurface.withOpacity(0.6),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isHealthy ? AppColors.primary : Colors.redAccent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        isHealthy ? 'Healthy' : 'Rehab Needed', 
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (isHealthy ? AppColors.primary : Colors.redAccent).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        scan.soilType, 
                                        style: TextStyle(color: isHealthy ? AppColors.primaryDark : Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  context.push('/scan', extra: {'scanRecord': scan});
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: const Text('View Results', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildEmptyState(TextTheme textTheme, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        const SizedBox(height: 48),
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
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
                  color: colorScheme.onSurface.withOpacity(0.5),
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
