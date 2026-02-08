# CareSync

A biometric-authenticated medical logging application built with Flutter, Riverpod, and Supabase.

## Features

- **Multi-role Support**: Patient, Doctor, Pharmacist, and First Responder roles
- **Biometric Authentication**: Face ID / Fingerprint for secure, quick sign-in
- **KYC Verification**: Secure identity verification with DiDIt integration
- **Prescription Management**: Create, view, and dispense prescriptions
- **Emergency QR Code**: Scannable QR for first responders to access critical medical data
- **Privacy Controls**: Patients can mark data as public or private

## Tech Stack

- **Flutter 3.7+** - Cross-platform framework
- **Riverpod** - State management
- **Supabase** - Backend (Auth, Database, Storage, Edge Functions)
- **local_auth** - Biometric authentication
- **go_router** - Navigation
- **DiDIt** - KYC/Identity verification

## Getting Started

### Prerequisites

- Flutter SDK 3.7+
- A Supabase project

### 1. Clone and Install Dependencies

```bash
flutter pub get
```

### 2. Set Up Supabase

1. Create a new project at [supabase.com](https://supabase.com)
2. Go to **SQL Editor** and run the contents of `supabase/schema.sql`
3. Copy your project URL and anon key

### 3. Configure Environment

Edit `lib/core/config/env_config.dart`:

```dart
abstract class EnvConfig {
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
}
```

### 4. Configure DiDIt KYC (Optional)

If you want to enable KYC verification:

1. Get your DiDIt credentials from [DiDIt Dashboard](https://didit.me)
2. Deploy the DiDIt KYC Edge Function:
   ```bash
   ./deploy-didit-kyc.sh
   ```
3. Set environment variables in Supabase Dashboard (Settings → Edge Functions):
   - `DIDIT_APP_ID`: Your DiDIt App ID
   - `DIDIT_API_KEY`: Your DiDIt API Key

For detailed instructions, see [DIDIT_KYC_BACKEND_IMPLEMENTATION.md](DIDIT_KYC_BACKEND_IMPLEMENTATION.md)

### 5. Download Fonts (Optional)

Download the Outfit font family and place in `assets/fonts/`:
- Outfit-Regular.ttf
- Outfit-Medium.ttf
- Outfit-SemiBold.ttf
- Outfit-Bold.ttf

Or remove the fonts section from `pubspec.yaml` to use system fonts.

### 6. Run the App

```bash
flutter run
```

## DiDIt KYC Integration

This project includes a secure backend implementation for DiDIt KYC verification:

- ✅ **Secure**: API keys never exposed to client
- ✅ **Backend-first**: All DiDIt calls go through Supabase Edge Functions
- ✅ **Auditable**: Complete logging and audit trail
- ✅ **Production-ready**: Error handling and retry logic

See documentation:
- [Implementation Guide](DIDIT_KYC_BACKEND_IMPLEMENTATION.md) - Complete setup and architecture
- [Code Examples](DIDIT_KYC_EXAMPLES.md) - Usage examples and patterns
- [Quick Deploy](deploy-didit-kyc.sh) - Automated deployment script

## Project Structure

```
lib/
├── main.dart                 # Entry point
├── app.dart                  # App configuration
├── core/
│   ├── config/               # Environment configuration
│   └── theme/                # App theme, colors, spacing
├── features/
│   ├── auth/                 # Authentication flow
│   ├── patient/              # Patient dashboard & features
│   ├── doctor/               # Doctor dashboard & features
│   ├── pharmacist/           # Pharmacist dashboard & features
│   ├── first_responder/      # First responder features
│   └── shared/               # Shared widgets & models
├── routing/                  # Navigation routes
└── services/                 # Supabase, biometric, storage services
```

## Database Schema

See `supabase/schema.sql` for the complete database schema including:

- `profiles` - User profiles with roles
- `user_devices` - Biometric device bindings
- `patients` - Patient-specific data
- `doctors` / `pharmacists` / `first_responders` - Role-specific data
- `prescriptions` - Medical prescriptions
- `prescription_items` - Individual medicines
- `dispensing_records` - Pharmacy transactions
- `medical_conditions` - Allergies, chronic conditions (for emergency access)

## Biometric Authentication Flow

1. **New User**: Sign up with email → Biometric enrollment prompt → Device UUID generated and stored
2. **Returning User (same device)**: Biometric verification → Instant sign-in
3. **New Device**: Email/password sign-in → Biometric enrollment for new device

Each device has its own biometric binding - biometric data never leaves the device.

## License

MIT
