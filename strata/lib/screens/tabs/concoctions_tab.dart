import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:strata/theme/app_theme.dart';

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

class ConcoctionsTab extends StatefulWidget {
  const ConcoctionsTab({super.key});

  @override
  State<ConcoctionsTab> createState() => _ConcoctionsTabState();
}

class _ConcoctionsTabState extends State<ConcoctionsTab> {
  late Future<Map<String, dynamic>> _concoctionsFuture;

  @override
  void initState() {
    super.initState();
    _concoctionsFuture = _loadConcoctions();
  }

  Future<Map<String, dynamic>> _loadConcoctions() async {
    final String response = await rootBundle.loadString('concoctions.json');
    return await json.decode(response);
  }

  void _openConcoctionDetails(BuildContext context, Map<String, dynamic> concoction, bool isDark) {
    final String id = concoction['id'];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConcoctionDetailScreen(
          concoction: concoction,
          isDark: isDark,
          brandColor: _getColorForConcoction(id),
          emoji: _getEmojiForConcoction(id),
        ),
      ),
    );
  }

  Color _getColorForConcoction(String id) {
    switch (id) {
      case 'FPJ': return const Color(0xFF4CAF50); // Green
      case 'FFJ': return const Color(0xFFFF9800); // Orange
      case 'FAA': return const Color(0xFF2196F3); // Blue
      case 'IMO': return const Color(0xFF795548); // Brown
      case 'LABS': return const Color(0xFF009688); // Teal
      case 'CalPhos': return const Color(0xFF607D8B); // BlueGrey
      case 'OHN': return const Color(0xFF9C27B0); // Purple
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
      default: return '🧪';
    }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _concoctionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading guide: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No data found'));
          }

          final data = snapshot.data!;
          final concoctions = data['concoctions'] as List;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                title: const Text('Organic Concoctions Guide'),
                backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Select a concoction below to view information, preparation steps, and maintenance details.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), // extra padding for bottom nav
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final concoction = concoctions[index];
                      final id = concoction['id'];
                      final brandColor = _getColorForConcoction(id);
                      final emoji = _getEmojiForConcoction(id);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () => _openConcoctionDetails(context, concoction, isDark),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: brandColor.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: brandColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 40),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: brandColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          id,
                                          style: TextStyle(
                                            color: brandColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        concoction['name'],
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          _buildMiniBadge(
                                            _shortenText(concoction['application']['dilution']),
                                            Icons.water_drop_rounded,
                                            brandColor,
                                          ),
                                          _buildMiniBadge(
                                            _shortenText(concoction['application']['frequency']),
                                            Icons.calendar_month_rounded,
                                            brandColor,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: concoctions.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ConcoctionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> concoction;
  final bool isDark;
  final Color brandColor;
  final String emoji;

  const ConcoctionDetailScreen({
    super.key,
    required this.concoction,
    required this.isDark,
    required this.brandColor,
    required this.emoji,
  });

  @override
  State<ConcoctionDetailScreen> createState() => _ConcoctionDetailScreenState();
}

class _ConcoctionDetailScreenState extends State<ConcoctionDetailScreen> {
  late List<bool> _checkedSteps;

  @override
  void initState() {
    super.initState();
    _checkedSteps = List.generate(
      (widget.concoction['procedure'] as List).length,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: widget.isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: widget.brandColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.concoction['id'],
                          style: TextStyle(
                            color: widget.brandColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          widget.concoction['name'],
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              indicatorColor: widget.brandColor,
              labelColor: widget.brandColor,
              unselectedLabelColor: colorScheme.onSurface.withOpacity(0.5),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'Information'),
                Tab(text: 'Procedure'),
                Tab(text: 'Maintenance'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildQuickFactsTab(textTheme, colorScheme),
                  _buildProcedureTab(textTheme, colorScheme),
                  _buildMaintenanceTab(widget.isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFactsTab(TextTheme textTheme, ColorScheme colorScheme) {
    final application = widget.concoction['application'];
    
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          widget.concoction['description'],
          style: textTheme.titleMedium?.copyWith(
            height: 1.5,
            color: colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 32),
        _buildFullWidthFactCard('Purpose', widget.concoction['purpose'], Icons.track_changes_rounded, textTheme),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildSmallFactCard('Growth Stage', application['stage'], Icons.grass_rounded, textTheme),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSmallFactCard('Dilution', application['dilution'], Icons.water_drop_rounded, textTheme),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildFullWidthFactCard('Frequency', application['frequency'], Icons.calendar_month_rounded, textTheme),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildProcedureTab(TextTheme textTheme, ColorScheme colorScheme) {
    final procedureList = widget.concoction['procedure'] as List;

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: procedureList.length,
      itemBuilder: (context, index) {
        final isChecked = _checkedSteps[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
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
                      ? widget.brandColor.withOpacity(0.1) 
                      : (widget.isDark ? AppColors.cardDark : AppColors.surfaceLight),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isChecked 
                        ? widget.brandColor.withOpacity(0.5) 
                        : (widget.isDark ? AppColors.dividerDark : AppColors.dividerLight),
                    width: isChecked ? 2 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2, right: 16),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isChecked ? widget.brandColor : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isChecked ? widget.brandColor : colorScheme.onSurface.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: isChecked
                          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                          : Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ),
                    ),
                    Expanded(
                      child: Text(
                        procedureList[index],
                        style: textTheme.bodyLarge?.copyWith(
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
      },
    );
  }

  Widget _buildMaintenanceTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Text(
            'Follow these essential standards to preserve your ${widget.concoction['id']} batch.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ),
        ..._maintenanceDataList.map((info) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MaintenanceCard(info: info, isDark: isDark),
            )),
        const SizedBox(height: 8),
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
    );
  }

  Widget _buildFullWidthFactCard(String title, String value, IconData icon, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.brandColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.brandColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: widget.brandColor, size: 24),
              const SizedBox(width: 8),
              Text(
                title, 
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold, 
                  color: widget.brandColor,
                )
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallFactCard(String title, String value, IconData icon, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.brandColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.brandColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: widget.brandColor, size: 28),
          const SizedBox(height: 12),
          Text(
            title, 
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold, 
              color: widget.brandColor,
            )
          ),
          const SizedBox(height: 8),
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
        borderRadius: BorderRadius.circular(20),
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
        Icon(info.icon, color: info.color, size: 28),
        const SizedBox(height: 12),
        Text(
          info.title,
          style: TextStyle(color: info.color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          info.keyword,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          info.description,
          style: const TextStyle(fontSize: 12, height: 1.3),
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
          child: Icon(info.icon, color: info.color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.title,
                style: TextStyle(color: info.color, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                info.keyword,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                info.description,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
