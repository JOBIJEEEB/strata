import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:strata/theme/app_theme.dart';
import 'package:strata/theme/components.dart';
import 'package:strata/database/database_service.dart';
import 'package:strata/screens/tabs/history_tab.dart';

class PlotHistoryScreen extends ConsumerStatefulWidget {
  final String plotName;
  final List<ScanRecord> scans;

  const PlotHistoryScreen({
    super.key,
    required this.plotName,
    required this.scans,
  });

  @override
  ConsumerState<PlotHistoryScreen> createState() => _PlotHistoryScreenState();
}

class _PlotHistoryScreenState extends ConsumerState<PlotHistoryScreen> {
  late List<ScanRecord> _scans;

  @override
  void initState() {
    super.initState();
    // Newest first
    _scans = List.from(widget.scans)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> _deleteScan(ScanRecord scan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Scan'),
        content: const Text(
          'Are you sure you want to delete this scan record? This action cannot be undone.',
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

    if (confirmed == true && scan.id != null) {
      await DatabaseService.instance.deleteScan(scan.id!);
      ref.invalidate(scansProvider);
      setState(() => _scans.remove(scan));

      if (_scans.isEmpty && mounted) {
        context.pop(); // Return to history if all scans deleted
      }
    }
  }

  String _formatTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
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

    final latestScan = _scans.isNotEmpty ? _scans.first : null;
    final soilType = latestScan?.soilType ?? '';
    final isLatestHealthy = latestScan?.healthStatus == 'Healthy';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.plotName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
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
                      color: (isLatestHealthy ? Colors.green : Colors.red)
                          .withValues(alpha: 0.25),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_scans.length} scan${_scans.length == 1 ? '' : 's'}',
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
                  const Icon(Icons.history_rounded,
                      size: 18, color: AppColors.primary),
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
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 4),
                itemCount: _scans.length,
                itemBuilder: (context, index) {
                  final scan = _scans[index];
                  final isHealthy = scan.healthStatus == 'Healthy';
                  final isFirst = index == 0;

                  return _buildTimelineRow(
                    context,
                    scan: scan,
                    isHealthy: isHealthy,
                    isFirst: isFirst,
                    isLast: index == _scans.length - 1,
                    isDark: isDark,
                    textTheme: textTheme,
                    colorScheme: colorScheme,
                  );
                },
              ),
            ),

            // ── Rescan button ─────────────────────────────────────────────────
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
      ),
    );
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

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  child: isFirst
                      ? null
                      : null,
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

          // ── Scan card ──────────────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/scan', extra: {'scanRecord': scan}),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
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
                    // Row 1: date + status + delete
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatTimestamp(scan.timestamp),
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
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
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _deleteScan(scan),
                          child: Icon(Icons.delete_outline,
                              size: 18,
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.35)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Row 2: quick nutrient chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _chip('pH', scan.soilPh.toStringAsFixed(1),
                            accentColor),
                        _chip('N', '${scan.nitrogen}', Colors.teal),
                        _chip(
                            'Moist',
                            '${scan.moisture.toStringAsFixed(0)}%',
                            Colors.blue),
                        _chip(
                            'Temp',
                            '${scan.temperature.toStringAsFixed(0)}°C',
                            Colors.orange),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Tap prompt
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
