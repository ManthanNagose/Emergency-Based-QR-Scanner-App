// Supabase client initialization
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' show log;

class SupabaseConfig {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    final url = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    final key = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    
    log('Supabase URL: $url');
    
    if (url.isEmpty || key.isEmpty) {
      throw Exception('SUPABASE_URL or SUPABASE_ANON_KEY not set in .env');
    }
    
    await Supabase.initialize(
      url: url,
      publishableKey: key,
    );
  }
}