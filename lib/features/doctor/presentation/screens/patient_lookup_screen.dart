import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../services/supabase_service.dart';
import 'new_prescription_screen.dart';

class PatientLookupScreen extends ConsumerStatefulWidget {
  const PatientLookupScreen({super.key});

  @override
  ConsumerState<PatientLookupScreen> createState() =>
      _PatientLookupScreenState();
}

class _PatientLookupScreenState extends ConsumerState<PatientLookupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPatients(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      // Search by email or phone
      final response = await SupabaseService.instance.client
          .from('profiles')
          .select('id, email, phone, full_name')
          .eq('role', 'patient')
          .or('email.ilike.%$query%,phone.ilike.%$query%,full_name.ilike.%$query%')
          .limit(10);

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      // Handle error silently
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _selectPatient(Map<String, dynamic> patient) async {
    // Get patient record
    try {
      final patientRecord = await SupabaseService.instance.client
          .from('patients')
          .select('id')
          .eq('user_id', patient['id'])
          .maybeSingle();

      if (patientRecord == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient record not found'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NewPrescriptionScreen(
              patientId: patientRecord['id'] as String,
              patientName: patient['full_name'] as String? ?? 'Unknown',
            ),
          ),
        );
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Patient'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Search'),
            Tab(text: 'Scan QR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchTab(),
          _buildScanTab(),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, email or phone',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = []);
                      },
                      icon: const Icon(Icons.clear_rounded),
                    )
                  : null,
            ),
            onChanged: _searchPatients,
          ),
          const SizedBox(height: 16),
          // Results
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else if (_searchResults.isEmpty && _searchController.text.length >= 2)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.person_search_rounded,
                    size: 48,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No patients found',
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
            Expanded(
              child: ListView.separated(
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final patient = _searchResults[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.patient.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.patient,
                      ),
                    ),
                    title: Text(patient['full_name'] ?? 'Unknown'),
                    subtitle: Text(
                      patient['email'] ?? patient['phone'] ?? '',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _selectPatient(patient),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanTab() {
    return _PatientQrScanner(
      onPatientFound: (patientId, patientName) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NewPrescriptionScreen(
              patientId: patientId,
              patientName: patientName,
            ),
          ),
        );
      },
    );
  }
}

class _PatientQrScanner extends StatefulWidget {
  final void Function(String patientId, String patientName) onPatientFound;

  const _PatientQrScanner({required this.onPatientFound});

  @override
  State<_PatientQrScanner> createState() => _PatientQrScannerState();
}

class _PatientQrScannerState extends State<_PatientQrScanner> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final value = barcode!.rawValue!;

    if (value.contains('/emergency/')) {
      setState(() => _isProcessing = true);

      try {
        final uri = Uri.parse(value);
        final qrCodeId = uri.pathSegments.last;

        // Look up patient by QR code ID
        final patient = await SupabaseService.instance.client
            .from('patients')
            .select('id, profiles!inner(full_name)')
            .eq('qr_code_id', qrCodeId)
            .maybeSingle();

        if (patient != null && mounted) {
          final profileData = patient['profiles'] as Map<String, dynamic>;
          widget.onPatientFound(
            patient['id'] as String,
            profileData['full_name'] as String? ?? 'Unknown',
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient not found'),
              backgroundColor: AppColors.error,
            ),
          );
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
        setState(() => _isProcessing = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not a valid CareSync QR code'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.doctor,
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
                'Scan patient\'s CareSync QR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }
}

