// AuthRepository - handles authentication
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_profile.dart';
import '../core/supabase_client.dart';

class AuthRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // Sign up with role and full_name in user metadata
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String role,
    required String fullName,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'role': role,
        'full_name': fullName,
      },
    );
  }

  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Get current user's profile from profiles table
  Future<AppProfile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return AppProfile.fromJson(response);
  }

  // Get profile by ID (for admin)
  Future<AppProfile?> getProfileById(String id) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return AppProfile.fromJson(response);
  }

  // Stream of auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // Current user
  User? get currentUser => _client.auth.currentUser;

  // Current session
  Session? get currentSession => _client.auth.currentSession;
}