/// Centralized route path constants
abstract class RouteNames {
  // Auth
  static const String splash = '/';
  static const String roleSelection = '/role-selection';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String biometricEnrollment = '/biometric-enrollment';
  static const String kycVerification = '/kyc-verification';
  static const String twoFactorVerification = '/two-factor-verification';
  static const String deviceManagement = '/device-management';

  // Common/Shared
  static const String profile = '/profile';
  static const String notifications = '/notifications';

  // Patient
  static const String patientDashboard = '/patient';
  static const String patientPrescriptions = '/patient/prescriptions';
  static const String patientMedicalHistory = '/patient/history';
  static const String patientQrCode = '/patient/qr-code';
  static const String patientProfile = '/patient/profile';
  static const String patientPrivacy = '/patient/privacy';
  static const String patientNewPrescription = '/patient/new-prescription';

  // Doctor
  static const String doctorDashboard = '/doctor';
  static const String doctorPatientLookup = '/doctor/patient-lookup';
  static const String doctorNewPrescription = '/doctor/new-prescription';
  static const String doctorHistory = '/doctor/history';
  static const String doctorScanQr = '/doctor/scan-qr';

  // Pharmacist
  static const String pharmacistDashboard = '/pharmacist';
  static const String pharmacistDispense = '/pharmacist/dispense';
  static const String pharmacistHistory = '/pharmacist/history';
  static const String pharmacistSearch = '/pharmacist/search';

  // First Responder
  static const String firstResponderDashboard = '/first-responder';
  static const String firstResponderScan = '/first-responder/scan';
  static const String firstResponderEmergencyView = '/first-responder/emergency';
}

