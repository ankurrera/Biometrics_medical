import 'package:flutter_test/flutter_test.dart';
import 'package:caresync/features/shared/services/ocr_service.dart';

void main() {
  test('OCR Extraction Logic', () {
    final text = '''
Apollo 24|7
Dr. Pawan Yelgulwar
MBBS
General Practitioner
Reg.No. 2004010051

Apollo 24|7 Virtual Clinic, Apollo Hospitals, Sandhya Elite
Nursing, Hyderabad, Telangana, 500032

Patient
Sheetal Fagna, Female, 23 Yrs
Date: Friday, 10 May 2024
Time: 5:21 PM
Consult Type: Online
Appointment ID: 12504403

Diagnosis/ Provisional Diagnosis
• Retrocalcaneal bursitis/Plantar Fasciitis?

Medication Prescribed

1. PAN 40 TABLET 15'S 1-0-0-0 TABLET | Once a day 15 days
Contains: PANTOPRAZOLE (40 MG) M-N-E-N Orally. Before food
Take medication 30 minutes before break fast

2. SUPRADYN DAILY MULTIVITAMIN TABLET 15'S 1-0-0-0 TABLET | Once a day 15 days
M-N-E-N Orally. After food

3. HIFENAC SR TABLET 10'S 1-0-0-0 TABLET | Once a day 15 days
Contains: ACECLOFENAC (200 MG) M-N-E-N Orally. After food

4. VOLINI PAIN RELIEF GEL, 75 GM -----1----- DROP | Twice a day 7 days
Contains: DICLOFENAC SODIUM (1.16 %W/W) + LINSEED OIL (3 Local application

M-N-E-N: Morning - Noon - Evening - Night Note: Medicine Substitution Allowed Wherever Applicable.
''';

    final parser = PrescriptionTextParser();
    final data = parser.parse(text);

    print('--- OCR RESULT ---');
    print('Doctor: ${data.doctorName}');
    print('Hospital: ${data.hospitalName}');
    print('Date: ${data.date}');
    print('Diagnosis: ${data.diagnosis}');
    print('Medications Found: ${data.medications.length}');
    
    for (var med in data.medications) {
      print('  - Name: ${med.name}');
      print('    Dosage: ${med.dosage}');
      print('    Freq: ${med.frequency}');
      print('    Duration: ${med.duration}');
      print('    Quantity: ${med.quantity}');
      print('    Instructions: ${med.instructions}');
      print('');
    }
  });
  test('OCR Extraction Logic - Noisy Data', () {
    // Simulating OCR noise and edge cases
    final text = '''
    1. PAN 40 TABLET 15'S 1 - 0 - 0 - 0 TABLET | Once a day 15 days
    2. SUPRADYN DAILY   1- 0- 0- 0   Tab.
    3. HIFENAC SR 1.0.0.0 (Dot separator)
    4. HALF DOSE 0.5 - 0 - 0.5 (Decimals with dash)
    ''';

    final parser = PrescriptionTextParser();
    final data = parser.parse(text);

    print('--- NOISY OCR RESULT ---');
    for (var med in data.medications) {
       print('Captured: ${med.name} | ${med.frequency} | Qty: ${med.quantity}');
    }
  });
}
