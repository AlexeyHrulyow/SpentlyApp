// lib/services/receipt_parser.dart

/// Результат парсинга чека.
class ParsedReceipt {
  final double? amount;
  final DateTime? date;
  final String? suggestedSubcategory;
  final String rawText;

  const ParsedReceipt({
    this.amount,
    this.date,
    this.suggestedSubcategory,
    required this.rawText,
  });

  bool get hasAnyData => amount != null || date != null;
}

/// Парсер русского чека на основе регулярных выражений.
/// В Python это был бы модуль с функциями; в Dart — класс
/// со статическими методами (аналог static class в C#).
class ReceiptParser {
  ReceiptParser._();

  /// Ключевые слова, по которым ищем итоговую сумму.
  /// Порядок важен: «к оплате» приоритетнее, чем «итого»,
  /// потому что на некоторых чеках «итого» — это сумма без НДС.
  static const List<String> _amountKeywords = [
    'к оплате',
    'итого',
    'итог',
    'всего',
    'сумма',
    'наличными',
    'безналичными',
  ];

  /// Словарь магазинов → подкатегории.
  /// Ключи — в нижнем регистре, без «ё» (заменяем на «е» при поиске).
  static const Map<String, String> _storeKeywords = {
    'пятерочка': 'products',
    'магнит': 'products',
    'перекресток': 'products',
    'вкусвилл': 'products',
    'лента': 'products',
    'ашан': 'products',
    'метро': 'products',
    'дикси': 'products',
    'аптека': 'health',
    'ригла': 'health',
    'самокат': 'transport',
    'kfc': 'fastfood',
    'бургер кинг': 'fastfood',
    'вкусно и точка': 'fastfood',
    'додо': 'fastfood',
    'coffee': 'local_cafe',
    'кофейня': 'local_cafe',
  };

  /// Главный метод: принимает сырой текст, возвращает распарсенные поля.
  static ParsedReceipt parse(String rawText) {
    final normalized = _normalize(rawText);
    return ParsedReceipt(
      amount: _extractAmount(normalized),
      date: _extractDate(rawText),
      suggestedSubcategory: _suggestSubcategory(normalized),
      rawText: rawText,
    );
  }

  /// Нормализация текста для парсинга.
  /// - нижний регистр;
  /// - «ё» → «е» (Tesseract часто путает);
  /// - запятая в числах → точка;
  /// - множественные пробелы → один.
  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[ \t]+'), ' ');
  }

  /// Ищет сумму в строках, содержащих ключевые слова.
  static double? _extractAmount(String normalized) {
    final lines = normalized.split('\n');
    double? best;

    for (final line in lines) {
      final hasKeyword =
          _amountKeywords.any((kw) => line.contains(kw));
      if (!hasKeyword) continue;

      // Ищем все числа в строке. Формат: 1234, 1234.56, 1234,56
      final matches =
          RegExp(r'(\d+[.,]?\d*)').allMatches(line);
      for (final m in matches) {
        final numStr = m.group(1)!.replaceAll(',', '.');
        final val = double.tryParse(numStr);
        // Отсекаем мусор: ИНН (10-12 цифр), телефоны (11 цифр),
        // суммы > 1 000 000 ₽ для обычного чека — маловероятны.
        if (val != null && val > 0 && val < 1000000) {
          // Берём максимальную сумму: обычно итог справа больше,
          // чем количество товара слева.
          if (best == null || val > best) best = val;
        }
      }
    }

    // Fallback: если ключевые слова не найдены — ищем самую большую
    // сумму в последних 5 строках чека (там обычно итог).
    if (best == null) {
      final tailLines = lines.length > 5
          ? lines.sublist(lines.length - 5)
          : lines;
      for (final line in tailLines) {
        final matches =
            RegExp(r'(\d{2,}[.,]?\d*)').allMatches(line);
        for (final m in matches) {
          final numStr = m.group(1)!.replaceAll(',', '.');
          final val = double.tryParse(numStr);
          if (val != null && val > 0 && val < 1000000) {
            if (best == null || val > best) best = val;
          }
        }
      }
    }

    return best;
  }

  /// Ищет дату в формате ДД.ММ.ГГГГ / ДД/ММ/ГГГГ / ДД-ММ-ГГГГ.
  /// Берём последнее совпадение: дата чека обычно внизу.
  static DateTime? _extractDate(String raw) {
    final regex = RegExp(r'(\d{2})[./-](\d{2})[./-](\d{2,4})');
    final matches = regex.allMatches(raw).toList();
    if (matches.isEmpty) return null;

    final m = matches.last;
    int day = int.parse(m.group(1)!);
    int month = int.parse(m.group(2)!);
    int year = int.parse(m.group(3)!);

    // Если год двузначный (26) — добавляем 2000 → 2026.
    if (year < 100) year += 2000;

    // Валидация: месяц 1..12, день 1..31.
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;

    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  /// Ищет название магазина в первых 5 строках текста.
  static String? _suggestSubcategory(String normalized) {
    final headLines = normalized
        .split('\n')
        .take(5)
        .join(' ');
    for (final entry in _storeKeywords.entries) {
      if (headLines.contains(entry.key)) return entry.value;
    }
    return null;
  }
}