import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

import 'package:strata/database/database_service.dart';
import 'package:strata/theme/app_theme.dart';

// --- Maintenance Info Models ---
class MaintenanceInfo {
  final String title;
  final String keyword;
  final String description;
  final IconData icon;
  final Color color;

  const MaintenanceInfo({
    required this.title,
    required this.keyword,
    required this.description,
    required this.icon,
    required this.color,
  });
}

const List<MaintenanceInfo> _maintenanceDataList = [
  MaintenanceInfo(
    title: 'Storage Environment',
    keyword: 'Cool & Dry',
    description: 'Store away from direct sunlight.',
    icon: Icons.inventory_2_rounded,
    color: Colors.blueGrey,
  ),
  MaintenanceInfo(
    title: 'Sanitation',
    keyword: 'Clean & Sealed',
    description: 'Clean materials, seal properly, avoid flies/pests.',
    icon: Icons.cleaning_services_rounded,
    color: Colors.teal,
  ),
  MaintenanceInfo(
    title: 'Shelf Life',
    keyword: '6 Months',
    description: 'Peak quality. Potency drops after microbes deplete molasses.',
    icon: Icons.calendar_month_rounded,
    color: Colors.orange,
  ),
];

const MaintenanceInfo _qualitySuccess = MaintenanceInfo(
  title: 'Quality Success',
  keyword: 'Sweet-Sour',
  description: 'Fermented aroma.',
  icon: Icons.check_circle_rounded,
  color: Colors.green,
);

const MaintenanceInfo _qualityFailure = MaintenanceInfo(
  title: 'Quality Failure',
  keyword: 'Putrid Smell',
  description: 'Foul or putrid smell (discard batch).',
  icon: Icons.warning_rounded,
  color: Colors.redAccent,
);

Color _getColorForConcoction(String id) {
  switch (id) {
    case 'FPJ': return const Color(0xFF4CAF50);    // Green
    case 'FFJ': return const Color(0xFFFF9800);    // Orange
    case 'FAA': return const Color(0xFF2196F3);    // Blue
    case 'IMO': return const Color(0xFF795548);    // Brown
    case 'LABS': return const Color(0xFF009688);   // Teal
    case 'CalPhos': return const Color(0xFF607D8B); // BlueGrey
    case 'OHN': return const Color(0xFF9C27B0);    // Purple
    case 'WATER': return const Color(0xFF29B6F6);  // Light Blue
    default: return AppColors.primary;
  }
}

String _getEmojiForConcoction(String id) {
  switch (id) {
    case 'FPJ': return '🌿';
    case 'FFJ': return '🍌';
    case 'FAA': return '🐟';
    case 'IMO': return '🧫';
    case 'LABS': return '🥛';
    case 'CalPhos': return '🦴';
    case 'OHN': return '🧄';
    case 'WATER': return '💧';
    default: return '🧪';
  }
}

/// Static concoction map for the WATER rehabilitation step.
/// Injected at runtime when the BLE server includes "WATER" in the rehab list.
const Map<String, dynamic> _waterConcoction = {
  'id': 'WATER',
  'name': 'Water Soil Regularly',
  'description': 'Restore soil moisture to optimal levels to support nutrient uptake and healthy root activity.',
  'purpose': 'Restore soil moisture to optimal levels for nutrient uptake',
  'application': {
    'dilution': 'Direct irrigation (no dilution needed)',
    'frequency': 'Daily or as needed until moisture recovers',
    'stage': 'All Stages',
  },
  'procedure': [
    'Check current soil moisture reading from the Strata sensor.',
    'Water the plot evenly using drip irrigation or a watering can.',
    'Avoid over-watering — target 40–70% moisture for most crops.',
    'Re-scan after 24 hours to confirm moisture has improved.',
    'Continue daily watering until sensor reads within the optimal range.',
  ],
};

// --- Flag Info ---

class _FlagInfo {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _FlagInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

/// Maps a raw server flag key to display metadata.
/// [mlSubtext] is passed through for the "No nutrients detected" case
/// so the server's diagnostic message appears as the subtitle.
_FlagInfo _getFlagInfo(String flagKey, String mlSubtext) {
  switch (flagKey) {
    case 'No nutrients detected':
      return _FlagInfo(
        title: 'No Nutrients Detected',
        subtitle: mlSubtext.isNotEmpty
            ? mlSubtext
            : 'No soil readings were detected. Make sure the sensor probe is '
              'fully inserted into the soil before rescanning.',
        icon: Icons.sensors_off_rounded,
        color: Colors.redAccent,
      );
    case 'Dry Soil':
      return _FlagInfo(
        title: 'Dry Soil',
        subtitle: 'Soil moisture is below optimal levels. Immediate watering is recommended.',
        icon: Icons.water_drop_outlined,
        color: Colors.orange,
      );
    case 'Waterlogged Soil':
      return _FlagInfo(
        title: 'Waterlogged Soil',
        subtitle: 'Soil moisture is above optimal levels. Allow the soil to drain before the next scan.',
        icon: Icons.water_rounded,
        color: Colors.blueAccent,
      );
    case 'High Acidity':
      return _FlagInfo(
        title: 'High Acidity',
        subtitle: 'Soil pH is below the optimal range. Consider lime application to raise pH.',
        icon: Icons.science_outlined,
        color: Colors.redAccent,
      );
    case 'High Alkalinity':
      return _FlagInfo(
        title: 'High Alkalinity',
        subtitle: 'Soil pH is above the optimal range. Consider acidifying amendments.',
        icon: Icons.science_rounded,
        color: Colors.purple,
      );
    case 'Low EC':
      return _FlagInfo(
        title: 'Low EC',
        subtitle: 'Electrical conductivity is below optimal. Nutrient concentration may be insufficient.',
        icon: Icons.bolt_outlined,
        color: Colors.amber,
      );
    case 'High EC':
      return _FlagInfo(
        title: 'High EC',
        subtitle: 'Electrical conductivity is above optimal. Salt stress may affect plant growth.',
        icon: Icons.bolt_rounded,
        color: Colors.deepOrange,
      );
    default:
      return _FlagInfo(
        title: flagKey,
        subtitle: '',
        icon: Icons.warning_amber_rounded,
        color: Colors.orange,
      );
  }
}

// --- Screen ---

class RehabProtocolsScreen extends ConsumerStatefulWidget {
  final ScanRecord scanRecord;

  const RehabProtocolsScreen({super.key, required this.scanRecord});

  @override
  ConsumerState<RehabProtocolsScreen> createState() => _RehabProtocolsScreenState();
}

class _RehabProtocolsScreenState extends ConsumerState<RehabProtocolsScreen> {
  late Future<Map<String, dynamic>> _concoctionsFuture;

  @override
  void initState() {
    super.initState();
    _concoctionsFuture = rootBundle.loadString('concoctions.json').then((s) => json.decode(s));
  }

  Future<void> _exportToPdf(List<Map<String, dynamic>> recommendedConcoctions) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                text: 'Soil Rehabilitation Report',
              ),
              pw.Text('Generated for Plot: ${widget.scanRecord.plotName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.Text('Date: ${widget.scanRecord.timestamp}'),
              pw.Text('Soil Type: ${widget.scanRecord.soilType}'),
              pw.SizedBox(height: 20),
              
              pw.Text('Diagnostic Readings', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('pH Level: ${widget.scanRecord.soilPh.toStringAsFixed(1)}'),
                  pw.Text('Moisture: ${widget.scanRecord.moisture.toStringAsFixed(0)}%'),
                  pw.Text('Temperature: ${widget.scanRecord.temperature.toStringAsFixed(1)} C'),
                ]
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Nitrogen (N): ${widget.scanRecord.nitrogen} mg/kg'),
                  pw.Text('Phosphorus (P): ${widget.scanRecord.phosphorus} mg/kg'),
                  pw.Text('Potassium (K): ${widget.scanRecord.potassium} mg/kg'),
                ]
              ),
              pw.SizedBox(height: 8),
              pw.Text('Electrical Conductivity (EC): ${widget.scanRecord.ecLevel.toStringAsFixed(2)} uS/cm'),
              
              pw.SizedBox(height: 30),
              
              pw.Text('Recommended Rehabilitation Methods', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.Divider(),
              pw.SizedBox(height: 10),

              ...recommendedConcoctions.expand((concoction) {
                final procedureList = concoction['procedure'] as List;
                return [
                  pw.Text('${concoction['id']}: ${concoction['name']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text(concoction['description']),
                  pw.SizedBox(height: 5),
                  pw.Text('Purpose: ${concoction['purpose']}'),
                  pw.SizedBox(height: 10),
                  pw.Text('Preparation Procedure', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  ...procedureList.asMap().entries.map((step) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('${step.key + 1}. ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Expanded(child: pw.Text(step.value)),
                        ]
                      )
                    );
                  }),
                  pw.SizedBox(height: 20),
                ];
              }),
            ];
          },
        ),
      );

      if (context.mounted) {
        final pdfBytes = await pdf.save();
        final safePlotName = widget.scanRecord.plotName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
        String filename = '${safePlotName}_rehab_protocol.pdf';

        final extDir = await getExternalStorageDirectory();
        final saveDir = extDir != null
            ? Directory('${extDir.path}').parent.parent.parent.parent
            : await getApplicationDocumentsDirectory();

        final downloadPath = Directory('${saveDir.path}/Download');
        if (!await downloadPath.exists()) {
          await downloadPath.create(recursive: true);
        }

        final filePath = '${downloadPath.path}/$filename';
        final file = File(filePath);
        await file.writeAsBytes(pdfBytes);

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
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded,
                          color: AppColors.primary, size: 40),
                    ),
                    const SizedBox(height: 16),
                    const Text('PDF Exported!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      'Rehabilitation report saved to:',
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Rehabilitation', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _concoctionsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final data = snapshot.data!;
            final concoctionsList = data['concoctions'] as List;
            
            // Extract multiple recommended IDs from rehabRecommendations
            final rawRec = widget.scanRecord.rehabRecommendations;
            List<String> recommendedIds = [];
            try {
              final decoded = jsonDecode(rawRec);
              if (decoded is List) {
                recommendedIds = decoded.map((e) => e.toString()).toList();
              }
            } catch (_) {
              // Fallback for older non-JSON string formats
              recommendedIds = rawRec.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            }
            
            final List<Map<String, dynamic>> recommendedConcoctions = [];
            for (final id in recommendedIds) {
              if (id == 'WATER') {
                // WATER is a built-in step, not loaded from concoctions.json
                recommendedConcoctions.add(_waterConcoction);
              } else {
                final c = concoctionsList.firstWhere(
                  (c) => c['id'] == id,
                  orElse: () => null,
                );
                if (c != null) recommendedConcoctions.add(Map<String, dynamic>.from(c));
              }
            }
            // No fallback: if rehab is empty, render nothing.
            // An empty rehab list is a valid server response (e.g. invalid sensor read).

            final hasAssessment = widget.scanRecord.mlDeficiencies.isNotEmpty || widget.scanRecord.mlFlags.isNotEmpty;

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      // Header stats
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.cardDark : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.terrain_rounded, color: AppColors.primary, size: 24),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(widget.scanRecord.plotName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(widget.scanRecord.soilType, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7), fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(height: 1),
                              ),
                              Wrap(
                                spacing: 24,
                                runSpacing: 16,
                                alignment: WrapAlignment.center,
                                children: [
                                  _buildStatChip('N', '${widget.scanRecord.nitrogen}', Colors.teal),
                                  _buildStatChip('P', '${widget.scanRecord.phosphorus}', Colors.purple),
                                  _buildStatChip('K', '${widget.scanRecord.potassium}', Colors.orange),
                                  _buildStatChip('EC', widget.scanRecord.ecLevel.toStringAsFixed(2), Colors.blue),
                                  _buildStatChip('Moisture', '${widget.scanRecord.moisture.toStringAsFixed(0)}%', Colors.blueAccent),
                                  _buildStatChip('Temp', '${widget.scanRecord.temperature.toStringAsFixed(1)}°C', Colors.redAccent),
                                  _buildStatChip('pH', widget.scanRecord.soilPh.toStringAsFixed(1), Colors.green),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                      
                      if (hasAssessment)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.cardDark : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 20),
                                    const SizedBox(width: 8),
                                    Text('Soil Assessment', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (widget.scanRecord.mlDeficiencies.isNotEmpty) ...[
                                  Text('Deficiencies:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: colorScheme.onSurface.withOpacity(0.7))),
                                  const SizedBox(height: 4),
                                  ...widget.scanRecord.mlDeficiencies.map((d) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('• ', style: TextStyle(color: Colors.redAccent)),
                                        Expanded(child: Text(d, style: const TextStyle(fontSize: 12, height: 1.4))),
                                      ],
                                    ),
                                  )),
                                  const SizedBox(height: 8),
                                ],
                                if (widget.scanRecord.mlFlags.isNotEmpty) ...[
                                  Text(
                                    'Physical Flags:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...widget.scanRecord.mlFlags.map((f) {
                                    final info = _getFlagInfo(
                                      f,
                                      widget.scanRecord.mlSubtext,
                                    );
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(top: 2),
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: info.color.withOpacity(0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(info.icon, size: 14, color: info.color),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  info.title,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: info.color,
                                                    height: 1.3,
                                                  ),
                                                ),
                                                if (info.subtitle.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 2),
                                                    child: Text(
                                                      info.subtitle,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        height: 1.4,
                                                        color: colorScheme.onSurface.withOpacity(0.7),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                        ),

                      // Only render the section heading and cards when the
                      // server actually provided rehab recommendations.
                      if (recommendedConcoctions.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                          child: Text(
                            'Recommended Rehabilitation',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        ...recommendedConcoctions.map((concoction) {
                          return _ConcoctionExpandableCard(
                            key: ValueKey(concoction['id']),
                            concoction: concoction,
                            isDark: isDark,
                          );
                        }),
                      ],
                    ],
                  ),
                ),

                // Export Button at the bottom
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Material(
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      color: Colors.transparent,
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () => _exportToPdf(recommendedConcoctions),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 22),
                                SizedBox(width: 10),
                                Text(
                                  'Export Rehab Report as PDF',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 14)),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class _ConcoctionExpandableCard extends StatefulWidget {
  final Map<String, dynamic> concoction;
  final bool isDark;

  const _ConcoctionExpandableCard({super.key, required this.concoction, required this.isDark});

  @override
  State<_ConcoctionExpandableCard> createState() => _ConcoctionExpandableCardState();
}

class _ConcoctionExpandableCardState extends State<_ConcoctionExpandableCard> {
  int _currentTab = 0;
  late List<bool> _checkedSteps;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    final procedureList = widget.concoction['procedure'] as List;
    _checkedSteps = List.generate(procedureList.length, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final brandColor = _getColorForConcoction(widget.concoction['id']);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: _isExpanded ? brandColor : (widget.isDark ? AppColors.dividerDark : AppColors.primary.withOpacity(0.1)),
            width: _isExpanded ? 2 : 1,
          ),
        ),
        color: widget.isDark ? AppColors.cardDark : Colors.white,
        child: ExpansionTile(
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: brandColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getEmojiForConcoction(widget.concoction['id']),
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          title: Text(
            widget.concoction['id'],
            style: TextStyle(
              color: brandColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.concoction['name'],
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildMiniBadge(
                    _shortenText(widget.concoction['application']['dilution']),
                    Icons.water_drop_rounded,
                    brandColor,
                  ),
                  _buildMiniBadge(
                    _shortenText(widget.concoction['application']['frequency']),
                    Icons.calendar_month_rounded,
                    brandColor,
                  ),
                ],
              ),
            ],
          ),
          children: [
            // Tabs Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: widget.isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    _buildTab(0, 'Quick Facts', Icons.info_outline_rounded, brandColor),
                    _buildTab(1, 'Procedure', Icons.format_list_numbered_rounded, brandColor),
                    if (widget.concoction['id'] != 'WATER')
                      _buildTab(2, 'Maintenance', Icons.health_and_safety_rounded, brandColor),
                  ],
                ),
              ),
            ),
            
            // Tab Content
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildConcoctionTabContent(widget.concoction, widget.isDark, textTheme, colorScheme, brandColor),
            ),
          ],
        ),
      ),
    );
  }

  String _shortenText(String text) {
    if (text.contains('10mL per 1 liter')) text = text.replaceAll('10mL per 1 liter', '10mL/1L');
    if (text.contains('Apply 2 to 3 times per week')) return '2-3x / week';
    if (text.contains('2 tablespoons per liter')) return '2 tbsp/1L';
    if (text.contains('1-to-2-week land-resting')) return '1-2 weeks resting';
    if (text.contains('10mL/L for plants;')) return '10mL/1L (Plants)';
    return text.replaceAll('.', '');
  }

  Widget _buildMiniBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String title, IconData icon, Color brandColor) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? brandColor.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? brandColor : Colors.grey),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? brandColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConcoctionTabContent(Map<String, dynamic> concoction, bool isDark, TextTheme textTheme, ColorScheme colorScheme, Color brandColor) {
    switch (_currentTab) {
      case 0:
        return _buildQuickFactsTab(concoction, textTheme, colorScheme, brandColor);
      case 1:
        return _buildProcedureTab(concoction, isDark, textTheme, colorScheme, brandColor);
      case 2:
        return _buildMaintenanceTab(concoction, isDark, brandColor);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildQuickFactsTab(Map<String, dynamic> concoction, TextTheme textTheme, ColorScheme colorScheme, Color brandColor) {
    final application = concoction['application'];
    return Padding(
      key: const ValueKey(0),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            concoction['description'],
            style: textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),
          _buildFullWidthFactCard('Purpose', concoction['purpose'], Icons.track_changes_rounded, textTheme, brandColor),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildSmallFactCard('Growth Stage', application['stage'], Icons.grass_rounded, textTheme, brandColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSmallFactCard('Dilution', application['dilution'], Icons.water_drop_rounded, textTheme, brandColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildFullWidthFactCard('Frequency', application['frequency'], Icons.calendar_month_rounded, textTheme, brandColor),
        ],
      ),
    );
  }

  Widget _buildProcedureTab(Map<String, dynamic> concoction, bool isDark, TextTheme textTheme, ColorScheme colorScheme, Color brandColor) {
    final procedureList = concoction['procedure'] as List;
    
    return Padding(
      key: const ValueKey(1),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(procedureList.length, (index) {
          final isChecked = _checkedSteps[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _checkedSteps[index] = !_checkedSteps[index];
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isChecked 
                        ? brandColor.withOpacity(0.1) 
                        : (isDark ? AppColors.surfaceDark : AppColors.backgroundLight),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isChecked 
                          ? brandColor.withOpacity(0.5) 
                          : (isDark ? AppColors.dividerDark : AppColors.primary.withOpacity(0.1)),
                      width: isChecked ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2, right: 12),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isChecked ? brandColor : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isChecked ? brandColor : colorScheme.onSurface.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: isChecked
                            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                            : Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                ),
                              ),
                      ),
                      Expanded(
                        child: Text(
                          procedureList[index],
                          style: textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                            decoration: isChecked ? TextDecoration.lineThrough : null,
                            color: isChecked 
                                ? colorScheme.onSurface.withOpacity(0.5) 
                                : colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMaintenanceTab(Map<String, dynamic> concoction, bool isDark, Color brandColor) {
    return Padding(
      key: const ValueKey(2),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Follow these essential standards to preserve your ${concoction['id']} batch.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
          ),
          ..._maintenanceDataList.map((info) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MaintenanceCard(info: info, isDark: isDark),
              )),
          const SizedBox(height: 4),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MaintenanceCard(
                    info: _qualitySuccess,
                    isDark: isDark,
                    isCompact: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MaintenanceCard(
                    info: _qualityFailure,
                    isDark: isDark,
                    isCompact: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullWidthFactCard(String title, String value, IconData icon, TextTheme textTheme, Color brandColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: brandColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brandColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: brandColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title, 
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold, 
                  color: brandColor,
                )
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallFactCard(String title, String value, IconData icon, TextTheme textTheme, Color brandColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: brandColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brandColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: brandColor, size: 24),
          const SizedBox(height: 8),
          Text(
            title, 
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold, 
              color: brandColor,
            )
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  final MaintenanceInfo info;
  final bool isDark;
  final bool isCompact;

  const _MaintenanceCard({
    required this.info,
    required this.isDark,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? info.color.withOpacity(0.1) : info.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: info.color.withOpacity(isDark ? 0.2 : 0.15),
        ),
      ),
      child: isCompact ? _buildCompactContent() : _buildFullContent(),
    );
  }

  Widget _buildCompactContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(info.icon, color: info.color, size: 24),
        const SizedBox(height: 12),
        Text(
          info.title,
          style: TextStyle(color: info.color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          info.keyword,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          info.description,
          style: const TextStyle(fontSize: 11, height: 1.3),
        ),
      ],
    );
  }

  Widget _buildFullContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: info.color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(info.icon, color: info.color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.title,
                style: TextStyle(color: info.color, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                info.keyword,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                info.description,
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
