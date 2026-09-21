// lib/screens/add_expense_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spently/models/category.dart';
import '../models/expense.dart';
import '../models/category_icons.dart';
import '../database/database_helper.dart';
import '../providers/category_provider.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'fixed';
  String? _selectedSubcategory;
  DateTime _selectedDate = DateTime.now();

  bool _hasSaved = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _resetForm(List<ExpenseCategory> fixedCats) {
    _amountController.clear();
    _descriptionController.clear();
    _selectedCategory = 'fixed';
    _selectedSubcategory = fixedCats.isEmpty ? null : fixedCats.first.name;
    _selectedDate = DateTime.now();
  }

  Future<void> _saveExpense() async {
    if (_selectedSubcategory == null) return;
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
      subcategory: _selectedSubcategory!,
      description: _descriptionController.text,
      date: _selectedDate,
    );

    await DatabaseHelper.instance.insertTransaction(newExpense);
    if (!mounted) return;

    final provider = context.read<CategoryProvider>();
    setState(() {
      _hasSaved = true;
      _resetForm(provider.byType('fixed'));
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
    final provider = context.watch<CategoryProvider>();

    if (!provider.isLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Добавить трату')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final subcategories = provider.byType(_selectedCategory);

    if (_selectedSubcategory == null && subcategories.isNotEmpty) {
      _selectedSubcategory = subcategories.first.name;
    }
    if (_selectedSubcategory != null &&
        !subcategories.any((c) => c.name == _selectedSubcategory)) {
      _selectedSubcategory =
          subcategories.isEmpty ? null : subcategories.first.name;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
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
                items: const [
                  DropdownMenuItem(
                    value: 'fixed',
                    child: Text('Обязательные'),
                  ),
                  DropdownMenuItem(
                    value: 'personal',
                    child: Text('Личные'),
                  ),
                ],
                onChanged: (newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                    final list = provider.byType(_selectedCategory);
                    _selectedSubcategory =
                        list.isEmpty ? null : list.first.name;
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
                items: subcategories.map((c) {
                  return DropdownMenuItem(
                    value: c.name,
                    child: Row(
                      children: [
                        Icon(iconForCode(c.iconCode), size: 20),
                        const SizedBox(width: 8),
                        Text(c.displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: subcategories.isEmpty
                    ? null
                    : (newValue) {
                        setState(() => _selectedSubcategory = newValue);
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
                        setState(() => _selectedDate = picked);
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
}