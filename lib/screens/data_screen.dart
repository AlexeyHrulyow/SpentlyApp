// lib/screens/data_screen.dart

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../services/backup_service.dart';

/// Способ восстановления из бэкапа.
enum RestoreMode {
  /// Добавить к текущим данным, пропуская дубликаты.
  merge,

  /// Удалить все текущие данные и заменить содержимым файла.
  replace,
}

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  List<BackupInfo> _backups = [];
  bool _isLoading = true;
  bool _dataChanged = false;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    final list = await BackupService.instance.listBackups();
    if (!mounted) return;
    setState(() {
      _backups = list;
      _isLoading = false;
    });
  }

  Future<void> _createBackup() async {
    try {
      final info = await BackupService.instance.createBackup();
      if (!mounted) return;
      await _loadBackups();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Бэкап создан: ${info.recordCount} записей'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка создания бэкапа: $e')),
      );
    }
  }

  // ---------- Восстановление ----------

  Future<void> _restoreBackup(BackupInfo info) async {
    // Сколько записей сейчас в БД — покажем в предупреждении при замене.
    final currentCount =
        (await DatabaseHelper.instance.getAllTransactions()).length;

    final RestoreMode? mode = await showDialog<RestoreMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Восстановить из бэкапа?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Файл от ${info.formattedDate}, '
                '${info.recordCount} записей.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Дополнить',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'Записи из файла добавятся к текущим. Совпадающие '
                '(сумма, категория, подкатегория, описание, дата) '
                'будут пропущены.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text(
                'Заменить всё',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              Text(
                'Все текущие записи ($currentCount) будут удалены, '
                'останутся только записи из файла. Действие необратимо.',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, RestoreMode.merge),
            child: const Text('Дополнить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, RestoreMode.replace),
            child: const Text(
              'Заменить всё',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (mode == null) return;

    // Дополнительное подтверждение для деструктивного действия.
    if (mode == RestoreMode.replace) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Удалить все текущие записи?'),
          content: Text(
            'Все $currentCount записей будут удалены и заменены содержимым '
            'файла. Это действие нельзя отменить.\n\n'
            'Совет: сначала создай бэкап текущего состояния, если не уверен.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить и восстановить'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      final result = await BackupService.instance.importFromFile(
        info.file,
        replaceExisting: mode == RestoreMode.replace,
      );
      if (!mounted) return;
      if (result.added > 0) _dataChanged = true;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Импорт завершён'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Добавлено: ${result.added}'),
              Text('Пропущено (дубликаты): ${result.skipped}'),
              if (result.errors > 0)
                Text(
                  'Ошибок в строках: ${result.errors}',
                  style: const TextStyle(color: Colors.orange),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка импорта: $e')),
      );
    }
  }

  // ---------- Остальные действия ----------

  Future<void> _shareBackup(BackupInfo info) async {
    try {
      await Share.shareXFiles(
        [XFile(info.file.path, mimeType: 'text/csv')],
        subject: 'Spently backup ${info.formattedDate}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось поделиться: $e')),
      );
    }
  }

  Future<void> _deleteBackup(BackupInfo info) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить бэкап?'),
        content: Text(
          'Файл от ${info.formattedDate}. Действие необратимо.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await BackupService.instance.deleteBackup(info.file);
    await _loadBackups();
  }

  void _onMenuSelected(String action, BackupInfo info) {
    switch (action) {
      case 'restore':
        _restoreBackup(info);
        break;
      case 'share':
        _shareBackup(info);
        break;
      case 'delete':
        _deleteBackup(info);
        break;
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _dataChanged);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Данные и бэкапы'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _dataChanged),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Обновить список',
              onPressed: _loadBackups,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _backups.isEmpty
                ? _buildEmptyState()
                : _buildBackupList(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createBackup,
          icon: const Icon(Icons.save_alt),
          label: const Text('Создать бэкап'),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Пока нет ни одного бэкапа.\n'
              'Нажми «Создать бэкап», чтобы сделать первый.',
              style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupList() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: _backups.length,
      itemBuilder: (context, index) {
        final info = _backups[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.description_outlined),
            ),
            title: Text(
              info.formattedDate,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${info.recordCount} записей · ${info.formattedSize}\n'
              '${info.fileName}',
              style: const TextStyle(fontSize: 12),
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _onMenuSelected(value, info),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'restore',
                  child: Text('Восстановить'),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: Text('Поделиться'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Удалить',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}