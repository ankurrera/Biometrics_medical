/// Patient-specific data model
class PatientData {
  final String id;
  final String userId;
  final String? bloodType;
  final DateTime? dateOfBirth;
  final EmergencyContact? emergencyContact;
  final String qrCodeId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PatientData({
    required this.id,
    required this.userId,
    this.bloodType,
    this.dateOfBirth,
    this.emergencyContact,
    required this.qrCodeId,
    required this.createdAt,
    this.updatedAt,
  });

  factory PatientData.fromJson(Map<String, dynamic> json) {
    return PatientData(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      bloodType: json['blood_type'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      emergencyContact: json['emergency_contact'] != null
          ? EmergencyContact.fromJson(
              json['emergency_contact'] as Map<String, dynamic>)
          : null,
      qrCodeId: json['qr_code_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'blood_type': bloodType,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'emergency_contact': emergencyContact?.toJson(),
      'qr_code_id': qrCodeId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int years = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      years--;
    }
    return years;
  }
}

/// Emergency contact information
class EmergencyContact {
  final String name;
  final String phone;
  final String? relationship;

  const EmergencyContact({
    required this.name,
    required this.phone,
    this.relationship,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String,
      phone: json['phone'] as String,
      relationship: json['relationship'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'relationship': relationship,
    };
  }
}

/// Medical condition model
class MedicalCondition {
  final String id;
  final String patientId;
  final String conditionType;
  final String description;
  final String? severity;
  final bool isPublic;
  final DateTime createdAt;

  const MedicalCondition({
    required this.id,
    required this.patientId,
    required this.conditionType,
    required this.description,
    this.severity,
    required this.isPublic,
    required this.createdAt,
  });

  factory MedicalCondition.fromJson(Map<String, dynamic> json) {
    return MedicalCondition(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      conditionType: json['condition_type'] as String,
      description: json['description'] as String,
      severity: json['severity'] as String?,
      isPublic: json['is_public'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get conditionTypeDisplayName {
    switch (conditionType) {
      case 'allergy':
        return 'Allergy';
      case 'chronic':
        return 'Chronic Condition';
      case 'medication':
        return 'Current Medication';
      default:
        return 'Other';
    }
  }
}

