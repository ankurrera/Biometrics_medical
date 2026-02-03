/// Enhanced models for comprehensive prescription input
/// These models support the full patient-input prescription workflow

import 'package:uuid/uuid.dart';

/// Prescription type enum
enum PrescriptionType {
  newPrescription,
  followUp,
  refill;

  String get displayName {
    switch (this) {
      case PrescriptionType.newPrescription:
        return 'New';
      case PrescriptionType.followUp:
        return 'Follow-up';
      case PrescriptionType.refill:
        return 'Refill';
    }
  }
}

/// Prescription metadata including date and validity
class PrescriptionMetadata {
  final DateTime prescriptionDate;
  final DateTime validUntil;
  final PrescriptionType type;
  final String? previousPrescriptionId; // For refills

  const PrescriptionMetadata({
    required this.prescriptionDate,
    required this.validUntil,
    required this.type,
    this.previousPrescriptionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'prescription_date': prescriptionDate.toIso8601String(),
      'valid_until': validUntil.toIso8601String(),
      'prescription_type': type.name,
      'previous_prescription_id': previousPrescriptionId,
    };
  }
}

/// Comprehensive doctor details for prescription
class DoctorDetails {
  final String doctorName;
  final String? specialization;
  final String hospitalClinicName;
  final String medicalRegistrationNumber;
  final bool signatureUploaded;

  const DoctorDetails({
    required this.doctorName,
    this.specialization,
    required this.hospitalClinicName,
    required this.medicalRegistrationNumber,
    this.signatureUploaded = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'doctor_name': doctorName,
      'specialization': specialization,
      'hospital_clinic_name': hospitalClinicName,
      'medical_registration_number': medicalRegistrationNumber,
      'signature_uploaded': signatureUploaded,
    };
  }

  bool get isValid {
    return doctorName.isNotEmpty &&
        hospitalClinicName.isNotEmpty &&
        medicalRegistrationNumber.isNotEmpty;
  }
}

/// Medicine type enum
enum MedicineType {
  tablet,
  syrup,
  injection,
  ointment,
  capsule,
  drops;

  String get displayName {
    switch (this) {
      case MedicineType.tablet:
        return 'Tablet';
      case MedicineType.syrup:
        return 'Syrup';
      case MedicineType.injection:
        return 'Injection';
      case MedicineType.ointment:
        return 'Ointment';
      case MedicineType.capsule:
        return 'Capsule';
      case MedicineType.drops:
        return 'Drops';
    }
  }
}

/// Route of administration enum
enum RouteOfAdministration {
  oral,
  intravenous,
  intramuscular,
  topical,
  sublingual;

  String get displayName {
    switch (this) {
      case RouteOfAdministration.oral:
        return 'Oral';
      case RouteOfAdministration.intravenous:
        return 'IV';
      case RouteOfAdministration.intramuscular:
        return 'IM';
      case RouteOfAdministration.topical:
        return 'Topical';
      case RouteOfAdministration.sublingual:
        return 'Sublingual';
    }
  }
}

/// Food timing enum
enum FoodTiming {
  beforeFood,
  afterFood,
  withFood,
  empty;

  String get displayName {
    switch (this) {
      case FoodTiming.beforeFood:
        return 'Before Food';
      case FoodTiming.afterFood:
        return 'After Food';
      case FoodTiming.withFood:
        return 'With Food';
      case FoodTiming.empty:
        return 'Empty Stomach';
    }
  }
}

/// Enhanced medication details with all required fields
class MedicationDetails {
  final String id;
  final String medicineName;
  final String dosage; // e.g., "500mg", "5ml"
  final String frequency; // e.g., "1-0-1", "Twice daily"
  final String duration; // e.g., "7 days", "2 weeks"
  final int quantity;
  final MedicineType? medicineType;
  final RouteOfAdministration? route;
  final FoodTiming? foodTiming;
  final String? instructions;

  MedicationDetails({
    String? id,
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    required this.duration,
    required this.quantity,
    this.medicineType,
    this.route,
    this.foodTiming,
    this.instructions,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      'medicine_name': medicineName,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'quantity': quantity,
      'medicine_type': medicineType?.name,
      'route': route?.name,
      'food_timing': foodTiming?.name,
      'instructions': instructions,
    };
  }

  bool get isValid {
    return medicineName.isNotEmpty &&
        dosage.isNotEmpty &&
        frequency.isNotEmpty &&
        duration.isNotEmpty &&
        quantity > 0;
  }
}

/// Safety flags for medical compliance
class SafetyFlags {
  final bool? allergiesMentioned;
  final bool? pregnancyBreastfeeding;
  final bool? chronicConditionLinked;
  final String? notes;

  const SafetyFlags({
    this.allergiesMentioned,
    this.pregnancyBreastfeeding,
    this.chronicConditionLinked,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'allergies_mentioned': allergiesMentioned,
      'pregnancy_breastfeeding': pregnancyBreastfeeding,
      'chronic_condition_linked': chronicConditionLinked,
      'notes': notes,
    };
  }
}

/// Prescription upload details
class PrescriptionUpload {
  final String? filePath;
  final String? fileName;
  final String? fileType;
  final int? fileSizeBytes;

  const PrescriptionUpload({
    this.filePath,
    this.fileName,
    this.fileType,
    this.fileSizeBytes,
  });

  bool get hasFile => filePath != null && filePath!.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'file_name': fileName,
      'file_type': fileType,
      'file_size_bytes': fileSizeBytes,
    };
  }
}

/// Complete prescription input data
class CompletePrescriptionInput {
  final PrescriptionMetadata metadata;
  final DoctorDetails doctorDetails;
  final String diagnosis;
  final String? doctorNotes;
  final String? patientNotes;
  final List<MedicationDetails> medications;
  final SafetyFlags safetyFlags;
  final PrescriptionUpload upload;
  final bool declarationAccepted;

  const CompletePrescriptionInput({
    required this.metadata,
    required this.doctorDetails,
    required this.diagnosis,
    this.doctorNotes,
    this.patientNotes,
    required this.medications,
    required this.safetyFlags,
    required this.upload,
    required this.declarationAccepted,
  });

  /// Validates that all mandatory fields are filled
  bool get isValid {
    // Metadata validation
    if (metadata.validUntil.isBefore(metadata.prescriptionDate)) {
      return false;
    }

    // Doctor validation
    if (!doctorDetails.isValid) {
      return false;
    }

    // Diagnosis required
    if (diagnosis.trim().isEmpty) {
      return false;
    }

    // At least one medication required
    if (medications.isEmpty) {
      return false;
    }

    // All medications must be valid
    if (!medications.every((med) => med.isValid)) {
      return false;
    }

    // Prescription upload required
    if (!upload.hasFile) {
      return false;
    }

    // Declaration must be accepted
    if (!declarationAccepted) {
      return false;
    }

    return true;
  }

  Map<String, dynamic> toJson() {
    return {
      'metadata': metadata.toJson(),
      'doctor_details': doctorDetails.toJson(),
      'diagnosis': diagnosis,
      'doctor_notes': doctorNotes,
      'patient_notes': patientNotes,
      'medications': medications.map((m) => m.toJson()).toList(),
      'safety_flags': safetyFlags.toJson(),
      'upload_info': upload.toJson(),
      'declaration_accepted': declarationAccepted,
      'verification_status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
