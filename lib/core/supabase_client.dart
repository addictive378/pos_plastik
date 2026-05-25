import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://pjimlzfwfeqlgilcnqlg.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_Y9-e3MXPw3IdvTgMf2EO7A_j3LD73ys';

  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}
