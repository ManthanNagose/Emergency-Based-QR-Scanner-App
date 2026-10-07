// Splash Screen - checks session and redirects by role
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    final authState = ref.read(authStateProvider);
    final user = authState.whenData((state) => state.session?.user).value;
    
    if (user == null) {
      context.go('/welcome');
      return;
    }
    
    // Load profile to get role
    final profile = await ref.read(authRepositoryProvider).getCurrentProfile();
    
    if (!mounted) return;
    
    if (profile == null) {
      context.go('/welcome');
      return;
    }
    
    switch (profile.role) {
      case 'user':
        context.go('/user-dashboard');
        break;
      case 'doctor':
        context.go('/doctor-dashboard');
        break;
      case 'admin':
        context.go('/admin-dashboard');
        break;
      default:
        context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.health_and_safety,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Suraksha QR',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Emergency QR Scanner',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}