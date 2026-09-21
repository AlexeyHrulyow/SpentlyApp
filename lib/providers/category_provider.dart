// lib/providers/category_provider.dart

import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/category.dart';

/// Кэш категорий в памяти + CRUD-обёртка над DatabaseHelper.
class CategoryProvider extends ChangeNotifier {
  final List<ExpenseCategory> _categories = [];
  bool _loaded = false;

  /// Активные (не архивные) категории.
  List<ExpenseCategory> get all =>
      _categories.where((c) => !c.isArchived).toList();

  bool get isLoaded => _loaded;

  /// Активные категории указанного типа ('fixed' | 'personal').
  List<ExpenseCategory> byType(String type) => _categories
      .where((c) => c.type == type && !c.isArchived)
      .toList();

  /// slug → отображаемое имя. Работает и для архивных категорий:
  /// старая трата с удалённой категорией покажет своё прежнее имя.
  /// Если slug вообще неизвестен — возвращаем его самого, чтобы UI не падал.
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

  /// Мягкое удаление. Транзакции со старым slug не трогаем.
  Future<void> delete(int id) async {
    await DatabaseHelper.instance.archiveCategory(id);
    await load();
  }

  Future<int> countUsages(String slug) =>
      DatabaseHelper.instance.countTransactionsWithSubcategory(slug);
}