import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Data class holding parsed fields from a Ghana Card.
class GhanaCardData {
  final String? fullName;
  final String? idNumber;
  final String? dateOfBirth; // YYYY-MM-DD
  final String? digitalAddress;
  final double confidence; // 0.0–1.0

  GhanaCardData({
    this.fullName,
    this.idNumber,
    this.dateOfBirth,
    this.digitalAddress,
    this.confidence = 0.0,
  });

  bool get isEmpty =>
      fullName == null &&
      idNumber == null &&
      dateOfBirth == null &&
      digitalAddress == null;
}

class GhanaCardOcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Process an image file and extract Ghana Card fields.
  Future<GhanaCardData> processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    final allText = recognizedText.text;
    final lines = recognizedText.blocks
        .expand((block) => block.lines)
        .map((line) => line.text.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return _parseGhanaCard(allText, lines);
  }

  GhanaCardData _parseGhanaCard(String fullText, List<String> lines) {
    String? fullName;
    String? idNumber;
    String? dateOfBirth;
    String? digitalAddress;

    // --- 1. ID Number: GHA-XXXXXXXXX-X ---
    final idRegex = RegExp(r'GHA[-\s]?\d{9}[-\s]?\d', caseSensitive: false);
    final idMatch = idRegex.firstMatch(fullText);
    if (idMatch != null) {
      String raw = idMatch.group(0)!.toUpperCase().replaceAll(' ', '-');
      // Normalize to GHA-XXXXXXXXX-X
      final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length == 10) {
        idNumber = 'GHA-${digits.substring(0, 9)}-${digits.substring(9)}';
      } else {
        idNumber = raw;
      }
    }

    // --- 2. Digital Address: XX-XXX-XXXX (Ghana Post GPS) ---
    final addrRegex = RegExp(r'[A-Z]{2}[-\s]\d{3}[-\s]\d{4}');
    final addrMatch = addrRegex.firstMatch(fullText.toUpperCase());
    if (addrMatch != null) {
      digitalAddress = addrMatch.group(0)!.replaceAll(' ', '-');
    }

    // --- 3. Date of Birth (DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY) ---
    final dobRegex = RegExp(r'\b(\d{2})[/\-.](\d{2})[/\-.](\d{4})\b');
    for (final match in dobRegex.allMatches(fullText)) {
      final day = int.tryParse(match.group(1)!);
      final month = int.tryParse(match.group(2)!);
      final year = int.tryParse(match.group(3)!);
      if (day != null &&
          month != null &&
          year != null &&
          day >= 1 &&
          day <= 31 &&
          month >= 1 &&
          month <= 12 &&
          year >= 1920 &&
          year <= 2015) {
        // Convert to YYYY-MM-DD for Django DateField
        dateOfBirth =
            '${match.group(3)}-${match.group(2)!.padLeft(2, '0')}-${match.group(1)!.padLeft(2, '0')}';
        break;
      }
    }

    // --- 4. Full Name (by elimination) ---
    final labelPatterns = RegExp(
      r'(GHANA\s*CARD|REPUBLIC|NATIONAL|IDENTIFICATION|DATE\s*OF\s*BIRTH|'
      r'PLACE\s*OF\s*ISSUE|EXPIRY|AUTHORITY|DIGITAL\s*ADDRESS|'
      r'PERSONAL\s*ID|NATIONALITY|HEIGHT|SEX|GHA[-\s]?\d|'
      r'DOCUMENT\s*NO|SURNAME|FIRST\s*NAME|OTHER\s*NAME|'
      r'\d{2}[/\-]\d{2}[/\-]\d{4}|[A-Z]{2}[-]\d{3}[-]\d{4})',
      caseSensitive: false,
    );
    final nameCharRegex = RegExp(r'^[A-Za-z\s\-\.]{3,}$');
    final skipWords = RegExp(
      r'^(MALE|FEMALE|GHANAIAN|MR|MRS|DR|MISS|GENDER|DATE|PLACE)$',
      caseSensitive: false,
    );

    final nameCandidates = <String>[];
    for (final line in lines) {
      final cleaned = line.trim();
      if (cleaned.length < 3) continue;
      if (labelPatterns.hasMatch(cleaned)) continue;
      if (!nameCharRegex.hasMatch(cleaned)) continue;
      if (skipWords.hasMatch(cleaned)) continue;
      nameCandidates.add(cleaned);
    }

    if (nameCandidates.isNotEmpty) {
      final multiWord =
          nameCandidates.where((c) => c.split(RegExp(r'\s+')).length >= 2).toList();
      if (multiWord.isNotEmpty) {
        fullName = _titleCase(multiWord.first);
      } else if (nameCandidates.length >= 2) {
        fullName = _titleCase('${nameCandidates[0]} ${nameCandidates[1]}');
      } else {
        fullName = _titleCase(nameCandidates.first);
      }
    }

    // --- Confidence ---
    int found = 0;
    const total = 4;
    if (fullName != null) found++;
    if (idNumber != null) found++;
    if (dateOfBirth != null) found++;
    if (digitalAddress != null) found++;

    return GhanaCardData(
      fullName: fullName,
      idNumber: idNumber,
      dateOfBirth: dateOfBirth,
      digitalAddress: digitalAddress,
      confidence: found / total,
    );
  }

  String _titleCase(String input) {
    return input
        .split(RegExp(r'\s+'))
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ')
        .trim();
  }

  void dispose() {
    _textRecognizer.close();
  }
}
