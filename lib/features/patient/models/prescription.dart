/// Prescription status enum
enum PrescriptionStatus {
  active,
  expired,
  upcoming,
  completed,
  cancelled;

  String get displayName {
    switch (this) {
      case PrescriptionStatus.active:
        return 'ACTIVE';
      case PrescriptionStatus.expired:
        return 'EXPIRED';
      case PrescriptionStatus.upcoming:
        return 'UPCOMING';
      case PrescriptionStatus.completed:
        return 'COMPLETED';
      case PrescriptionStatus.cancelled:
        return 'CANCELLED';
    }
  }

  static PrescriptionStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'active':
        return PrescriptionStatus.active;
      case 'expired':
        return PrescriptionStatus.expired;
      case 'upcoming':
        return PrescriptionStatus.upcoming;
      case 'completed':
        return PrescriptionStatus.completed;
      case 'cancelled':
        return PrescriptionStatus.cancelled;
      default:
        return PrescriptionStatus.active;
    }
  }
}

/// Verification status enum
enum VerificationStatus {
  pending,
  verified,
  rejected;

  String get displayName {
    switch (this) {
      case VerificationStatus.pending:
        return 'Pending Verification';
      case VerificationStatus.verified:
        return 'Doctor Verified';
      case VerificationStatus.rejected:
        return 'Rejected';
    }
  }

  static VerificationStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'verified':
        return VerificationStatus.verified;
      case 'rejected':
        return VerificationStatus.rejected;
      default:
        return VerificationStatus.pending;
    }
  }
}

/// Entry source enum
enum EntrySource {
  doctor,
  patient;

  String get displayName {
    switch (this) {
      case EntrySource.doctor:
        return 'Doctor Entered';
      case EntrySource.patient:
        return 'Patient Entered';
    }
  }
}

/// Prescription model
class Prescription {
  final String id;
  final String patientId;
  final String? doctorId;
  final String diagnosis;
  final String? notes;
  final bool isPublic;
  final bool patientEntered;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<PrescriptionItem> items;
  final DoctorInfo? doctor;
  final Map<String, dynamic>? metadata;

  const Prescription({
    required this.id,
    required this.patientId,
    this.doctorId,
    required this.diagnosis,
    this.notes,
    required this.isPublic,
    this.patientEntered = false,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.items = const [],
    this.doctor,
    this.metadata,
  });

  factory Prescription.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['prescription_items'] as List<dynamic>?;
    final doctorJson = json['doctor'] as Map<String, dynamic>?;

    return Prescription(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      doctorId: json['doctor_id'] as String?,
      diagnosis: json['diagnosis'] as String,
      notes: json['notes'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      patientEntered: json['patient_entered'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      items: itemsJson
          ?.map((e) => PrescriptionItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      doctor: doctorJson != null ? DoctorInfo.fromJson(doctorJson) : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'diagnosis': diagnosis,
      'notes': notes,
      'is_public': isPublic,
      'patient_entered': patientEntered,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  // Status helpers
  PrescriptionStatus get prescriptionStatus => PrescriptionStatus.fromString(status);
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isExpired => status == 'expired';
  bool get isUpcoming => status == 'upcoming';

  // Computed status based on dates
  PrescriptionStatus get computedStatus {
    final now = DateTime.now();
    final prescriptionDate = this.prescriptionDate;
    final validUntil = this.validUntil;
    final currentStatus = prescriptionStatus;

    if (currentStatus == PrescriptionStatus.cancelled) return PrescriptionStatus.cancelled;
    if (currentStatus == PrescriptionStatus.completed) return PrescriptionStatus.completed;

    if (prescriptionDate != null && prescriptionDate.isAfter(now)) {
      return PrescriptionStatus.upcoming;
    }
    if (validUntil != null && validUntil.isBefore(now)) {
      return PrescriptionStatus.expired;
    }
    return PrescriptionStatus.active;
  }

  // Entry source
  EntrySource get entrySource => patientEntered ? EntrySource.patient : EntrySource.doctor;

  // Verification status from metadata
  VerificationStatus get verificationStatus {
    final status = metadata?['verification_status'] as String?;
    return VerificationStatus.fromString(status);
  }

  // Get doctor details from metadata (for patient-entered prescriptions)
  PrescriptionDoctorDetails? get doctorDetails {
    final details = metadata?['doctor_details'] as Map<String, dynamic>?;
    if (details == null) return null;
    return PrescriptionDoctorDetails.fromJson(details);
  }

  // Get prescription date from metadata
  DateTime? get prescriptionDate {
    final metadataInfo = metadata?['metadata'] as Map<String, dynamic>?; // Fallback for old structure
    final directDate = metadata?['prescription_date'] as String?; // New structure

    // Check direct first, then nested
    if (directDate != null) return DateTime.tryParse(directDate);

    final dateStr = metadataInfo?['prescription_date'] as String?;
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  // Get valid until date from metadata
  DateTime? get validUntil {
    final metadataInfo = metadata?['metadata'] as Map<String, dynamic>?;
    final directDate = metadata?['valid_until'] as String?;

    if (directDate != null) return DateTime.tryParse(directDate);

    final dateStr = metadataInfo?['valid_until'] as String?;
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  NEW: Get PDF URL from metadata
  // ──────────────────────────────────────────────────────────────────────────
  String? get pdfUrl => metadata?['pdf_url'] as String?;

  // Get prescription type from metadata
  String? get prescriptionType {
    final metadataInfo = metadata?['metadata'] as Map<String, dynamic>?;
    final directType = metadata?['type'] as String?;
    return directType ?? metadataInfo?['prescription_type'] as String?;
  }

  // Get doctor notes from metadata
  String? get doctorNotes {
    final notes = metadata?['doctor_notes'] as String?;
    if (notes == null || notes.trim().isEmpty) return null;
    // Check for placeholder values
    final lowerNotes = notes.trim().toLowerCase();
    if (lowerNotes == 'mm' || lowerNotes == 'mmm' ||
        lowerNotes == 'n/a' || lowerNotes == 'na') {
      return null; // Treat placeholders as no notes
    }
    return notes;
  }

  // Get patient notes from metadata
  String? get patientNotes {
    final notes = metadata?['patient_notes'] as String?;
    if (notes == null || notes.trim().isEmpty) return null;
    // Check for placeholder values
    final lowerNotes = notes.trim().toLowerCase();
    if (lowerNotes == 'mm' || lowerNotes == 'mmm' ||
        lowerNotes == 'n/a' || lowerNotes == 'na') {
      return null; // Treat placeholders as no notes
    }
    return notes;
  }

  // Get safety flags from metadata
  SafetyFlags? get safetyFlags {
    final flags = metadata?['safety_flags'] as Map<String, dynamic>?;
    if (flags == null) return null;
    return SafetyFlags.fromJson(flags);
  }

  // Get upload info from metadata
  UploadInfo? get uploadInfo {
    final info = metadata?['upload_info'] as Map<String, dynamic>?;
    if (info == null) return null;
    return UploadInfo.fromJson(info);
  }

  // Display-friendly doctor name
  String get displayDoctorName {
    // Try from doctor details first (for patient-entered)
    final details = doctorDetails;
    if (details != null && details.doctorName.isNotEmpty) {
      return details.doctorName;
    }
    // Try from linked doctor profile
    if (doctor != null && doctor!.fullName.isNotEmpty) {
      return 'Dr. ${doctor!.fullName}';
    }
    // Fallback for patient-entered
    if (patientEntered) {
      return 'Patient-entered';
    }
    return 'Not specified';
  }

  // Display-friendly clinic name
  String? get displayClinicName {
    return doctorDetails?.hospitalClinicName;
  }

  // Display-friendly specialization
  String? get displaySpecialization {
    return doctorDetails?.specialization;
  }

  // Display-friendly registration number
  String? get displayRegistrationNumber {
    return doctorDetails?.medicalRegistrationNumber;
  }

  // Display-friendly diagnosis (with fallback for empty/placeholder)
  String get displayDiagnosis {
    if (diagnosis.trim().isEmpty) {
      return 'No diagnosis provided';
    }
    final lowerDiagnosis = diagnosis.trim().toLowerCase();
    // Check for common placeholder values
    if (lowerDiagnosis == 'mm' || lowerDiagnosis == 'mmm' ||
        lowerDiagnosis == 'n/a' || lowerDiagnosis == 'na' ||
        lowerDiagnosis == 'test' || lowerDiagnosis == 'placeholder') {
      return 'Incomplete diagnosis data';
    }
    return diagnosis;
  }
}

/// Doctor details from prescription metadata (for display)
class PrescriptionDoctorDetails {
  final String doctorName;
  final String? specialization;
  final String? hospitalClinicName;
  final String? medicalRegistrationNumber;
  final bool signatureUploaded;

  const PrescriptionDoctorDetails({
    required this.doctorName,
    this.specialization,
    this.hospitalClinicName,
    this.medicalRegistrationNumber,
    this.signatureUploaded = false,
  });

  factory PrescriptionDoctorDetails.fromJson(Map<String, dynamic> json) {
    return PrescriptionDoctorDetails(
      doctorName: json['doctor_name'] as String? ?? '',
      specialization: json['specialization'] as String?,
      hospitalClinicName: json['hospital_clinic_name'] as String?,
      medicalRegistrationNumber: json['medical_registration_number'] as String?,
      signatureUploaded: json['signature_uploaded'] as bool? ?? false,
    );
  }
}

/// Safety flags model
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

  factory SafetyFlags.fromJson(Map<String, dynamic> json) {
    return SafetyFlags(
      allergiesMentioned: json['allergies_mentioned'] as bool?,
      pregnancyBreastfeeding: json['pregnancy_breastfeeding'] as bool?,
      chronicConditionLinked: json['chronic_condition_linked'] as bool?,
      notes: json['notes'] as String?,
    );
  }
}

/// Upload info model
class UploadInfo {
  final String? fileName;
  final String? fileType;
  final int? fileSizeBytes;

  const UploadInfo({
    this.fileName,
    this.fileType,
    this.fileSizeBytes,
  });

  factory UploadInfo.fromJson(Map<String, dynamic> json) {
    return UploadInfo(
      fileName: json['file_name'] as String?,
      fileType: json['file_type'] as String?,
      fileSizeBytes: json['file_size_bytes'] as int?,
    );
  }

  bool get hasFile => fileName != null && fileName!.isNotEmpty;
}

/// Individual prescription item (medicine)
class PrescriptionItem {
  final String id;
  final String prescriptionId;
  final String medicineName;
  final String dosage;
  final String frequency;
  final String? duration;
  final String? instructions;
  final int? quantity;
  final bool isDispensed;
  final DateTime createdAt;
  final String? medicineType;
  final String? route;
  final String? foodTiming;

  const PrescriptionItem({
    required this.id,
    required this.prescriptionId,
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    this.duration,
    this.instructions,
    this.quantity,
    required this.isDispensed,
    required this.createdAt,
    this.medicineType,
    this.route,
    this.foodTiming,
  });

  factory PrescriptionItem.fromJson(Map<String, dynamic> json) {
    return PrescriptionItem(
      id: json['id'] as String,
      prescriptionId: json['prescription_id'] as String,
      medicineName: json['medicine_name'] as String,
      dosage: json['dosage'] as String,
      frequency: json['frequency'] as String,
      duration: json['duration'] as String?,
      instructions: json['instructions'] as String?,
      quantity: json['quantity'] as int?,
      isDispensed: json['is_dispensed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      medicineType: json['medicine_type'] as String?,
      route: json['route'] as String?,
      foodTiming: json['food_timing'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prescription_id': prescriptionId,
      'medicine_name': medicineName,
      'dosage': dosage,
      'frequency': frequency,
      'duration': duration,
      'instructions': instructions,
      'quantity': quantity,
      'is_dispensed': isDispensed,
      'created_at': createdAt.toIso8601String(),
      'medicine_type': medicineType,
      'route': route,
      'food_timing': foodTiming,
    };
  }

  // Display-friendly medicine type
  String? get displayMedicineType {
    if (medicineType == null) return null;
    switch (medicineType) {
      case 'tablet':
        return 'Tablet';
      case 'syrup':
        return 'Syrup';
      case 'injection':
        return 'Injection';
      case 'ointment':
        return 'Ointment';
      case 'capsule':
        return 'Capsule';
      case 'drops':
        return 'Drops';
      default:
        return medicineType;
    }
  }

  // Display-friendly route
  String? get displayRoute {
    if (route == null) return null;
    switch (route) {
      case 'oral':
        return 'Oral';
      case 'intravenous':
        return 'IV (Intravenous)';
      case 'intramuscular':
        return 'IM (Intramuscular)';
      case 'topical':
        return 'Topical';
      case 'sublingual':
        return 'Sublingual';
      default:
        return route;
    }
  }

  // Display-friendly food timing
  String? get displayFoodTiming {
    if (foodTiming == null) return null;
    switch (foodTiming) {
      case 'beforeFood':
        return 'Before Food';
      case 'afterFood':
        return 'After Food';
      case 'withFood':
        return 'With Food';
      case 'empty':
        return 'Empty Stomach';
      default:
        return foodTiming;
    }
  }

  // Display-friendly instructions (with placeholder detection)
  String? get displayInstructions {
    if (instructions == null || instructions!.trim().isEmpty) return null;
    final lowerInstructions = instructions!.trim().toLowerCase();
    // Check for placeholder values
    if (lowerInstructions == 'mm' || lowerInstructions == 'mmm' ||
        lowerInstructions == 'n/a' || lowerInstructions == 'na' ||
        lowerInstructions.contains('take food mmm') ||
        lowerInstructions.contains('take after food mmm')) {
      return null; // Treat placeholders as no instructions
    }
    return instructions;
  }
}

/// Doctor info for display
class DoctorInfo {
  final String id;
  final String fullName;
  final String? email;

  const DoctorInfo({
    required this.id,
    required this.fullName,
    this.email,
  });

  factory DoctorInfo.fromJson(Map<String, dynamic> json) {
    return DoctorInfo(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Unknown Doctor',
      email: json['email'] as String?,
    );
  }
}