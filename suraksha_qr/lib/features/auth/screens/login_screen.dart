// Login Screen - common for all roles with role toggle
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/providers.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/text_fields.dart';
import '../../../core/constants/app_constants.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = AppConstants.roleUser;
  bool _isLoading = false;

  final List<String> _roles = [
    AppConstants.roleUser,
    AppConstants.roleDoctor,
    AppConstants.roleAdmin,
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final response = await authRepo.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user == null) {
        _showError('Login failed. Please try again.');
        return;
      }

      // Load profile to verify role matches
      final profile = await authRepo.getCurrentProfile();

      if (profile == null) {
        await authRepo.signOut();
        _showError('Profile not found. Please contact support.');
        return;
      }

      if (profile.role != _selectedRole) {
        await authRepo.signOut();
        _showError('This account is not registered as ${_roleLabel(_selectedRole)}');
        return;
      }

      if (!mounted) return;

      // Navigate to correct dashboard
      switch (profile.role) {
        case AppConstants.roleUser:
          context.go('/user-dashboard');
          break;
        case AppConstants.roleDoctor:
          context.go('/doctor-dashboard');
          break;
        case AppConstants.roleAdmin:
          context.go('/admin-dashboard');
          break;
      }
    } catch (e) {
      _showError(_getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getErrorMessage(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login credentials') || msg.contains('invalid email or password')) {
      return 'Invalid email or password';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please verify your email first';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'No internet connection. Please try again.';
    }
    return 'Login failed. Please try again.';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case AppConstants.roleUser:
        return 'User';
      case AppConstants.roleDoctor:
        return 'Doctor';
      case AppConstants.roleAdmin:
        return 'Admin';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Role Toggle
                Text(
                  'Login as',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: _roles
                      .map((role) => ButtonSegment<String>(
                            value: role,
                            label: Text(_roleLabel(role)),
                            icon: Icon(
                              role == AppConstants.roleUser
                                  ? Icons.person
                                  : role == AppConstants.roleDoctor
                                      ? Icons.medical_services
                                      : Icons.admin_panel_settings,
                            ),
                          ))
                      .toList(),
                  selected: {_selectedRole},
                  onSelectionChanged: (selection) {
                    setState(() => _selectedRole = selection.first);
                  },
                  multiSelectionEnabled: false,
                  style: ButtonStyle(
                    minimumSize: WidgetStateProperty.all(const Size(double.infinity, 48)),
                  ),
                ),
                const SizedBox(height: 32),

                // Email Field
                AppTextField(
                  label: 'Email',
                  hint: 'you@example.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Password Field
                AppTextField(
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: _passwordController,
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                  textInputAction: TextInputAction.done,
                  onTap: _handleLogin,
                ),
                const SizedBox(height: 24),

                // Login Button
                PrimaryButton(
                  text: 'Login',
                  icon: Icons.login,
                  isLoading: _isLoading,
                  onPressed: _handleLogin,
                ),
                const SizedBox(height: 16),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Don\'t have an account? ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: const Text('Register'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}