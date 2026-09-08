// lib/screens/add_expense_screen.dart

import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../database/database_helper.dart';

class AddExpenseScreen extends StatefulWidget {
  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  // Контроллеры для полей ввода
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Переменные для хранения выбранных значений
  String _selectedCategory = 'fixed';   // по умолчанию 'fixed'
  String _selectedSubcategory = 'products';
  DateTime _selectedDate = DateTime.now();

  // Список подкатегорий для 'fixed'
  final List<String> fixedSubcategories = [
    'communal',
    'products',
    'supplies', // расходники
    'transport',
    'health',
    'education',
  ];

  // Список подкатегорий для 'personal'
  final List<String> personalSubcategories = [
    'restaurant',
    'fastfood',
    'snacks',
    'entertainment',
    'gadgets',
    'clothes',
  ];

  // Метод для сохранения траты
  Future<void> _saveExpense() async {
    // Считываем сумму из поля (преобразуем String в double)
    double amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      // Показываем ошибку, если сумма невалидна
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Введите корректную сумму')),
      );
      return;
    }

    // Создаём объект Expense
    Expense newExpense = Expense(
      amount: amount,
      category: _selectedCategory,
      subcategory: _selectedSubcategory,
      description: _descriptionController.text,
      date: _selectedDate,
    );

    // Вставляем в БД
    int id = await DatabaseHelper.instance.insertTransaction(newExpense);
    print('Добавлена трата с id: $id');

    // Возвращаемся на предыдущий экран (передаём сигнал об обновлении)
    // ignore: use_build_context_synchronously
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Добавить трату'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Поле для суммы
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Сумма (₽)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // Выбор категории (fixed / personal)
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              items: ['fixed', 'personal'].map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category == 'fixed' ? 'Обязательные' : 'Личные'),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedCategory = newValue!;
                  // При смене категории сбрасываем подкатегорию на первую из списка
                  _selectedSubcategory = _getSubcategories().first;
                });
              },
              decoration: InputDecoration(
                labelText: 'Категория',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // Выбор подкатегории (зависит от выбранной категории)
            DropdownButtonFormField<String>(
              initialValue: _selectedSubcategory,
              items: _getSubcategories().map((sub) {
                return DropdownMenuItem(
                  value: sub,
                  child: Text(_translateSubcategory(sub)),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedSubcategory = newValue!;
                });
              },
              decoration: InputDecoration(
                labelText: 'Подкатегория',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // Поле для описания
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Описание (необязательно)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            // Выбор даты
            Row(
              children: [
                Text(
                  'Дата: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                  style: TextStyle(fontSize: 16),
                ),
                Spacer(),
                ElevatedButton(
                  onPressed: () async {
                    // Открываем диалог выбора даты
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                  child: Text('Выбрать дату'),
                ),
              ],
            ),
            SizedBox(height: 32),

            // Кнопка сохранения
            Center(
              child: ElevatedButton.icon(
                onPressed: _saveExpense,
                icon: Icon(Icons.save),
                label: Text('Сохранить'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Вспомогательный метод: возвращает список подкатегорий в зависимости от категории
  List<String> _getSubcategories() {
    return _selectedCategory == 'fixed'
        ? fixedSubcategories
        : personalSubcategories;
  }

  // Вспомогательный метод: перевод подкатегорий на русский для отображения
  String _translateSubcategory(String sub) {
    switch (sub) {
      case 'communal':
        return 'Коммуналка';
      case 'products':
        return 'Продукты';
      case 'supplies':
        return 'Расходники';
      case 'transport':
        return 'Транспорт';
      case 'health':
        return 'Здоровье';
      case 'education':
        return 'Образование';
      case 'restaurant':
        return 'Ресторан';
      case 'fastfood':
        return 'Фастфуд';
      case 'snacks':
        return 'Вкусняшки';
      case 'entertainment':
        return 'Развлечения';
      case 'gadgets':
        return 'Техника';
      case 'clothes':
        return 'Одежда';
      default:
        return sub;
    }
  }
}