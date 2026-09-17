// lib/database/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/expense.dart';
import '../models/monthly_stats.dart';

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
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

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

  // ========== CRUD ==========

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

  /// Полная очистка таблицы. Используется при восстановлении из бэкапа
  /// в режиме «Заменить всё».
  Future<void> deleteAllTransactions() async {
    final db = await database;
    await db.delete('transactions');
  }

  // ========== Агрегат по месяцам для экрана «Динамика» ==========

  /// Возвращает список месяцев (в порядке от старого к новому),
  /// включая пустые (там, где не было трат, все суммы = 0).
  ///
  /// [monthsBack] — сколько последних месяцев включая текущий.
  Future<List<MonthlyStats>> getMonthlyStats({required int monthsBack}) async {
    final Database db = await database;
    final DateTime now = DateTime.now();

    // Дата начала: первое число месяца за (monthsBack - 1) месяцев назад.
    // DateTime в Dart сам нормализует выходящие за границы года значения,
    // поэтому DateTime(2026, -3, 1) корректно превратится в 2025-10-01.
    final DateTime start = DateTime(now.year, now.month - monthsBack + 1, 1);
    final String startDate = start.toIso8601String();

    // Один запрос группирует всё по году-месяцу и сразу считает
    // три суммы: общую, обязательные, личные. В Python это был бы
    // аналог pandas.groupby(...).agg({'amount': ['sum']}).
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

    // Раскладываем результаты в словарь по ключу 'YYYY-MM'.
    // strftime('%m') возвращает строку с ведущим нулём ('03'), поэтому
    // ключ '2026-03' сортируется лексикографически так же, как хронологически.
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

    // Строим полный список за monthsBack месяцев от старого к новому.
    // Для месяцев без записей подставляем нули — иначе график будет
    // «прыгать» с пропущенными точками.
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