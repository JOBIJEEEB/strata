import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strata/theme/app_theme.dart';
import 'package:strata/database/database_service.dart';
import 'package:strata/screens/tabs/history_tab.dart';
import 'package:strata/providers/providers.dart'; // Implements MockScanGenerator

class ScanFlowScreen extends ConsumerStatefulWidget {
  final String? initialPlotName;
  final String? initialSoilType;
  final ScanRecord? viewOnlyRecord;
  final int? updateId;

  const ScanFlowScreen({
    super.key,
    this.initialPlotName,
    this.initialSoilType,
    this.viewOnlyRecord,
    this.updateId,
  });

  @override
  ConsumerState<ScanFlowScreen> createState() => _ScanFlowScreenState();
}

class _ScanFlowScreenState extends ConsumerState<ScanFlowScreen> with SingleTickerProviderStateMixin {
  int _currentView = 0; 

  final _plotNameController = TextEditingController();
  final List<String> _soilChoices = ['Loam', 'Sandy', 'Clay', 'Silt'];
  String? _selectedSoilType; 

  late AnimationController _radarController;
  ScanRecord? _finalScanRecord;
  bool _isCropsExpanded = false;
  bool _isRehabExpanded = false;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(vsync: this, duration: const Duration(seconds: 2));

    if (widget.initialPlotName != null) {
      _plotNameController.text = widget.initialPlotName!;
    }
    if (widget.initialSoilType != null && _soilChoices.contains(widget.initialSoilType)) {
      _selectedSoilType = widget.initialSoilType;
    }

    if (widget.viewOnlyRecord != null) {
      _currentView = 2; // Fast forward directly to results
      _finalScanRecord = widget.viewOnlyRecord;
    }
  }

  @override
  void dispose() {
    _plotNameController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  void _beginScan() {
    FocusScope.of(context).unfocus(); 
    
    // Enforce Bluetooth check
    if (!ref.read(bleConnectionProvider).isConnected) {
      context.push('/pairing');
      return;
    }

    // Strict Soil Type Requirement
    if (_selectedSoilType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Soil Type to proceed.'), backgroundColor: Colors.redAccent)
      );
      return;
    }
    
    setState(() => _currentView = 1);
    _radarController.repeat();
    
    // Process internal logical evaluation mocking the BLE response bounds
    _finalScanRecord = SoilMockGenerator.generateMockScan(
      plotName: _plotNameController.text.trim(),
      soilType: _selectedSoilType!,
      overrideId: widget.updateId,
    );
    
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _radarController.stop();
        setState(() => _currentView = 2);
      }
    });
  }

  void _saveRecord() async {
    if (_finalScanRecord != null) {
      if (_finalScanRecord!.id != null) {
        await DatabaseService.instance.updateScan(_finalScanRecord!);
      } else {
        await DatabaseService.instance.insertScan(_finalScanRecord!);
      }
      ref.invalidate(scansProvider);
      
      final rootContext = context;
      if (mounted) {
        showDialog(
          context: rootContext,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Record saved successfully!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(rootContext); // Return to home/history
                },
                child: const Text('Okay', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  void _discardRecord() {
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
           widget.viewOnlyRecord != null 
             ? '${widget.viewOnlyRecord!.plotName}'
             : _currentView == 0 ? 'Configure Scan' : 
               _currentView == 1 ? 'Diagnostic Scan' : 'Scan Results'
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentView) {
      case 0: return _buildConfigView();
      case 1: return _buildScanningView();
      case 2: return _buildResultsView();
      default: return const SizedBox();
    }
  }

  // ── VIEW 1: CONFIG ────────────────────────────────────────────────────────
  Widget _buildConfigView() {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      key: const ValueKey('view0'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Image.asset('assets/strata_logo.png', height: 64, errorBuilder: (c, e, s) => const Icon(Icons.agriculture_rounded, size: 64, color: AppColors.primary)),
          const SizedBox(height: 16),
          Text(
            'Secure Soil Sample', 
            style: textTheme.headlineMedium, 
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 8),
          Text(
            'Place your soil sample inside the Strata chamber before configuring the scan context.',
            style: textTheme.bodyMedium?.copyWith(
               color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          TextField(
            controller: _plotNameController,
            decoration: InputDecoration(
              labelText: 'Plot Name',
              hintText: 'e.g. Tomato Bed 1',
              filled: true,
              fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Soil Type', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _soilChoices.map((type) {
              final isSelected = _selectedSoilType == type;
              return GestureDetector(
                onTap: () => setState(() => _selectedSoilType = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : (isDark ? AppColors.cardDark : AppColors.surfaceLight),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : (isDark ? AppColors.dividerDark : AppColors.dividerLight),
                      width: 2,
                    ),
                    boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.terrain_rounded, size: 18, color: isSelected ? Colors.white : AppColors.primary),
                      const SizedBox(width: 8),
                      Text(type, style: TextStyle(color: isSelected ? Colors.white : null, fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 64),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            icon: const Icon(Icons.sensors_rounded, size: 24, color: Colors.white),
            label: const Text('Scan Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: () {
              if (_plotNameController.text.trim().isEmpty) {
                 _plotNameController.text = 'Unnamed Plot';
              }
              _beginScan();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── VIEW 2: ACTIVE SCAN ───────────────────────────────────────────────────
  Widget _buildScanningView() {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      key: const ValueKey('view1'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RotationTransition(
            turns: _radarController,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 40,
                    spreadRadius: 10,
                  )
                ]
              ),
              child: const Icon(Icons.sensors_rounded, color: AppColors.primary, size: 72),
            ),
          ),
          const SizedBox(height: 48),
          Text('Reading Soil Diagnostics', style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(
            'Calibrating electrochemical properties...\nPlease keep the probe steady.',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ── VIEW 3: RESULTS (Bento Grid) Compressed ───────────────────────────────
  Widget _buildResultsView() {
    final scan = _finalScanRecord!;
    final isHealthy = scan.healthStatus == 'Healthy';
    
    // Minimal spacing variables
    const double outerPad = 10.0;
    const double gapPad = 6.0; 

    // Organic Farming dynamic parameter evaluation logic
    Color evaluateN(int n) => n >= 40 ? Colors.green : (n >= 25 ? Colors.orange : Colors.red);
    Color evaluateP(int p) => p >= 25 ? Colors.green : (p >= 15 ? Colors.orange : Colors.red);
    Color evaluateK(int k) => k >= 30 ? Colors.green : (k >= 20 ? Colors.orange : Colors.red);
    Color evaluatePh(double ph) => (ph >= 5.8 && ph <= 7.5) ? Colors.green : Colors.orange;
    Color evaluateMoisture(double m) => (m >= 40 && m <= 80) ? Colors.green : (m >= 20 ? Colors.orange : Colors.red);
    Color evaluateEc(double ec) => ec <= 1.5 ? Colors.green : Colors.orange;
    Color evaluateTemp(double t) => (t >= 18 && t <= 28) ? Colors.green : Colors.orange;

    return SingleChildScrollView(
      key: const ValueKey('view2'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dynamic Rehab or Hero Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isHealthy 
                    ? [const Color(0xFF2BB673), const Color(0xFF1E8A55)] 
                    : [const Color(0xFFFF5722), const Color(0xFFD32F2F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (isHealthy ? Colors.green : Colors.red).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6)
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isHealthy ? Icons.check_circle_rounded : Icons.warning_amber_rounded, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            isHealthy ? 'Healthy Soil' : 'Rehab Required', 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.3)
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Type: ${scan.soilType}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isHealthy) ...[
                  _buildCropRecommendation(scan.cropRecommendation, inHeader: true),
                ] else ...[
                  _buildRehabProtocols(scan.cropRecommendation, inHeader: true),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),
          Text('Nutrient Overview', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),


          // Bento Middle Matrix - NPK (3 Columns)
          Row(
            children: [
              Expanded(child: _BentoBox(icon: Icons.eco_rounded, label: 'Nitrogen', value: scan.nitrogen.toString(), unit: 'mg/kg', color: evaluateN(scan.nitrogen))),
              const SizedBox(width: gapPad),
              Expanded(child: _BentoBox(icon: Icons.science_rounded, label: 'Phosphorus', value: scan.phosphorus.toString(), unit: 'mg/kg', color: evaluateP(scan.phosphorus))),
              const SizedBox(width: gapPad),
              Expanded(child: _BentoBox(icon: Icons.spa_rounded, label: 'Potassium', value: scan.potassium.toString(), unit: 'mg/kg', color: evaluateK(scan.potassium))),
            ],
          ),
          
          const SizedBox(height: 10),

          // Bento Bottom Base - Moisture & Temp
          Row(
            children: [
              Expanded(child: _BentoBox(icon: Icons.water_drop_rounded, label: 'Moisture', value: scan.moisture.toStringAsFixed(1), unit: '%', color: evaluateMoisture(scan.moisture))),
              const SizedBox(width: gapPad),
              Expanded(child: _BentoBox(icon: Icons.thermostat_rounded, label: 'Temperature', value: scan.temperature.toStringAsFixed(1), unit: '°C', color: evaluateTemp(scan.temperature))),
            ],
          ),

          const SizedBox(height: 6),

          // Bento Floor - pH & EC
          Row(
            children: [
              Expanded(child: _BentoBox(icon: Icons.speed_rounded, label: 'pH Level', value: scan.soilPh.toStringAsFixed(1), unit: 'pH', color: evaluatePh(scan.soilPh))),
              const SizedBox(width: gapPad),
              Expanded(child: _BentoBox(icon: Icons.bolt_rounded, label: 'EC Level', value: scan.ecLevel.toStringAsFixed(2), unit: 'mS/cm', color: evaluateEc(scan.ecLevel))),
            ],
          ),

          const SizedBox(height: 10),
          
          // Action Buttons Contextually Generated
          if (widget.viewOnlyRecord != null)
             ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Rescan this Plot', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                onPressed: () {
                   context.pushReplacement('/scan', extra: {
                     'plotName': scan.plotName, // Pre-fill directly from db
                     'soilType': scan.soilType, 
                     'updateId': scan.id, // Direct UPDATE hook
                   });
                },
             )
          else 
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.redAccent),
                      foregroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _discardRecord,
                    child: const Text('Discard', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.save_rounded, size: 20, color: Colors.white),
                    label: const Text('Save Record', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    onPressed: _saveRecord,
                  ),
                ),
              ],
            ),
            
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCropRecommendation(String cropsText, {bool inHeader = false}) {
    final crops = cropsText.split(',').map((e) => e.trim()).toList();
    final displayCrops = _isCropsExpanded ? crops.take(8).toList() : crops.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Recommended Crops', 
                style: (inHeader ? const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900) : Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _isCropsExpanded = !_isCropsExpanded),
              child: Text(
                _isCropsExpanded ? 'Show Less' : 'View More', 
                style: TextStyle(fontWeight: FontWeight.bold, color: inHeader ? Colors.white70 : AppColors.primary)
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Built-in Hierarchy: Emphasize Top 3
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: displayCrops.asMap().entries.map((entry) {
             final index = entry.key;
             final crop = entry.value;
             final isTopTier = index < 3;
             return _buildCropBadge(crop, isTopTier: isTopTier, inHeader: inHeader);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCropBadge(String name, {bool isTopTier = false, bool inHeader = false}) {
    final bgColor = inHeader 
        ? (isTopTier ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.12))
        : (isTopTier ? AppColors.primary : AppColors.primary.withOpacity(0.1));
    
    final textColor = inHeader 
        ? Colors.white 
        : (isTopTier ? Colors.white : AppColors.primary);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isTopTier ? 16 : 12, vertical: isTopTier ? 10 : 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: inHeader ? Colors.white.withOpacity(0.2) : AppColors.primary.withOpacity(0.3),
          width: isTopTier ? 2 : 1,
        ),
        boxShadow: isTopTier && !inHeader ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))] : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isTopTier ? Icons.star_rounded : Icons.grass_rounded, size: isTopTier ? 18 : 14, color: textColor),
          const SizedBox(width: 8),
          Text(
            name, 
            style: TextStyle(
              fontWeight: isTopTier ? FontWeight.w900 : FontWeight.bold, 
              fontSize: isTopTier ? 15 : 13,
              color: textColor,
            )
          ),
        ],
      ),
    );
  }

  Widget _buildRehabProtocols(String rehabText, {bool inHeader = false}) {
    final protocols = rehabText.split(',').map((e) => e.trim()).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Organic Rehab Protocols', 
                style: inHeader 
                  ? const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                  : Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => setState(() => _isRehabExpanded = !_isRehabExpanded),
              child: Text(
                _isRehabExpanded ? 'Hide' : 'Expand', 
                style: TextStyle(fontWeight: FontWeight.bold, color: inHeader ? Colors.white : Colors.orange, fontSize: 13)
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: Column(
            children: [
              if (!_isRehabExpanded)
                _buildSimpleRehabList(protocols.take(2).toList(), inHeader: inHeader)
              else
                ...protocols.asMap().entries.map((entry) {
                  return _buildRehabStep(entry.key + 1, entry.value, inHeader: inHeader);
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleRehabList(List<String> items, {bool inHeader = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: inHeader ? Colors.white.withOpacity(0.12) : Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inHeader ? Colors.white.withOpacity(0.15) : Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            children: [
              Icon(Icons.circle, size: 4, color: inHeader ? Colors.white : Colors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item, 
                  style: TextStyle(
                    fontWeight: FontWeight.w600, 
                    fontSize: 12, 
                    color: inHeader ? Colors.white : null
                  ),
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                )
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildRehabStep(int count, String text, {bool inHeader = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: inHeader 
          ? Colors.white.withOpacity(0.15) 
          : (Theme.of(context).brightness == Brightness.dark ? AppColors.cardDark : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: inHeader ? Colors.white.withOpacity(0.1) : Colors.orange.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$count.', style: TextStyle(color: inHeader ? Colors.white : Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text, 
              style: TextStyle(
                fontWeight: FontWeight.w600, 
                fontSize: 12, 
                color: inHeader ? Colors.white : null
              )
            )
          ),
        ],
      ),
    );
  }
}

class _BentoBox extends StatelessWidget {
  const _BentoBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(isDark ? 0.4 : 0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (color != Colors.green)
                Icon(Icons.warning_amber_rounded, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.w600))
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(width: 2),
                Text(unit, style: textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
