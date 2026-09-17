// lib/screens/edit_expense_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../database/database_helper.dart';
import '../providers/category_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: widget.expense.amount.toString());
    _descriptionController =
        TextEditingController(text: widget.expense.description);
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
    final double amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректную сумму')),
      );
      return;
    }

    final Expense updatedExpense = Expense(
      id: widget.expense.id,
      amount: amount,
      category: _selectedCategory,
      subcategory: _selectedSubcategory,
      description: _descriptionController.text,
      date: _selectedDate,
    );

    await DatabaseHelper.instance.updateTransaction(updatedExpense);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _deleteExpense() async {
    final bool? confirm = await showDialog<bool>(
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

    if (confirm == true && mounted) {
      await DatabaseHelper.instance.deleteTransaction(widget.expense.id!);
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();

    if (!provider.isLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Редактировать трату')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final subcategories = provider.byType(_selectedCategory);

    // Если slug траты отсутствует в списке (категорию удалили в другом
    // экране) — добавляем fallback-элемент, иначе Dropdown заассертит.
    final bool slugMissing =
        !subcategories.any((c) => c.name == _selectedSubcategory);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать трату'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
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
                      list.isEmpty ? '' : list.first.name;
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
              items: [
                if (slugMissing)
                  DropdownMenuItem(
                    value: _selectedSubcategory,
                    child: Text('$_selectedSubcategory (удалена)'),
                  ),
                ...subcategories.map((c) {
                  return DropdownMenuItem(
                    value: c.name,
                    child: Text(c.displayName),
                  );
                }),
              ],
              onChanged: (newValue) {
                setState(() => _selectedSubcategory = newValue ?? '');
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
                onPressed: _updateExpense,
                icon: const Icon(Icons.save),
                label: const Text('Обновить'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}