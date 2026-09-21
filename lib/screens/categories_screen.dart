// lib/screens/categories_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/category_icons.dart';
import '../providers/category_provider.dart';

/// Результат, который возвращают диалоги создания/редактирования.
class CategoryDialogResult {
  final String displayName;
  final String type;
  final String iconCode;

  const CategoryDialogResult({
    required this.displayName,
    required this.type,
    required this.iconCode,
  });
}

// =====================================================================
//  ОСНОВНОЙ ЭКРАН
// =====================================================================

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Категории')),
      body: Consumer<CategoryProvider>(
        builder: (context, provider, _) {
          if (!provider.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _buildSection(context, provider, 'fixed', 'Обязательные'),
              _buildSection(context, provider, 'personal', 'Личные'),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Категория'),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    CategoryProvider provider,
    String type,
    String title,
  ) {
    final items = provider.byType(type);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Нет категорий',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          )
        else
          ...items.map((c) => _buildTile(context, provider, c)),
      ],
    );
  }

  Widget _buildTile(
    BuildContext context,
    CategoryProvider provider,
    ExpenseCategory cat,
  ) {
    return ListTile(
      leading: CircleAvatar(
        child: Icon(iconForCode(cat.iconCode), size: 20),
      ),
      title: Text(cat.displayName),
      subtitle: Text(cat.name, style: const TextStyle(fontSize: 11)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Переименовать',
            onPressed: () => _openEditDialog(context, provider, cat),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Удалить',
            onPressed: () => _confirmDelete(context, provider, cat),
          ),
        ],
      ),
    );
  }

  // ---------- ДИАЛОГ СОЗДАНИЯ ----------

  Future<void> _openAddDialog(BuildContext context) async {
    final provider = context.read<CategoryProvider>();

    final result = await showDialog<CategoryDialogResult>(
      context: context,
      builder: (_) => const _AddCategoryDialog(),
    );
    if (result == null) return;

    await provider.add(
      displayName: result.displayName,
      type: result.type,
      iconCode: result.iconCode,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Категория создана')),
    );
  }

  // ---------- ДИАЛОГ РЕДАКТИРОВАНИЯ ----------

  Future<void> _openEditDialog(
    BuildContext context,
    CategoryProvider provider,
    ExpenseCategory cat,
  ) async {
    final result = await showDialog<CategoryDialogResult>(
      context: context,
      builder: (_) => _EditCategoryDialog(category: cat),
    );
    if (result == null) return;

    await provider.update(
      cat.copyWith(
        displayName: result.displayName,
        iconCode: result.iconCode,
      ),
    );
  }

  // ---------- УДАЛЕНИЕ (АРХИВАЦИЯ) ----------

  Future<void> _confirmDelete(
    BuildContext context,
    CategoryProvider provider,
    ExpenseCategory cat,
  ) async {
    if (cat.id == null) return;

    final count = await provider.countUsages(cat.name);
    if (!context.mounted) return;

    final String message;
    if (count == 0) {
      message = '«${cat.displayName}» будет удалена из списка выбора.';
    } else {
      final String word = _pluralizeRecords(count);
      message = 'У категории «${cat.displayName}» уже есть $count $word.\n\n'
          'Категория пропадёт из списка выбора для новых трат, но '
          '$count $word сохранят её название и иконку — ничего не потеряется.';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.delete(cat.id!);
    }
  }

  String _pluralizeRecords(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'запись';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'записи';
    }
    return 'записей';
  }
}

// =====================================================================
//  ДИАЛОГ СОЗДАНИЯ
// =====================================================================

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog();

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _controller = TextEditingController();
  String _type = 'fixed';
  String _icon = 'label';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _IconPickerDialog(current: _icon),
    );
    if (picked != null && mounted) {
      setState(() => _icon = picked);
    }
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      CategoryDialogResult(
        displayName: name,
        type: _type,
        iconCode: _icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новая категория'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'fixed', label: Text('Обязательная')),
                ButtonSegment(value: 'personal', label: Text('Личная')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Иконка:'),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: Icon(iconForCode(_icon)),
                  label: const Text('Выбрать'),
                  onPressed: _pickIcon,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Создать'),
        ),
      ],
    );
  }
}

// =====================================================================
//  ДИАЛОГ РЕДАКТИРОВАНИЯ
// =====================================================================

class _EditCategoryDialog extends StatefulWidget {
  final ExpenseCategory category;
  const _EditCategoryDialog({required this.category});

  @override
  State<_EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<_EditCategoryDialog> {
  late final TextEditingController _controller;
  late String _icon;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.category.displayName);
    _icon = widget.category.iconCode;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _IconPickerDialog(current: _icon),
    );
    if (picked != null && mounted) {
      setState(() => _icon = picked);
    }
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      CategoryDialogResult(
        displayName: name,
        type: widget.category.type,
        iconCode: _icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Переименовать'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Иконка:'),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: Icon(iconForCode(_icon)),
                  label: const Text('Выбрать'),
                  onPressed: _pickIcon,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

// =====================================================================
//  ПИКЕР ИКОНКИ
// =====================================================================

class _IconPickerDialog extends StatelessWidget {
  final String current;
  const _IconPickerDialog({required this.current});

  @override
  Widget build(BuildContext context) {
    final entries = kCategoryIcons.entries.toList();
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Иконка'),
      content: SizedBox(
        width: 320,
        height: 360,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final entry = entries[i];
            final bool selected = entry.key == current;
            return InkWell(
              onTap: () => Navigator.pop(context, entry.key),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: selected ? cs.primaryContainer : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  entry.value,
                  color: selected ? cs.onPrimaryContainer : cs.onSurface,
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ],
    );
  }
}