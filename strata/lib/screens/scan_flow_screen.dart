import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strata/theme/app_theme.dart';
import 'package:strata/theme/components.dart';
import 'package:strata/database/database_service.dart';
import 'package:strata/screens/tabs/history_tab.dart';
import 'package:strata/providers/providers.dart';
import 'package:strata/services/ble_service.dart';

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

class _ScanFlowScreenState extends ConsumerState<ScanFlowScreen>
    with TickerProviderStateMixin {
  int _currentView = 0;

  final _plotNameController = TextEditingController();
  final List<String> _soilChoices = ['Clay', 'Coarse', 'Loamy', 'Sandy', 'Sandy & Loamy', 'Silt', 'Any'];
  String? _selectedSoilType;

  late AnimationController _radarController;
  late AnimationController _progressController;
  ScanRecord? _finalScanRecord;
  bool _isCropsExpanded = false;


  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    if (widget.initialPlotName != null) {
      _plotNameController.text = widget.initialPlotName!;
    }
    if (widget.initialSoilType != null &&
        _soilChoices.contains(widget.initialSoilType)) {
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
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _beginScan() async {
    FocusScope.of(context).unfocus();

    if (!ref.read(bleConnectionProvider).isConnected) {
      context.push('/pairing');
      return;
    }

    if (_selectedSoilType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Soil Type to proceed.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _currentView = 1;
      _finalScanRecord = null;   // Clear any previous scan result
      _isCropsExpanded = false;  // Reset UI expansion state
    });
    _radarController.repeat();
    _progressController.reset();
    _progressController.forward();

    // ── Debug mode: use mock data ──────────────────────────────────────────
    if (kBleDebugMode) {
      await Future.delayed(const Duration(seconds: 10)); // Faster mock for testing
      _finalScanRecord = SoilMockGenerator.generateMockScan(
        plotName: _plotNameController.text.trim(),
        soilType: _selectedSoilType!,
        overrideId: widget.updateId,
      );
      if (mounted) {
        _radarController.stop();
        _progressController.animateTo(1.0, duration: const Duration(milliseconds: 500));
        await Future.delayed(const Duration(milliseconds: 600));
        setState(() => _currentView = 2);
      }
      return;
    }

    // ── Production: read from Pi over BLE ─────────────────────────────────
    try {
      final reading = await ref
          .read(bleServiceProvider)
          .readSoilScan(); // Uses the new 75s default timeout

      final plotName = _plotNameController.text.trim().isEmpty
          ? 'Unnamed Plot'
          : _plotNameController.text.trim();

      // Parse ML JSON
      List<String> parsedFlags = [];
      List<String> parsedDeficiencies = [];
      String parsedRehab = '[]';
      String cropJson = '[]';
      String parsedHealthStatus = 'Healthy';
      String parsedSubtext = '';
      
      try {
        if (reading.mlJson.isNotEmpty && reading.mlJson != '{}') {
          final Map<String, dynamic> parsedMl = jsonDecode(reading.mlJson);
          
          if (parsedMl['crops'] != null) {
            cropJson = jsonEncode(parsedMl['crops']);
          }
          
          if (parsedMl['ml_flags'] != null) {
            parsedFlags = List<String>.from(parsedMl['ml_flags']);
          }
          
          if (parsedMl['ml_deficiencies'] != null) {
            final Map<String, dynamic> defs = parsedMl['ml_deficiencies'];
            parsedDeficiencies = defs.entries
                .map((e) => "${e.key} deficit: ${e.value} mg/kg")
                .toList();
          }

          if (parsedMl['rehab'] != null) {
            parsedRehab = jsonEncode(parsedMl['rehab']);
          }

          // Optional subtitle for the primary flag (e.g. sensor error message)
          parsedSubtext = parsedMl['ml_subtext'] as String? ?? '';

          // has_crop_match is the authoritative routing gate:
          //   true  → crop recommendations screen (crops list will be populated)
          //   false → soil rehabilitation screen (show rehab + ml_flags instead)
          // Defaults to true if the field is absent (safe fallback for older payloads).
          final hasCropMatch = parsedMl['has_crop_match'] as bool? ?? true;
          parsedHealthStatus = hasCropMatch ? 'Healthy' : 'Unhealthy';
        }
      } catch (e) {
        debugPrint('Error parsing ML JSON: $e');
        // Fallback to basic rule-based check
        final isHealthy = reading.soilPh >= 5.8 &&
            reading.soilPh <= 7.5 &&
            reading.nitrogen >= 40 &&
            reading.phosphorus >= 25 &&
            reading.potassium >= 30;
        parsedHealthStatus = isHealthy ? 'Healthy' : 'Unhealthy';
      }

      _finalScanRecord = ScanRecord(
        id: widget.updateId,
        plotName: plotName,
        soilType: _selectedSoilType!,
        timestamp: DateTime.now().toIso8601String(),
        soilPh: reading.soilPh,
        moisture: reading.moisture,
        temperature: reading.soilTemp,
        ecLevel: reading.ecLevel,
        nitrogen: reading.nitrogen,
        phosphorus: reading.phosphorus,
        potassium: reading.potassium,
        healthStatus: parsedHealthStatus,
        cropRecommendation: cropJson,
        mlFlags: parsedFlags,
        mlDeficiencies: parsedDeficiencies,
        rehabRecommendations: parsedRehab,
        mlSubtext: parsedSubtext,
      );

      if (mounted) {
        _radarController.stop();
        _progressController.animateTo(1.0, duration: const Duration(milliseconds: 500));
        await Future.delayed(const Duration(milliseconds: 600));
        setState(() => _currentView = 2);
      }
    } catch (e) {
      if (mounted) {
        _radarController.stop();
        _progressController.stop();
        setState(() => _currentView = 0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('TimeoutException')
                  ? 'Scan timed out. Check the Pi sensor and try again.'
                  : 'Scan failed: $e',
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _saveRecord() async {
    if (_finalScanRecord != null) {
      if (_finalScanRecord!.id != null) {
        await DatabaseService.instance.updateScan(_finalScanRecord!);
      } else {
        await DatabaseService.instance.insertScan(_finalScanRecord!);
      }
      ref.invalidate(scansProvider);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Success'),
                content: const Text('Record saved successfully!'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Okay',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
              ? widget.viewOnlyRecord!.plotName
              : _currentView == 0
              ? 'Configure Scan'
              : _currentView == 1
              ? 'Diagnostic Scan'
              : 'Scan Results',
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
      case 0:
        return _buildConfigView();
      case 1:
        return _buildScanningView();
      case 2:
        return _buildResultsView();
      default:
        return const SizedBox();
    }
  }

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
          Semantics(
            label: 'Strata Logo',
            child: Image.asset(
              'assets/strata_logo.png',
              height: 64,
              errorBuilder:
                  (c, e, s) => const Icon(
                    Icons.agriculture_rounded,
                    size: 64,
                    color: AppColors.primary,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Secure Soil Sample',
            style: textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Place your soil sample inside the Strata chamber before configuring the scan context.',
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          TextField(
            controller: _plotNameController,
            decoration: const InputDecoration(
              labelText: 'Plot Name',
              hintText: 'e.g. Tomato Bed 1',
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Soil Type',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                _soilChoices.map((type) {
                  final isSelected = _selectedSoilType == type;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSoilType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.cardDark
                                    : AppColors.surfaceLight),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              isSelected
                                  ? AppColors.primary
                                  : (isDark
                                      ? AppColors.dividerDark
                                      : AppColors.dividerLight),
                          width: 2,
                        ),
                        boxShadow:
                            isSelected
                                ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                                : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.terrain_rounded,
                            size: 18,
                            color:
                                isSelected ? Colors.white : AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            type,
                            style: TextStyle(
                              color: isSelected ? Colors.white : null,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 64),
          StrataButton(
            label: 'Scan Data',
            icon: Icons.sensors_rounded,
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

  Widget _buildScanningView() {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      key: const ValueKey('view1'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: 'Scanning active',
              child: RotationTransition(
                turns: _radarController,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sensors_rounded,
                    color: AppColors.primary,
                    size: 64,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              'Reading Soil Diagnostics',
              style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progressController.value,
                        minHeight: 12,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${(_progressController.value * 100).toInt()}% Complete',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Strata is performing a 10-point sensor averaging analysis for maximum precision.\nThis process takes approximately 20 seconds.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    final scan = _finalScanRecord!;
    final isHealthy = scan.healthStatus == 'Healthy';
    const double gapPad = 8.0;

    return SingleChildScrollView(
      key: const ValueKey('view2'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    isHealthy
                        ? [const Color(0xFF2BB673), const Color(0xFF1E8A55)]
                        : [const Color(0xFFFF5722), const Color(0xFFD32F2F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: (isHealthy ? Colors.green : Colors.red).withValues(
                    alpha: 0.3,
                  ),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Badge(
                      label: Text(
                        isHealthy ? 'HEALTHY' : 'REHAB NEEDED',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    Text(
                      scan.soilType,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isHealthy)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.eco_rounded),
                    label: const Text('View Recommended Crops', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => context.push('/recommended-crops', extra: {'scanRecord': scan}),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFD32F2F),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.medical_services_rounded),
                    label: const Text('View Rehabilitation Protocols', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => context.push('/rehab-protocols', extra: {'scanRecord': scan}),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Nutrient Analysis',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          Builder(builder: (context) {
            bool hasCrops = false;
            try {
              final List decoded = jsonDecode(scan.cropRecommendation);
              hasCrops = decoded.isNotEmpty;
            } catch(_) {}
            
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: BentoBox(
                        icon: Icons.eco_rounded,
                        label: 'Nitrogen',
                        value: scan.nitrogen.toString(),
                        unit: 'mg/kg',
                        color: _evaluateN(scan.nitrogen, hasCrops),
                      ),
                    ),
                    const SizedBox(width: gapPad),
                    Expanded(
                      child: BentoBox(
                        icon: Icons.science_rounded,
                        label: 'Phosphorus',
                        value: scan.phosphorus.toString(),
                        unit: 'mg/kg',
                        color: _evaluateP(scan.phosphorus, hasCrops),
                      ),
                    ),
                    const SizedBox(width: gapPad),
                    Expanded(
                      child: BentoBox(
                        icon: Icons.spa_rounded,
                        label: 'Potassium',
                        value: scan.potassium.toString(),
                        unit: 'mg/kg',
                        color: _evaluateK(scan.potassium, hasCrops),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: gapPad),
                Row(
                  children: [
                    Expanded(
                      child: BentoBox(
                        icon: Icons.water_drop_rounded,
                        label: 'Moisture',
                        value: scan.moisture.toStringAsFixed(1),
                        unit: '%',
                        color: _evaluateMoisture(scan.moisture, hasCrops),
                      ),
                    ),
                    const SizedBox(width: gapPad),
                    Expanded(
                      child: BentoBox(
                        icon: Icons.thermostat_rounded,
                        label: 'Temp',
                        value: scan.temperature.toStringAsFixed(1),
                        unit: '°C',
                        color: _evaluateTemp(scan.temperature, hasCrops),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: gapPad),
                Row(
                  children: [
                    Expanded(
                      child: BentoBox(
                        icon: Icons.speed_rounded,
                        label: 'pH Level',
                        value: scan.soilPh.toStringAsFixed(1),
                        unit: 'pH',
                        color: _evaluatePh(scan.soilPh, hasCrops),
                      ),
                    ),
                    const SizedBox(width: gapPad),
                    Expanded(
                      child: BentoBox(
                        icon: Icons.bolt_rounded,
                        label: 'EC Level',
                        value: scan.ecLevel.toStringAsFixed(2),
                        unit: 'µS/cm',
                        color: _evaluateEc(scan.ecLevel, hasCrops),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
          const SizedBox(height: 32),
          if (widget.viewOnlyRecord != null)
            StrataButton(
              label: 'Rescan Plot',
              icon: Icons.refresh_rounded,
              onPressed: () {
                context.pushReplacement(
                  '/scan',
                  extra: {
                    'plotName': scan.plotName,
                    'soilType': scan.soilType,
                  },
                );
              },
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _discardRecord,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Discard',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: StrataButton(
                    label: 'Save Record',
                    icon: Icons.save_rounded,
                    onPressed: _saveRecord,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Color _evaluateN(int n, bool hasCrops) =>
      hasCrops ? Colors.green : (n >= 40 ? Colors.green : (n >= 25 ? Colors.orange : Colors.red));
  Color _evaluateP(int p, bool hasCrops) =>
      hasCrops ? Colors.green : (p >= 25 ? Colors.green : (p >= 15 ? Colors.orange : Colors.red));
  Color _evaluateK(int k, bool hasCrops) =>
      hasCrops ? Colors.green : (k >= 30 ? Colors.green : (k >= 20 ? Colors.orange : Colors.red));
  Color _evaluatePh(double ph, bool hasCrops) =>
      hasCrops ? Colors.green : ((ph >= 5.8 && ph <= 7.5) ? Colors.green : Colors.orange);
  Color _evaluateMoisture(double m, bool hasCrops) =>
      hasCrops ? Colors.blue : ((m >= 40 && m <= 80) ? Colors.blue : (m >= 20 ? Colors.orange : Colors.red));
  Color _evaluateEc(double ec, bool hasCrops) =>
      hasCrops ? Colors.amber : (ec <= 1.5 ? Colors.amber : Colors.orange);
  Color _evaluateTemp(double t, bool hasCrops) =>
      hasCrops ? Colors.redAccent : ((t >= 18 && t <= 28) ? Colors.redAccent : Colors.orange);


}
