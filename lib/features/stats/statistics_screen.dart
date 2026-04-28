import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/auth_api.dart';
import '../../core/utils/app_events.dart';
import '../../widgets/app_card.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _api = ApiClient();
  var _range = 0;
  var _loading = true;
  String? _error;
  var _stats = <String, dynamic>{
    'adherence_percent': 0,
    'taken_count': 0,
    'missed_count': 0,
    'pending_count': 0,
    'daily_breakdown': [],
  };

  @override
  void initState() {
    super.initState();
    AppEvents.medicineChanged.addListener(_loadStats);
    _loadStats();
  }

  @override
  void dispose() {
    AppEvents.medicineChanged.removeListener(_loadStats);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 116),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistika',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sizning dori qabul qilish holatingiz',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.calendar),
                icon: const Icon(Icons.calendar_month_outlined),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SegmentedRange(
            value: _range,
            onChanged: (value) {
              setState(() => _range = value);
              _loadStats();
            },
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            TextButton(onPressed: _loadStats, child: Text(_error!))
          else
            _SummaryCard(stats: _stats),
          const SizedBox(height: 20),
          _ChartCard(stats: _stats),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.check_circle,
                  color: AppColors.primary,
                  value: '${_count(_stats, 'taken')}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  icon: Icons.cancel,
                  color: AppColors.error,
                  value: '${_count(_stats, 'missed')}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  icon: Icons.schedule,
                  color: AppColors.accent,
                  value: '${_count(_stats, 'pending')}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await _api.getStatistics(period: [7, 30, 90][_range]);
      if (!mounted) return;
      setState(() => _stats = stats);
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

int _count(Map<String, dynamic> stats, String key) {
  return _num(stats['${key}_count'] ?? stats[key]).toInt();
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.stats});

  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final points = _points(stats);
    final taken = _count(stats, 'taken').toDouble();
    final missed = _count(stats, 'missed').toDouble();
    final pending = _count(stats, 'pending').toDouble();
    final maxY = [
      ...points.map((e) => e.y),
      taken,
      missed,
      pending,
      5.0,
    ].reduce((a, b) => a > b ? a : b);

    return AppCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trend', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: points,
                    color: AppColors.primary,
                    barWidth: 4,
                    isCurved: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                barGroups: [
                  _bar(0, taken, AppColors.primary),
                  _bar(1, missed, AppColors.error),
                  _bar(2, pending, AppColors.accent),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _LegendDot(color: AppColors.primary, label: 'Ichilgan'),
              _LegendDot(color: AppColors.error, label: 'O‘tkazilgan'),
              _LegendDot(color: AppColors.accent, label: 'Kutilmoqda'),
            ],
          ),
        ],
      ),
    );
  }

  static BarChartGroupData _bar(int x, double value, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          width: 26,
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }

  static List<FlSpot> _points(Map<String, dynamic> stats) {
    final raw =
        stats['daily_breakdown'] ??
        stats['daily'] ??
        stats['trend'] ??
        stats['chart'];
    if (raw is List && raw.isNotEmpty) {
      return raw.indexed.map((entry) {
        final item = entry.$2;
        final value = item is Map ? _dayPercent(item) : _num(item);
        return FlSpot(entry.$1.toDouble(), value.toDouble());
      }).toList();
    }
    final percent = _num(stats['adherence_percent']);
    return List.generate(
      7,
      (index) => FlSpot(index.toDouble(), (percent * (0.72 + index * 0.04))),
    );
  }

  static num _dayPercent(Map item) {
    final taken = _num(item['taken_count'] ?? item['taken']);
    final missed = _num(item['missed_count'] ?? item['missed']);
    final pending = _num(item['pending_count'] ?? item['pending']);
    final total = taken + missed + pending;
    if (total == 0) return 0;
    return (taken / total) * 100;
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}

num _num(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

class _SegmentedRange extends StatelessWidget {
  const _SegmentedRange({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = ['7 kun', '30 kun', '90 kun'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = value == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  labels[index],
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.stats});

  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.floatingShadow,
      ),
      child: Column(
        children: [
          const Text(
            'Umumiy natija',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${stats['adherence_percent'] ?? 0}%',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'Bajarilgan dorilar foizi',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.25)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryChip(
                icon: Icons.check,
                text: '${_count(stats, 'taken')} ichildi',
              ),
              _SummaryChip(
                icon: Icons.close,
                text: "${_count(stats, 'missed')} o'tkazildi",
              ),
              _SummaryChip(
                icon: Icons.schedule,
                text: '${_count(stats, 'pending')} kutilmoqda',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: Colors.white, size: 15),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.color,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String value;
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 16,
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}
