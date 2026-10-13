// lib/services/ocr_service.dart

import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';

/// Результат распознавания: текст + служебная информация.
class OcrResult {
  final String text;

  const OcrResult({required this.text});

  /// Ленивый геттер: вычисляется при обращении, а не в конструкторе.
  bool get isEmpty => text.trim().isEmpty;
}

/// Синглтон-обёртка над TesseractOcr.
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  /// Распознаёт текст на изображении по пути [imagePath].
  Future<OcrResult> recognize(
    String imagePath, {
    String language = 'rus+eng',
  }) async {
    final text = await TesseractOcr.extractText(
      imagePath,
      config: OCRConfig(
        language: language,
        engine: OCREngine.tesseract,
        options: {
          // PSM 6 — "Assume a single uniform block of text".
          // Для чека это надёжнее, чем PSM 4: чек — это единый блок
          // текста, а не колонка с переменным кеглем.
          TesseractConfig.pageSegMode: PageSegmentationMode.singleBlock,
          // Сохраняем пробелы между словами — иначе "ИТОГО 1234.56"
          // превратится в "ИТОГО1234.56".
          TesseractConfig.preserveInterwordSpaces: '1',
        },
      ),
    );
    return OcrResult(text: text);
  }
}