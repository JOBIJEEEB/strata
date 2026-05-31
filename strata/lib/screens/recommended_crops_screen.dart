import 'package:flutter/material.dart';
import 'package:strata/database/database_service.dart';
import 'package:strata/theme/app_theme.dart';
import 'dart:convert';

class RecommendedCropsScreen extends StatelessWidget {
  final ScanRecord scanRecord;

  const RecommendedCropsScreen({super.key, required this.scanRecord});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Parse JSON
    List<Map<String, dynamic>> crops = [];
    try {
      final parsed = jsonDecode(scanRecord.cropRecommendation);
      if (parsed is List) {
        crops = List<Map<String, dynamic>>.from(parsed);
      }
    } catch (_) {
      // Legacy handling
      final list = scanRecord.cropRecommendation.split(',').map((e) => e.trim()).toList();
      crops = list.map((c) => {'name': c, 'match': 50.0, 'tier': 'SUITABLE'}).toList();
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Suggested Crops', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header stats (Mirroring Rehab Screen)
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
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.eco_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(scanRecord.plotName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Soil Type: ${scanRecord.soilType}', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12)),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'HEALTHY',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildStatChip('N', '${scanRecord.nitrogen}', Colors.teal),
                        _buildStatChip('P', '${scanRecord.phosphorus}', Colors.purple),
                        _buildStatChip('K', '${scanRecord.potassium}', Colors.orange),
                        _buildStatChip('pH', scanRecord.soilPh.toStringAsFixed(1), Colors.green),
                        _buildStatChip('Moisture', '${scanRecord.moisture.toStringAsFixed(0)}%', Colors.blue),
                        _buildStatChip('Temp', '${scanRecord.temperature.toStringAsFixed(1)}°C', Colors.redAccent),
                        _buildStatChip('EC', scanRecord.ecLevel.toStringAsFixed(2), Colors.amber),
                      ],
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Best Matches for your Soil',
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: crops.length,
                itemBuilder: (context, index) {
                  final cropData = crops[index];
                  final rawName = cropData['name'] as String? ?? 'Unknown';
                  // Convert snake_case to Title Case (e.g. thai_basil → Thai Basil)
                  final name = rawName
                      .split('_')
                      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
                      .join(' ');
                  final confidence = (cropData['match'] as num?)?.toDouble() ?? 0.0;
                  final tier = (cropData['tier'] as String?) ?? 'SUITABLE';
                  return _buildCropCard(name, confidence, tier, index, isDark, textTheme, colorScheme);
                },
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

  Widget _buildCropCard(String name, double confidence, String tier, int index, bool isDark, TextTheme textTheme, ColorScheme colorScheme) {
    final icon = _getCropIcon(name);
    final tierStyle = _getTierStyle(tier);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tierStyle['color'] as Color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tierStyle['label'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getTierStyle(String tier) {
    switch (tier.toUpperCase()) {
      case 'OPTIMAL':
        return {'label': 'Optimal', 'color': const Color(0xFF2BB673)};
      case 'HIGHLY SUITABLE':
        return {'label': 'Highly Suitable', 'color': const Color(0xFF00897B)};
      case 'SUITABLE':
        return {'label': 'Suitable', 'color': const Color(0xFF1976D2)};
      default:
        return {'label': 'Suitable', 'color': const Color(0xFF1976D2)};
    }
  }



  IconData _getCropIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('tomato')) return Icons.circle;
    if (n.contains('maize') || n.contains('corn')) return Icons.agriculture;
    if (n.contains('onion')) return Icons.brightness_low_rounded;
    if (n.contains('pepper') || n.contains('siling')) return Icons.spa;
    if (n.contains('basil') || n.contains('herb') || n.contains('coriander') || n.contains('roselle')) return Icons.local_florist_rounded;
    if (n.contains('bean') || n.contains('gram') || n.contains('lentil') || n.contains('pea')) return Icons.grain_rounded;
    if (n.contains('cabbage') || n.contains('kale') || n.contains('pechay') || n.contains('lettuce') || n.contains('spinach')) return Icons.eco_rounded;
    if (n.contains('carrot') || n.contains('radish') || n.contains('beetroot') || n.contains('labanos') || n.contains('potato')) return Icons.grass_rounded;
    if (n.contains('cucumber') || n.contains('upo') || n.contains('patola') || n.contains('kalabasa') || n.contains('ampalaya')) return Icons.water_drop_rounded;
    if (n.contains('garlic')) return Icons.spa_rounded;
    if (n.contains('sugarcane') || n.contains('wheat') || n.contains('barley') || n.contains('ragi') || n.contains('jowar')) return Icons.agriculture_rounded;
    return Icons.grass_rounded;
  }
}
