// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/expense.dart';
import '../providers/theme_provider.dart';
import 'add_expense_screen.dart';
import 'edit_expense_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentYear = DateTime.now().year;
  int _currentMonth = DateTime.now().month;

  String? _filterCategory;
  String? _filterSubcategory;

  List<Expense> _expenses = [];
  double _total = 0.0;
  double _totalFixed = 0.0;
  double _totalPersonal = 0.0;
  double? _budget;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    List<Expense> expenses = await DatabaseHelper.instance
        .getTransactionsForMonth(_currentYear, _currentMonth);

    double total = 0.0;
    double fixed = 0.0;
    double personal = 0.0;
    for (var e in expenses) {
      total += e.amount;
      if (e.category == 'fixed') {
        fixed += e.amount;
      } else {
        personal += e.amount;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final budgetKey = 'budget_${_currentYear}_${_currentMonth}';
    final budget = prefs.getDouble(budgetKey);

    if (!mounted) return;
    setState(() {
      _expenses = expenses;
      _total = total;
      _totalFixed = fixed;
      _totalPersonal = personal;
      _budget = budget;
      _isLoading = false;
    });
  }

  void _resetFilters() {
    setState(() {
      _filterCategory = null;
      _filterSubcategory = null;
    });
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
    _resetFilters();
    _loadData();
  }

  Future<void> _deleteExpense(int id) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить трату?'),
        content: const Text('Вы уверены?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteTransaction(id);
      _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Трата удалена')),
      );
    }
  }

  List<Expense> _getFilteredExpenses() {
    var filtered = _expenses;
    if (_filterCategory != null) {
      filtered = filtered.where((e) => e.category == _filterCategory).toList();
    }
    if (_filterSubcategory != null) {
      filtered =
          filtered.where((e) => e.subcategory == _filterSubcategory).toList();
    }
    return filtered;
  }

  Future<void> _showBudgetDialog() async {
    final controller = TextEditingController();
    if (_budget != null) controller.text = _budget!.toString();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Бюджет на месяц'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Сумма бюджета (₽)',
            hintText: 'Введите сумму',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Введите корректную сумму')),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      final budgetKey = 'budget_${_currentYear}_${_currentMonth}';
      await prefs.setDouble(budgetKey, result);
      if (!mounted) return;
      setState(() => _budget = result);
    }
  }

  // ← Фон прогресс-бара берём из темы, а не хардкодим серый.
  Widget _buildBudgetProgress() {
    if (_budget == null || _budget == 0) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final spent = _total;
    final percent = spent / _budget!;
    final clampedPercent = percent.clamp(0.0, 1.0);

    final barColor = clampedPercent < 0.8
        ? Colors.green
        : (clampedPercent < 1.0 ? Colors.orange : Colors.red);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Бюджет: ${_budget!.toStringAsFixed(0)} ₽'),
              Text(
                'Потрачено: ${spent.toStringAsFixed(0)} ₽ '
                '(${(clampedPercent * 100).toStringAsFixed(0)}%)',
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: clampedPercent,
            // ← surfaceContainerHighest: светло-серый в light, тёмно-серый в dark.
            backgroundColor: cs.surfaceContainerHighest,
            color: barColor,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spently'),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return IconButton(
                icon: Icon(
                  themeProvider.themeMode == ThemeMode.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                onPressed: themeProvider.toggleTheme,
                tooltip: 'Сменить тему',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StatsScreen(
                    initialYear: _currentYear,
                    initialMonth: _currentMonth,
                  ),
                ),
              );
              if (result != null && result is Map<String, int>) {
                setState(() {
                  _currentYear = result['year']!;
                  _currentMonth = result['month']!;
                });
                _resetFilters();
                _loadData();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummary(),
                _buildFilters(),
                // ← Фильтр считается один раз, а не в каждой итерации ListView.
                Expanded(child: _buildExpenseList()),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          bool? result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddExpenseScreen()),
          );
          if (result == true) {
            _loadData();
          }
        },
        child: const Icon(Icons.add),
        tooltip: 'Добавить трату',
      ),
    );
  }

  Widget _buildExpenseList() {
    final filtered = _getFilteredExpenses();
    if (filtered.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Text(
          'Нет трат за этот месяц',
          style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
        ),
      );
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildExpenseItem(filtered[index]),
    );
  }

  // ================== СВОДКА ==================
  // ← Полностью переведена на цвета темы.
  Widget _buildSummary() {
    final cs = Theme.of(context).colorScheme;
    final String monthName = _getMonthName(_currentMonth);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // primaryContainer: светло-синяя в light, тёмно-синяя в dark.
        color: cs.primaryContainer,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1),
                color: cs.onPrimaryContainer,
              ),
              Text(
                '$monthName $_currentYear',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimaryContainer,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(1),
                color: cs.onPrimaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Всего:',
                style: TextStyle(fontSize: 16, color: cs.onPrimaryContainer),
              ),
              Text(
                '${_total.toStringAsFixed(2)} ₽',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Обязательные:',
                // ← onPrimaryContainer с прозрачностью вместо серого.
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                ),
              ),
              Text(
                '${_totalFixed.toStringAsFixed(2)} ₽',
                style: TextStyle(
                  fontSize: 16,
                  color: cs.onPrimaryContainer.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Личные:',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                ),
              ),
              Text(
                '${_totalPersonal.toStringAsFixed(2)} ₽',
                style: TextStyle(
                  fontSize: 16,
                  color: cs.onPrimaryContainer.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          _buildBudgetProgress(),
          if (_budget == null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showBudgetDialog,
                child: const Text('Установить бюджет'),
              ),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: _showBudgetDialog,
                    child: const Text('Изменить'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final budgetKey =
                          'budget_${_currentYear}_${_currentMonth}';
                      await prefs.remove(budgetKey);
                      if (!mounted) return;
                      setState(() => _budget = null);
                    },
                    child: const Text(
                      'Удалить',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final subcategories =
        _expenses.map((e) => e.subcategory).toSet().toList();
    subcategories.sort();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Категория:',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _buildCategoryChip('Все', null),
              _buildCategoryChip('Обязательные', 'fixed'),
              _buildCategoryChip('Личные', 'personal'),
            ],
          ),
          const SizedBox(height: 8),
          if (subcategories.isNotEmpty)
            Row(
              children: [
                const Text(
                  'Подкатегория:',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    hint: const Text('Все'),
                    value: _filterSubcategory,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Все'),
                      ),
                      ...subcategories.map((sub) {
                        return DropdownMenuItem<String>(
                          value: sub,
                          child: Text(_translateSubcategory(sub)),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _filterSubcategory = value);
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String? value) {
    final bool isSelected = _filterCategory == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterCategory = selected ? value : null);
      },
    );
  }

  Widget _buildExpenseItem(Expense expense) {
    final Color iconColor =
        expense.category == 'fixed' ? Colors.blue : Colors.orange;
    final IconData iconData = expense.category == 'fixed'
        ? Icons.home_work
        : Icons.person_outline;

    return Dismissible(
      key: Key(expense.id.toString()),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _deleteExpense(expense.id!);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: iconColor.withValues(alpha: 0.2),
            child: Icon(iconData, color: iconColor),
          ),
          title: Text(
            '${expense.amount.toStringAsFixed(2)} ₽',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${_translateSubcategory(expense.subcategory)}   '
            '${expense.date.toLocal().toString().split(' ')[0]}',
          ),
          trailing: expense.description.isNotEmpty
              ? Tooltip(
                  message: expense.description,
                  // ← без цвета: наследуется из темы (было Colors.grey).
                  child: const Icon(Icons.info_outline),
                )
              : null,
          onTap: () async {
            bool? updated = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditExpenseScreen(expense: expense),
              ),
            );
            if (updated == true) {
              _loadData();
            }
          },
        ),
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