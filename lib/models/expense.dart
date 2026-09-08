// lib/models/expense.dart

class Expense {
  // Поля класса
  int? id;                 // int? означает "может быть null" (для новых записей id нет)
  double amount;           // число с плавающей точкой
  String category;         // 'fixed' или 'personal'
  String subcategory;      // например, 'communal', 'restaurant'
  String description;      // описание, по умолчанию пустая строка
  DateTime date;           // дата и время

  // Конструктор класса
  Expense({
    this.id,               // именованный параметр, может отсутствовать (тогда null)
    required this.amount,  // required значит, что параметр обязателен
    required this.category,
    required this.subcategory,
    this.description = '', // значение по умолчанию
    required this.date,
  });

  // Преобразуем объект в Map (словарь) для вставки в БД
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'subcategory': subcategory,
      'description': description,
      'date': date.toIso8601String(), // дата в строковом формате ISO
    };
  }

  // Фабричный конструктор для создания объекта из Map (из БД)
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      amount: map['amount'].toDouble(),
      category: map['category'],
      subcategory: map['subcategory'],
      description: map['description'] ?? '', // если null, то пустая строка
      date: DateTime.parse(map['date']),     // парсим строку обратно в DateTime
    );
  }
}