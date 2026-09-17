// lib/providers/category_provider.dart

import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/category.dart';

/// Кэш категорий в памяти + CRUD-обёртка над DatabaseHelper.
/// Регистрируется в main.dart как ChangeNotifierProvider.
class CategoryProvider extends ChangeNotifier {
  final List<ExpenseCategory> _categories = [];
  bool _loaded = false;

  List<ExpenseCategory> get all => List.unmodifiable(_categories);
  bool get isLoaded => _loaded;

  /// Категории одного типа ('fixed' или 'personal').
  List<ExpenseCategory> byType(String type) =>
      _categories.where((c) => c.type == type).toList();

  /// slug → отображаемое имя. Если slug неизвестен (категорию удалили,
  /// а старая трата осталась) — возвращаем сам slug, чтобы UI не падал.
  String displayNameFor(String slug) {
    for (final c in _categories) {
      if (c.name == slug) return c.displayName;
    }
    return slug;
  }

  Future<void> load() async {
    final list = await DatabaseHelper.instance.getAllCategories();
    _categories
      ..clear()
      ..addAll(list);
    _loaded = true;
    notifyListeners();
  }

  /// Создание новой категории. `name` генерируется автоматически —
  /// юзер вводит только отображаемое имя.
  Future<void> add({
    required String displayName,
    required String type,
  }) async {
    final name = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final sortOrder = byType(type).length;
    final cat = ExpenseCategory(
      name: name,
      displayName: displayName,
      type: type,
      sortOrder: sortOrder,
    );
    await DatabaseHelper.instance.insertCategory(cat);
    await load();
  }

  Future<void> update(ExpenseCategory category) async {
    await DatabaseHelper.instance.updateCategory(category);
    await load();
  }

  Future<void> delete(int id) async {
    await DatabaseHelper.instance.deleteCategory(id);
    await load();
  }

  Future<int> countUsages(String slug) =>
      DatabaseHelper.instance.countTransactionsWithSubcategory(slug);
}