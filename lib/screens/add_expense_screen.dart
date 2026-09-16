// lib/screens/add_expense_screen.dart

import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../database/database_helper.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'fixed';
  String _selectedSubcategory = 'communal';
  DateTime _selectedDate = DateTime.now();

  // Флаг: сохранили ли мы хотя бы одну трату за время работы экрана.
  // Его вернём на главный экран через Navigator.pop, чтобы тот решил,
  // обновлять ли данные.
  bool _hasSaved = false;

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
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Сбрасываем форму в исходное состояние.
  void _resetForm() {
    _amountController.clear();
    _descriptionController.clear();
    _selectedCategory = 'fixed';
    _selectedSubcategory = fixedSubcategories.first;
    _selectedDate = DateTime.now();
  }

  Future<void> _saveExpense() async {
    final double amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректную сумму')),
      );
      return;
    }

    final Expense newExpense = Expense(
      amount: amount,
      category: _selectedCategory,
      subcategory: _selectedSubcategory,
      description: _descriptionController.text,
      date: _selectedDate,
    );

    await DatabaseHelper.instance.insertTransaction(newExpense);

    // После await виджет мог быть удалён — обязательно проверяем.
    if (!mounted) return;

    setState(() {
      _hasSaved = true;
      _resetForm();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Трата добавлена'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Перехватываем системную кнопку «Назад», чтобы вернуть _hasSaved.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return; // уже закрылись — ничего не делаем
        Navigator.pop(context, _hasSaved);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Добавить трату'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Закрыть',
            onPressed: () => Navigator.pop(context, _hasSaved),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Сумма (₽)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                items: ['fixed', 'personal'].map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(
                      category == 'fixed' ? 'Обязательные' : 'Личные',
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                    _selectedSubcategory = _getSubcategories().first;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Категория',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

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
                decoration: const InputDecoration(
                  labelText: 'Подкатегория',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Описание (необязательно)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Text(
                    'Дата: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null && mounted) {
                        setState(() {
                          _selectedDate = picked;
                        });
                      }
                    },
                    child: const Text('Выбрать дату'),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Center(
                child: ElevatedButton.icon(
                  onPressed: _saveExpense,
                  icon: const Icon(Icons.save),
                  label: const Text('Сохранить'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
            ],
          ),
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