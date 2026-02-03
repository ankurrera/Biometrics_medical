import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/kyc_service.dart';
import '../../../../services/biometric_service.dart';
import '../../../../services/secure_storage_service.dart';
import '../../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isUploading = false;
  String? _avatarUrl;
  File? _selectedImage;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadBiometricSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ref.read(currentProfileProvider.future);
    if (profile != null) {
      _nameController.text = profile.fullName;
      _phoneController.text = profile.phone ?? '';
      setState(() {
        _avatarUrl = profile.avatarUrl;
      });
    }
  }

  Future<void> _loadBiometricSettings() async {
    final enabled = await SecureStorageService.instance.isBiometricEnabled();
    final available = await BiometricService.instance.isBiometricAvailable();
    
    setState(() {
      _biometricEnabled = enabled;
      _biometricAvailable = available;
    });
  }

  Future<void> _toggleBiometric(bool value) async {
    if (!_biometricAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric authentication is not available on this device'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (value) {
      // Enable biometric - require authentication first
      try {
        final authenticated = await BiometricService.instance.authenticate(
          reason: 'Authenticate to enable biometric login',
          biometricOnly: false,
        );

        if (authenticated) {
          await SecureStorageService.instance.setBiometricEnabled(true);
          setState(() => _biometricEnabled = true);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometric authentication enabled'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      } on BiometricException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } else {
      // Disable biometric
      await SecureStorageService.instance.setBiometricEnabled(false);
      setState(() => _biometricEnabled = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication disabled'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      await _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

    setState(() => _isUploading = true);

    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('Not logged in');

      final fileName = 'avatar_$userId.jpg';
      final bytes = await _selectedImage!.readAsBytes();

      // Upload to Supabase Storage
      try {
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );
      } catch (storageError) {
        // If bucket doesn't exist or permission denied, show helpful message
        throw Exception(
          'Unable to upload avatar. Please ensure the "avatars" storage bucket exists '
          'and has proper permissions in Supabase.'
        );
      }

      // Get public URL
      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);

      // Update profile with avatar URL using direct update
      await Supabase.instance.client.from('profiles').update({
        'avatar_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      setState(() {
        _avatarUrl = publicUrl;
      });

      // Refresh profile
      ref.invalidate(currentProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Use Supabase client directly for better error handling
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) {
        throw Exception('Not logged in');
      }

      await Supabase.instance.client.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      // Refresh profile
      ref.invalidate(currentProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await ref.read(authNotifierProvider.notifier).signOut();
    // Invalidate all providers
    ref.invalidate(currentProfileProvider);
    
    if (mounted) {
      context.go(RouteNames.roleSelection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 3,
                      ),
                      image: _selectedImage != null
                          ? DecorationImage(
                              image: FileImage(_selectedImage!),
                              fit: BoxFit.cover,
                            )
                          : _avatarUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(_avatarUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                    ),
                    child: (_selectedImage == null && _avatarUrl == null)
                        ? const Icon(
                            Icons.person_rounded,
                            size: 60,
                            color: AppColors.primary,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploading ? null : _pickImage,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: _isUploading
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Role badge
              profile.when(
                data: (p) => p != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleColor(p.role).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _formatRole(p.role),
                          style: TextStyle(
                            color: _getRoleColor(p.role),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 32),

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone field
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // Email (read-only)
              profile.when(
                data: (p) => p != null
                    ? TextFormField(
                        initialValue: p.email,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        readOnly: true,
                        enabled: false,
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 32),

              // Account actions
              Card(
                child: Column(
                  children: [
                    // KYC Verification
                    Consumer(
                      builder: (context, ref, child) {
                        final kycStatus = ref.watch(kycStatusProvider);
                        return kycStatus.when(
                          data: (kyc) {
                            final isVerified = kyc?.status == KYCStatus.verified;
                            final isPending = kyc?.status == KYCStatus.pending;
                            final isRejected = kyc?.status == KYCStatus.rejected;
                            
                            return ListTile(
                              leading: Icon(
                                isVerified 
                                    ? Icons.verified_rounded 
                                    : isPending
                                        ? Icons.pending_rounded
                                        : Icons.badge_rounded,
                                color: isVerified 
                                    ? AppColors.success 
                                    : isPending
                                        ? AppColors.warning
                                        : AppColors.primary,
                              ),
                              title: const Text('Verify Identity (KYC)'),
                              subtitle: kyc != null
                                  ? Text(
                                      isVerified 
                                          ? 'Verified ✓' 
                                          : isPending
                                              ? 'Pending verification'
                                              : isRejected
                                                  ? 'Rejected - Please resubmit'
                                                  : 'Not verified',
                                      style: TextStyle(
                                        color: isVerified 
                                            ? AppColors.success 
                                            : isPending
                                                ? AppColors.warning
                                                : AppColors.error,
                                      ),
                                    )
                                  : const Text('Required for full access'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                context.push(RouteNames.kycVerification);
                              },
                            );
                          },
                          loading: () => const ListTile(
                            leading: CircularProgressIndicator(),
                            title: Text('Verify Identity (KYC)'),
                          ),
                          error: (_, __) => ListTile(
                            leading: const Icon(Icons.badge_rounded),
                            title: const Text('Verify Identity (KYC)'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              context.push(RouteNames.kycVerification);
                            },
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.devices_rounded),
                      title: const Text('Manage Devices'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        context.push(RouteNames.deviceManagement);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.fingerprint_rounded,
                        color: _biometricAvailable ? AppColors.primary : Colors.grey,
                      ),
                      title: const Text('Biometric Authentication'),
                      subtitle: Text(
                        _biometricAvailable
                            ? _biometricEnabled
                                ? 'Enabled'
                                : 'Disabled'
                            : 'Not available on this device',
                        style: TextStyle(
                          color: _biometricAvailable
                              ? _biometricEnabled
                                  ? AppColors.success
                                  : Colors.grey
                              : AppColors.error,
                        ),
                      ),
                      trailing: Switch(
                        value: _biometricEnabled,
                        onChanged: _biometricAvailable ? _toggleBiometric : null,
                        activeColor: AppColors.primary,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.security_rounded),
                      title: const Text('Change Password'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        // TODO: Implement password change
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password change coming soon'),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.error,
                      ),
                      title: const Text(
                        'Sign Out',
                        style: TextStyle(color: AppColors.error),
                      ),
                      onTap: _signOut,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'doctor':
        return AppColors.doctor;
      case 'pharmacist':
        return AppColors.pharmacist;
      case 'first_responder':
        return AppColors.firstResponder;
      case 'patient':
      default:
        return AppColors.patient;
    }
  }

  String _formatRole(String role) {
    switch (role) {
      case 'doctor':
        return 'Doctor';
      case 'pharmacist':
        return 'Pharmacist';
      case 'first_responder':
        return 'First Responder';
      case 'patient':
      default:
        return 'Patient';
    }
  }
}

