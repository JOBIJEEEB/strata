import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strata/theme/app_theme.dart';
import 'package:strata/theme/components.dart';
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

class _ScanFlowScreenState extends ConsumerState<ScanFlowScreen>
    with SingleTickerProviderStateMixin {
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
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
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
    super.dispose();
  }

  void _beginScan() {
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

    setState(() => _currentView = 1);
    _radarController.repeat();

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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            label: 'Scanning active',
            child: RotationTransition(
              turns: _radarController,
              child: Container(
                width: 160,
                height: 160,
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
                  size: 72,
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          Text('Reading Soil Diagnostics', style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(
            'Calibrating electrochemical properties...\nPlease keep the probe steady.',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
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
                  _buildCropRecommendation(
                    scan.cropRecommendation,
                    inHeader: true,
                  )
                else
                  _buildRehabProtocols(scan.cropRecommendation, inHeader: true),
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
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: BentoBox(
                      icon: Icons.eco_rounded,
                      label: 'Nitrogen',
                      value: scan.nitrogen.toString(),
                      unit: 'mg/kg',
                      color: _evaluateN(scan.nitrogen),
                    ),
                  ),
                  const SizedBox(width: gapPad),
                  Expanded(
                    child: BentoBox(
                      icon: Icons.science_rounded,
                      label: 'Phosphorus',
                      value: scan.phosphorus.toString(),
                      unit: 'mg/kg',
                      color: _evaluateP(scan.phosphorus),
                    ),
                  ),
                  const SizedBox(width: gapPad),
                  Expanded(
                    child: BentoBox(
                      icon: Icons.spa_rounded,
                      label: 'Potassium',
                      value: scan.potassium.toString(),
                      unit: 'mg/kg',
                      color: _evaluateK(scan.potassium),
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
                      color: _evaluateMoisture(scan.moisture),
                    ),
                  ),
                  const SizedBox(width: gapPad),
                  Expanded(
                    child: BentoBox(
                      icon: Icons.thermostat_rounded,
                      label: 'Temp',
                      value: scan.temperature.toStringAsFixed(1),
                      unit: '°C',
                      color: _evaluateTemp(scan.temperature),
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
                      color: _evaluatePh(scan.soilPh),
                    ),
                  ),
                  const SizedBox(width: gapPad),
                  Expanded(
                    child: BentoBox(
                      icon: Icons.bolt_rounded,
                      label: 'EC Level',
                      value: scan.ecLevel.toStringAsFixed(2),
                      unit: 'mS/cm',
                      color: _evaluateEc(scan.ecLevel),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
                    'updateId': scan.id,
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

  Color _evaluateN(int n) =>
      n >= 40 ? Colors.green : (n >= 25 ? Colors.orange : Colors.red);
  Color _evaluateP(int p) =>
      p >= 25 ? Colors.green : (p >= 15 ? Colors.orange : Colors.red);
  Color _evaluateK(int k) =>
      k >= 30 ? Colors.green : (k >= 20 ? Colors.orange : Colors.red);
  Color _evaluatePh(double ph) =>
      (ph >= 5.8 && ph <= 7.5) ? Colors.green : Colors.orange;
  Color _evaluateMoisture(double m) =>
      (m >= 40 && m <= 80)
          ? Colors.green
          : (m >= 20 ? Colors.orange : Colors.red);
  Color _evaluateEc(double ec) => ec <= 1.5 ? Colors.green : Colors.orange;
  Color _evaluateTemp(double t) =>
      (t >= 18 && t <= 28) ? Colors.green : Colors.orange;

  Widget _buildCropRecommendation(String cropsText, {bool inHeader = false}) {
    final crops = cropsText.split(',').map((e) => e.trim()).toList();
    final displayCrops =
        _isCropsExpanded ? crops.take(12).toList() : crops.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recommended Crops',
              style:
                  (inHeader
                      ? const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      )
                      : Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
            ),
            IconButton(
              onPressed:
                  () => setState(() => _isCropsExpanded = !_isCropsExpanded),
              icon: Icon(
                _isCropsExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: inHeader ? Colors.white70 : AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              displayCrops.asMap().entries.map((entry) {
                final index = entry.key;
                final crop = entry.value;
                final isTopTier = index < 3;
                return _buildCropBadge(
                  crop,
                  isTopTier: isTopTier,
                  inHeader: inHeader,
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildCropBadge(
    String name, {
    bool isTopTier = false,
    bool inHeader = false,
  }) {
    final bgColor =
        inHeader
            ? (isTopTier
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.12))
            : (isTopTier
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.1));
    final textColor =
        inHeader
            ? Colors.white
            : (isTopTier ? Colors.white : AppColors.primary);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTopTier ? 16 : 12,
        vertical: isTopTier ? 10 : 8,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              inHeader
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppColors.primary.withValues(alpha: 0.3),
          width: isTopTier ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isTopTier ? Icons.star_rounded : Icons.grass_rounded,
            size: isTopTier ? 18 : 14,
            color: textColor,
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(
              fontWeight: isTopTier ? FontWeight.w900 : FontWeight.bold,
              fontSize: 14,
              color: textColor,
            ),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Organic Rehab Protocols',
              style:
                  inHeader
                      ? const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      )
                      : Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
            ),
            IconButton(
              onPressed:
                  () => setState(() => _isRehabExpanded = !_isRehabExpanded),
              icon: Icon(
                _isRehabExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: inHeader ? Colors.white70 : Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedCrossFade(
          firstChild: _buildSimpleRehabList(
            protocols.take(2).toList(),
            inHeader: inHeader,
          ),
          secondChild: Column(
            children:
                protocols.asMap().entries.map((entry) {
                  return _buildRehabStep(
                    entry.key + 1,
                    entry.value,
                    inHeader: inHeader,
                  );
                }).toList(),
          ),
          crossFadeState:
              _isRehabExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ],
    );
  }

  Widget _buildSimpleRehabList(List<String> items, {bool inHeader = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            inHeader
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children:
            items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 14,
                          color: inHeader ? Colors.white70 : Colors.orange,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: inHeader ? Colors.white : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildRehabStep(int count, String text, {bool inHeader = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            inHeader
                ? Colors.white.withValues(alpha: 0.15)
                : (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.cardDark
                    : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              inHeader
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: inHeader ? Colors.white24 : Colors.orange[100],
            child: Text(
              count.toString(),
              style: TextStyle(
                color: inHeader ? Colors.white : Colors.orange[900],
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: inHeader ? Colors.white : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
