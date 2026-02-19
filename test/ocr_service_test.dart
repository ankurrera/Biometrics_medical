import 'package:flutter_test/flutter_test.dart';
import 'package:caresync/features/shared/services/ocr_service.dart';

// Since OcrService depends on valid flutter plugins that might not be mockable easily without Mockito
// We can just instantiate it since the parsing logic is pure Dart and doesn't call platform channels unless processPrescriptionImage is called.
// We are testing parseRecognizedText directly.

void main() {
  group('OcrService Parsing Logic', () {
    final parser = PrescriptionTextParser();

    test('Parses Doctor Name correctly', () {
      final text = '''
      Dr. John Smith
      Cardiologist
      ''';
      final data = parser.parse(text);
      expect(data.doctorName, 'Dr. John Smith');
    });

    test('Parses Date correctly (dd/MM/yyyy)', () {
      final text = '''
      Date: 25/12/2023
      Prescription
      ''';
      final data = parser.parse(text);
      expect(data.date, DateTime(2023, 12, 25));
    });

    test('Parses Date correctly (yyyy-MM-dd)', () {
      final text = '''
      2024-01-15
      ''';
      final data = parser.parse(text);
      expect(data.date, DateTime(2024, 1, 15));
    });

    test('Parses Diagnosis correctly', () {
      final text = '''
      Diagnosis: Acute Bronchitis
      ''';
      final data = parser.parse(text);
      expect(data.diagnosis, 'Acute Bronchitis');
    });

    test('Parses Medications (Simple Lines)', () {
      final text = '''
      Rx
      Paracetamol 500mg
      Amoxicillin 250mg 
      ''';
      final data = parser.parse(text);
      expect(data.medications.length, 2);
      expect(data.medications, contains('Paracetamol 500mg'));
      expect(data.medications, contains('Amoxicillin 250mg'));
    });

    test('Parses Medications (No Rx Header, heuristic)', () {
      final text = '''
      Dr. Strange
      10/10/2024
      Ibuprofen 400mg
      ''';
      final data = parser.parse(text);
      expect(data.medications.length, 1);
      expect(data.medications.first, 'Ibuprofen 400mg');
    });

     test('Parses Complex Prescription', () {
      final text = '''
      Mercy Hospital
      Dr. Gregory House, MD
      Date: 12-05-2024
      
      Dx: Lupus
      
      Rx:
      Prednisone 20mg daily
      Vicodin 500mg as needed
      ''';
      
      final data = parser.parse(text);
      
      expect(data.doctorName, 'Dr. Gregory House'); // The regex might stop at comma or capture MD if greedy. Let's check regex: ([a-z.\s]+) is greedy.
      // Actually my regex `([a-z.\s]+)` might capture "Gregory House, MD" if comma was in set. It's not.
      // So it will capture "Gregory House".
      
      expect(data.date, DateTime(2024, 5, 12));
      expect(data.diagnosis, 'Lupus');
      expect(data.medications.length, 2);
    });
  });
}
