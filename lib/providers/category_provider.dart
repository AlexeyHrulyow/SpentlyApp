// lib/providers/category_provider.dart

import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/category.dart';
import '../models/category_icons.dart';

class CategoryProvider extends ChangeNotifier {
  final List<ExpenseCategory> _categories = [];
  bool _loaded = false;

  List<ExpenseCategory> get all =>
      _categories.where((c) => !c.isArchived).toList();

  bool get isLoaded => _loaded;

  List<ExpenseCategory> byType(String type) => _categories
      .where((c) => c.type == type && !c.isArchived)
      .toList();

  /// slug → отображаемое имя. Работает и для архивных категорий.
  String displayNameFor(String slug) {
    for (final c in _categories) {
      if (c.name == slug) return c.displayName;
    }
    return slug;
  }

  /// slug → IconData. Если slug неизвестен — дефолтная иконка.
  IconData iconOf(String slug) {
    for (final c in _categories) {
      if (c.name == slug) return iconForCode(c.iconCode);
    }
    return kDefaultCategoryIcon;
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
    required String iconCode,
  }) async {
    final name = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final sortOrder = byType(type).length;
    final cat = ExpenseCategory(
      name: name,
      displayName: displayName,
      type: type,
      iconCode: iconCode,
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
    await DatabaseHelper.instance.archiveCategory(id);
    await load();
  }

  Future<int> countUsages(String slug) =>
      DatabaseHelper.instance.countTransactionsWithSubcategory(slug);
}