// lib/models/category.dart

/// Подкатегория трат. Хранится в таблице `categories`.
///
/// `isArchived == true` — «мягко удалена»: не показывается в списках
/// выбора, но её `displayName` и `iconCode` сохраняются, чтобы старые
/// траты продолжали отображаться человекочитаемо.
class ExpenseCategory {
  final int? id;
  final String name;        // 'communal', 'custom_...' — ключ
  final String displayName; // 'Коммуналка', 'Еда'
  final String type;        // 'fixed' | 'personal'
  final int sortOrder;
  final bool isArchived;
  final String iconCode;    // ключ в kCategoryIcons

  const ExpenseCategory({
    this.id,
    required this.name,
    required this.displayName,
    required this.type,
    this.sortOrder = 0,
    this.isArchived = false,
    this.iconCode = 'label',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'display_name': displayName,
        'type': type,
        'sort_order': sortOrder,
        'is_archived': isArchived ? 1 : 0,
        'icon_code': iconCode,
      };

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) => ExpenseCategory(
        id: map['id'] as int?,
        name: map['name'] as String,
        displayName: map['display_name'] as String,
        type: map['type'] as String,
        sortOrder: (map['sort_order'] as int?) ?? 0,
        isArchived: (map['is_archived'] as int? ?? 0) == 1,
        iconCode: (map['icon_code'] as String?) ?? 'label',
      );

  ExpenseCategory copyWith({
    int? id,
    String? name,
    String? displayName,
    String? type,
    int? sortOrder,
    bool? isArchived,
    String? iconCode,
  }) =>
      ExpenseCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        displayName: displayName ?? this.displayName,
        type: type ?? this.type,
        sortOrder: sortOrder ?? this.sortOrder,
        isArchived: isArchived ?? this.isArchived,
        iconCode: iconCode ?? this.iconCode,
      );
}