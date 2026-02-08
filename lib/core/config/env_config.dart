// ankurrera/biometrics_medical/.../lib/core/config/env_config.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';


abstract class EnvConfig {
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? _throwMissingEnv('SUPABASE_URL');

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? _throwMissingEnv('SUPABASE_ANON_KEY');

  static String get emergencyBaseUrl => '$supabaseUrl/functions/v1/emergency';

  // Didit Credentials
  static const String diditAppId = 'c8d23e40-b59d-43d1-9e82-6597b158adea';
  static const String diditApiKey = 'BzuGk-BYOedLezdMHI6WAFDmrm8bSG3TYO526UuZVms';

  static String _throwMissingEnv(String key) {
    throw Exception('Missing environment variable: $key');
  }
}