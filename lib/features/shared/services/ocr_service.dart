import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

/// Intermediate model for parsed medication data within OCR service
class ParsedMedication {
  final String name;
  final String dosage;
  final String frequency;
  final String duration;
  final int quantity;
  final String instructions;

  ParsedMedication({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
    required this.quantity,
    required this.instructions,
  });

  @override
  String toString() => '$name | $dosage | $frequency | $duration | Qty: $quantity';
}

class PrescriptionData {
  final String? doctorName;
  final String? hospitalName;
  final DateTime? date;
  final String? diagnosis;
  final List<ParsedMedication> medications;
  final String rawText;

  PrescriptionData({
    this.doctorName,
    this.hospitalName,
    this.date,
    this.diagnosis,
    this.medications = const [],
    required this.rawText,
  });

  @override
  String toString() {
    return 'Dr: $doctorName\nHosp: $hospitalName\nDate: $date\nDx: $diagnosis\nMeds: ${medications.length} found';
  }
}

class OcrService {
  static final OcrService _instance = OcrService._internal();
  factory OcrService() => _instance;
  OcrService._internal();

  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<void> dispose() async {
    await _textRecognizer.close();
  }

  Future<PrescriptionData> processPrescriptionImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
    
    return PrescriptionTextParser().parse(recognizedText.text);
  }

  Future<PrescriptionData> processPrescriptionFile(File file) async {
    final extension = file.path.split('.').last.toLowerCase();
    
    if (extension == 'pdf') {
       return _processPdf(file);
    } else {
       return processPrescriptionImage(file);
    }
  }

  Future<PrescriptionData> _processPdf(File pdfFile) async {
    try {
      final doc = await PdfDocument.openFile(pdfFile.path);
      if (doc.pageCount == 0) throw Exception("Empty PDF");
      
      // Get the first page
      final page = await doc.getPage(1);
      final pageImage = await page.render(
         width: page.width.toInt() * 2, // Scale up for better OCR
         height: page.height.toInt() * 2,
      );
      
      final img = image.Image.fromBytes(
        width: pageImage.width,
        height: pageImage.height,
        bytes: pageImage.pixels.buffer,
        order: image.ChannelOrder.rgba,
      );
      
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_ocr_page_1.png');
      await tempFile.writeAsBytes(image.encodePng(img));
      
      pageImage.dispose();
      
      return processPrescriptionImage(tempFile);
    } catch (e) {
      debugPrint("Error processing PDF for OCR: $e");
      rethrow;
    }
  }
}

class PrescriptionTextParser {
  PrescriptionData parse(String text) {
    debugPrint('--- RAW OCR TEXT START ---\n$text\n--- RAW OCR TEXT END ---');

    String? doctorName;
    String? hospitalName;
    DateTime? date;
    String? diagnosis;
    List<ParsedMedication> medications = [];
    
    // ... rest of method


    // Pre-processing
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // 1. Extract Date
    date = _extractDate(lines);

    // 2. Extract Doctor & Hospital
    // Heuristic: Doctor details often at top. Look for "Dr." and "Hospital" or "Clinic"
    for (int i = 0; i < lines.length && i < 10; i++) { // Check first 10 lines
        final line = lines[i];
        if (doctorName == null && RegExp(r'\b(Dr\.|Doctor|Dr)\s+([a-zA-Z\s]+)', caseSensitive: false).hasMatch(line)) {
            doctorName = line.replaceAll(RegExp(r'^(Dr\.|Doctor|Dr)\s*', caseSensitive: false), '').trim();
        }
        if (hospitalName == null && RegExp(r'\b(Hospital|Clinic|Medical|Health|Apollo|Care)\b', caseSensitive: false).hasMatch(line)) {
            // Avoid if line is too short or looks like a header
            if (line.length > 5) hospitalName = line;
        }
    }

    // 3. Extract Diagnosis
    // Look for keywords
    final diagnosisRegex = RegExp(r'^(Diagnosis|Dx|Impression|Assessment|Provisional Diagnosis)[:\s\-]*', caseSensitive: false);
    for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (diagnosisRegex.hasMatch(line)) {
            // If the line has content after the label, take it
            String content = line.replaceFirst(diagnosisRegex, '').trim();
            
            // Check if content is empty OR just a secondary header like "/ Provisional Diagnosis"
            bool isSecondaryHeader = content.isEmpty || RegExp(r'^[/|]\s*Provisional Diagnosis', caseSensitive: false).hasMatch(content);
            
            if (isSecondaryHeader && i + 1 < lines.length) {
                // Take next line, cleaner
                diagnosis = lines[i+1].replaceAll(RegExp(r'^[\u2022\-\*]\s*'), '');
            } else if (content.isNotEmpty) {
                diagnosis = content;
            }
            break; 
        }
    }

    // 4. Extract Medications (Advanced)
    medications = _extractMedications(lines);

    return PrescriptionData(
      doctorName: doctorName,
      hospitalName: hospitalName,
      date: date,
      diagnosis: diagnosis,
      medications: medications,
      rawText: text,
    );
  }

  DateTime? _extractDate(List<String> lines) {
    final datePattern = RegExp(
      r'(Date|Dated|Dt)?[:\s-]*(\d{1,2}[-/. ]\s*[a-zA-Z]+[-/. ]\s*\d{2,4}|\d{1,2}[-/. ]\s*\d{1,2}[-/. ]\s*\d{2,4}|\d{4}[-/. ]\s*\d{1,2}[-/. ]\s*\d{1,2})',
      caseSensitive: false,
    );
    
    for (var line in lines) {
      final match = datePattern.firstMatch(line);
      if (match != null) {
         try {
           String dateStr = match.group(2) ?? '';
           // Normalize dividers
           dateStr = dateStr.replaceAll(RegExp(r'[-.]'), '/');
           // Attempt basic parsing tactics
           // 1. dd/MMM/yyyy (10 May 2024)
           // 2. dd/mm/yyyy
           return _parseFlexibleDate(dateStr);
         } catch (e) {
           continue; 
         }
      }
    }
    return null;
  }
  
  DateTime? _parseFlexibleDate(String input) {
     // Very naive parser. In production, use DateFormat with multiple patterns.
     // Try standard packages or custom logic.
     // Handling "10 May 2024"
     final parts = input.split(RegExp(r'[\s/]+'));
     if (parts.length >= 3) {
        int? d = int.tryParse(parts[0]);
        int? y = int.tryParse(parts[2]);
        if (y != null && y < 100) y += 2000;
        
        int m = 1;
        // Month string parsing
        const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
        final mStr = parts[1].toLowerCase();
        int mIdx = months.indexWhere((mon) => mStr.startsWith(mon));
        if (mIdx != -1) {
            m = mIdx + 1;
        } else {
            m = int.tryParse(parts[1]) ?? 1;
        }
        
        if (d != null && y != null) {
           return DateTime(y, m, d);
        }
     }
     return null;
  }

  List<ParsedMedication> _extractMedications(List<String> lines) {
    List<ParsedMedication> meds = [];
    
    // Pattern to identify frequency: 1-0-0, 1-0-1-0, 1/2-0-1/2 etc.
    // Enhanced to allow spaces: 1 - 0 - 0, and dots: 1.0.0
    final freqPattern = RegExp(r'(\d+(?:[./]\d+)?\s*[-xX*.]\s*\d+(?:[./]\d+)?\s*[-xX*.]\s*\d+(?:[./]\d+)?(?:\s*[-xX*.]\s*\d+(?:[./]\d+)?)?)');
    
    // Pattern to identify duration: 5 Days, 1 Week, 10-15 Days
    final durationPattern = RegExp(r'(\d+[-]?\d*)\s*(Days?|Weeks?|Months?|Yrs?|Years?)', caseSensitive: false);

    bool inMedSection = false;
    
    for (var line in lines) {
        // Detect start of meds
        if (RegExp(r'^(Rx|Treatment|Medication|Medicine)', caseSensitive: false).hasMatch(line)) {
            inMedSection = true;
            continue;
        }
        
        // Find frequency as Anchor
        final freqMatch = freqPattern.firstMatch(line);
        if (freqMatch != null) {
            String frequency = freqMatch.group(0)!;
            
            // Split line around frequency
            int freqIndex = line.indexOf(frequency);
            String part1 = line.substring(0, freqIndex).trim(); // Before freq (Name + Dosage)
            String part2 = line.substring(freqIndex + frequency.length).trim(); // After freq (Duration + Instructions)
            
            // Clean up Name (remove "1. " bullets)
            String name = part1.replaceAll(RegExp(r'^\d+[\.)]\s*'), '').trim();
            String dosage = '';
            
            // Attempt to extract dosage from name (e.g. 500mg)
            final doseMatch = RegExp(r'(\d+\s*(mg|ml|gm|mcg|unit|u))', caseSensitive: false).firstMatch(name);
            if (doseMatch != null) {
                dosage = doseMatch.group(0)!;
            }
            
            // Duration
            String duration = '';
            int durationDays = 0;
            final durMatch = durationPattern.firstMatch(part2); // Look in part 2 first
            if (durMatch != null) {
               duration = durMatch.group(0)!;
               
               // Calculate duration in days for quantity
               int val = int.tryParse(durMatch.group(1)!) ?? 0;
               String unit = durMatch.group(2)!.toLowerCase();
               if (unit.startsWith('week')) val *= 7;
               if (unit.startsWith('month')) val *= 30;
               durationDays = val;
            }
            
            // Instructions
            String instructions = part2.replaceAll(duration, '').replaceAll(RegExp(r'[\|\(\)]'), '').trim();
            
            // Quantity Calculation
            int qty = 0;
            if (durationDays > 0) {
               // Sum the frequency digits (1-0-1 => 2)
               // Clean frequency string for parsing (replace hyphens/spaces with just spaces)
               String cleanFreq = frequency.replaceAll(RegExp(r'[-xX*\s]+'), ' ');
               List<String> parts = cleanFreq.trim().split(' ');
               
               double dailyDose = 0;
               for (var p in parts) {
                  // Handle fractions like 1/2
                  if (p.contains('/')) {
                      final frac = p.split('/');
                      if (frac.length == 2) {
                          dailyDose += (double.tryParse(frac[0]) ?? 0) / (double.tryParse(frac[1]) ?? 1);
                      }
                  } else {
                      dailyDose += double.tryParse(p) ?? 0;
                  }
               }
               qty = (dailyDose * durationDays).ceil();
            }
            
            meds.add(ParsedMedication(
              name: name,
              dosage: dosage,
              frequency: frequency,
              duration: duration,
              quantity: qty,
              instructions: instructions, // e.g. "After food"
            ));
        }
    }
    
    return meds;
  }
}

