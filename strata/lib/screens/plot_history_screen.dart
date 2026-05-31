import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import 'package:strata/theme/app_theme.dart';
import 'package:strata/theme/components.dart';
import 'package:strata/database/database_service.dart';
import 'package:strata/screens/tabs/history_tab.dart'; // for scansProvider

class PlotHistoryScreen extends ConsumerStatefulWidget {
  final String plotName;
  final List<ScanRecord> scans; // Initial scans

  const PlotHistoryScreen({
    super.key,
    required this.plotName,
    required this.scans,
  });

  @override
  ConsumerState<PlotHistoryScreen> createState() => _PlotHistoryScreenState();
}

class _PlotHistoryScreenState extends ConsumerState<PlotHistoryScreen> {
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};
  String _filterStatus = 'All'; // 'All', 'Healthy', 'Rehab Needed'
  bool _sortNewest = true;

  Future<void> _exportSelected(List<ScanRecord> allScans) async {
    final selectedScans = allScans.where((s) => s.id != null && _selectedIds.contains(s.id)).toList();
    if (selectedScans.isEmpty) return;

    final filenameController = TextEditingController(text: '${widget.plotName.replaceAll(' ', '_')}_export');
    final render = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Selected'),
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
      final header = 'ID,Plot Name,Soil Type,Timestamp,Soil pH,Moisture (%),Temp (°C),EC Level (µS/cm),Nitrogen (mg/kg),Phosphorus (mg/kg),Potassium (mg/kg),Health Status,Crop Recommendation\n';
      final buffer = StringBuffer(header);
      for (final s in selectedScans) {
        buffer.write('${s.id},"${s.plotName}","${s.soilType}","${s.timestamp}",${s.soilPh},${s.moisture},${s.temperature},${s.ecLevel},${s.nitrogen},${s.phosphorus},${s.potassium},"${s.healthStatus}","${s.cropRecommendation.replaceAll('"', '""')}"\n');
      }

      final directory = await getExternalStorageDirectory();
      final saveDir = directory != null
          ? Directory('${directory.path}').parent.parent.parent.parent
          : await getApplicationDocumentsDirectory();

      final downloadPath = Directory('${saveDir.path}/Download');
      if (!await downloadPath.exists()) {
        await downloadPath.create(recursive: true);
      }

      String filename = filenameController.text.trim();
      if (filename.isEmpty) filename = 'export';
      if (!filename.endsWith('.csv')) filename += '.csv';

      final filePath = '${downloadPath.path}/$filename';
      final file = File(filePath);
      await file.writeAsString(buffer.toString());

      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });

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
                    'Your CSV file has been saved to:',
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Scans'),
        content: Text('Are you sure you want to delete ${_selectedIds.length} selected scan(s)? This action cannot be undone.'),
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
      for (final id in _selectedIds) {
        await DatabaseService.instance.deleteScan(id);
      }
      ref.invalidate(scansProvider);
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
    }
  }

  String _formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour:$minute $ampm';
    } catch (_) {
      return ts.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final asyncScans = ref.watch(scansProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode ? '${_selectedIds.length} Selected' : widget.plotName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all_rounded),
              tooltip: 'Select All in view',
              onPressed: () {
                asyncScans.whenData((allScans) {
                  final plotScans = _getFilteredScans(allScans);
                  setState(() {
                    if (_selectedIds.length == plotScans.length) {
                      _selectedIds.clear();
                    } else {
                      _selectedIds.addAll(plotScans.map((e) => e.id!).whereType<int>());
                    }
                  });
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() {
                _selectionMode = false;
                _selectedIds.clear();
              }),
            ),
          ] else ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list_rounded),
              tooltip: 'Filter & Sort',
              onSelected: (value) {
                if (value == 'Sort') {
                  setState(() => _sortNewest = !_sortNewest);
                } else {
                  setState(() => _filterStatus = value);
                }
              },
              itemBuilder: (context) => [
                CheckedPopupMenuItem(
                  value: 'All',
                  checked: _filterStatus == 'All',
                  child: const Text('Show All'),
                ),
                CheckedPopupMenuItem(
                  value: 'Healthy',
                  checked: _filterStatus == 'Healthy',
                  child: const Text('Show Healthy only'),
                ),
                CheckedPopupMenuItem(
                  value: 'Rehab Needed',
                  checked: _filterStatus == 'Rehab Needed',
                  child: const Text('Show Rehab Needed only'),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'Sort',
                  child: Text(_sortNewest ? 'Sort Oldest First' : 'Sort Newest First'),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.checklist_rtl_rounded),
              tooltip: 'Select Scans',
              onPressed: () {
                setState(() => _selectionMode = true);
              },
            ),
          ]
        ],
      ),
      bottomNavigationBar: _selectionMode && _selectedIds.isNotEmpty
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
                        onPressed: _deleteSelected,
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
                                color: const Color(0xFF2BB673).withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () {
                              asyncScans.whenData((all) => _exportSelected(all));
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.file_download_outlined, color: Colors.white, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'Export Scans',
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
        child: asyncScans.when(
          data: (allScans) {
            final filteredScans = _getFilteredScans(allScans);

            // Using pure raw scans to render header (not filtered)
            final allPlotScans = allScans.where((s) => s.plotName == widget.plotName).toList();
            allPlotScans.sort((a, b) => b.timestamp.compareTo(a.timestamp));

            if (allPlotScans.isEmpty) {
              return Center(
                child: Text('All scans deleted.', style: textTheme.bodyLarge),
              );
            }

            final latestScan = allPlotScans.first;
            final soilType = latestScan.soilType;
            final isLatestHealthy = latestScan.healthStatus == 'Healthy';

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(scansProvider);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // ── Plot Summary Header ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isLatestHealthy
                              ? [const Color(0xFF2BB673), const Color(0xFF1E8A55)]
                              : [const Color(0xFFFF5722), const Color(0xFFD32F2F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: (isLatestHealthy ? Colors.green : Colors.red).withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.terrain_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  soilType,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isLatestHealthy ? 'Currently Healthy' : 'Rehab Needed',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${allPlotScans.length} scan${allPlotScans.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Section title ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Scan Timeline',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Timeline list ─────────────────────────────────────────────────
                  if (filteredScans.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'No scans match this filter.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      itemCount: filteredScans.length,
                      itemBuilder: (context, index) {
                        final scan = filteredScans[index];
                        final isHealthy = scan.healthStatus == 'Healthy';
                        final isFirst = index == 0;

                        return _buildTimelineRow(
                          context,
                          scan: scan,
                          isHealthy: isHealthy,
                          isFirst: isFirst,
                          isLast: index == filteredScans.length - 1,
                          isDark: isDark,
                          textTheme: textTheme,
                          colorScheme: colorScheme,
                        );
                      },
                    ),

                  // ── Rescan button ─────────────────────────────────────────────────
                  if (!_selectionMode)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: StrataButton(
                        label: 'Rescan This Plot',
                        icon: Icons.sensors_rounded,
                        onPressed: () {
                          context.push('/scan', extra: {
                            'plotName': widget.plotName,
                            'soilType': soilType,
                          });
                        },
                      ),
                    ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  List<ScanRecord> _getFilteredScans(List<ScanRecord> allScans) {
    var plotScans = allScans.where((s) => s.plotName == widget.plotName).toList();
    if (_filterStatus == 'Healthy') {
      plotScans = plotScans.where((s) => s.healthStatus == 'Healthy').toList();
    } else if (_filterStatus == 'Rehab Needed') {
      plotScans = plotScans.where((s) => s.healthStatus != 'Healthy').toList();
    }

    if (_sortNewest) {
      plotScans.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } else {
      plotScans.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    return plotScans;
  }

  Widget _buildTimelineRow(
    BuildContext context, {
    required ScanRecord scan,
    required bool isHealthy,
    required bool isFirst,
    required bool isLast,
    required bool isDark,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    final accentColor = isHealthy ? AppColors.primary : Colors.redAccent;
    final isSelected = scan.id != null && _selectedIds.contains(scan.id);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_selectionMode) ...[
            Center(
              child: Checkbox(
                value: isSelected,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    if (val == true && scan.id != null) {
                      _selectedIds.add(scan.id!);
                    } else {
                      _selectedIds.remove(scan.id);
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
          ] else ...[
            // ── Timeline rail ──────────────────────────────────────────────────
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  if (!isFirst)
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: Container(
                          width: 2,
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFirst ? accentColor : Colors.transparent,
                      border: Border.all(
                        color: accentColor,
                        width: isFirst ? 0 : 2,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: Container(
                          width: 2,
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],

          // ── Scan card ──────────────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectionMode && scan.id != null) {
                  setState(() {
                    if (isSelected) {
                      _selectedIds.remove(scan.id);
                    } else {
                      _selectedIds.add(scan.id!);
                    }
                  });
                } else {
                  context.push('/scan', extra: {'scanRecord': scan});
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : (isDark ? AppColors.cardDark : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : accentColor.withValues(alpha: 0.2),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    if (!isSelected)
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: date + status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatTimestamp(scan.timestamp),
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isHealthy ? 'Healthy' : 'Rehab',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Row 2: NPK EC badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _chip('N', '${scan.nitrogen}', Colors.teal),
                        _chip('P', '${scan.phosphorus}', Colors.purple),
                        _chip('K', '${scan.potassium}', Colors.orange),
                        _chip('EC', scan.ecLevel.toStringAsFixed(2), Colors.blue),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Tap prompt
                    if (!_selectionMode)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'View full results',
                            style: textTheme.labelSmall?.copyWith(
                              color: AppColors.primary.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded,
                              size: 16,
                              color: AppColors.primary.withValues(alpha: 0.8)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.7),
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
