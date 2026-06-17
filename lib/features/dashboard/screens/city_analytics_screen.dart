import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildacre_crm/core/constants/app_constants.dart';
import 'package:buildacre_crm/core/theme/app_theme.dart';
import 'package:buildacre_crm/features/leads/models/lead.dart';
import 'package:buildacre_crm/features/leads/providers/leads_provider.dart';

// Per-city computed stats
class _CityStats {
  final City city;
  final int total;
  final int won;
  final int lost;
  final int active;
  final int overdue;
  final Map<LeadSource, int> bySource;
  final Map<ServiceType, int> byService;
  final Map<LeadStage, int> byStage;

  const _CityStats({
    required this.city,
    required this.total,
    required this.won,
    required this.lost,
    required this.active,
    required this.overdue,
    required this.bySource,
    required this.byService,
    required this.byStage,
  });

  double get conversionRate => total == 0 ? 0 : won / total * 100;
  double get lossRate => total == 0 ? 0 : lost / total * 100;
}

_CityStats _computeCityStats(City city, List<Lead> leads) {
  final cl = leads.where((l) => l.city == city).toList();
  final bySource = {for (final s in LeadSource.values) s: cl.where((l) => l.source == s).length};
  final byService = {for (final s in ServiceType.values) s: cl.where((l) => l.serviceType == s).length};
  final byStage = {for (final s in LeadStage.values) s: cl.where((l) => l.stage == s).length};

  return _CityStats(
    city: city,
    total: cl.length,
    won: cl.where((l) => l.stage == LeadStage.finalAgreement).length,
    lost: cl.where((l) => l.stage == LeadStage.lost).length,
    active: cl.where((l) =>
        l.stage != LeadStage.finalAgreement &&
        l.stage != LeadStage.lost &&
        l.stage != LeadStage.future).length,
    overdue: cl.where((l) => l.hasOverdueFollowup).length,
    bySource: bySource,
    byService: byService,
    byStage: byStage,
  );
}

class CityAnalyticsScreen extends ConsumerStatefulWidget {
  const CityAnalyticsScreen({super.key});

  @override
  ConsumerState<CityAnalyticsScreen> createState() => _CityAnalyticsScreenState();
}

class _CityAnalyticsScreenState extends ConsumerState<CityAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leads = ref.watch(leadsProvider);
    final blr = _computeCityStats(City.bangalore, leads);
    final mys = _computeCityStats(City.mysore, leads);

    return Scaffold(
      appBar: AppBar(
        title: const Text('City Analytics'),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.gold,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.gold,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Sources'),
            Tab(text: 'Services'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _OverviewTab(blr: blr, mys: mys, total: leads.length),
          _SourcesTab(blr: blr, mys: mys),
          _ServicesTab(blr: blr, mys: mys),
        ],
      ),
    );
  }
}

// ─── Overview Tab ────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final _CityStats blr;
  final _CityStats mys;
  final int total;

  const _OverviewTab({required this.blr, required this.mys, required this.total});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header split
        _buildSplitHeader(context),
        const SizedBox(height: 16),
        // Head-to-head metric cards
        _SectionTitle('Key Metrics'),
        const SizedBox(height: 10),
        _buildMetricRows(context),
        const SizedBox(height: 16),
        // Conversion comparison
        _SectionTitle('Conversion Rate'),
        const SizedBox(height: 10),
        _ConversionCard(blr: blr, mys: mys),
        const SizedBox(height: 16),
        // Pipeline stage distribution
        _SectionTitle('Pipeline Distribution'),
        const SizedBox(height: 10),
        _StageDistCard(blr: blr, mys: mys),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSplitHeader(BuildContext context) {
    final blrPct = total == 0 ? 0.5 : blr.total / total;
    final mysPct = total == 0 ? 0.5 : mys.total / total;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _CityHeaderStat(city: blr, color: const Color(0xFF4FC3F7))),
              Container(width: 1, height: 60, color: Colors.white24),
              Expanded(child: _CityHeaderStat(city: mys, color: const Color(0xFFFFB74D))),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Flexible(
                  flex: (blrPct * 100).round(),
                  child: Container(height: 8, color: const Color(0xFF4FC3F7)),
                ),
                Flexible(
                  flex: (mysPct * 100).round(),
                  child: Container(height: 8, color: const Color(0xFFFFB74D)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Legend(color: const Color(0xFF4FC3F7), label: 'Bangalore ${(blrPct * 100).toStringAsFixed(0)}%'),
              const SizedBox(width: 16),
              _Legend(color: const Color(0xFFFFB74D), label: 'Mysore ${(mysPct * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRows(BuildContext context) {
    return Column(
      children: [
        _MetricRow(label: 'Active Leads', blrValue: '${blr.active}', mysValue: '${mys.active}'),
        _MetricRow(label: 'Won',          blrValue: '${blr.won}',    mysValue: '${mys.won}',   positive: true),
        _MetricRow(label: 'Lost',         blrValue: '${blr.lost}',   mysValue: '${mys.lost}',  positive: false),
        _MetricRow(label: 'Overdue',      blrValue: '${blr.overdue}', mysValue: '${mys.overdue}', positive: false),
      ],
    );
  }
}

class _CityHeaderStat extends StatelessWidget {
  final _CityStats city;
  final Color color;
  const _CityHeaderStat({required this.city, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(city.city.label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 4),
        Text('${city.total}',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
        const Text('total leads', style: TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String blrValue;
  final String mysValue;
  final bool? positive; // null = neutral

  const _MetricRow({required this.label, required this.blrValue, required this.mysValue, this.positive});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              blrValue,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _valueColor(blrValue, mysValue, true),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              mysValue,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _valueColor(mysValue, blrValue, false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _valueColor(String a, String b, bool isLeft) {
    if (positive == null) return AppColors.textPrimary;
    final av = int.tryParse(a) ?? 0;
    final bv = int.tryParse(b) ?? 0;
    if (av == bv) return AppColors.textPrimary;
    final aWins = positive! ? av > bv : av < bv;
    return aWins ? AppColors.stageWon : AppColors.stageLost;
  }
}

class _ConversionCard extends StatelessWidget {
  final _CityStats blr;
  final _CityStats mys;
  const _ConversionCard({required this.blr, required this.mys});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _ConvBar(label: 'Bangalore', pct: blr.conversionRate, color: const Color(0xFF4FC3F7)),
          const SizedBox(height: 12),
          _ConvBar(label: 'Mysore', pct: mys.conversionRate, color: const Color(0xFFFFB74D)),
        ],
      ),
    );
  }
}

class _ConvBar extends StatelessWidget {
  final String label;
  final double pct;
  final Color color;
  const _ConvBar({required this.label, required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 12,
              backgroundColor: AppColors.surface,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${pct.toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

class _StageDistCard extends StatelessWidget {
  final _CityStats blr;
  final _CityStats mys;
  const _StageDistCard({required this.blr, required this.mys});

  static const _stages = [
    LeadStage.enquiryReceived,
    LeadStage.telecallerCallDone,
    LeadStage.meetingAtOffice,
    LeadStage.siteVisit,
    LeadStage.quotationSent,
    LeadStage.negotiation,
    LeadStage.finalAgreement,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // column headers
          Row(
            children: [
              const Expanded(flex: 2, child: SizedBox()),
              Expanded(
                child: Text('BLR', textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4FC3F7))),
              ),
              Expanded(
                child: Text('MYS', textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFFB74D))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._stages.map((s) {
            final bv = blr.byStage[s] ?? 0;
            final mv = mys.byStage[s] ?? 0;
            if (bv == 0 && mv == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(s.label,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  Expanded(
                    child: Text('$bv',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4FC3F7))),
                  ),
                  Expanded(
                    child: Text('$mv',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFFFB74D))),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Sources Tab ─────────────────────────────────────────────────────────────

class _SourcesTab extends StatelessWidget {
  final _CityStats blr;
  final _CityStats mys;
  const _SourcesTab({required this.blr, required this.mys});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Where leads come from per city — use this to decide where to spend on ads.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        _SourceCompareCard(city: blr, color: const Color(0xFF4FC3F7)),
        const SizedBox(height: 12),
        _SourceCompareCard(city: mys, color: const Color(0xFFFFB74D)),
        const SizedBox(height: 16),
        _SectionTitle('Head-to-Head by Source'),
        const SizedBox(height: 10),
        ...LeadSource.values.map((s) {
          final bv = blr.bySource[s] ?? 0;
          final mv = mys.bySource[s] ?? 0;
          if (bv == 0 && mv == 0) return const SizedBox.shrink();
          return _SourceH2H(source: s, blrCount: bv, mysCount: mv);
        }),
        const SizedBox(height: 100),
      ],
    );
  }
}

class _SourceCompareCard extends StatelessWidget {
  final _CityStats city;
  final Color color;
  const _SourceCompareCard({required this.city, required this.color});

  static const _sourceColors = {
    LeadSource.facebook:  Color(0xFF1877F2),
    LeadSource.instagram: Color(0xFFE1306C),
    LeadSource.website:   AppColors.navy,
    LeadSource.phone:     AppColors.stageWon,
    LeadSource.whatsapp:  Color(0xFF25D366),
    LeadSource.referral:  AppColors.gold,
  };

  @override
  Widget build(BuildContext context) {
    final sorted = LeadSource.values
        .map((s) => MapEntry(s, city.bySource[s] ?? 0))
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = sorted.isEmpty ? 1 : sorted.first.value;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                '${city.city.label}  ·  ${city.total} leads',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            const Text('No leads yet', style: TextStyle(color: AppColors.textSecondary))
          else
            ...sorted.map((e) {
              final c = _sourceColors[e.key] ?? AppColors.textSecondary;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 76,
                      child: Text(e.key.label,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: e.value / max,
                          minHeight: 10,
                          backgroundColor: AppColors.surface,
                          valueColor: AlwaysStoppedAnimation(c),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${e.value}',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: c)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SourceH2H extends StatelessWidget {
  final LeadSource source;
  final int blrCount;
  final int mysCount;
  const _SourceH2H({required this.source, required this.blrCount, required this.mysCount});

  @override
  Widget build(BuildContext context) {
    final total = blrCount + mysCount;
    final blrPct = total == 0 ? 0.5 : blrCount / total;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(source.label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$blrCount BLR',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4FC3F7), fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Text('$mysCount MYS',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFFFB74D), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Row(
              children: [
                Flexible(
                  flex: (blrPct * 100).round(),
                  child: Container(height: 6, color: const Color(0xFF4FC3F7)),
                ),
                Flexible(
                  flex: ((1 - blrPct) * 100).round(),
                  child: Container(height: 6, color: const Color(0xFFFFB74D)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Services Tab ─────────────────────────────────────────────────────────────

class _ServicesTab extends StatelessWidget {
  final _CityStats blr;
  final _CityStats mys;
  const _ServicesTab({required this.blr, required this.mys});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Construction vs Renovation vs Interiors split by city.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        ...ServiceType.values.map((s) => _ServiceCard(service: s, blr: blr, mys: mys)),
        const SizedBox(height: 100),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceType service;
  final _CityStats blr;
  final _CityStats mys;
  const _ServiceCard({required this.service, required this.blr, required this.mys});

  static const _serviceColors = {
    ServiceType.construction: AppColors.navy,
    ServiceType.renovation:   AppColors.gold,
    ServiceType.interiors:    Color(0xFFE1306C),
  };

  @override
  Widget build(BuildContext context) {
    final bv = blr.byService[service] ?? 0;
    final mv = mys.byService[service] ?? 0;
    final total = bv + mv;
    final color = _serviceColors[service] ?? AppColors.navy;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_serviceIcon(service), color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.label,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: color)),
                  Text('$total leads total',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ServiceCityBar(
                    city: 'Bangalore', count: bv, total: total, color: const Color(0xFF4FC3F7)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ServiceCityBar(
                    city: 'Mysore', count: mv, total: total, color: const Color(0xFFFFB74D)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _serviceIcon(ServiceType s) {
    switch (s) {
      case ServiceType.construction: return Icons.home_work_outlined;
      case ServiceType.renovation:   return Icons.handyman_outlined;
      case ServiceType.interiors:    return Icons.chair_outlined;
    }
  }
}

class _ServiceCityBar extends StatelessWidget {
  final String city;
  final int count;
  final int total;
  final Color color;
  const _ServiceCityBar(
      {required this.city, required this.count, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(city, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: AppColors.surface,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 2),
        Text('${(pct * 100).toStringAsFixed(0)}% of total',
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ─── Shared helpers ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.8),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}
