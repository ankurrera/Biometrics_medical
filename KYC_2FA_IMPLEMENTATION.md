# CareSync - KYC + 2FA + Biometric Authentication Implementation

## Overview

This implementation adds a comprehensive security system to CareSync that includes:

1. **KYC (Know Your Customer) Verification** - Identity verification with document uploads
2. **Two-Factor Authentication (2FA)** - Email and SMS OTP verification
3. **Device Management** - Track and manage registered devices
4. **Biometric Authentication** - Fingerprint/Face ID for quick login on registered devices
5. **Audit Trail** - Complete logging of all security-related actions

## Architecture

### Key Principles

✅ **Biometric data never leaves the device** - Stored in Secure Enclave (iOS) or TEE (Android)
✅ **Multi-factor authentication** - Email/Password + 2FA required for new devices
✅ **Device-level convenience** - Biometrics unlock local encrypted tokens
✅ **Access from anywhere** - Email + Password + 2FA works on any device
✅ **HIPAA Compliant** - Complete audit trail and proper security measures

### Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    NEW USER REGISTRATION                 │
└─────────────────────────────────────────────────────────┘
                         ↓
    1. Sign Up (Email + Password + Phone + Full Name)
                         ↓
    2. KYC Verification (Upload ID + Selfie) [Patients Only]
                         ↓
    3. Biometric Enrollment (Optional - Sets up quick login)
                         ↓
    4. Device Registered ✓

┌─────────────────────────────────────────────────────────┐
│              LOGIN FROM REGISTERED DEVICE                │
└─────────────────────────────────────────────────────────┘
                         ↓
    1. Biometric Authentication (Fingerprint/Face ID)
                         ↓
    2. Unlock Stored Token
                         ↓
    3. Verify Token with Backend
                         ↓
    4. Access Granted ✓

┌─────────────────────────────────────────────────────────┐
│              LOGIN FROM NEW DEVICE                       │
└─────────────────────────────────────────────────────────┘
                         ↓
    1. Email + Password
                         ↓
    2. Two-Factor Authentication (Email/SMS OTP)
                         ↓
    3. Verify Code (Max 3 attempts, 10 min expiry)
                         ↓
    4. Register Device (Optional)
                         ↓
    5. Enable Biometrics (Optional)
                         ↓
    6. Access Granted ✓
```

## Database Schema

### New Tables

#### `kyc_verifications`
Stores KYC verification documents and status
- User identity documents
- Selfie verification
- Verification status (pending/verified/rejected)
- Verified by (admin user)

#### `registered_devices`
Tracks all registered devices for each user
- Device ID (unique identifier)
- Device name & platform
- Biometric enabled status
- Last used timestamp
- Revocation status

#### `medical_records`
Stores encrypted medical records
- Record type (prescription, lab_result, diagnosis)
- JSONB data (flexible structure)
- Privacy controls (public/private)
- Access tracking

#### `two_factor_codes`
Manages 2FA verification codes
- Email/SMS codes
- Expiry timestamp (10 minutes)
- Attempt counter (max 3)
- Verification status

#### `audit_log`
Complete audit trail of all actions
- User actions (login, view records, etc.)
- Device information
- IP address & user agent
- Metadata (additional context)

## Services

### 1. KYCService (`lib/services/kyc_service.dart`)

Handles KYC document uploads and verification.

```dart
// Submit KYC verification
await KYCService.instance.submitKYC(
  fullName: 'John Doe',
  dateOfBirth: DateTime(1990, 1, 1),
  idDocumentUrl: 'https://...',
  selfieUrl: 'https://...',
);

// Check KYC status
final status = await KYCService.instance.getKYCStatus();
final isVerified = await KYCService.instance.isKYCVerified();
```

**Features:**
- Document upload to Supabase Storage
- Image picking from gallery or camera
- Status tracking (pending/verified/rejected)
- Resubmission capability

### 2. TwoFactorService (`lib/services/two_factor_service.dart`)

Manages two-factor authentication codes.

```dart
// Send email code
await TwoFactorService.instance.sendEmailCode(
  userId: userId,
  email: 'user@example.com',
);

// Send SMS code
await TwoFactorService.instance.sendSMSCode(
  userId: userId,
  phoneNumber: '+1234567890',
);

// Verify code
final verified = await TwoFactorService.instance.verifyCode(
  userId: userId,
  code: '123456',
  codeType: TwoFactorCodeType.email,
);
```

**Features:**
- 6-digit random code generation
- Email and SMS delivery (placeholders for actual services)
- Code expiry (10 minutes)
- Attempt limiting (max 3 attempts)
- Resend functionality (60-second cooldown)

### 3. DeviceService (`lib/services/device_service.dart`)

Manages registered devices for users.

```dart
// Register current device
await DeviceService.instance.registerDevice(
  biometricEnabled: true,
);

// Get all user devices
final devices = await DeviceService.instance.getUserDevices();

// Revoke a device
await DeviceService.instance.revokeDevice(deviceId);

// Check if current device is registered
final isRegistered = await DeviceService.instance.isDeviceRegistered();
```

**Features:**
- Unique device ID generation
- Device information tracking (name, model, OS)
- Biometric status management
- Device revocation
- Last used tracking

### 4. AuditService (`lib/services/audit_service.dart`)

Logs all security-related actions.

```dart
// Log login
await AuditService.instance.logLogin(
  deviceId: deviceId,
  biometric: true,
);

// Log medical record access
await AuditService.instance.logMedicalRecordAccess(
  recordId: recordId,
  deviceId: deviceId,
);

// Get user's audit logs
final logs = await AuditService.instance.getUserAuditLogs(limit: 50);
```

**Features:**
- Comprehensive action logging
- Device tracking
- IP address & user agent capture
- Metadata support for additional context
- Audit log retrieval

### 5. Enhanced SecureStorageService

Extended to support session management.

```dart
// Store auth tokens
await SecureStorageService.instance.setAccessToken(token);
await SecureStorageService.instance.setRefreshToken(token);

// Session timeout management
await SecureStorageService.instance.updateLastActivity();
final hasTimedOut = await SecureStorageService.instance.hasSessionTimedOut();
```

**Features:**
- Encrypted token storage
- Session timeout tracking (15 minutes)
- Last activity timestamp
- Secure cleanup on logout

## UI Screens

### 1. KYC Verification Screen (`kyc_verification_screen.dart`)

Allows users to submit KYC documents.

**Features:**
- Full name and date of birth input
- ID document upload (gallery or camera)
- Selfie verification
- Status display (pending/verified)
- Resubmission capability

### 2. Two-Factor Verification Screen (`two_factor_verification_screen.dart`)

Handles 2FA code verification.

**Features:**
- 6-digit code input
- Email/SMS code delivery
- Auto-verification on complete input
- Resend functionality (60-second cooldown)
- Attempt counter display
- Security tips

### 3. Device Management Screen (`device_management_screen.dart`)

Displays and manages registered devices.

**Features:**
- List of all registered devices
- Device information (name, platform, last used)
- Biometric status indicator
- Current device highlight
- Device revocation
- Device deletion

## Authentication Flow Updates

### Enhanced AuthProvider

The `AuthProvider` has been updated to support:

1. **Sign In with 2FA Check**
   - Returns `SignInResult` with 2FA requirement flag
   - Checks if device is registered
   - Triggers 2FA flow for new devices

2. **Biometric Quick Login**
   - Checks session timeout (15 minutes)
   - Verifies biometric authentication
   - Restores session from stored tokens
   - Updates device last used timestamp

3. **Complete 2FA Flow**
   - Registers device after 2FA verification
   - Optionally enables biometric authentication
   - Logs device registration to audit trail

4. **Enhanced Sign Out**
   - Logs logout action to audit trail
   - Clears session tokens
   - Maintains device ID for future logins

## Security Features

### 1. Device Management

Users can:
- View all registered devices
- See last used timestamps
- Identify current device
- Revoke device access
- Delete devices permanently

### 2. Audit Trail

All actions are logged:
- Login attempts (with/without biometric)
- Logout events
- KYC document uploads
- Medical record access
- Device registration/revocation
- 2FA code requests

### 3. Session Timeout

- 15-minute inactivity timeout
- Automatic re-authentication required
- Biometric re-verification on timeout

### 4. Code Security

- 2FA codes expire in 10 minutes
- Maximum 3 verification attempts
- Automatic cleanup of expired codes
- 60-second cooldown on resend

## Implementation Notes

### Email/SMS Integration

The `TwoFactorService` includes placeholders for email and SMS delivery:

```dart
// TODO: Implement actual email sending
// Options:
// 1. Supabase Edge Function with Resend/SendGrid
// 2. Firebase Cloud Functions
// 3. AWS SES
```

For production, integrate with:
- **Email**: SendGrid, AWS SES, Resend, or Supabase Edge Functions
- **SMS**: Twilio, AWS SNS, Vonage (Nexmo)

### Storage Bucket Configuration

Run the `kyc_schema.sql` to create:
- `kyc-documents` bucket (private)
- Storage policies for user access
- RLS policies for all new tables

```sql
-- Create bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('kyc-documents', 'kyc-documents', false);
```

### Device Info Enhancement

For production, use `device_info_plus` package to get actual device details:

```yaml
dependencies:
  device_info_plus: ^9.0.0
```

## Testing Checklist

- [ ] Sign up with KYC (patient role)
- [ ] Upload ID document and selfie
- [ ] Sign in from new device triggers 2FA
- [ ] Verify email/SMS code
- [ ] Register device and enable biometric
- [ ] Sign out and sign in with biometric
- [ ] Access from another device requires 2FA
- [ ] View and revoke devices
- [ ] Check audit trail
- [ ] Session timeout after 15 minutes

## Production Checklist

- [ ] Integrate actual email service (SendGrid/AWS SES)
- [ ] Integrate actual SMS service (Twilio/AWS SNS)
- [ ] Add KYC verification admin panel
- [ ] Implement device_info_plus for real device details
- [ ] Set up proper storage bucket policies
- [ ] Configure rate limiting for 2FA requests
- [ ] Add phone number verification during sign-up
- [ ] Implement TOTP authenticator app support
- [ ] Add backup codes for 2FA
- [ ] Set up monitoring and alerting
- [ ] Perform security audit
- [ ] Load test the authentication flow

## Security Best Practices

1. **Never store biometric data** - It stays on the device
2. **Use encrypted storage** - All tokens are encrypted
3. **Log all actions** - Complete audit trail
4. **Limit attempts** - Prevent brute force attacks
5. **Short expiry times** - 10 minutes for 2FA codes
6. **Device management** - Users can revoke access
7. **Session timeout** - 15 minutes of inactivity
8. **Multi-factor auth** - Required for new devices

## API Endpoints Needed (Optional)

For enhanced functionality, consider adding these Supabase Edge Functions:

1. **send-2fa-email** - Send verification email
2. **send-2fa-sms** - Send verification SMS
3. **verify-kyc-document** - Auto-verify documents with AI
4. **detect-suspicious-login** - Detect unusual login patterns
5. **cleanup-expired-data** - Clean up old 2FA codes and logs

## Troubleshooting

### 2FA Code Not Received

Check:
- Email/SMS service integration is configured
- User's email/phone is correct
- Spam folder (for email)
- Service rate limits

### Biometric Not Working

Check:
- Device has biometric hardware
- User has enrolled biometrics in device settings
- App has permission to use biometrics
- Device is registered in backend

### Session Timeout Issues

Check:
- Last activity timestamp is being updated
- Token refresh is working correctly
- 15-minute threshold is appropriate for use case

## License

MIT - See LICENSE file for details
