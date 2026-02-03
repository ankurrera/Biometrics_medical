import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../services/supabase_service.dart';

class DispenseScreen extends ConsumerStatefulWidget {
  const DispenseScreen({super.key});

  @override
  ConsumerState<DispenseScreen> createState() => _DispenseScreenState();
}

class _DispenseScreenState extends ConsumerState<DispenseScreen> {
  Map<String, dynamic>? _patient;
  List<Map<String, dynamic>> _prescriptions = [];
  bool _isLoading = false;
  bool _isScanning = true;

  final MobileScannerController _scannerController = MobileScannerController();

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientPrescriptions(String qrCodeId) async {
    setState(() {
      _isLoading = true;
      _isScanning = false;
    });

    try {
      // Get patient by QR code
      final patient = await SupabaseService.instance.client
          .from('patients')
          .select('id, user_id, profiles!inner(full_name, email)')
          .eq('qr_code_id', qrCodeId)
          .maybeSingle();

      if (patient == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient not found'),
              backgroundColor: AppColors.error,
            ),
          );
          setState(() => _isScanning = true);
        }
        return;
      }

      // Get active prescriptions
      final prescriptions = await SupabaseService.instance.client
          .from('prescriptions')
          .select('''
            *,
            prescription_items(*),
            doctor:profiles!doctor_id(full_name)
          ''')
          .eq('patient_id', patient['id'])
          .eq('status', 'active')
          .order('created_at', ascending: false);

      setState(() {
        _patient = patient;
        _prescriptions = List<Map<String, dynamic>>.from(prescriptions);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isScanning = true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isLoading || !_isScanning) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final value = barcode!.rawValue!;

    if (value.contains('/emergency/')) {
      final uri = Uri.parse(value);
      final qrCodeId = uri.pathSegments.last;
      _loadPatientPrescriptions(qrCodeId);
    }
  }

  Future<void> _dispensePrescription(Map<String, dynamic> prescription) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Dispensing'),
        content: Text(
          'Dispense all medications for prescription:\n${prescription['diagnosis']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dispense'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // Record dispensing
      await SupabaseService.instance.recordDispensing(
        prescriptionId: prescription['id'] as String,
        patientId: _patient!['id'] as String,
      );

      // Mark prescription items as dispensed
      final items = prescription['prescription_items'] as List? ?? [];
      for (final item in items) {
        await SupabaseService.instance.client
            .from('prescription_items')
            .update({'is_dispensed': true})
            .eq('id', item['id']);
      }

      // Update prescription status
      await SupabaseService.instance.client
          .from('prescriptions')
          .update({'status': 'completed'})
          .eq('id', prescription['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription dispensed successfully'),
            backgroundColor: AppColors.success,
          ),
        );

        // Reload prescriptions
        final qrCodeId = await SupabaseService.instance.client
            .from('patients')
            .select('qr_code_id')
            .eq('id', _patient!['id'])
            .single();
        _loadPatientPrescriptions(qrCodeId['qr_code_id'] as String);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetScan() {
    setState(() {
      _patient = null;
      _prescriptions = [];
      _isScanning = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispense Medication'),
        actions: [
          if (_patient != null)
            IconButton(
              onPressed: _resetScan,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              tooltip: 'Scan New Patient',
            ),
        ],
      ),
      body: _isScanning
          ? _buildScanner()
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildPrescriptionList(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _onDetect,
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.pharmacist,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Scan patient\'s QR code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrescriptionList() {
    final dateFormat = DateFormat('MMM d, yyyy');
    final profileData = _patient!['profiles'] as Map<String, dynamic>;

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.pharmacist.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.pharmacist.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.pharmacist,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Patient',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.pharmacist,
                        ),
                      ),
                      Text(
                        profileData['full_name'] as String? ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (profileData['email'] != null)
                        Text(
                          profileData['email'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Prescriptions
          Text(
            'Active Prescriptions (${_prescriptions.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (_prescriptions.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 48,
                    color: AppColors.success.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No active prescriptions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All prescriptions have been dispensed',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_prescriptions.length, (index) {
              final rx = _prescriptions[index];
              final items = rx['prescription_items'] as List? ?? [];
              final doctor = rx['doctor'] as Map<String, dynamic>?;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rx['diagnosis'] as String? ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Dr. ${doctor?['full_name'] ?? 'Unknown'} • ${dateFormat.format(DateTime.parse(rx['created_at'] as String))}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (items.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            ...items.map((item) {
                              final isDispensed = item['is_dispensed'] as bool? ?? false;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      isDispensed
                                          ? Icons.check_circle_rounded
                                          : Icons.medication_rounded,
                                      size: 20,
                                      color: isDispensed
                                          ? AppColors.success
                                          : AppColors.pharmacist,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${item['medicine_name']} - ${item['dosage']}',
                                        style: TextStyle(
                                          decoration: isDispensed
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      item['frequency'] as String? ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                    // Dispense button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.pharmacist.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _dispensePrescription(rx),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Dispense All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.pharmacist,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

