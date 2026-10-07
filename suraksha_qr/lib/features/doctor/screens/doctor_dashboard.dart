// Doctor Dashboard - with verification status, scan QR, recent scans
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/providers.dart';
import '../../../widgets/buttons.dart';

final recentScansProvider = FutureProvider<List<RecentScan>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final response = await client.rpc('get_recent_scans');
  if (response == null) return [];
  return (response as List)
      .map((e) => RecentScan(
            scannedUserName: e['scanned_user_name'] as String,
            scannedAt: DateTime.parse(e['scanned_at'] as String),
          ))
      .toList();
});

class RecentScan {
  final String scannedUserName;
  final DateTime scannedAt;

  RecentScan({required this.scannedUserName, required this.scannedAt});
}

class DoctorDashboard extends ConsumerWidget {
  const DoctorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentProfileProvider);
    final recentScansAsync = ref.watch(recentScansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
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
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not loaded'));
          }

          final isVerified = profile.verificationStatus == 'verified';
          final isRejected = profile.verificationStatus == 'rejected';
          final isPending = profile.verificationStatus == 'pending';

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(recentScansProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage: profile.photoUrl != null
                                ? NetworkImage(profile.photoUrl!)
                                : null,
                            child: profile.photoUrl == null
                                ? Icon(Icons.person, size: 40, color: theme.colorScheme.primary)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dr. ${profile.fullName ?? 'Doctor'}',
                                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                _VerificationStatusBadge(status: profile.verificationStatus, reason: profile.rejectionReason),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status Message & Actions
                  if (isPending) ...[
                    Card(
                      color: Colors.orange.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(Icons.hourglass_empty, size: 48, color: Colors.orange[800]),
                            const SizedBox(height: 12),
                            Text(
                              'Your profile is under verification.',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'You can scan QR codes after Admin approval.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (isRejected) ...[
                    Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(Icons.cancel, size: 48, color: theme.colorScheme.error),
                            const SizedBox(height: 12),
                            Text(
                              'Registration Rejected',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            if (profile.rejectionReason != null && profile.rejectionReason!.isNotEmpty)
                              Text(
                                'Reason: ${profile.rejectionReason}',
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onErrorContainer),
                                textAlign: TextAlign.center,
                              ),
                            const SizedBox(height: 16),
                            PrimaryButton(
                              text: 'Re-upload Documents & Resubmit',
                              icon: Icons.upload,
                              onPressed: () async {
                                try {
                                  final client = ref.read(supabaseClientProvider);
                                  await client.rpc('resubmit_for_verification');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Resubmitted for verification. Status reset to Pending.')),
                                    );
                                    ref.invalidate(currentProfileProvider);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to resubmit: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (isVerified) ...[
                    // Scan QR Button
                    PrimaryButton(
                      text: 'Scan QR Code',
                      icon: Icons.qr_code_scanner,
                      onPressed: () => context.go('/scanner'),
                    ),
                    const SizedBox(height: 16),

                    // Recent Scans
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Recent Scans', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                TextButton.icon(
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Refresh'),
                                  onPressed: () => ref.invalidate(recentScansProvider),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            recentScansAsync.when(
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (_, _) => Text(
                                'No scans yet',
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                              data: (scans) {
                                if (scans.isEmpty) {
                                  return Text(
                                    'No scans yet',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  );
                                }
                                return Column(
                                  children: scans.map((scan) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: CircleAvatar(
                                          backgroundColor: theme.colorScheme.primaryContainer,
                                          child: Icon(Icons.person, color: theme.colorScheme.primary),
                                        ),
                                        title: Text(scan.scannedUserName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                        subtitle: Text('Scanned at ${_formatTime(scan.scannedAt)}'),
                                      )).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $e'),
              const SizedBox(height: 16),
              PrimaryButton(
                text: 'Logout',
                icon: Icons.logout,
                onPressed: () async {
                  final authRepo = ref.read(authRepositoryProvider);
                  await authRepo.signOut();
                  if (context.mounted) context.go('/welcome');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _VerificationStatusBadge extends StatelessWidget {
  final String status;
  final String? reason;

  const _VerificationStatusBadge({required this.status, this.reason});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String label;

    switch (status) {
      case 'verified':
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green[800]!;
        icon = Icons.verified;
        label = 'Verified';
        break;
      case 'rejected':
        backgroundColor = theme.colorScheme.errorContainer;
        textColor = theme.colorScheme.onErrorContainer;
        icon = Icons.cancel;
        label = 'Rejected';
        break;
      default:
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange[800]!;
        icon = Icons.hourglass_empty;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              reason!,
              style: theme.textTheme.bodySmall?.copyWith(color: textColor),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}