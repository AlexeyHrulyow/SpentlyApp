// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/expense.dart';
import '../providers/theme_provider.dart';
import '../providers/category_provider.dart';
import 'add_expense_screen.dart';
import 'edit_expense_screen.dart';
import 'stats_screen.dart';
import 'trend_screen.dart';
import 'data_screen.dart';
import 'categories_screen.dart';
import '../services/notification_service.dart';

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

  // Два независимых бюджета на месяц.
  double? _budgetFixed;
  double? _budgetPersonal;

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
    // Миграция: старый единый ключ больше не используем — чистим,
    // чтобы он не мусорил в SharedPreferences.
    await prefs.remove('budget_${_currentYear}_${_currentMonth}');

    final budgetFixed =
        prefs.getDouble('budget_fixed_${_currentYear}_${_currentMonth}');
    final budgetPersonal =
        prefs.getDouble('budget_personal_${_currentYear}_${_currentMonth}');

    // Проверяем пороги для каждой категории отдельно.
    await _checkBudgetThresholds(
      kind: 'fixed',
      budget: budgetFixed,
      spent: fixed,
      year: _currentYear,
      month: _currentMonth,
    );
    await _checkBudgetThresholds(
      kind: 'personal',
      budget: budgetPersonal,
      spent: personal,
      year: _currentYear,
      month: _currentMonth,
    );

    if (!mounted) return;
    setState(() {
      _expenses = expenses;
      _total = total;
      _totalFixed = fixed;
      _totalPersonal = personal;
      _budgetFixed = budgetFixed;
      _budgetPersonal = budgetPersonal;
      _isLoading = false;
    });
  }

  /// Проверка порогов одного бюджета. [kind] — 'fixed' или 'personal'.
  /// Флаги «уже отправлено» в SharedPreferences отдельные для каждой
  /// категории и каждого месяца, поэтому fixed и personal не глушат друг друга.
  Future<void> _checkBudgetThresholds({
    required String kind,
    required double? budget,
    required double spent,
    required int year,
    required int month,
  }) async {
    if (budget == null || budget <= 0) return;
    final percent = spent / budget;

    final prefs = await SharedPreferences.getInstance();
    final key80 = 'budget_notified_80_${kind}_${year}_${month}';
    final key100 = 'budget_notified_100_${kind}_${year}_${month}';

    // kindCode: 0 — fixed, 1 — personal.
    // Итоговый ID: year*10000 + month*100 + kindCode*10 + thresholdCode.
    // Для year=2026, month=10: fixed → 20261000/20261001, personal → 20261010/20261011.
    final int kindCode = kind == 'fixed' ? 0 : 1;
    final int baseId = year * 10000 + month * 100 + kindCode * 10;

    final String label = kind == 'fixed' ? 'Обязательные' : 'Личные';

    if (percent >= 1.0) {
      if (prefs.getBool(key100) != true) {
        await NotificationService.instance.showBudgetNotification(
          id: baseId + 1,
          title: 'Бюджет превышен · $label',
          body: 'Потрачено ${spent.toStringAsFixed(0)} ₽ из '
              '${budget.toStringAsFixed(0)} ₽ — лимит исчерпан.',
        );
        await prefs.setBool(key100, true);
        await prefs.setBool(key80, true);
      }
    } else if (percent >= 0.8) {
      if (prefs.getBool(key80) != true) {
        await NotificationService.instance.showBudgetNotification(
          id: baseId,
          title: 'Скоро закончится бюджет · $label',
          body: 'Потрачено уже ${(percent * 100).toStringAsFixed(0)}% '
              '(${spent.toStringAsFixed(0)} ₽ из '
              '${budget.toStringAsFixed(0)} ₽).',
        );
        await prefs.setBool(key80, true);
      }
    }
  }

  /// Сброс флагов «уже уведомляли» для обоих бюджетов за текущий месяц.
  /// Вызывается после изменения бюджетов, чтобы пороги пересчитались заново.
  Future<void> _resetBudgetNotifiedFlags(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    for (final kind in ['fixed', 'personal']) {
      await prefs.remove('budget_notified_80_${kind}_${year}_${month}');
      await prefs.remove('budget_notified_100_${kind}_${year}_${month}');
    }
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

  // ---------- УДАЛЕНИЕ ТРАТЫ ----------

  Future<void> _deleteExpense(int id) async {
    await DatabaseHelper.instance.deleteTransaction(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Трата удалена')),
    );
  }

  Future<bool> _confirmDeleteExpense() async {
    final result = await showDialog<bool>(
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
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    return result == true;
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

  // ---------- ДИАЛОГ БЮДЖЕТОВ ----------

  Future<void> _showBudgetsDialog() async {
    final result = await showDialog<_BudgetsResult>(
      context: context,
      builder: (_) => _BudgetsDialog(
        fixed: _budgetFixed,
        personal: _budgetPersonal,
      ),
    );
    if (result == null) return;

    final prefs = await SharedPreferences.getInstance();
    final fixedKey = 'budget_fixed_${_currentYear}_${_currentMonth}';
    final personalKey = 'budget_personal_${_currentYear}_${_currentMonth}';

    if (result.fixed != null) {
      await prefs.setDouble(fixedKey, result.fixed!);
    } else {
      await prefs.remove(fixedKey);
    }
    if (result.personal != null) {
      await prefs.setDouble(personalKey, result.personal!);
    } else {
      await prefs.remove(personalKey);
    }

    // Бюджеты изменились — пороги 80/100 нужно пересчитать заново.
    await _resetBudgetNotifiedFlags(_currentYear, _currentMonth);

    if (!mounted) return;
    setState(() {
      _budgetFixed = result.fixed;
      _budgetPersonal = result.personal;
    });

    await _checkBudgetThresholds(
      kind: 'fixed',
      budget: _budgetFixed,
      spent: _totalFixed,
      year: _currentYear,
      month: _currentMonth,
    );
    await _checkBudgetThresholds(
      kind: 'personal',
      budget: _budgetPersonal,
      spent: _totalPersonal,
      year: _currentYear,
      month: _currentMonth,
    );
  }

  /// Одна прогресс-шкала для конкретного бюджета.
  /// Если бюджета нет — возвращаем пустой виджет.
  Widget _buildBudgetProgress({
    required double? budget,
    required double spent,
  }) {
    if (budget == null || budget == 0) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final percent = spent / budget;
    final clampedPercent = percent.clamp(0.0, 1.0);

    final barColor = clampedPercent < 0.8
        ? Colors.green
        : (clampedPercent < 1.0 ? Colors.orange : Colors.red);

    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Бюджет: ${budget.toStringAsFixed(0)} ₽',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                ),
              ),
              Text(
                '${(clampedPercent * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.onPrimaryContainer.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: clampedPercent,
            backgroundColor: cs.surfaceContainerHighest,
            color: barColor,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>();

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
            icon: const Icon(Icons.trending_up),
            tooltip: 'Динамика по месяцам',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TrendScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.storage),
            tooltip: 'Данные и бэкапы',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DataScreen()),
              );
              if (result == true) {
                _loadData();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Категории',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoriesScreen(),
                ),
              );
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
                _buildFilters(categories),
                Expanded(child: _buildExpenseList(categories)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          bool? result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
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

  Widget _buildExpenseList(CategoryProvider categories) {
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
      itemBuilder: (context, index) =>
          _buildExpenseItem(filtered[index], categories),
    );
  }

  // ================== СВОДКА ==================
  // Теперь с двумя независимыми шкалами бюджета.
  Widget _buildSummary() {
    final cs = Theme.of(context).colorScheme;
    final String monthName = _getMonthName(_currentMonth);

    final bool hasAnyBudget = _budgetFixed != null || _budgetPersonal != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Переключатель месяца ---
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

          // --- Всего ---
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
          const SizedBox(height: 8),

          // --- Обязательные + прогресс ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Обязательные:',
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
          _buildBudgetProgress(budget: _budgetFixed, spent: _totalFixed),

          // --- Личные + прогресс ---
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
          _buildBudgetProgress(budget: _budgetPersonal, spent: _totalPersonal),

          // --- Кнопка настройки бюджетов ---
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showBudgetsDialog,
              child: Text(
                hasAnyBudget ? 'Настроить бюджеты' : 'Установить бюджеты',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(CategoryProvider categories) {
    final subSlugs = _expenses.map((e) => e.subcategory).toSet().toList();
    subSlugs.sort();

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
          if (subSlugs.isNotEmpty)
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
                      ...subSlugs.map((slug) {
                        return DropdownMenuItem<String>(
                          value: slug,
                          child: Row(
                            children: [
                              Icon(categories.iconOf(slug), size: 18),
                              const SizedBox(width: 8),
                              Text(categories.displayNameFor(slug)),
                            ],
                          ),
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

  Widget _buildExpenseItem(Expense expense, CategoryProvider categories) {
    final Color iconColor =
        expense.category == 'fixed' ? Colors.blue : Colors.orange;
    final IconData iconData = categories.iconOf(expense.subcategory);

    return Dismissible(
      key: Key(expense.id.toString()),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeleteExpense(),
      onDismissed: (_) {
        final removed = expense;
        setState(() {
          _expenses.removeWhere((e) => e.id == removed.id);
          _total -= removed.amount;
          if (removed.category == 'fixed') {
            _totalFixed -= removed.amount;
          } else {
            _totalPersonal -= removed.amount;
          }
        });
        _deleteExpense(removed.id!);
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
            '${categories.displayNameFor(expense.subcategory)}   '
            '${expense.date.toLocal().toString().split(' ')[0]}',
          ),
          trailing: expense.description.isNotEmpty
              ? Tooltip(
                  message: expense.description,
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
}

class _BudgetsResult {
  final double? fixed;
  final double? personal;
  const _BudgetsResult({this.fixed, this.personal});
}

class _BudgetsDialog extends StatefulWidget {
  final double? fixed;
  final double? personal;
  const _BudgetsDialog({this.fixed, this.personal});

  @override
  State<_BudgetsDialog> createState() => _BudgetsDialogState();
}

class _BudgetsDialogState extends State<_BudgetsDialog> {
  late final TextEditingController _fixedController;
  late final TextEditingController _personalController;

  @override
  void initState() {
    super.initState();
    _fixedController =
        TextEditingController(text: widget.fixed?.toString() ?? '');
    _personalController =
        TextEditingController(text: widget.personal?.toString() ?? '');
  }

  @override
  void dispose() {
    _fixedController.dispose();
    _personalController.dispose();
    super.dispose();
  }

  void _submit() {
    final fixed = double.tryParse(_fixedController.text.trim());
    final personal = double.tryParse(_personalController.text.trim());
    Navigator.pop(
      context,
      _BudgetsResult(
        fixed: (fixed != null && fixed > 0) ? fixed : null,
        personal: (personal != null && personal > 0) ? personal : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Бюджеты на месяц'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _fixedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Обязательные (₽)',
                hintText: 'Пусто — без лимита',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _personalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Личные (₽)',
                hintText: 'Пусто — без лимита',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
