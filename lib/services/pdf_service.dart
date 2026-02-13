import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../features/shared/models/user_profile.dart';

class PdfService {
  static Future<Uint8List> generatePrescription({
    required UserProfile doctor,
    required String patientName,
    required String patientId,
    required DateTime date,
    required String diagnosis,
    required List<Map<String, dynamic>> medications,
    List<String>? tests, // NEW PARAMETER
    String? notes,
  }) async {
    final pdf = pw.Document();

    // Define standard medical colors
    final baseColor = PdfColors.blue900;
    final accentColor = PdfColors.grey700;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // ──────────────── HEADER ────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Clinic Name
                    pw.Text(
                      doctor.hospitalName ?? 'CareSync Medical',
                      style: pw.TextStyle(
                        color: baseColor,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Official Digital Prescription',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
                // Doctor Details
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Dr. ${doctor.fullName}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    if (doctor.specialization != null)
                      pw.Text(doctor.specialization!,
                          style: const pw.TextStyle(fontSize: 12)),
                    if (doctor.medicalRegNumber != null)
                      pw.Text('Reg No: ${doctor.medicalRegNumber}',
                          style: pw.TextStyle(color: accentColor, fontSize: 10)),
                  ],
                )
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: baseColor, thickness: 2),
            pw.SizedBox(height: 20),

            // ──────────────── PATIENT INFO ────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoColumn('PATIENT NAME', patientName),
                  _buildInfoColumn('PATIENT ID', patientId.substring(0, 8).toUpperCase()),
                  _buildInfoColumn('DATE', DateFormat('dd MMM yyyy').format(date)),
                  _buildInfoColumn('DIAGNOSIS', diagnosis),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // ──────────────── RX SECTION ────────────────
            pw.Text('Rx',
                style: pw.TextStyle(
                  fontStyle: pw.FontStyle.italic,
                  fontSize: 34,
                  fontWeight: pw.FontWeight.bold,
                  color: baseColor,
                )
            ),
            pw.SizedBox(height: 10),

            // Medications Table
            pw.Table.fromTextArray(
              headers: ['Medicine', 'Dosage', 'Frequency', 'Duration', 'Instructions'],
              data: medications.map((med) {
                return [
                  med['medicine_name'],
                  med['dosage'],
                  med['frequency'],
                  med['duration'] ?? '-',
                  med['instructions'] ?? '-',
                ];
              }).toList(),
              border: null,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 10,
              ),
              headerDecoration: pw.BoxDecoration(color: baseColor),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
              ),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.centerLeft,
              },
            ),
            pw.SizedBox(height: 30),

            // ──────────────── TESTS SECTION (NEW) ────────────────
            if (tests != null && tests.isNotEmpty) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                  color: PdfColors.grey50,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('RECOMMENDED TESTS / INVESTIGATIONS:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: baseColor)),
                    pw.SizedBox(height: 6),
                    pw.Wrap(
                      spacing: 10,
                      runSpacing: 5,
                      children: tests.map((test) =>
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: baseColor, width: 0.5),
                              borderRadius: pw.BorderRadius.circular(10),
                            ),
                            child: pw.Text(test, style: const pw.TextStyle(fontSize: 9)),
                          )
                      ).toList(),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
            ],

            // ──────────────── NOTES ────────────────
            if (notes != null && notes.isNotEmpty) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Doctor\'s Notes / Advice:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: baseColor)),
                    pw.SizedBox(height: 4),
                    pw.Text(notes, style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),
            ],

            pw.Spacer(),

            // ──────────────── FOOTER ────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Powered by CareSync',
                        style: pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                    pw.Text('Digitally verified biometric prescription.',
                        style: pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Digital Signature Stamp
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: baseColor, width: 2),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text('DIGITALLY SIGNED',
                          style: pw.TextStyle(color: baseColor, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Dr. ${doctor.fullName}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildInfoColumn(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(color: PdfColors.grey600, fontSize: 8)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      ],
    );
  }
}