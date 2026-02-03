# Biometric Authentication Fix - Testing Guide

## Overview
This document outlines the testing procedures to verify that the biometric authentication fix is working correctly.

## Problem Fixed
- **Before**: App always showed "Enable Fingerprint" even when already enabled
- **Before**: No distinction between SETUP (one-time) vs UNLOCK (recurring) modes
- **Before**: No backend verification - only local storage check
- **After**: Backend-verified Single Source of Truth (SSOT) for biometric state
- **After**: Clear separation between SETUP and UNLOCK modes with proper logging

## Key Changes

### 1. Single Source of Truth (SSOT) Implementation
**Location**: `lib/services/auth_controller.dart`
- Added `isBiometricAlreadyEnabled(userId)` function
- Checks ALL three conditions:
  1. ✅ Secure storage contains tokens
  2. ✅ Backend `registered_devices` has `biometric_enabled = true`
  3. ✅ Device is NOT revoked

### 2. Provider Update
**Location**: `lib/features/auth/providers/auth_provider.dart`
- `biometricEnabledProvider` now calls `isBiometricAlreadyEnabled()`
- No longer relies on local storage alone
- Checks backend for authoritative state

### 3. Biometric Unlock Enhancement
**Location**: `lib/features/auth/providers/auth_provider.dart`
- `signInWithBiometric()` now verifies SSOT before attempting unlock
- Logs `[BIO] Mode = UNLOCK` to distinguish from setup
- Returns false if backend says biometric not enabled

### 4. Session Restoration
**Location**: `lib/services/auth_controller.dart`
- `restoreSession()` uses SSOT to check if biometric enabled
- Logs mode (SETUP vs UNLOCK)
- Only prompts biometric if backend confirms it's enabled

## Testing Procedures

### Test Case 1: First Time Biometric Setup
**Expected Logs**:
```
[AUTH] Login success
[AUTH] Checking KYC status
[AUTH] KYC verified
[AUTH] Biometric required
[BIO] Starting biometric setup
[BIO] Mode = SETUP
[BIO] Triggering authenticate()
[BIO] Biometric authentication successful
[BIO] Biometric setup completed successfully
[BIO] ✅ Device is now biometric-enabled
[AUTH] Biometric enabled
```

**Steps**:
1. Fresh install or clear app data
2. Sign up and complete KYC
3. Sign in with email/password
4. Enable biometric when prompted
5. Verify backend has `biometric_enabled = true` in `registered_devices`

**Expected Result**:
- Biometric prompt appears
- After successful auth, device is registered in backend
- Tokens stored in secure storage
- App proceeds to dashboard

---

### Test Case 2: App Restart - Biometric Unlock
**Expected Logs**:
```
[AUTH] Starting session restoration
[BIO] Checking if biometric already enabled (SSOT)
[BIO] ✅ Biometric IS enabled (all checks passed)
[BIO] Mode = UNLOCK
[BIO] Biometric required for unlock
[BIO] Fingerprint success
[BIO] Session restored
[AUTH] Session restored
```

**Steps**:
1. Complete Test Case 1
2. Kill app completely
3. Restart app
4. Verify biometric prompt appears automatically
5. Authenticate with biometric

**Expected Result**:
- App immediately prompts for biometric (no login screen)
- Logs show `Mode = UNLOCK` (not SETUP)
- Session restored successfully
- Navigates to dashboard

---

### Test Case 3: Sign-In Screen - Biometric Button Display
**Expected Logs**:
```
[BIO] Provider check result: isEnabled = true
```

**Steps**:
1. Complete biometric setup (Test Case 1)
2. Sign out
3. Navigate to sign-in screen
4. Verify "Sign in with Fingerprint" button appears

**Expected Result**:
- Button only appears if backend confirms biometric is enabled
- Button does NOT say "Enable" - it says "Sign in with"
- Tapping button triggers UNLOCK mode

---

### Test Case 4: Biometric Not Enabled - No Button
**Expected Logs**:
```
[BIO] Checking if biometric already enabled (SSOT)
[BIO] Backend shows biometric_enabled=false - biometric not enabled
[BIO] Provider check result: isEnabled = false
```

**Steps**:
1. Fresh device or new user
2. Sign in with email/password (skip biometric setup)
3. Sign out
4. Return to sign-in screen

**Expected Result**:
- NO "Sign in with Fingerprint" button appears
- Only email/password fields shown
- Backend has `biometric_enabled = false` or no device record

---

### Test Case 5: Revoked Device - No Biometric Access
**Expected Logs**:
```
[BIO] Checking if biometric already enabled (SSOT)
[BIO] Device revoked - biometric not enabled
[BIO] Provider check result: isEnabled = false
```

**Steps**:
1. Enable biometric on Device A
2. From another device or web, revoke Device A in device management
3. On Device A, kill and restart app
4. Verify biometric does NOT work

**Expected Result**:
- SSOT check returns false (device is revoked)
- App redirects to login screen
- Must re-authenticate with email/password + 2FA

---

### Test Case 6: No Infinite Setup Loop
**Steps**:
1. Enable biometric (Test Case 1)
2. Restart app (Test Case 2)
3. Sign out and sign in again
4. Restart app multiple times

**Expected Result**:
- Biometric setup NEVER runs again after initial setup
- Each restart uses UNLOCK mode
- Logs consistently show `Mode = UNLOCK`
- Backend `biometric_enabled` stays true

---

### Test Case 7: Biometric Enrollment Screen
**Expected Logs**:
```
[BIO] Starting explicit biometric enrollment
[BIO] Mode = SETUP
[BIO] Prompting for biometric authentication
[BIO] Biometric authentication successful
[BIO] Device record updated
[BIO] ✅ Biometric enrollment complete - device is now biometric-enabled
```

**Steps**:
1. Navigate to biometric enrollment screen manually
2. Tap "Enable Fingerprint/Face ID"
3. Complete biometric authentication

**Expected Result**:
- Backend updated with `biometric_enabled = true`
- Tokens stored securely
- Mode logged as SETUP
- Subsequent logins use UNLOCK mode

---

## Backend Verification

### Query to Check Device Status
```sql
SELECT 
  device_id,
  device_name,
  biometric_enabled,
  trusted,
  revoked,
  last_used_at
FROM registered_devices
WHERE user_id = '<user_id>';
```

**Expected Results After Setup**:
- `biometric_enabled = true`
- `trusted = true`
- `revoked = false`
- `token_fingerprint` is set

---

## Debugging

### Check Logs for Issues

**Problem**: Biometric button still says "Enable" after restart
- Check log: Does `[BIO] ✅ Biometric IS enabled` appear?
- If NO: Backend may not have `biometric_enabled = true`
- If YES: Provider may not be refreshing correctly

**Problem**: Biometric prompt doesn't appear on restart
- Check log: Does `isBiometricAlreadyEnabled` return true?
- Verify tokens exist in secure storage
- Verify device record in backend

**Problem**: App shows SETUP mode after restart
- Check log: What does `isBiometricAlreadyEnabled` return?
- Verify backend `biometric_enabled = true`
- Check device is not revoked

---

## Success Criteria

✅ **All criteria must be met**:
1. First-time setup logs show `Mode = SETUP`
2. After restart, logs show `Mode = UNLOCK`
3. Backend `registered_devices` has `biometric_enabled = true`
4. Sign-in screen shows "Sign in with Fingerprint" (not "Enable")
5. Revoked devices cannot use biometric
6. No infinite setup loop
7. State persists across app restarts

---

## Code Review Checklist

- [ ] `isBiometricAlreadyEnabled()` checks all 3 conditions (tokens, backend, not revoked)
- [ ] `biometricEnabledProvider` calls SSOT function
- [ ] `signInWithBiometric()` verifies SSOT before unlock
- [ ] `restoreSession()` uses SSOT and logs mode
- [ ] All biometric operations log with `[BIO]` prefix
- [ ] SETUP mode only runs once per device
- [ ] UNLOCK mode never writes to backend
