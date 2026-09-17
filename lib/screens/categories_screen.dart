// lib/screens/categories_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../providers/category_provider.dart';

/// CRUD-экран для управления подкатегориями трат.
/// Читает / пишет через CategoryProvider (кэш в памяти + БД).
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

  // ---------- секция ----------

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
      // Служебный slug серым мелким шрифтом — чтобы было видно,
      // какой именно ключ уйдёт в transactions.subcategory.
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

  // ---------- создание ----------

  Future<void> _showAddDialog(BuildContext context) async {
    final controller = TextEditingController();
    String selectedType = 'fixed';
    final provider = context.read<CategoryProvider>();

    // StatefulBuilder — чтобы переключатель типа внутри AlertDialog
    // мог вызывать setState только для себя, не перестраивая весь экран.
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

  // ---------- переименование ----------

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
      // copyWith — изменяем только displayName, name (slug) остаётся,
      // поэтому старые траты не «отвяжутся».
      await provider.update(cat.copyWith(displayName: controller.text.trim()));
    }
    controller.dispose();
  }

  // ---------- удаление ----------

  Future<void> _confirmDelete(
    BuildContext context,
    CategoryProvider provider,
    ExpenseCategory cat,
  ) async {
    if (cat.id == null) return;

    final count = await provider.countUsages(cat.name);
    if (!context.mounted) return;

    // Защита от удаления используемой категории.
    if (count > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Нельзя удалить'),
          content: Text(
            'К категории «${cat.displayName}» привязано $count трат. '
            'Сначала удали или измени эти траты.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить категорию?'),
        content: Text('«${cat.displayName}» будет удалена.'),
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
}