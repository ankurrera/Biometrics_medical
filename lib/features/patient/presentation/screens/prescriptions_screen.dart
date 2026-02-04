import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../models/prescription.dart';
import '../../providers/patient_provider.dart';

/// Professional My Prescriptions List Screen
/// 
/// Features:
/// - Card-based layout (no timeline)
/// - Status badges (ACTIVE/EXPIRED/UPCOMING)
/// - Verification badges (Doctor Verified/Patient Entered)
/// - Complete doctor information
/// - Validity period display
/// - Medication count
/// - Quick action buttons
class PrescriptionsScreen extends ConsumerWidget {
  const PrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptions = ref.watch(patientPrescriptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Prescriptions'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/patient/add-prescription'),
            tooltip: 'Add Prescription',
          ),
        ],
      ),
      body: prescriptions.when(
        data: (list) {
          if (list.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(patientPrescriptionsProvider);
            },
            child: ListView.separated(
              padding: AppSpacing.screenPadding,
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _PrescriptionCard(prescription: list[index]);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error loading prescriptions',
                  style: TextStyle(color: AppColors.error)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(patientPrescriptionsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/patient/add-prescription'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Prescription'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.description_outlined,
                size: 64,
                color: AppColors.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Prescriptions Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your prescriptions will appear here.\nAdd a new prescription to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/patient/add-prescription'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Prescription'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Professional Prescription Card Widget
class _PrescriptionCard extends StatelessWidget {
  final Prescription prescription;

  const _PrescriptionCard({required this.prescription});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final status = prescription.computedStatus;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _getStatusColor(status).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showPrescriptionDetails(context),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status and verification badges
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  // Status Badge
                  _buildStatusBadge(status),
                  const Spacer(),
                  // Verification Badge
                  _buildVerificationBadge(),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Diagnosis / Condition (Primary Title)
                  Text(
                    prescription.displayDiagnosis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Doctor Information
                  _buildDoctorInfo(context),
                  const SizedBox(height: 8),

                  // Validity Period
                  _buildValidityPeriod(context, dateFormat),
                  const SizedBox(height: 12),

                  // Divider
                  Divider(
                    height: 1,
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                  const SizedBox(height: 12),

                  // Medication Summary & Quick Actions
                  Row(
                    children: [
                      // Medication Count
                      _buildMedicationSummary(context),
                      const Spacer(),
                      // Quick Actions
                      _buildQuickActions(context),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(PrescriptionStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(status),
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBadge() {
    final isVerified = prescription.verificationStatus == VerificationStatus.verified;
    final isPatientEntered = prescription.patientEntered;

    if (isVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.success.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 14, color: AppColors.success),
            SizedBox(width: 4),
            Text(
              'VERIFIED',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    }

    if (isPatientEntered) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.info.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.info.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline_rounded, size: 14, color: AppColors.info),
            SizedBox(width: 4),
            Text(
              'PATIENT ENTERED',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.info,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.doctor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.doctor.withOpacity(0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.medical_services_outlined, size: 14, color: AppColors.doctor),
          SizedBox(width: 4),
          Text(
            'DOCTOR ISSUED',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.doctor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorInfo(BuildContext context) {
    final doctorName = prescription.displayDoctorName;
    final clinicName = prescription.displayClinicName;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.doctor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            size: 18,
            color: AppColors.doctor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doctorName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (clinicName != null && clinicName.isNotEmpty)
                Text(
                  clinicName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildValidityPeriod(BuildContext context, DateFormat dateFormat) {
    final prescriptionDate = prescription.prescriptionDate ?? prescription.createdAt;
    final validUntil = prescription.validUntil;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.calendar_today_rounded,
            size: 18,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Text(
                dateFormat.format(prescriptionDate),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (validUntil != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
                Text(
                  dateFormat.format(validUntil),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: validUntil.isBefore(DateTime.now())
                        ? AppColors.error
                        : AppColors.success,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationSummary(BuildContext context) {
    final count = prescription.items.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.pharmacist.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.medication_rounded,
            size: 16,
            color: AppColors.pharmacist,
          ),
          const SizedBox(width: 6),
          Text(
            '$count medicine${count != 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.pharmacist,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // View Details button
        TextButton.icon(
          onPressed: () => _showPrescriptionDetails(context),
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('Details'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
        // Share button (optional)
        IconButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Share feature coming soon'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.share_outlined, size: 20),
          color: AppColors.secondary,
          tooltip: 'Share',
        ),
      ],
    );
  }

  void _showPrescriptionDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PrescriptionDetailsSheet(prescription: prescription),
    );
  }

  Color _getStatusColor(PrescriptionStatus status) {
    switch (status) {
      case PrescriptionStatus.active:
        return AppColors.success;
      case PrescriptionStatus.expired:
        return AppColors.error;
      case PrescriptionStatus.upcoming:
        return AppColors.info;
      case PrescriptionStatus.completed:
        return AppColors.primary;
      case PrescriptionStatus.cancelled:
        return AppColors.secondary;
    }
  }

  IconData _getStatusIcon(PrescriptionStatus status) {
    switch (status) {
      case PrescriptionStatus.active:
        return Icons.check_circle_rounded;
      case PrescriptionStatus.expired:
        return Icons.error_rounded;
      case PrescriptionStatus.upcoming:
        return Icons.schedule_rounded;
      case PrescriptionStatus.completed:
        return Icons.done_all_rounded;
      case PrescriptionStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }
}

/// Professional Prescription Details Bottom Sheet
class _PrescriptionDetailsSheet extends StatelessWidget {
  final Prescription prescription;

  const _PrescriptionDetailsSheet({required this.prescription});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMMM d, yyyy');
    final status = prescription.computedStatus;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header with badges
                _buildHeader(context, status, dateFormat),
                const SizedBox(height: 24),

                // Doctor / Issuer Section
                _buildSectionTitle(context, 'Doctor / Issuer', Icons.person_outline_rounded),
                const SizedBox(height: 12),
                _buildDoctorSection(context),
                const SizedBox(height: 20),

                // Prescription Metadata
                _buildSectionTitle(context, 'Prescription Details', Icons.info_outline_rounded),
                const SizedBox(height: 12),
                _buildMetadataSection(context, dateFormat),
                const SizedBox(height: 20),

                // Diagnosis & Notes
                _buildSectionTitle(context, 'Diagnosis & Notes', Icons.medical_information_outlined),
                const SizedBox(height: 12),
                _buildDiagnosisSection(context),
                const SizedBox(height: 20),

                // Medications
                _buildSectionTitle(context, 'Medications', Icons.medication_outlined),
                const SizedBox(height: 12),
                if (prescription.items.isEmpty)
                  _buildEmptyMedications(context)
                else
                  ...prescription.items.asMap().entries.map(
                    (entry) => _buildMedicationCard(context, entry.value, entry.key + 1),
                  ),

                // Safety Information
                if (prescription.safetyFlags != null) ...[
                  const SizedBox(height: 20),
                  _buildSectionTitle(context, 'Safety Information', Icons.health_and_safety_outlined),
                  const SizedBox(height: 12),
                  _buildSafetySection(context),
                ],

                // Uploaded Prescription
                if (prescription.uploadInfo != null && prescription.uploadInfo!.hasFile) ...[
                  const SizedBox(height: 20),
                  _buildSectionTitle(context, 'Uploaded Prescription', Icons.file_present_outlined),
                  const SizedBox(height: 12),
                  _buildUploadSection(context),
                ],

                const SizedBox(height: 32),

                // Action Buttons
                _buildActionButtons(context),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PrescriptionStatus status, DateFormat dateFormat) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Prescription Details',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Status and Verification badges
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatusBadge(status),
                  _buildVerificationBadge(),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(PrescriptionStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.displayName,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildVerificationBadge() {
    final verificationStatus = prescription.verificationStatus;
    Color color;
    String text;
    IconData icon;

    switch (verificationStatus) {
      case VerificationStatus.verified:
        color = AppColors.success;
        text = 'Verified';
        icon = Icons.verified_rounded;
        break;
      case VerificationStatus.rejected:
        color = AppColors.error;
        text = 'Rejected';
        icon = Icons.cancel_rounded;
        break;
      case VerificationStatus.pending:
      default:
        color = prescription.patientEntered ? AppColors.info : AppColors.doctor;
        text = prescription.patientEntered ? 'Patient Entered' : 'Doctor Issued';
        icon = prescription.patientEntered ? Icons.person_outline_rounded : Icons.medical_services_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorSection(BuildContext context) {
    final details = prescription.doctorDetails;
    final doctor = prescription.doctor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            context,
            'Doctor Name',
            prescription.displayDoctorName,
            Icons.person_rounded,
          ),
          if (details?.specialization != null) ...[
            const Divider(height: 20),
            _buildInfoRow(
              context,
              'Specialization',
              details!.specialization!,
              Icons.medical_services_rounded,
            ),
          ],
          if (details?.hospitalClinicName != null) ...[
            const Divider(height: 20),
            _buildInfoRow(
              context,
              'Hospital / Clinic',
              details!.hospitalClinicName!,
              Icons.local_hospital_rounded,
            ),
          ],
          if (details?.medicalRegistrationNumber != null) ...[
            const Divider(height: 20),
            _buildInfoRow(
              context,
              'Medical Registration No.',
              details!.medicalRegistrationNumber!,
              Icons.badge_rounded,
            ),
          ],
          const Divider(height: 20),
          _buildInfoRow(
            context,
            'Signature',
            (details?.signatureUploaded ?? false) ? 'Uploaded' : 'Not uploaded',
            Icons.draw_rounded,
            valueColor: (details?.signatureUploaded ?? false) 
                ? AppColors.success 
                : AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataSection(BuildContext context, DateFormat dateFormat) {
    final prescriptionDate = prescription.prescriptionDate ?? prescription.createdAt;
    final validUntil = prescription.validUntil;
    final prescriptionType = prescription.prescriptionType;
    final entrySource = prescription.entrySource;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            context,
            'Prescription Date',
            dateFormat.format(prescriptionDate),
            Icons.calendar_today_rounded,
          ),
          if (validUntil != null) ...[
            const Divider(height: 20),
            _buildInfoRow(
              context,
              'Valid Until',
              dateFormat.format(validUntil),
              Icons.event_available_rounded,
              valueColor: validUntil.isBefore(DateTime.now())
                  ? AppColors.error
                  : AppColors.success,
            ),
          ],
          if (prescriptionType != null) ...[
            const Divider(height: 20),
            _buildInfoRow(
              context,
              'Prescription Type',
              _formatPrescriptionType(prescriptionType),
              Icons.category_rounded,
            ),
          ],
          const Divider(height: 20),
          _buildInfoRow(
            context,
            'Entry Source',
            entrySource.displayName,
            Icons.input_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            context,
            'Diagnosis',
            prescription.displayDiagnosis,
            Icons.healing_rounded,
          ),
          if (prescription.doctorNotes != null && prescription.doctorNotes!.isNotEmpty) ...[
            const Divider(height: 20),
            _buildInfoRow(
              context,
              'Doctor Notes',
              prescription.doctorNotes!,
              Icons.notes_rounded,
            ),
          ],
          if (prescription.patientNotes != null && prescription.patientNotes!.isNotEmpty) ...[
            const Divider(height: 20),
            _buildInfoRow(
              context,
              'Patient Notes',
              prescription.patientNotes!,
              Icons.edit_note_rounded,
              labelSuffix: '(Personal)',
            ),
          ],
          if (prescription.notes != null && prescription.notes!.isNotEmpty) ...[
            const Divider(height: 20),
            _buildInfoRow(
              context,
              'Notes',
              prescription.notes!,
              Icons.notes_rounded,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyMedications(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Center(
        child: Text(
          'No medications listed',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationCard(BuildContext context, PrescriptionItem item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.pharmacist.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.pharmacist.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: AppColors.pharmacist,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.medicineName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.displayMedicineType != null)
                      Text(
                        item.displayMedicineType!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                  ],
                ),
              ),
              if (item.isDispensed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'DISPENSED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Medication details grid
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildMedChip('Dosage', item.dosage, Icons.analytics_outlined),
              _buildMedChip('Frequency', item.frequency, Icons.schedule_outlined),
              if (item.duration != null)
                _buildMedChip('Duration', item.duration!, Icons.timer_outlined),
              if (item.quantity != null)
                _buildMedChip('Quantity', '${item.quantity}', Icons.inventory_2_outlined),
              if (item.displayRoute != null)
                _buildMedChip('Route', item.displayRoute!, Icons.route_outlined),
              if (item.displayFoodTiming != null)
                _buildMedChip('Timing', item.displayFoodTiming!, Icons.restaurant_outlined),
            ],
          ),

          if (item.displayInstructions != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.displayInstructions!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetySection(BuildContext context) {
    final flags = prescription.safetyFlags!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSafetyRow(
            'Allergies mentioned',
            flags.allergiesMentioned,
            Icons.warning_amber_rounded,
          ),
          const Divider(height: 16),
          _buildSafetyRow(
            'Pregnancy / Breastfeeding',
            flags.pregnancyBreastfeeding,
            Icons.pregnant_woman_rounded,
          ),
          const Divider(height: 16),
          _buildSafetyRow(
            'Chronic condition linked',
            flags.chronicConditionLinked,
            Icons.favorite_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyRow(String label, bool? value, IconData icon) {
    String displayValue;
    Color valueColor;

    if (value == true) {
      displayValue = 'Yes';
      valueColor = AppColors.warning;
    } else if (value == false) {
      displayValue = 'No';
      valueColor = AppColors.success;
    } else {
      displayValue = 'Unknown';
      valueColor = AppColors.secondary;
    }

    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.warning),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: valueColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            displayValue,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadSection(BuildContext context) {
    final upload = prescription.uploadInfo!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.success.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.file_present_rounded,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  upload.fileName ?? 'Prescription File',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Uploaded • ${upload.fileType ?? 'File'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('View file feature coming soon'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.visibility_outlined),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export feature coming soon'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.download_outlined),
            label: const Text('Export'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Share feature coming soon'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
    String? labelSuffix,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                labelSuffix != null ? '$label $labelSuffix' : label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(PrescriptionStatus status) {
    switch (status) {
      case PrescriptionStatus.active:
        return AppColors.success;
      case PrescriptionStatus.expired:
        return AppColors.error;
      case PrescriptionStatus.upcoming:
        return AppColors.info;
      case PrescriptionStatus.completed:
        return AppColors.primary;
      case PrescriptionStatus.cancelled:
        return AppColors.secondary;
    }
  }

  String _formatPrescriptionType(String type) {
    switch (type) {
      case 'newPrescription':
        return 'New Prescription';
      case 'followUp':
        return 'Follow-up';
      case 'refill':
        return 'Refill';
      default:
        return type;
    }
  }
}

