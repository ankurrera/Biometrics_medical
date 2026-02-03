import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/screens/role_selection_screen.dart';
import '../features/auth/presentation/screens/sign_in_screen.dart';
import '../features/auth/presentation/screens/sign_up_screen.dart';
import '../features/auth/presentation/screens/biometric_enrollment_screen.dart';
import '../features/auth/presentation/screens/kyc_verification_screen.dart';
import '../features/auth/presentation/screens/device_management_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/patient/presentation/screens/patient_dashboard_screen.dart';
import '../features/patient/presentation/screens/add_prescription_screen.dart';
import '../features/patient/presentation/screens/prescriptions_screen.dart';
import '../features/patient/presentation/screens/qr_code_screen.dart';
import '../features/patient/presentation/screens/medical_history_screen.dart';
import '../features/patient/presentation/screens/privacy_settings_screen.dart';
import '../features/doctor/presentation/screens/doctor_dashboard_screen.dart';
import '../features/doctor/presentation/screens/patient_lookup_screen.dart';
import '../features/doctor/presentation/screens/prescription_history_screen.dart';
import '../features/pharmacist/presentation/screens/pharmacist_dashboard_screen.dart';
import '../features/pharmacist/presentation/screens/dispensing_history_screen.dart';
import '../features/pharmacist/presentation/screens/dispense_screen.dart';
import '../features/first_responder/presentation/screens/first_responder_dashboard_screen.dart';
import '../features/first_responder/presentation/screens/qr_scanner_screen.dart';
import '../features/first_responder/presentation/screens/emergency_data_screen.dart';
import '../features/shared/presentation/screens/splash_screen.dart';
import '../features/shared/presentation/screens/profile_screen.dart';
import '../features/shared/presentation/screens/notifications_screen.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final profile = ref.read(currentProfileProvider).valueOrNull;

  return GoRouter(
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(authState),
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == RouteNames.signIn ||
          state.matchedLocation == RouteNames.signUp ||
          state.matchedLocation == RouteNames.roleSelection;
      final isSplash = state.matchedLocation == RouteNames.splash;

      // If still loading, stay on splash
      if (authState.isLoading && isSplash) {
        return null;
      }

      // Not authenticated - redirect to role selection (unless already on auth route)
      if (!isAuthenticated && !isAuthRoute && !isSplash) {
        // Allow KYC and device management screens without auth
        final isKYCRoute = state.matchedLocation == RouteNames.kycVerification;
        final isDeviceRoute = state.matchedLocation == RouteNames.deviceManagement;
        
        if (!isKYCRoute && !isDeviceRoute) {
          return RouteNames.roleSelection;
        }
      }

      // Authenticated but on auth route - redirect to appropriate dashboard
      if (isAuthenticated && isAuthRoute) {
        return _getDashboardRoute(ref);
      }

      // Enforce role-specific paths
      if (isAuthenticated && profile != null) {
        final path = state.matchedLocation;
        final expectedPrefix = _rolePrefix(profile.role);
        final isCommonRoute = path == RouteNames.profile ||
            path == RouteNames.notifications ||
            path == RouteNames.biometricEnrollment ||
            path == RouteNames.kycVerification ||
            path == RouteNames.deviceManagement;

        if (!isCommonRoute &&
            expectedPrefix != null &&
            !path.startsWith(expectedPrefix)) {
          return _getDashboardRoute(ref);
        }
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: RouteNames.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth Routes
      GoRoute(
        path: RouteNames.roleSelection,
        name: 'roleSelection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: RouteNames.signIn,
        name: 'signIn',
        builder: (context, state) {
          final role = state.extra as String? ?? 'patient';
          return SignInScreen(role: role);
        },
      ),
      GoRoute(
        path: RouteNames.signUp,
        name: 'signUp',
        builder: (context, state) {
          final role = state.extra as String? ?? 'patient';
          return SignUpScreen(role: role);
        },
      ),
      GoRoute(
        path: RouteNames.biometricEnrollment,
        name: 'biometricEnrollment',
        builder: (context, state) {
          final isMandatory = state.extra as bool? ?? false;
          return BiometricEnrollmentScreen(isMandatory: isMandatory);
        },
      ),
      GoRoute(
        path: RouteNames.kycVerification,
        name: 'kycVerification',
        builder: (context, state) => const KYCVerificationScreen(),
      ),
      GoRoute(
        path: RouteNames.deviceManagement,
        name: 'deviceManagement',
        builder: (context, state) => const DeviceManagementScreen(),
      ),

      // Common Routes
      GoRoute(
        path: RouteNames.profile,
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: RouteNames.notifications,
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      // Patient Routes
      GoRoute(
        path: RouteNames.patientDashboard,
        name: 'patientDashboard',
        builder: (context, state) => const PatientDashboardScreen(),
      ),
      GoRoute(
        path: RouteNames.patientPrescriptions,
        name: 'patientPrescriptions',
        builder: (context, state) => const PrescriptionsScreen(),
      ),
      GoRoute(
        path: RouteNames.patientNewPrescription,
        name: 'patientNewPrescription',
        builder: (context, state) => const AddPrescriptionScreen(),
      ),
      GoRoute(
        path: RouteNames.patientQrCode,
        name: 'patientQrCode',
        builder: (context, state) => const QrCodeScreen(),
      ),
      GoRoute(
        path: RouteNames.patientMedicalHistory,
        name: 'patientMedicalHistory',
        builder: (context, state) => const MedicalHistoryScreen(),
      ),
      GoRoute(
        path: RouteNames.patientPrivacy,
        name: 'patientPrivacy',
        builder: (context, state) => const PrivacySettingsScreen(),
      ),

      // Doctor Routes
      GoRoute(
        path: RouteNames.doctorDashboard,
        name: 'doctorDashboard',
        builder: (context, state) => const DoctorDashboardScreen(),
      ),
      GoRoute(
        path: RouteNames.doctorPatientLookup,
        name: 'doctorPatientLookup',
        builder: (context, state) => const PatientLookupScreen(),
      ),
      GoRoute(
        path: RouteNames.doctorHistory,
        name: 'doctorHistory',
        builder: (context, state) => const PrescriptionHistoryScreen(),
      ),

      // Pharmacist Routes
      GoRoute(
        path: RouteNames.pharmacistDashboard,
        name: 'pharmacistDashboard',
        builder: (context, state) => const PharmacistDashboardScreen(),
      ),
      GoRoute(
        path: RouteNames.pharmacistDispense,
        name: 'pharmacistDispense',
        builder: (context, state) => const DispenseScreen(),
      ),
      GoRoute(
        path: RouteNames.pharmacistHistory,
        name: 'pharmacistHistory',
        builder: (context, state) => const DispensingHistoryScreen(),
      ),

      // First Responder Routes
      GoRoute(
        path: RouteNames.firstResponderDashboard,
        name: 'firstResponderDashboard',
        builder: (context, state) => const FirstResponderDashboardScreen(),
      ),
      GoRoute(
        path: RouteNames.firstResponderScan,
        name: 'firstResponderScan',
        builder: (context, state) => const QrScannerScreen(),
      ),
      GoRoute(
        path: '${RouteNames.firstResponderEmergencyView}/:qrCodeId',
        name: 'firstResponderEmergencyView',
        builder: (context, state) {
          final qrCodeId = state.pathParameters['qrCodeId']!;
          return EmergencyDataScreen(qrCodeId: qrCodeId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});

String _getDashboardRoute(Ref ref) {
  final profile = ref.read(currentProfileProvider).valueOrNull;
  switch (profile?.role) {
    case 'doctor':
      return RouteNames.doctorDashboard;
    case 'pharmacist':
      return RouteNames.pharmacistDashboard;
    case 'first_responder':
      return RouteNames.firstResponderDashboard;
    case 'patient':
    default:
      return RouteNames.patientDashboard;
  }
}

/// Helper class to convert a stream to a listenable for GoRouter
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(AsyncValue<dynamic> stream) {
    notifyListeners();
  }
}

String? _rolePrefix(String role) {
  switch (role) {
    case 'doctor':
      return '/doctor';
    case 'pharmacist':
      return '/pharmacist';
    case 'first_responder':
      return '/first-responder';
    case 'patient':
      return '/patient';
    default:
      return null;
  }
}

