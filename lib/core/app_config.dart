import 'app_secrets.dart';

class AppConfig {
  static const supabaseUrl = kSupabaseUrl;
  static const supabaseAnonKey = kSupabaseAnonKey;

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
