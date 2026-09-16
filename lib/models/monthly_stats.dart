// lib/models/monthly_stats.dart

/// Агрегат по одному месяцу: сколько всего потрачено и как это
/// распределилось между обязательными и личными расходами.
///
/// В Python это был бы `@dataclass`, в C# — `record`.
class MonthlyStats {
  final int year;
  final int month;
  final double total;
  final double fixed;
  final double personal;

  const MonthlyStats({
    required this.year,
    required this.month,
    required this.total,
    required this.fixed,
    required this.personal,
  });

  /// Короткое имя месяца для подписей на оси X: 'Янв', 'Фев', ...
  String get shortMonthName {
    const months = [
      'Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
      'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек',
    ];
    return months[month - 1];
  }

  /// Полное имя: 'Январь', 'Февраль', ...
  String get fullMonthName {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
    ];
    return months[month - 1];
  }
}