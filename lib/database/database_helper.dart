// lib/database/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/expense.dart';
import '../models/monthly_stats.dart';
import '../models/category.dart';

class DatabaseHelper {
  DatabaseHelper._privateConstructor();

  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'spently.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ==================== СХЕМА ====================

  Future<void> _onCreate(Database db, int version) async {
    await _createTransactionsTable(db);
    await _createCategoriesTable(db);
    await _seedDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createCategoriesTable(db);
      await _seedDefaultCategories(db);
      return;
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE categories ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<void> _createTransactionsTable(Database db) async {
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

  Future<void> _createCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        type TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _seedDefaultCategories(Database db) async {
    const defaults = <List<String>>[
      ['communal',      'Коммуналка',  'fixed'],
      ['products',      'Продукты',    'fixed'],
      ['supplies',      'Расходники',  'fixed'],
      ['transport',     'Транспорт',   'fixed'],
      ['health',        'Здоровье',    'fixed'],
      ['education',     'Образование', 'fixed'],
      ['restaurant',    'Ресторан',    'personal'],
      ['fastfood',      'Фастфуд',     'personal'],
      ['snacks',        'Вкусняшки',   'personal'],
      ['entertainment', 'Развлечения', 'personal'],
      ['gadgets',       'Техника',     'personal'],
      ['clothes',       'Одежда',      'personal'],
    ];
    for (int i = 0; i < defaults.length; i++) {
      final row = defaults[i];
      await db.insert('categories', {
        'name': row[0],
        'display_name': row[1],
        'type': row[2],
        'sort_order': i,
      });
    }
  }

  // ==================== TRANSACTIONS CRUD ====================

  Future<int> insertTransaction(Expense expense) async {
    Database db = await database;
    return await db.insert('transactions', expense.toMap());
  }

  Future<List<Expense>> getAllTransactions() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

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

  Future<int> updateTransaction(Expense expense) async {
    Database db = await database;
    return await db.update(
      'transactions',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    Database db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getTotalAmountForMonth(int year, int month) async {
    Database db = await database;
    String startDate = DateTime(year, month, 1).toIso8601String();
    String endDate = DateTime(year, month + 1, 1).toIso8601String();

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions
      WHERE date >= ? AND date < ?
    ''', [startDate, endDate]);

    return result.first['total'] as double? ?? 0.0;
  }

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

  Future<void> deleteAllTransactions() async {
    final db = await database;
    await db.delete('transactions');
  }

  // ==================== CATEGORIES CRUD ====================

  /// Возвращает ВСЕ категории, включая архивные.
  /// Фильтрация (только активные для UI выбора) — на стороне Provider.
  Future<List<ExpenseCategory>> getAllCategories() async {
    final db = await database;
    final maps = await db.query(
      'categories',
      orderBy: 'type ASC, sort_order ASC, id ASC',
    );
    return maps.map(ExpenseCategory.fromMap).toList();
  }

  Future<int> insertCategory(ExpenseCategory category) async {
    final db = await database;
    final map = category.toMap()..remove('id');
    return db.insert('categories', map);
  }

  Future<int> updateCategory(ExpenseCategory category) async {
    final db = await database;
    return db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  /// Мягкое удаление: помечаем is_archived = 1.
  /// Строка остаётся в БД, её display_name используется для отображения
  /// старых трат. Из UI-списков категория пропадает.
  Future<int> archiveCategory(int id) async {
    final db = await database;
    return db.update(
      'categories',
      {'is_archived': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countTransactionsWithSubcategory(String name) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM transactions WHERE subcategory = ?',
      [name],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  // ==================== АГРЕГАТ ПО МЕСЯЦАМ ====================

  Future<List<MonthlyStats>> getMonthlyStats({required int monthsBack}) async {
    final Database db = await database;
    final DateTime now = DateTime.now();

    final DateTime start = DateTime(now.year, now.month - monthsBack + 1, 1);
    final String startDate = start.toIso8601String();

    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT
        strftime('%Y', date) AS year,
        strftime('%m', date) AS month,
        SUM(amount) AS total,
        SUM(CASE WHEN category = 'fixed'    THEN amount ELSE 0 END) AS fixed,
        SUM(CASE WHEN category = 'personal' THEN amount ELSE 0 END) AS personal
      FROM transactions
      WHERE date >= ?
      GROUP BY year, month
      ORDER BY year ASC, month ASC
    ''', [startDate]);

    final Map<String, MonthlyStats> byKey = {};
    for (final row in rows) {
      final int y = int.parse(row['year'] as String);
      final int m = int.parse(row['month'] as String);
      final String key = '$y-${m.toString().padLeft(2, '0')}';
      byKey[key] = MonthlyStats(
        year: y,
        month: m,
        total: (row['total'] as num?)?.toDouble() ?? 0.0,
        fixed: (row['fixed'] as num?)?.toDouble() ?? 0.0,
        personal: (row['personal'] as num?)?.toDouble() ?? 0.0,
      );
    }

    final List<MonthlyStats> result = [];
    for (int i = monthsBack - 1; i >= 0; i--) {
      final DateTime d = DateTime(now.year, now.month - i, 1);
      final String key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      result.add(
        byKey[key] ??
            MonthlyStats(
              year: d.year,
              month: d.month,
              total: 0,
              fixed: 0,
              personal: 0,
            ),
      );
    }

    return result;
  }
}