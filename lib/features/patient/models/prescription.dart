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
    };
  }

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
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
    };
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

