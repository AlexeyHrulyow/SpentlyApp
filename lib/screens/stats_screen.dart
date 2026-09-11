// lib/screens/stats_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/database_helper.dart';
import '../models/expense.dart';

class StatsScreen extends StatefulWidget {
  final int initialYear;
  final int initialMonth;

  const StatsScreen({
    Key? key,
    required this.initialYear,
    required this.initialMonth,
  }) : super(key: key);

  @override
  _StatsScreenState createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late int _currentYear;
  late int _currentMonth;

  List<Expense> _expenses = [];
  bool _isLoading = true;

  Map<String, double> _subcategoryData = {};
  Map<int, double> _dailyData = {};

  int _selectedChartIndex = 0;

  // ← Флаг для PopScope: разрешает фактический pop.
  bool _canPop = false;

  @override
  void initState() {
    super.initState();
    _currentYear = widget.initialYear;
    _currentMonth = widget.initialMonth;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    List<Expense> expenses = await DatabaseHelper.instance
        .getTransactionsForMonth(_currentYear, _currentMonth);
    _expenses = expenses;

    Map<String, double> subcatMap = {};
    for (var e in expenses) {
      subcatMap[e.subcategory] = (subcatMap[e.subcategory] ?? 0.0) + e.amount;
    }
    _subcategoryData = subcatMap;

    Map<int, double> dayMap = {};
    for (var e in expenses) {
      int day = e.date.day;
      dayMap[day] = (dayMap[day] ?? 0.0) + e.amount;
    }
    _dailyData = dayMap;

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth += offset;
      if (_currentMonth > 12) {
        _currentMonth = 1;
        _currentYear++;
      } else if (_currentMonth < 1) {
        _currentMonth = 12;
        _currentYear--;
      }
    });
    _loadData();
  }

  // Возврат с передачей текущих года и месяца на главный экран.
  // Мы сначала разрешаем pop (setState -> _canPop=true), затем в следующем
  // кадре вызываем Navigator.pop уже с результатом.
  void _closeWithResult() {
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop({
        'year': _currentYear,
        'month': _currentMonth,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // PopScope заменил устаревший WillPopScope.
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _closeWithResult();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Статистика за ${_getMonthName(_currentMonth)} $_currentYear',
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _closeWithResult,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeMonth(-1),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeMonth(1),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment<int>(
                            value: 0,
                            label: Text('Круговая'),
                            icon: Icon(Icons.pie_chart),
                          ),
                          ButtonSegment<int>(
                            value: 1,
                            label: Text('Столбчатая'),
                            icon: Icon(Icons.bar_chart),
                          ),
                        ],
                        selected: {_selectedChartIndex},
                        onSelectionChanged: (Set<int> newSelection) {
                          setState(
                            () => _selectedChartIndex = newSelection.first,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _selectedChartIndex == 0
                        ? _buildPieChart()
                        : _buildBarChart(context),
                    const SizedBox(height: 32),
                    _buildTotals(),
                  ],
                ),
              ),
      ),
    );
  }

  // ------------------- КРУГОВАЯ ДИАГРАММА -------------------
  Widget _buildPieChart() {
    final cs = Theme.of(context).colorScheme;

    if (_subcategoryData.isEmpty) {
      return Center(
        child: Text(
          'Нет данных для отображения',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }

    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.lime,
      Colors.cyan,
      Colors.brown,
      Colors.grey,
      Colors.deepPurple,
    ];

    final List<String> subcatNames = _subcategoryData.keys.toList();
    final double total = _subcategoryData.values.reduce((a, b) => a + b);

    List<PieChartSectionData> sections = [];
    for (int i = 0; i < subcatNames.length; i++) {
      String subcat = subcatNames[i];
      double amount = _subcategoryData[subcat]!;
      double percentage = (amount / total) * 100;

      sections.add(
        PieChartSectionData(
          color: colors[i % colors.length],
          value: amount,
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 80,
          // ← Цвет секторов яркий и не зависит от темы,
          // поэтому белый текст + тёмная тень читаются всегда.
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 3,
                color: Colors.black87,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: List.generate(subcatNames.length, (index) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  color: colors[index % colors.length],
                ),
                const SizedBox(width: 4),
                Text(
                  '${_translateSubcategory(subcatNames[index])} '
                  '(${_subcategoryData[subcatNames[index]]!.toStringAsFixed(0)}₽)',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  // ------------------- СТОЛБЧАТАЯ ДИАГРАММА -------------------
  Widget _buildBarChart(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_dailyData.isEmpty) {
      return Center(
        child: Text(
          'Нет данных для отображения',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }

    final List<int> days = _dailyData.keys.toList()..sort();
    final double maxValue =
        _dailyData.values.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    double availableWidth = screenWidth - 40 - 32;
    double barWidth = (availableWidth / days.length) * 0.7;
    barWidth = barWidth.clamp(6.0, 40.0);

    int labelStep = 1;
    if (days.length > 20) {
      labelStep = 3;
    } else if (days.length > 14) {
      labelStep = 2;
    }

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < days.length; i++) {
      int day = days[i];
      double amount = _dailyData[day]!;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: amount,
              // ← primary из темы: синий в light, светлее в dark.
              color: cs.primary,
              width: barWidth,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 40.0, bottom: 16.0),
      child: SizedBox(
        height: 250,
        child: BarChart(
          BarChartData(
            barGroups: barGroups,
            groupsSpace: 0,
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    int index = value.toInt();
                    if (index >= 0 &&
                        index < days.length &&
                        (index % labelStep == 0 ||
                            index == days.length - 1)) {
                      return Transform.rotate(
                        angle: -0.8,
                        child: Text(
                          days[index].toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      '${value.toInt()}₽',
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: true),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipBorderRadius: BorderRadius.circular(4),
                tooltipPadding: const EdgeInsets.all(4),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${rod.toY.toStringAsFixed(0)} ₽',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------- БЛОК ИТОГОВ -------------------
  // ← Переведён на цвета темы.
  Widget _buildTotals() {
    final cs = Theme.of(context).colorScheme;

    final double total = _expenses.fold(0.0, (sum, e) => sum + e.amount);
    final double fixed = _expenses
        .where((e) => e.category == 'fixed')
        .fold(0.0, (sum, e) => sum + e.amount);
    final double personal = _expenses
        .where((e) => e.category == 'personal')
        .fold(0.0, (sum, e) => sum + e.amount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Итоги за месяц:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          _totalsRow('Всего:', total, cs.onPrimaryContainer, bold: true),
          _totalsRow('Обязательные:', fixed, cs.onPrimaryContainer),
          _totalsRow('Личные:', personal, cs.onPrimaryContainer),
        ],
      ),
    );
  }

  Widget _totalsRow(
    String label,
    double value,
    Color color, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, color: color)),
          Text(
            '${value.toStringAsFixed(2)} ₽',
            style: TextStyle(
              fontSize: bold ? 18 : 16,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    return months[month - 1];
  }

  String _translateSubcategory(String sub) {
    switch (sub) {
      case 'communal': return 'Коммуналка';
      case 'products': return 'Продукты';
      case 'supplies': return 'Расходники';
      case 'transport': return 'Транспорт';
      case 'health': return 'Здоровье';
      case 'education': return 'Образование';
      case 'restaurant': return 'Ресторан';
      case 'fastfood': return 'Фастфуд';
      case 'snacks': return 'Вкусняшки';
      case 'entertainment': return 'Развлечения';
      case 'gadgets': return 'Техника';
      case 'clothes': return 'Одежда';
      default: return sub;
    }
  }
}