// lib/screens/scan_receipt_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ocr_service.dart';
import '../services/receipt_parser.dart';
import 'add_expense_screen.dart';

/// Шаги экрана: выбор источника → обработка → результат.
enum ScanStep { pickSource, processing, result }

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  final ImagePicker _picker = ImagePicker();

  ScanStep _step = ScanStep.pickSource;
  File? _image;
  ParsedReceipt? _parsed;
  String? _errorMessage;

  // Контроллеры для полей результата — создаём в State,
  // чтобы dispose() корректно их освободил.
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // ---------- Выбор изображения ----------

  Future<void> _pickFromCamera() async {
    await _pick(ImageSource.camera);
  }

  Future<void> _pickFromGallery() async {
    await _pick(ImageSource.gallery);
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        // Уменьшаем разрешение: Tesseract не нужны 12 МП,
        // а время обработки растёт квадратично.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (picked == null) return;

      if (!mounted) return;
      setState(() {
        _image = File(picked.path);
        _step = ScanStep.processing;
        _errorMessage = null;
      });

      await _runOcr();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Не удалось получить изображение: $e';
        _step = ScanStep.pickSource;
      });
    }
  }

  // ---------- OCR + парсинг ----------

  Future<void> _runOcr() async {
    if (_image == null) return;

    try {
      final ocrResult = await OcrService.instance.recognize(_image!.path);
      if (!mounted) return;

      if (ocrResult.isEmpty) {
        setState(() {
          _errorMessage =
              'Не удалось распознать текст на изображении.\n'
              'Попробуйте сфотографировать чек ровно и при хорошем свете.';
          _step = ScanStep.pickSource;
        });
        return;
      }

      final parsed = ReceiptParser.parse(ocrResult.text);
      if (!mounted) return;

      setState(() {
        _parsed = parsed;
        _amountController.text =
            parsed.amount?.toStringAsFixed(2) ?? '';
        _dateController.text = parsed.date != null
            ? _formatDate(parsed.date!)
            : '';
        _step = ScanStep.result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Ошибка распознавания: $e';
        _step = ScanStep.pickSource;
      });
    }
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  DateTime? _parseDateFromField(String input) {
    final m = RegExp(r'(\d{2})\.(\d{2})\.(\d{4})').firstMatch(input);
    if (m == null) return null;
    final d = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final y = int.tryParse(m.group(3)!);
    if (d == null || mo == null || y == null) return null;
    return DateTime(y, mo, d);
  }

  // ---------- Переход в AddExpenseScreen ----------

  Future<void> _proceedToAddExpense() async {
    final amount = double.tryParse(_amountController.text.trim());
    final date = _parseDateFromField(_dateController.text.trim());

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          initialAmount: amount,
          initialDate: date,
          initialSubcategory: _parsed?.suggestedSubcategory,
        ),
      ),
    );

    if (!mounted) return;
    // Если пользователь сохранил трату — возвращаем true на HomeScreen.
    if (result == true) {
      Navigator.pop(context, true);
    }
  }

  void _enterManually() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
    );
  }

  void _retry() {
    setState(() {
      _image = null;
      _parsed = null;
      _errorMessage = null;
      _amountController.clear();
      _dateController.clear();
      _step = ScanStep.pickSource;
    });
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканировать чек'),
      ),
      body: switch (_step) {
        ScanStep.pickSource => _buildPickSource(),
        ScanStep.processing => _buildProcessing(),
        ScanStep.result => _buildResult(),
      },
    );
  }

  Widget _buildPickSource() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_errorMessage != null) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onErrorContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildSourceTile(
            icon: Icons.camera_alt,
            title: 'Сфотографировать',
            subtitle: 'Открыть камеру и снять чек',
            onTap: _pickFromCamera,
          ),
          const SizedBox(height: 12),
          _buildSourceTile(
            icon: Icons.photo_library,
            title: 'Выбрать из галереи',
            subtitle: 'Импортировать готовое фото',
            onTap: _pickFromGallery,
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _enterManually,
            icon: const Icon(Icons.edit),
            label: const Text('Ввести вручную'),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 28,
          child: Icon(icon, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _image!,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            'Распознаём текст…',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Это может занять несколько секунд',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final parsed = _parsed!;
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Превью фото
          if (_image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _image!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 16),

          // Предупреждение, если ничего не распознано
          if (!parsed.hasAnyData)
            Card(
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Не удалось извлечь сумму или дату. '
                        'Проверьте поля вручную.',
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Поля результата
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Сумма (₽)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.attach_money),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _dateController,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'Дата (ДД.ММ.ГГГГ)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
            ),
          ),

          // Предполагаемая подкатегория
          if (parsed.suggestedSubcategory != null) ...[
            const SizedBox(height: 16),
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: cs.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Предполагаемая подкатегория определена '
                        'по названию магазина',
                        style: TextStyle(color: cs.onPrimaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _proceedToAddExpense,
            icon: const Icon(Icons.check),
            label: const Text('Проверить и сохранить'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Попробовать другое фото'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 16),

          // Сырой текст (для отладки — можно свернуть)
          ExpansionTile(
            title: const Text(
              'Распознанный текст',
              style: TextStyle(fontSize: 14),
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  parsed.rawText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}