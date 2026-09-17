// lib/models/category.dart

/// Подкатегория трат. Хранится в таблице `categories`.
/// В `transactions.subcategory` лежит `name` — стабильный внутренний ключ,
/// который НЕ меняется при переименовании категории пользователем.
///
/// ⚠️ Название класса — ExpenseCategory, а не Category: во Flutter уже есть
/// аннотация `Category` из package:flutter/foundation.dart, и они конфликтуют.
class ExpenseCategory {
  final int? id;
  final String name;        // 'communal', 'custom_1712345678901', ... — ключ
  final String displayName; // 'Коммуналка', 'Еда' — то, что видит юзер
  final String type;        // 'fixed' | 'personal'
  final int sortOrder;

  const ExpenseCategory({
    this.id,
    required this.name,
    required this.displayName,
    required this.type,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'display_name': displayName,
        'type': type,
        'sort_order': sortOrder,
      };

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) => ExpenseCategory(
        id: map['id'] as int?,
        name: map['name'] as String,
        displayName: map['display_name'] as String,
        type: map['type'] as String,
        sortOrder: (map['sort_order'] as int?) ?? 0,
      );

  ExpenseCategory copyWith({
    int? id,
    String? name,
    String? displayName,
    String? type,
    int? sortOrder,
  }) =>
      ExpenseCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        displayName: displayName ?? this.displayName,
        type: type ?? this.type,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}