// lib/screens/categories_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../providers/category_provider.dart';

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
        onPressed: () => _showAddDialog(context),
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
      leading: const Icon(Icons.label_outline),
      title: Text(cat.displayName),
      subtitle: Text(
        cat.name,
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Переименовать',
            onPressed: () => _showEditDialog(context, provider, cat),
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

  Future<void> _showAddDialog(BuildContext context) async {
    final controller = TextEditingController();
    String selectedType = 'fixed';
    final provider = context.read<CategoryProvider>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Новая категория'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
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
                selected: {selectedType},
                onSelectionChanged: (s) =>
                    setLocalState(() => selectedType = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await provider.add(
        displayName: controller.text.trim(),
        type: selectedType,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Категория создана')),
        );
      }
    }
    controller.dispose();
  }

  Future<void> _showEditDialog(
    BuildContext context,
    CategoryProvider provider,
    ExpenseCategory cat,
  ) async {
    final controller = TextEditingController(text: cat.displayName);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Переименовать'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Название',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result == true) {
      await provider.update(cat.copyWith(displayName: controller.text.trim()));
    }
    controller.dispose();
  }

  // ---------- удаление (архивирование) ----------

  Future<void> _confirmDelete(
    BuildContext context,
    CategoryProvider provider,
    ExpenseCategory cat,
  ) async {
    if (cat.id == null) return;

    final count = await provider.countUsages(cat.name);
    if (!context.mounted) return;

    // Разный текст в зависимости от того, есть ли привязанные траты.
    final String message;
    if (count == 0) {
      message = '«${cat.displayName}» будет удалена из списка выбора.';
    } else {
      final String word = _pluralizeRecords(count);
      message = 'У категории «${cat.displayName}» уже есть $count $word.\n\n'
          'Категория пропадёт из списка выбора для новых трат, но '
          '$count $word сохранят её название — ничего не потеряется.';
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

  // '1 запись', '2 записи', '5 записей' — простое правило для русского.
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