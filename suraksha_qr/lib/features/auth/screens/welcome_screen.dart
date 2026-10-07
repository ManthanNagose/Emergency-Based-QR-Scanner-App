// Welcome Screen - Login, Register, Scan QR as Guest
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/buttons.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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
              PrimaryButton(
                text: 'Login',
                icon: Icons.login,
                onPressed: () => context.go('/login'),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                text: 'Register',
                icon: Icons.person_add,
                onPressed: () => context.go('/register'),
              ),
              const SizedBox(height: 16),
              SecondaryButton(
                text: 'Scan QR as Guest',
                icon: Icons.qr_code_scanner,
                onPressed: () => context.go('/scanner'),
              ),
              const SizedBox(height: 32),
              Text(
                'No account needed to scan a QR code',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}