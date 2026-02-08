// ankurrera/biometrics_medical/.../lib/core/config/env_config.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';


abstract class EnvConfig {
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? _throwMissingEnv('SUPABASE_URL');

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? _throwMissingEnv('SUPABASE_ANON_KEY');

  static String get emergencyBaseUrl => '$supabaseUrl/functions/v1/emergency';

  // DiDIt Credentials are now managed on the backend (Supabase Edge Functions)
  // and should NOT be exposed to the client app for security reasons.
  // If you need to configure DiDIt credentials, set them as environment variables
  // in your Supabase project: DIDIT_APP_ID and DIDIT_API_KEY

  /// DiDIt KYC callback URL - configurable per environment
  /// This is where DiDIt will redirect after verification completes
  static String get diditCallbackUrl =>
      dotenv.env['DIDIT_CALLBACK_URL'] ?? 'https://caresync.app/verify-callback';

  static String _throwMissingEnv(String key) {
    throw Exception('Missing environment variable: $key');
  }
}