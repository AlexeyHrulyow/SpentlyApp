// lib/screens/edit_expense_screen.dart

import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../database/database_helper.dart';

class EditExpenseScreen extends StatefulWidget {
  final Expense expense;

  const EditExpenseScreen({Key? key, required this.expense}) : super(key: key);

  @override
  _EditExpenseScreenState createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  late String _selectedCategory;
  late String _selectedSubcategory;
  late DateTime _selectedDate;

  final List<String> fixedSubcategories = [
    'communal',
    'products',
    'supplies',
    'transport',
    'health',
    'education',
  ];

  final List<String> personalSubcategories = [
    'restaurant',
    'fastfood',
    'snacks',
    'entertainment',
    'gadgets',
    'clothes',
  ];

  @override
  void initState() {
    super.initState();
    // Инициализируем контроллеры и переменные значениями из expense
    _amountController = TextEditingController(text: widget.expense.amount.toString());
    _descriptionController = TextEditingController(text: widget.expense.description);
    _selectedCategory = widget.expense.category;
    _selectedSubcategory = widget.expense.subcategory;
    _selectedDate = widget.expense.date;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateExpense() async {
    double amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Введите корректную сумму')),
      );
      return;
    }

    // Создаём обновлённый объект (с тем же id)
    Expense updatedExpense = Expense(
      id: widget.expense.id,
      amount: amount,
      category: _selectedCategory,
      subcategory: _selectedSubcategory,
      description: _descriptionController.text,
      date: _selectedDate,
    );

    await DatabaseHelper.instance.updateTransaction(updatedExpense);
    print('Обновлена трата с id: ${widget.expense.id}');

    // Возвращаем true, чтобы на главном экране обновился список
    Navigator.pop(context, true);
  }

  Future<void> _deleteExpense() async {
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
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteTransaction(widget.expense.id!);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Редактировать трату'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteExpense,
            tooltip: 'Удалить трату',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Сумма (₽)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedCategory,
              items: ['fixed', 'personal'].map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category == 'fixed' ? 'Обязательные' : 'Личные'),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedCategory = newValue!;
                  _selectedSubcategory = _getSubcategories().first;
                });
              },
              decoration: InputDecoration(
                labelText: 'Категория',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedSubcategory,
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

            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Описание (необязательно)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Text(
                  'Дата: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                  style: TextStyle(fontSize: 16),
                ),
                Spacer(),
                ElevatedButton(
                  onPressed: () async {
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

            Center(
              child: ElevatedButton.icon(
                onPressed: _updateExpense,
                icon: Icon(Icons.save),
                label: Text('Обновить'),
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

  List<String> _getSubcategories() {
    return _selectedCategory == 'fixed'
        ? fixedSubcategories
        : personalSubcategories;
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