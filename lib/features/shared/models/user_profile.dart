/// User profile model
class UserProfile {
  final String id;
  final String email;
  final String? phone;
  final String fullName;
  final String role;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Doctor Specific Fields (Added)
  final String? hospitalName;
  final String? specialization;
  final String? medicalRegNumber;

  const UserProfile({
    required this.id,
    required this.email,
    this.phone,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    required this.createdAt,
    this.updatedAt,
    this.hospitalName,
    this.specialization,
    this.medicalRegNumber,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? 'patient',
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      // Map database columns to Dart properties
      hospitalName: json['hospital_clinic_name'] as String?,
      specialization: json['specialization'] as String?,
      medicalRegNumber: json['medical_registration_number'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'full_name': fullName,
      'role': role,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      // Include new fields in JSON
      'hospital_clinic_name': hospitalName,
      'specialization': specialization,
      'medical_registration_number': medicalRegNumber,
    };
  }

  bool get isPatient => role == 'patient';
  bool get isDoctor => role == 'doctor';
  bool get isPharmacist => role == 'pharmacist';
  bool get isFirstResponder => role == 'first_responder';

  String get roleDisplayName {
    switch (role) {
      case 'patient':
        return 'Patient';
      case 'doctor':
        return 'Doctor';
      case 'pharmacist':
        return 'Pharmacist';
      case 'first_responder':
        return 'First Responder';
      default:
        return role;
    }
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? phone,
    String? fullName,
    String? role,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? hospitalName,
    String? specialization,
    String? medicalRegNumber,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hospitalName: hospitalName ?? this.hospitalName,
      specialization: specialization ?? this.specialization,
      medicalRegNumber: medicalRegNumber ?? this.medicalRegNumber,
    );
  }
}