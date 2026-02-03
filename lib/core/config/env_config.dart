import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration for the app.
/// 
/// Loads values from .env file. Make sure to call `dotenv.load()` 
/// in main.dart before using these values.
abstract class EnvConfig {
  /// Supabase project URL
  static String get supabaseUrl => 
      dotenv.env['SUPABASE_URL'] ?? _throwMissingEnv('SUPABASE_URL');

  /// Supabase anonymous key (safe to expose in client)
  static String get supabaseAnonKey => 
      dotenv.env['SUPABASE_ANON_KEY'] ?? _throwMissingEnv('SUPABASE_ANON_KEY');

  /// Base URL for emergency QR codes
  static String get emergencyBaseUrl => '$supabaseUrl/functions/v1/emergency';
  
  /// Helper to throw meaningful error for missing env vars
  static String _throwMissingEnv(String key) {
    throw Exception(
      'Missing environment variable: $key\n'
      'Please ensure you have a .env file with all required variables.\n'
      'See .env.example for reference.',
    );
  }
}
