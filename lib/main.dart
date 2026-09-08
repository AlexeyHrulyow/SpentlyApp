// lib/main.dart

import 'package:flutter/material.dart';
import 'database/database_helper.dart';
import 'models/expense.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Spently — тест БД')),
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              // Создаём две тестовые траты
              var e1 = Expense(
                amount: 500.0,
                category: 'fixed',
                subcategory: 'products',
                description: 'Продукты в Пятёрочке',
                date: DateTime.now(),
              );
              var e2 = Expense(
                amount: 2500.0,
                category: 'personal',
                subcategory: 'restaurant',
                description: 'Ужин в ресторане',
                date: DateTime.now().subtract(Duration(days: 1)),
              );

              // Вставляем в БД
              int id1 = await DatabaseHelper.instance.insertTransaction(e1);
              int id2 = await DatabaseHelper.instance.insertTransaction(e2);
              print('Добавлены траты с id: $id1, $id2');

              // Получаем все траты
              List<Expense> all = await DatabaseHelper.instance.getAllTransactions();
              print('Все траты:');
              for (var e in all) {
                print('${e.id}: ${e.amount} руб. — ${e.subcategory} (${e.category})');
              }

              // Сумма за текущий месяц
              double total = await DatabaseHelper.instance.getTotalAmountForMonth(
                DateTime.now().year,
                DateTime.now().month,
              );
              print('Сумма за текущий месяц: $total руб.');

              // Показываем всплывающее сообщение об успехе
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Данные добавлены, смотрите консоль!')),
              );
            },
            child: Text('Запустить тест'),
          ),
        ),
      ),
    );
  }
}