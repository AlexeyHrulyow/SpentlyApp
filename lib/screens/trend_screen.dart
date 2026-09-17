// lib/screens/trend_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/database_helper.dart';
import '../models/monthly_stats.dart';

class TrendScreen extends StatefulWidget {
  const TrendScreen({super.key});

  @override
  State<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen> {
  // Переключатель периода: 6 или 12 месяцев.
  int _monthsBack = 6;

  // Режим: false — одна общая линия (A), true — три линии (B).
  bool _showBreakdown = false;

  List<MonthlyStats> _data = [];
  bool _isLoading = true;

  // Цвета линий. Хардкод оправдан: это семантические категории,
  // они должны оставаться узнаваемыми в обеих темах.
  static const Color _colorTotal = Color(0xFF673AB7);   // deepPurple
  static const Color _colorFixed = Color(0xFF1E88E5);   // blue 600
  static const Color _colorPersonal = Color(0xFFFB8C00); // orange 600

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final data = await DatabaseHelper.instance.getMonthlyStats(
      monthsBack: _monthsBack,
    );

    if (!mounted) return;
    setState(() {
      _data = data;
      _isLoading = false;
    });
  }

  Future<void> _setMonthsBack(int value) async {
    if (_monthsBack == value) return;
    setState(() => _monthsBack = value);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Динамика расходов'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data.every((s) => s.total == 0)
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPeriodSwitcher(),
                      const SizedBox(height: 8),
                      _buildModeSwitcher(),
                      const SizedBox(height: 24),
                      _buildChartCard(),
                      const SizedBox(height: 24),
                      _buildComparison(),
                      const SizedBox(height: 16),
                      _buildAverage(),
                    ],
                  ),
                ),
    );
  }

  // ---------- Пустое состояние ----------
  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Нет данных за выбранный период',
              style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Переключатель 6/12 месяцев ----------
  Widget _buildPeriodSwitcher() {
    return Center(
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment<int>(value: 6, label: Text('6 мес')),
          ButtonSegment<int>(value: 12, label: Text('12 мес')),
        ],
        selected: {_monthsBack},
        onSelectionChanged: (s) => _setMonthsBack(s.first),
      ),
    );
  }

  // ---------- Переключатель режима ----------
  Widget _buildModeSwitcher() {
    return Center(
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment<bool>(
            value: false,
            label: Text('Общая'),
            icon: Icon(Icons.show_chart),
          ),
          ButtonSegment<bool>(
            value: true,
            label: Text('Детально'),
            icon: Icon(Icons.stacked_line_chart),
          ),
        ],
        selected: {_showBreakdown},
        onSelectionChanged: (s) {
          setState(() => _showBreakdown = s.first);
        },
      ),
    );
  }

  // ---------- Карточка с графиком ----------
  Widget _buildChartCard() {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 24, 16, 16),
        child: Column(
          children: [
            SizedBox(height: 260, child: _buildLineChart()),
            const SizedBox(height: 16),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    // Максимум по Y — на 15% больше реального максимума, чтобы верхние
    // точки не прилипали к краю графика.
    double maxY = _data.map((s) => s.total).reduce((a, b) => a > b ? a : b);
    if (_showBreakdown) {
      final fixedMax = _data.map((s) => s.fixed).reduce((a, b) => a > b ? a : b);
      final personalMax =
          _data.map((s) => s.personal).reduce((a, b) => a > b ? a : b);
      if (fixedMax > maxY) maxY = fixedMax;
      if (personalMax > maxY) maxY = personalMax;
    }
    maxY = maxY * 1.15;

    // Среднее за весь период — для пунктирной линии.
    final double avg =
        _data.map((s) => s.total).reduce((a, b) => a + b) / _data.length;

    // На узком экране подписи месяцев через один, чтобы не слипались.
    final bool everyOther = _data.length > 8;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (_data.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                // Делаем подпись компактной: 12000 -> 12K.
                final double v = value;
                final String label = v >= 1000
                    ? '${(v / 1000).toStringAsFixed(0)}K'
                    : v.toStringAsFixed(0);
                return Text(label, style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final int index = value.toInt();
                if (index < 0 || index >= _data.length) {
                  return const SizedBox.shrink();
                }
                if (everyOther && index % 2 != 0 && index != _data.length - 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _data[index].shortMonthName,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        // Пунктирная линия среднего. Показываем только в режиме «Общая»,
        // чтобы в «Детально» не путать с линиями категорий.
        extraLinesData: _showBreakdown
            ? const ExtraLinesData()
            : ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: avg,
                    color: Colors.grey,
                    strokeWidth: 1,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 4, bottom: 2),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      labelResolver: (_) =>
                          'Среднее ${avg.toStringAsFixed(0)}₽',
                    ),
                  ),
                ],
              ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> spots) {
              return spots.map((spot) {
                final int index = spot.x.toInt();
                final MonthlyStats stat = _data[index];
                // Определяем, какой линии принадлежит точка.
                String name;
                if (spot.barIndex == 0 && _showBreakdown) {
                  name = 'Общая';
                } else if (spot.barIndex == 0) {
                  name = 'Общая';
                } else if (spot.barIndex == 1) {
                  name = 'Обязательные';
                } else {
                  name = 'Личные';
                }
                return LineTooltipItem(
                  '${stat.shortMonthName} · $name\n'
                  '${spot.y.toStringAsFixed(0)} ₽',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: _buildLines(),
      ),
    );
  }

  List<LineChartBarData> _buildLines() {
    // Строим точки: x — индекс месяца (0..N-1), y — сумма.
    // List.generate создаёт список длиной _data.length, применяя
    // функцию (i) => FlSpot(i.toDouble(), значение).
    List<FlSpot> spotsFor(double Function(MonthlyStats) pick) {
      return List.generate(
        _data.length,
        (i) => FlSpot(i.toDouble(), pick(_data[i])),
      );
    }

    final totalLine = LineChartBarData(
      spots: spotsFor((s) => s.total),
      isCurved: true,
      curveSmoothness: 0.25,
      preventCurveOverShooting: true,
      color: _colorTotal,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 3.5,
            color: _colorTotal,
            strokeWidth: 1.5,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: _colorTotal.withValues(alpha: 0.12),
      ),
    );

    if (!_showBreakdown) {
      return [totalLine];
    }

    final fixedLine = LineChartBarData(
      spots: spotsFor((s) => s.fixed),
      isCurved: true,
      curveSmoothness: 0.25,
      preventCurveOverShooting: true,
      color: _colorFixed,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 3,
            color: _colorFixed,
            strokeWidth: 1.5,
            strokeColor: Colors.white,
          );
        },
      ),
    );

    final personalLine = LineChartBarData(
      spots: spotsFor((s) => s.personal),
      isCurved: true,
      curveSmoothness: 0.25,
      preventCurveOverShooting: true,
      color: _colorPersonal,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 3,
            color: _colorPersonal,
            strokeWidth: 1.5,
            strokeColor: Colors.white,
          );
        },
      ),
    );

    return [totalLine, fixedLine, personalLine];
  }

  Widget _buildLegend() {
    Widget item(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        item(_colorTotal, 'Общая'),
        if (_showBreakdown) ...[
          item(_colorFixed, 'Обязательные'),
          item(_colorPersonal, 'Личные'),
        ],
      ],
    );
  }

  // ---------- Блок сравнения (последний месяц vs предыдущий) ----------
  Widget _buildComparison() {
    if (_data.length < 2) return const SizedBox.shrink();

    final MonthlyStats previous = _data[_data.length - 2];
    final MonthlyStats current = _data[_data.length - 1];

    if (previous.total == 0 && current.total == 0) {
      return const SizedBox.shrink();
    }

    final double diff = current.total - previous.total;
    final String sign = diff > 0 ? '+' : '';
    String percentText;
    if (previous.total == 0) {
      percentText = '—';
    } else {
      final double percent = diff / previous.total * 100;
      percentText = '$sign${percent.toStringAsFixed(0)}%';
    }

    final bool grew = diff > 0;
    final Color trendColor = grew ? Colors.red : Colors.green;
    final IconData trendIcon = grew ? Icons.trending_up : Icons.trending_down;

    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Сравнение с прошлым месяцем',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _comparisonSide(
                    label: previous.fullMonthName,
                    value: previous.total,
                    color: cs.onPrimaryContainer,
                    alignEnd: false,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, color: cs.onPrimaryContainer),
                ),
                Expanded(
                  child: _comparisonSide(
                    label: current.fullMonthName,
                    value: current.total,
                    color: cs.onPrimaryContainer,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(trendIcon, color: trendColor, size: 20),
                const SizedBox(width: 6),
                Text(
                  '$sign${diff.toStringAsFixed(0)} ₽ ($percentText)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: trendColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _comparisonSide({
    required String label,
    required double value,
    required Color color,
    required bool alignEnd,
  }) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.75)),
        ),
        const SizedBox(height: 2),
        Text(
          '${value.toStringAsFixed(0)} ₽',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ---------- Среднее за период ----------
  Widget _buildAverage() {
    final double avg =
        _data.map((s) => s.total).reduce((a, b) => a + b) / _data.length;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        'В среднем за ${_data.length} мес: ${avg.toStringAsFixed(0)} ₽',
        style: TextStyle(
          fontSize: 14,
          color: cs.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}