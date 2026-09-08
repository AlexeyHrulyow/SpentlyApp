// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/expense.dart';
import 'add_expense_screen.dart';
import 'edit_expense_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Текущий месяц (год и месяц)
  int _currentYear = DateTime.now().year;
  int _currentMonth = DateTime.now().month;

  // Список трат за текущий месяц
  List<Expense> _expenses = [];
  // Итоговые суммы
  double _total = 0.0;
  double _totalFixed = 0.0;
  double _totalPersonal = 0.0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Загрузка данных из БД
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    // Получаем траты за месяц
    List<Expense> expenses = await DatabaseHelper.instance.getTransactionsForMonth(
      _currentYear,
      _currentMonth,
    );

    // Считаем суммы
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

    setState(() {
      _expenses = expenses;
      _total = total;
      _totalFixed = fixed;
      _totalPersonal = personal;
      _isLoading = false;
    });
  }

  // Переключение месяца
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

  // Удаление траты (с подтверждением)
  Future<void> _deleteExpense(int id) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить трату?'),
        content: Text('Вы уверены?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteTransaction(id);
      _loadData(); // обновляем список
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Трата удалена')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Spently'),
        actions: [
          // Кнопка для обновления (на случай, если данные не обновились)
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Сводка за месяц
                _buildSummary(),
                // Список трат
                Expanded(
                  child: _expenses.isEmpty
                      ? Center(
                          child: Text(
                            'Нет трат за этот месяц',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _expenses.length,
                          itemBuilder: (context, index) {
                            final expense = _expenses[index];
                            return _buildExpenseItem(expense);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Переход на экран добавления и ожидание результата
          bool? result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddExpenseScreen()),
          );
          if (result == true) {
            // Если пользователь сохранил трату — обновляем данные
            _loadData();
          }
        },
        child: Icon(Icons.add),
        tooltip: 'Добавить трату',
      ),
    );
  }

  // Виджет сводки (итоги за месяц)
  Widget _buildSummary() {
    String monthName = _getMonthName(_currentMonth);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Переключатель месяца
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1),
              ),
              Text(
                '$monthName $_currentYear',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          SizedBox(height: 8),
          // Общая сумма
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Всего:', style: TextStyle(fontSize: 16)),
              Text(
                '${_total.toStringAsFixed(2)} ₽',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Обязательные:', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
              Text(
                '${_totalFixed.toStringAsFixed(2)} ₽',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Личные:', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
              Text(
                '${_totalPersonal.toStringAsFixed(2)} ₽',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Виджет одной траты в списке
  Widget _buildExpenseItem(Expense expense) {
    // Определяем цвет иконки в зависимости от категории
    Color iconColor = expense.category == 'fixed' ? Colors.blue : Colors.orange;
    IconData iconData = expense.category == 'fixed'
        ? Icons.home_work
        : Icons.person_outline;

    return Dismissible(
      key: Key(expense.id.toString()),
      background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 20), child: Icon(Icons.delete, color: Colors.white)),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _deleteExpense(expense.id!);
      },
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.2),
            child: Icon(iconData, color: iconColor),
          ),
          title: Text(
            '${expense.amount.toStringAsFixed(2)} ₽',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('${_translateSubcategory(expense.subcategory)}   ${expense.date.toLocal().toString().split(' ')[0]}'),
          trailing: expense.description.isNotEmpty
              ? Tooltip(
                  message: expense.description,
                  child: Icon(Icons.info_outline, color: Colors.grey),
                )
              : null,
          onTap: () async {
            // Открываем экран редактирования и ждём результат
            bool? updated = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditExpenseScreen(expense: expense),
              ),
            );
            if (updated == true) {
              _loadData(); // обновляем список после редактирования
            }
          },
        ),
      ),
    );
  }

  // Вспомогательные методы
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