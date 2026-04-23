import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

import 'package:strata/database/database_service.dart';
import 'package:strata/theme/app_theme.dart';
import 'package:strata/data/rehab_protocols_data.dart';

class RehabProtocolsScreen extends ConsumerStatefulWidget {
  final ScanRecord scanRecord;

  const RehabProtocolsScreen({super.key, required this.scanRecord});

  @override
  ConsumerState<RehabProtocolsScreen> createState() => _RehabProtocolsScreenState();
}

class _RehabProtocolsScreenState extends ConsumerState<RehabProtocolsScreen> {
  int _currentTab = 0;

  Future<void> _exportToPdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              text: 'Soil Rehabilitation Protocol',
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
                pw.Text('Temperature: ${widget.scanRecord.temperature.toStringAsFixed(1)}°C'),
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
            pw.Text('Electrical Conductivity (EC): ${widget.scanRecord.ecLevel.toStringAsFixed(2)} mS/cm'),
            
            pw.SizedBox(height: 30),
            
            pw.Text('Required Materials', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.Divider(),
            ...RehabContent.materials.map((m) => pw.Bullet(text: m)),
            
            pw.SizedBox(height: 20),
            
            pw.Text('Required Equipment', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.Divider(),
            ...RehabContent.equipment.map((e) => pw.Bullet(text: e)),
            
            pw.SizedBox(height: 20),
            
            pw.Text('Action Procedure', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.Divider(),
            ...RehabContent.procedureSteps.asMap().entries.map((step) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${step.key + 1}. ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Expanded(child: pw.Text(step.value)),
                  ]
                )
              );
            }),
          ];
        },
      ),
    );

    if (context.mounted) {
      final pdfBytes = await pdf.save();
      String filename = '${widget.scanRecord.plotName.replaceAll(' ', '_')}_rehab_protocol.pdf';

      // Save directly to Downloads folder (reliable on Android)
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
                      color: AppColors.primary.withValues(alpha: 0.1),
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
      bottomNavigationBar: SafeArea(
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
                    color: Colors.red.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: InkWell(
                onTap: _exportToPdf,
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
      body: SafeArea(
        child: Column(
          children: [
            // Header stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.05),
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
                            Text(widget.scanRecord.soilType, style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12)),
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
            
            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    _buildTab(0, 'Materials', Icons.inventory_2_rounded),
                    _buildTab(1, 'Equipment', Icons.hardware_rounded),
                    _buildTab(2, 'Procedure', Icons.format_list_numbered_rounded),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildTabContent(isDark, textTheme, colorScheme),
              ),
            ),
          ],
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

  Widget _buildTab(int index, String title, IconData icon) {
    final isSelected = _currentTab == index;
    final primary = AppColors.primary;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? primary : Colors.grey),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? primary : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(bool isDark, TextTheme textTheme, ColorScheme colorScheme) {
    switch (_currentTab) {
      case 0:
        return _buildListCard(RehabContent.materials, Colors.green, isDark, textTheme);
      case 1:
        return _buildListCard(RehabContent.equipment, Colors.orange, isDark, textTheme);
      case 2:
        return _buildProcedureCard(isDark, textTheme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildListCard(List<String> items, Color iconColor, bool isDark, TextTheme textTheme) {
    return ListView.builder(
      key: ValueKey(_currentTab),
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                child: Text(
                  '${index + 1}.',
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  items[index],
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProcedureCard(bool isDark, TextTheme textTheme) {
    return ListView.builder(
      key: const ValueKey(2),
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24, top: 8),
      itemCount: RehabContent.procedureSteps.length,
      itemBuilder: (context, index) {
        final step = RehabContent.procedureSteps[index];
        final parts = step.split(': ');
        final title = parts.isNotEmpty ? parts[0] : '';
        final description = parts.length > 1 ? parts[1] : '';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
                if (index < RehabContent.procedureSteps.length - 1)
                  Container(
                    width: 2,
                    height: 60,
                    color: AppColors.primary.withValues(alpha: 0.2),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description.isNotEmpty ? description : step,
                      style: textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
