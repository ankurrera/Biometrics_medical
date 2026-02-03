import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../widgets/role_card.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDark 
                  ? AppColors.primary.withOpacity(0.15) 
                  : AppColors.primarySurface,
              Theme.of(context).scaffoldBackgroundColor,
            ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                // Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.medical_services_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'CareSync',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // Title
                const Text(
                  'Welcome!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select your role to get started',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 32),
                // Role cards
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.95,
                    children: [
                      RoleCard(
                        title: 'Patient',
                        description: 'Manage your prescriptions & medical history',
                        icon: Icons.person_rounded,
                        color: AppColors.patient,
                        onTap: () => _navigateToSignIn(context, 'patient'),
                      ),
                      RoleCard(
                        title: 'Doctor',
                        description: 'Create prescriptions & view patient records',
                        icon: Icons.local_hospital_rounded,
                        color: AppColors.doctor,
                        onTap: () => _navigateToSignIn(context, 'doctor'),
                      ),
                      RoleCard(
                        title: 'Pharmacist',
                        description: 'Dispense medicines & track transactions',
                        icon: Icons.medication_rounded,
                        color: AppColors.pharmacist,
                        onTap: () => _navigateToSignIn(context, 'pharmacist'),
                      ),
                      RoleCard(
                        title: 'First Responder',
                        description: 'Access emergency medical data via QR scan',
                        icon: Icons.emergency_rounded,
                        color: AppColors.firstResponder,
                        onTap: () => _navigateToSignIn(context, 'first_responder'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToSignIn(BuildContext context, String role) {
    context.push(RouteNames.signIn, extra: role);
  }
}

