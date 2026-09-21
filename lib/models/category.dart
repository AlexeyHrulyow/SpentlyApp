// lib/models/category.dart

/// Подкатегория трат. Хранится в таблице `categories`.
///
/// `isArchived == true` означает «мягко удалена»: она больше не показывается
/// в списках выбора, но её `displayName` сохраняется, чтобы старые траты
/// продолжали отображаться человекочитаемо.
class ExpenseCategory {
  final int? id;
  final String name;        // 'communal', 'custom_1712345678901', ... — ключ
  final String displayName; // 'Коммуналка', 'Еда' — то, что видит юзер
  final String type;        // 'fixed' | 'personal'
  final int sortOrder;
  final bool isArchived;

  const ExpenseCategory({
    this.id,
    required this.name,
    required this.displayName,
    required this.type,
    this.sortOrder = 0,
    this.isArchived = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'display_name': displayName,
        'type': type,
        'sort_order': sortOrder,
        'is_archived': isArchived ? 1 : 0,
      };

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) => ExpenseCategory(
        id: map['id'] as int?,
        name: map['name'] as String,
        displayName: map['display_name'] as String,
        type: map['type'] as String,
        sortOrder: (map['sort_order'] as int?) ?? 0,
        isArchived: (map['is_archived'] as int? ?? 0) == 1,
      );

  ExpenseCategory copyWith({
    int? id,
    String? name,
    String? displayName,
    String? type,
    int? sortOrder,
    bool? isArchived,
  }) =>
      ExpenseCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        displayName: displayName ?? this.displayName,
        type: type ?? this.type,
        sortOrder: sortOrder ?? this.sortOrder,
        isArchived: isArchived ?? this.isArchived,
      );
}