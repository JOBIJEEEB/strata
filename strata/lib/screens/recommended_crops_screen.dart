import 'package:flutter/material.dart';
import 'package:strata/database/database_service.dart';
import 'package:strata/theme/app_theme.dart';

class RecommendedCropsScreen extends StatelessWidget {
  final ScanRecord scanRecord;

  const RecommendedCropsScreen({super.key, required this.scanRecord});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final crops = scanRecord.cropRecommendation.split(',').map((e) => e.trim()).toList();

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
                  final crop = crops[index];
                  return _buildCropCard(crop, index, isDark, textTheme);
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

  Widget _buildCropCard(String name, int index, bool isDark, TextTheme textTheme) {
    // Basic mapping for icons/descriptions based on name
    final icon = _getCropIcon(name);
    final description = _getCropDescription(name);
    
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (index < 3)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'TOP PICK',
                          style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.w900),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildTag('Moderate Water'),
                    const SizedBox(width: 8),
                    _buildTag('Full Sun'),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }

  IconData _getCropIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('tomato')) return Icons.circle; // Close enough to a tomato
    if (n.contains('maize') || n.contains('corn')) return Icons.agriculture;
    if (n.contains('onion')) return Icons.brightness_low_rounded;
    if (n.contains('pepper')) return Icons.spa;
    return Icons.grass_rounded;
  }

  String _getCropDescription(String name) {
    final n = name.toLowerCase();
    if (n.contains('tomato')) return 'High demand for Nitrogen and Phosphorus. Requires consistent moisture.';
    if (n.contains('maize')) return 'A heavy feeder that thrives in your current soil conditions.';
    if (n.contains('onion')) return 'Requires loose soil and moderate fertilization.';
    if (n.contains('pechay')) return 'Fast-growing leafy green that benefits from your soil pH.';
    return 'Resilient variety that matches your soil nutrient profile perfectly.';
  }
}
