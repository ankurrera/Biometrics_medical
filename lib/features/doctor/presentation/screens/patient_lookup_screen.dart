import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_colors.dart';
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
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchPatients(query);
    });
  }

  Future<void> _searchPatients(String query) async {
    if (query.length < 2) {
      if (mounted) {
        setState(() => _searchResults = []);
      }
      return;
    }

    if (mounted) {
      setState(() => _isSearching = true);
    }

    try {
      // Search by email, phone, or name
      // Using 'or' logic to match any of the fields
      final response = await SupabaseService.instance.client
          .from('profiles')
          .select('id, email, phone, full_name')
          .eq('role', 'patient')
          .or('email.ilike.%$query%,phone.ilike.%$query%,full_name.ilike.%$query%')
          .limit(10);

      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      // Handle error silently or log it
      debugPrint('Error searching patients: $e');
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _selectPatient(Map<String, dynamic> patientProfile) async {
    try {
      // Get patient specific record from the 'patients' table using the profile 'id'
      final patientRecord = await SupabaseService.instance.client
          .from('patients')
          .select('id')
          .eq('user_id', patientProfile['id'])
          .maybeSingle();

      if (!mounted) return;

      if (patientRecord == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Patient record incomplete or not found.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NewPrescriptionScreen(
            patientId: patientRecord['id'] as String,
            patientName: patientProfile['full_name'] as String? ?? 'Unknown',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting patient: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for contrast
      appBar: AppBar(
        title: const Text('Find Patient'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.search_rounded),
              text: 'Search',
            ),
            Tab(
              icon: Icon(Icons.qr_code_scanner_rounded),
              text: 'Scan QR',
            ),
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Search Patient Database',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                // Professional Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Name, Email, or Phone Number',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[600]),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.cancel_rounded, size: 20),
                      color: Colors.grey[500],
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                        setState(() => _searchResults = []);
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.search,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // Results Area
          Expanded(
            child: _isSearching
                ? const Center(
              child: CircularProgressIndicator(),
            )
                : _searchResults.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final patient = _searchResults[index];
                return _buildPatientListItem(patient);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchController.text.length < 2) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.manage_search_rounded,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Start typing to search for a patient',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_rounded,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No patients found',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try checking the spelling or use a different keyword',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientListItem(Map<String, dynamic> patient) {
    final name = patient['full_name'] ?? 'Unknown';
    final email = patient['email'] ?? '';
    final phone = patient['phone'] ?? '';
    // Display whichever contact info is available, prioritizing email then phone
    final subTitle = email.isNotEmpty ? email : phone;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: () => _selectPatient(patient),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    if (subTitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            email.isNotEmpty ? Icons.email_outlined : Icons.phone_outlined,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              subTitle,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
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

  // To avoid duplicate detections
  String? _lastScannedValue;
  Timer? _scanCooldown;

  @override
  void dispose() {
    _controller.dispose();
    _scanCooldown?.cancel();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final value = barcode!.rawValue!;

    // Prevent immediate re-scan of the same code
    if (value == _lastScannedValue) return;

    _lastScannedValue = value;
    _scanCooldown?.cancel();
    _scanCooldown = Timer(const Duration(seconds: 3), () {
      _lastScannedValue = null;
    });

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

        if (!mounted) return;

        if (patient != null) {
          final profileData = patient['profiles'] as Map<String, dynamic>;
          widget.onPatientFound(
            patient['id'] as String,
            profileData['full_name'] as String? ?? 'Unknown',
          );
        } else {
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
        if (mounted) {
          setState(() => _isProcessing = false);
        }
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
        // Overlay mask
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.5),
            BlendMode.srcOut,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Scanner border
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ]
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
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Align QR code within frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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