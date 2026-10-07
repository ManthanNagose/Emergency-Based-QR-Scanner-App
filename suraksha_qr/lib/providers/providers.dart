// Riverpod providers
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';
import '../repositories/storage_repository.dart';
import '../models/app_profile.dart';
import '../models/medical_info.dart';
import '../models/emergency_contact.dart';
import '../models/doctor_details.dart';
import '../core/supabase_client.dart';

// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseConfig.client;
});

// Repository providers
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return StorageRepository();
});

// Auth state stream provider
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.authStateChanges;
});

// Current user provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenData((state) => state.session?.user).value;
});

// Current profile provider - fetches profile when user logs in
final currentProfileProvider = FutureProvider<AppProfile?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.whenData((state) => state.session?.user).value;
  
  if (user == null) return null;
  
  final authRepo = ref.watch(authRepositoryProvider);
  return await authRepo.getCurrentProfile();
});

// Current medical info provider
final currentMedicalInfoProvider = FutureProvider<MedicalInfo?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return null;
  
  final client = SupabaseConfig.client;
  final response = await client
      .from('medical_info')
      .select()
      .eq('user_id', profile.id)
      .maybeSingle();
  
  if (response == null) return null;
  return MedicalInfo.fromJson(response);
});

// Current emergency contacts provider
final currentEmergencyContactsProvider = FutureProvider<List<EmergencyContact>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  
  final client = SupabaseConfig.client;
  final response = await client
      .from('emergency_contacts')
      .select()
      .eq('user_id', profile.id);
  
  return (response as List).map((e) => EmergencyContact.fromJson(e)).toList();
});

// Profile by ID provider (for admin)
final profileByIdProvider = FutureProvider.family<AppProfile?, String>((ref, id) async {
  final authRepo = ref.watch(authRepositoryProvider);
  return await authRepo.getProfileById(id);
});

// Admin dashboard counts provider
final adminCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final client = SupabaseConfig.client;
  
  final pendingUsers = await client
      .from('profiles')
      .select('id')
      .eq('role', 'user')
      .eq('verification_status', 'pending');
  
  final pendingDoctors = await client
      .from('profiles')
      .select('id')
      .eq('role', 'doctor')
      .eq('verification_status', 'pending');
  
  final verified = await client
      .from('profiles')
      .select('id')
      .eq('verification_status', 'verified');
  
  final rejected = await client
      .from('profiles')
      .select('id')
      .eq('verification_status', 'rejected');
  
  return {
    'pendingUsers': pendingUsers.length,
    'pendingDoctors': pendingDoctors.length,
    'verified': verified.length,
    'rejected': rejected.length,
  };
});

// Pending users provider
final pendingUsersProvider = FutureProvider<List<AppProfile>>((ref) async {
  final client = SupabaseConfig.client;
  final response = await client
      .from('profiles')
      .select()
      .eq('role', 'user')
      .eq('verification_status', 'pending')
      .order('created_at', ascending: true);
  
  return (response as List).map((e) => AppProfile.fromJson(e)).toList();
});

// Pending doctors provider
final pendingDoctorsProvider = FutureProvider<List<AppProfile>>((ref) async {
  final client = SupabaseConfig.client;
  final response = await client
      .from('profiles')
      .select()
      .eq('role', 'doctor')
      .eq('verification_status', 'pending')
      .order('created_at', ascending: true);
  
  return (response as List).map((e) => AppProfile.fromJson(e)).toList();
});

// Doctor details by ID provider (for admin)
final doctorDetailsByIdProvider = FutureProvider.family<DoctorDetails?, String>((ref, doctorId) async {
  final client = SupabaseConfig.client;
  final response = await client
      .from('doctor_details')
      .select()
      .eq('doctor_id', doctorId)
      .maybeSingle();
  
  if (response == null) return null;
  return DoctorDetails.fromJson(response);
});

// Medical info by user ID provider (for admin)
final medicalInfoByUserIdProvider = FutureProvider.family<MedicalInfo?, String>((ref, userId) async {
  final client = SupabaseConfig.client;
  final response = await client
      .from('medical_info')
      .select()
      .eq('user_id', userId)
      .maybeSingle();
  
  if (response == null) return null;
  return MedicalInfo.fromJson(response);
});