// lib/services/backup_service.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database_helper.dart';
import '../models/expense.dart';

/// Результат импорта CSV-файла.
class ImportResult {
  final int added;
  final int skipped;
  final int errors;

  const ImportResult({
    required this.added,
    required this.skipped,
    required this.errors,
  });
}

/// Метаданные одного бэкапа для отображения в списке.
class BackupInfo {
  final File file;
  final DateTime createdAt;
  final int sizeBytes;
  final int recordCount;

  const BackupInfo({
    required this.file,
    required this.createdAt,
    required this.sizeBytes,
    required this.recordCount,
  });

  String get fileName => file.path.split(Platform.pathSeparator).last;

  String get formattedDate {
    String two(int n) => n.toString().padLeft(2, '0');
    final d = createdAt.toLocal();
    return '${two(d.day)}.${two(d.month)}.${d.year} '
        '${two(d.hour)}:${two(d.minute)}';
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes Б';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} КБ';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} МБ';
  }
}

/// Сервис резервных копий. Синглтон, как и DatabaseHelper.
class BackupService {
  BackupService._privateConstructor();
  static final BackupService instance = BackupService._privateConstructor();

  static const String _header = 'amount,category,subcategory,description,date';

  // ---------- папка бэкапов ----------

  Future<Directory> _getBackupsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'spently_backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // ---------- публичные методы ----------

  Future<BackupInfo> createBackup() async {
    final expenses = await DatabaseHelper.instance.getAllTransactions();
    final csv = _buildCsv(expenses);

    final dir = await _getBackupsDir();
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final name = 'spently_backup_'
        '${now.year}-${two(now.month)}-${two(now.day)}_'
        '${two(now.hour)}-${two(now.minute)}-${two(now.second)}.csv';
    final file = File(p.join(dir.path, name));

    // BOM в начале файла заставляет Excel корректно распознавать UTF-8,
    // иначе русские буквы в описаниях превратятся в кракозябры.
    await file.writeAsString('\uFEFF$csv', encoding: utf8);

    return _buildBackupInfo(file);
  }

  Future<List<BackupInfo>> listBackups() async {
    final dir = await _getBackupsDir();
    final entries = await dir.list().toList();
    final files = entries
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.csv'))
        .toList();

    final infos = <BackupInfo>[];
    for (final f in files) {
      try {
        infos.add(await _buildBackupInfo(f));
      } catch (_) {
        // Битый или недоступный файл — просто пропускаем.
      }
    }

    // Свежие бэкапы — сверху.
    infos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return infos;
  }

  Future<ImportResult> importFromFile(
    File file, {
    bool replaceExisting = false,
  }) async {
    final raw = await file.readAsString(encoding: utf8);
    final content = raw.startsWith('\uFEFF') ? raw.substring(1) : raw;

    final rows = _parseCsv(content);
    if (rows.length <= 1) {
      return const ImportResult(added: 0, skipped: 0, errors: 0);
    }

    final dataRows =
        rows.skip(1).where((r) => r.any((c) => c.trim().isNotEmpty)).toList();

    // При режиме замены чистим таблицу до вставки.
    // Делаем это ПОСЛЕ успешного парсинга CSV — если файл битый,
    // данные не потеряем.
    if (replaceExisting) {
      await DatabaseHelper.instance.deleteAllTransactions();
    }

    // Ключи существующих записей — только для режима merge.
    // В режиме replace это пустое множество: отсеивать нечего.
    final Set<String> existingKeys;
    if (replaceExisting) {
      existingKeys = <String>{};
    } else {
      final existing = await DatabaseHelper.instance.getAllTransactions();
      existingKeys = existing.map(_dedupKey).toSet();
    }

    int added = 0;
    int skipped = 0;
    int errors = 0;

    for (final row in dataRows) {
      try {
        if (row.length < 5) {
          errors++;
          continue;
        }

        final amount = double.tryParse(row[0]);
        final category = row[1].trim();
        final subcategory = row[2].trim();
        final description = row[3];
        final date = DateTime.tryParse(row[4]);

        if (amount == null ||
            date == null ||
            category.isEmpty ||
            subcategory.isEmpty) {
          errors++;
          continue;
        }

        final expense = Expense(
          amount: amount,
          category: category,
          subcategory: subcategory,
          description: description,
          date: date,
        );

        final key = _dedupKey(expense);
        if (existingKeys.contains(key)) {
          skipped++;
          continue;
        }

        await DatabaseHelper.instance.insertTransaction(expense);
        existingKeys.add(key);
        added++;
      } catch (_) {
        errors++;
      }
    }

    return ImportResult(added: added, skipped: skipped, errors: errors);
  }

  Future<void> deleteBackup(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ---------- внутренние помощники ----------

  /// Две траты считаем одинаковыми, если совпадают все значимые поля.
  /// id не используем: в разных БД он разный.
  String _dedupKey(Expense e) {
    return '${e.amount}|${e.category}|${e.subcategory}|'
        '${e.description}|${e.date.toIso8601String()}';
  }

  Future<BackupInfo> _buildBackupInfo(File file) async {
    final stat = await file.stat();
    final lines = await file.readAsLines(encoding: utf8);
    final recordCount = lines.isEmpty ? 0 : math.max(0, lines.length - 1);
    return BackupInfo(
      file: file,
      createdAt: stat.modified,
      sizeBytes: stat.size,
      recordCount: recordCount,
    );
  }

  String _buildCsv(List<Expense> expenses) {
    final buffer = StringBuffer();
    buffer.writeln(_header);
    for (final e in expenses) {
      buffer.writeln([
        e.amount.toString(),
        _csvField(e.category),
        _csvField(e.subcategory),
        _csvField(e.description),
        e.date.toIso8601String(),
      ].join(','));
    }
    return buffer.toString();
  }

  /// Экранируем поле, если в нём есть запятая, кавычка или перевод строки.
  /// Двойные кавычки внутри поля заменяем на две подряд (стандарт RFC 4180).
  String _csvField(String value) {
    final needsQuotes = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  /// Конечный автомат для разбора CSV.
  /// Понимает кавычки, экранированные кавычки ("") и переводы строк
  /// внутри кавычек. Простой `split(',')` тут бы не справился.
  List<List<String>> _parseCsv(String content) {
    final rows = <List<String>>[];
    final row = <String>[];
    final field = StringBuffer();
    bool inQuotes = false;
    int i = 0;

    while (i < content.length) {
      final ch = content[i];

      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            field.write('"');
            i += 2;
          } else {
            inQuotes = false;
            i++;
          }
        } else {
          field.write(ch);
          i++;
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
          i++;
        } else if (ch == ',') {
          row.add(field.toString());
          field.clear();
          i++;
        } else if (ch == '\n' || ch == '\r') {
          row.add(field.toString());
          field.clear();
          rows.add(List<String>.from(row));
          row.clear();
          i++;
          if (ch == '\r' && i < content.length && content[i] == '\n') {
            i++;
          }
        } else {
          field.write(ch);
          i++;
        }
      }
    }

    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }

    return rows;
  }
}