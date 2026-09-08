// lib/database/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/expense.dart';

class DatabaseHelper {
  // Приватный конструктор – чтобы нельзя было создать экземпляр извне
  DatabaseHelper._privateConstructor();
  
  // Единственный экземпляр (синглтон)
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // Переменная для хранения объекта базы данных (может быть null)
  static Database? _database;

  // Геттер, который возвращает Future<Database> – асинхронно открывает БД
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Инициализация базы данных (создание файла и таблиц)
  Future<Database> _initDatabase() async {
    // Получаем путь к папке приложения
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'spently.db');
    
    // Открываем базу данных (если файла нет – создаётся)
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Создание таблицы при первом запуске
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        subcategory TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL
      )
    ''');
  }

  // ========== Методы для работы с данными (CRUD) ==========

  // Вставка новой траты
  Future<int> insertTransaction(Expense expense) async {
    Database db = await database;
    return await db.insert('transactions', expense.toMap());
  }

  // Получить все траты (сортировка по дате, новые сверху)
  Future<List<Expense>> getAllTransactions() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  // Получить траты за определённый месяц (год, месяц)
  Future<List<Expense>> getTransactionsForMonth(int year, int month) async {
    Database db = await database;
    String startDate = DateTime(year, month, 1).toIso8601String();
    String endDate = DateTime(year, month + 1, 1).toIso8601String();
    
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  // Обновить существующую трату
  Future<int> updateTransaction(Expense expense) async {
    Database db = await database;
    return await db.update(
      'transactions',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  // Удалить трату по id
  Future<int> deleteTransaction(int id) async {
    Database db = await database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Получить сумму всех трат за месяц
  Future<double> getTotalAmountForMonth(int year, int month) async {
    Database db = await database;
    String startDate = DateTime(year, month, 1).toIso8601String();
    String endDate = DateTime(year, month + 1, 1).toIso8601String();
    
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions
      WHERE date >= ? AND date < ?
    ''', [startDate, endDate]);
    
    // Если нет записей, result[0]['total'] может быть null, поэтому используем ?? 0.0
    return result.first['total'] as double? ?? 0.0;
  }

  // Дополнительно: суммы по категориям за месяц
  Future<Map<String, double>> getCategoryTotalsForMonth(int year, int month) async {
    Database db = await database;
    String startDate = DateTime(year, month, 1).toIso8601String();
    String endDate = DateTime(year, month + 1, 1).toIso8601String();
    
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT category, SUM(amount) as total FROM transactions
      WHERE date >= ? AND date < ?
      GROUP BY category
    ''', [startDate, endDate]);
    
    Map<String, double> totals = {};
    for (var row in result) {
      totals[row['category']] = (row['total'] as double?) ?? 0.0;
    }
    return totals;
  }
}