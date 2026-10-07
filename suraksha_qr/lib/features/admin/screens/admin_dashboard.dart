// Admin Dashboard with counts and tabs for pending users/doctors
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/providers.dart';
import '../../../models/app_profile.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final countsAsync = ref.watch(adminCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authRepo = ref.read(authRepositoryProvider);
              await authRepo.signOut();
              if (context.mounted) context.go('/welcome');
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: countsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading counts: $e')),
        data: (counts) => DefaultTabController(
          length: 2,
          child: Column(
            children: [
              // Counts Summary
              Container(
                padding: const EdgeInsets.all(16),
                color: theme.colorScheme.surfaceContainerHighest,
                child: Column(
                  children: [
                    Text('Verification Queue', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CountCard(
                          label: 'Pending Users',
                          count: counts['pendingUsers'] ?? 0,
                          color: Colors.orange,
                          icon: Icons.person,
                        ),
                        _CountCard(
                          label: 'Pending Doctors',
                          count: counts['pendingDoctors'] ?? 0,
                          color: Colors.blue,
                          icon: Icons.medical_services,
                        ),
                        _CountCard(
                          label: 'Verified',
                          count: counts['verified'] ?? 0,
                          color: Colors.green,
                          icon: Icons.verified,
                        ),
                        _CountCard(
                          label: 'Rejected',
                          count: counts['rejected'] ?? 0,
                          color: Colors.red,
                          icon: Icons.cancel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Tabs
              TabBar(
                tabs: [
                  Tab(text: 'Users (${counts['pendingUsers'] ?? 0})'),
                  Tab(text: 'Doctors (${counts['pendingDoctors'] ?? 0})'),
                ],
              ),
              // Tab Views
              Expanded(
                child: TabBarView(
                  children: [
                    _PendingUsersTab(),
                    _PendingDoctorsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _CountCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text('$count', style: theme.textTheme.headlineMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _PendingUsersTab extends ConsumerWidget {
  const _PendingUsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final usersAsync = ref.watch(pendingUsersProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No pending users', style: theme.textTheme.headlineSmall),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _PendingUserCard(user: user);
          },
        );
      },
    );
  }
}

class _PendingDoctorsTab extends ConsumerWidget {
  const _PendingDoctorsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final doctorsAsync = ref.watch(pendingDoctorsProvider);

    return doctorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (doctors) {
        if (doctors.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.medical_services_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No pending doctors', style: theme.textTheme.headlineSmall),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: doctors.length,
          itemBuilder: (context, index) {
            final doctor = doctors[index];
            return _PendingDoctorCard(doctor: doctor);
          },
        );
      },
    );
  }
}

class _PendingUserCard extends StatelessWidget {
  final AppProfile user;

  const _PendingUserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
          child: user.photoUrl == null ? Icon(Icons.person, color: theme.colorScheme.primary) : null,
        ),
        title: Text(user.fullName ?? 'Unknown', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text('Submitted: ${_formatDate(user.createdAt)}'),
        trailing: IconButton(
          icon: Icon(Icons.visibility, color: theme.colorScheme.primary),
          onPressed: () => context.push('/admin/verify/user/${user.id}'),
          tooltip: 'View & Verify',
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _PendingDoctorCard extends StatelessWidget {
  final AppProfile doctor;

  const _PendingDoctorCard({required this.doctor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          backgroundImage: doctor.photoUrl != null ? NetworkImage(doctor.photoUrl!) : null,
          child: doctor.photoUrl == null ? Icon(Icons.person, color: theme.colorScheme.primary) : null,
        ),
        title: Text('Dr. ${doctor.fullName ?? 'Unknown'}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text('Submitted: ${_formatDate(doctor.createdAt)}'),
        trailing: IconButton(
          icon: Icon(Icons.visibility, color: theme.colorScheme.primary),
          onPressed: () => context.push('/admin/verify/doctor/${doctor.id}'),
          tooltip: 'View & Verify',
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}