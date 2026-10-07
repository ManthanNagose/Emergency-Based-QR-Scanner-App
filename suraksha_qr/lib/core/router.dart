// GoRouter configuration with auth redirect and role-based access
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/welcome_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_entry_screen.dart';
import '../features/auth/screens/admin_register_screen.dart';
import '../features/user/screens/user_registration_screen.dart';
import '../features/user/screens/user_dashboard.dart';
import '../features/user/screens/edit_profile_screen.dart';
import '../features/doctor/screens/doctor_registration_screen.dart';
import '../features/doctor/screens/doctor_dashboard.dart';
import '../features/admin/screens/admin_dashboard.dart';
import '../features/admin/screens/verification_detail_screen.dart';
import '../features/scanner/screens/scanner_screen.dart';
import '../features/scanner/screens/scan_result_limited_screen.dart';
import '../features/scanner/screens/scan_result_full_screen.dart';
import '../core/constants/app_constants.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    redirect: _redirect,
    refreshListenable: _AuthChangeNotifier(),
    routes: [
      // Public routes (no auth required)
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterEntryScreen(),
      ),
      GoRoute(
        path: '/register/user',
        builder: (context, state) => const UserRegistrationScreen(),
      ),
      GoRoute(
        path: '/register/doctor',
        builder: (context, state) => const DoctorRegistrationScreen(),
      ),
      GoRoute(
        path: '/register/admin',
        builder: (context, state) => const AdminRegisterScreen(),
      ),
      GoRoute(
        path: '/scanner',
        builder: (context, state) => const ScannerScreen(),
      ),

      // Protected routes (require auth)
      GoRoute(
        path: '/user-dashboard',
        builder: (context, state) => const UserDashboard(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/doctor-dashboard',
        builder: (context, state) => const DoctorDashboard(),
      ),
      GoRoute(
        path: '/admin-dashboard',
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: '/admin/verify/user/:targetId',
        builder: (context, state) => VerificationDetailScreen(
          targetId: state.pathParameters['targetId']!,
          targetType: 'user',
        ),
      ),
      GoRoute(
        path: '/admin/verify/doctor/:targetId',
        builder: (context, state) => VerificationDetailScreen(
          targetId: state.pathParameters['targetId']!,
          targetType: 'doctor',
        ),
      ),
      GoRoute(
        path: '/scan-result/limited/:token',
        builder: (context, state) => ScanResultLimitedScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/scan-result/full/:token',
        builder: (context, state) => ScanResultFullScreen(token: state.pathParameters['token']!),
      ),
    ],
  );

  // Redirect logic - async to support role-based access control
  static Future<String?> _redirect(BuildContext context, GoRouterState state) async {
    final location = state.matchedLocation;
    final user = Supabase.instance.client.auth.currentUser;
    final isLoggedIn = user != null;

    // Public routes that don't need auth
    final publicRoutes = [
      '/splash',
      '/welcome',
      '/login',
      '/register',
      '/register/user',
      '/register/doctor',
      '/register/admin',
      '/scanner',
    ];

    // If not logged in and trying to access protected route -> go to welcome
    if (!isLoggedIn && !publicRoutes.contains(location)) {
      return '/welcome';
    }

    // If logged in and trying to access auth pages -> redirect to correct dashboard
    if (isLoggedIn) {
      final authPages = ['/welcome', '/login', '/register', '/register/user', '/register/doctor', '/register/admin'];
      if (authPages.contains(location)) {
        // Fetch profile to get role and redirect to correct dashboard
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        if (profileResponse != null) {
          final role = profileResponse['role'] as String;
          switch (role) {
            case AppConstants.roleUser:
              return '/user-dashboard';
            case AppConstants.roleDoctor:
              return '/doctor-dashboard';
            case AppConstants.roleAdmin:
              return '/admin-dashboard';
          }
        } else {
          return '/welcome';
        }
        return '/welcome';
      }

      // Role-based access control for dashboards
      // Check if user is trying to access a dashboard they don't have permission for
      if (location == '/user-dashboard' || location == '/doctor-dashboard' || location == '/admin-dashboard') {
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        if (profileResponse != null) {
          final role = profileResponse['role'] as String;
          // Check if the user has access to this dashboard
          bool hasAccess = false;
          if (location == '/user-dashboard' && role == AppConstants.roleUser) hasAccess = true;
          if (location == '/doctor-dashboard' && role == AppConstants.roleDoctor) hasAccess = true;
          if (location == '/admin-dashboard' && role == AppConstants.roleAdmin) hasAccess = true;

          if (!hasAccess) {
            // Redirect to their correct dashboard
            switch (role) {
              case AppConstants.roleUser:
                return '/user-dashboard';
              case AppConstants.roleDoctor:
                return '/doctor-dashboard';
              case AppConstants.roleAdmin:
                return '/admin-dashboard';
            }
          }
        }
      }
    }

    return null;
  }
}

// Notifier to refresh router on auth changes
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      notifyListeners();
    });
  }
}