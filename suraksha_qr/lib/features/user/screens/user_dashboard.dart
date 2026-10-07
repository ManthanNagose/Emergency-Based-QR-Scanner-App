// User Dashboard with profile, medical info, emergency contacts, QR code
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/providers.dart';
import '../../../widgets/buttons.dart';
import '../../../models/app_profile.dart';
import '../../../models/medical_info.dart';
import '../../../models/emergency_contact.dart';

class UserDashboard extends ConsumerStatefulWidget {
  const UserDashboard({super.key});

  @override
  ConsumerState<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends ConsumerState<UserDashboard> {
  final GlobalKey _qrKey = GlobalKey();
  bool _isRefreshing = false;

  Future<void> _handleLogout() async {
    final authRepo = ref.read(authRepositoryProvider);
    await authRepo.signOut();
    if (mounted) {
      context.go('/welcome');
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    ref.invalidate(currentProfileProvider);
    ref.invalidate(currentMedicalInfoProvider);
    ref.invalidate(currentEmergencyContactsProvider);
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _downloadQrCode() async {
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('QR widget not rendered');
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to capture QR code');

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/suraksha_qr_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR saved to ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save QR: $e')),
        );
      }
    }
  }

  Future<void> _shareQrCode() async {
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('QR widget not rendered');
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to capture QR code');

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/suraksha_qr_share.png');
      await file.writeAsBytes(pngBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'My Suraksha QR Emergency Code',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share QR: $e')),
        );
      }
    }
  }

  void _navigateToEditProfile() {
    context.push('/edit-profile');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentProfileProvider);
    final medicalAsync = ref.watch(currentMedicalInfoProvider);
    final contactsAsync = ref.watch(currentEmergencyContactsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header Card
              _buildProfileHeader(profileAsync, medicalAsync, contactsAsync, theme),
              const SizedBox(height: 16),

              // Blood Group Card
              _buildBloodGroupCard(profileAsync, medicalAsync, theme),
              const SizedBox(height: 16),

              // Medical Summary Card
              _buildMedicalSummaryCard(medicalAsync, theme),
              const SizedBox(height: 16),

              // Emergency Contacts Card
              _buildEmergencyContactsCard(contactsAsync, theme),
              const SizedBox(height: 16),

              // QR Code Card
              _buildQrCodeCard(profileAsync, theme),
              const SizedBox(height: 16),

              // Action Buttons
              _buildActionButtons(theme),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    AsyncValue<AppProfile?> profileAsync,
    AsyncValue<MedicalInfo?> medicalAsync,
    AsyncValue<List<EmergencyContact>> contactsAsync,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                // Profile Photo
                CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: profileAsync.when(
                    data: (p) => p?.photoUrl != null
                        ? NetworkImage(p!.photoUrl!)
                        : null,
                    loading: () => null,
                    error: (_, _) => null,
                  ),
                  child: profileAsync.when(
                    data: (p) => p?.photoUrl == null
                        ? Icon(Icons.person, size: 40, color: theme.colorScheme.primary)
                        : null,
                    loading: () => const CircularProgressIndicator(),
                    error: (_, _) => Icon(Icons.person, size: 40, color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      profileAsync.when(
                        data: (p) => Text(
                          p?.fullName ?? 'User',
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        loading: () => const Text('Loading...'),
                        error: (_, _) => const Text('Error loading profile'),
                      ),
                      const SizedBox(height: 4),
                      profileAsync.when(
                        data: (p) => Row(
                          children: [
                            if (p?.age != null) ...[
                              Icon(Icons.cake_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text('${p!.age} years', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              const SizedBox(width: 16),
                            ],
                            if (p?.gender != null) ...[
                              Icon(Icons.transgender, size: 16, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(p!.gender!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ],
                        ),
                        loading: () => const SizedBox(),
                        error: (_, _) => const SizedBox(),
                      ),
                    ],
                  ),
                ),
                // Verification Status Badge
                profileAsync.when(
                  data: (p) => _VerificationStatusBadge(status: p?.verificationStatus ?? 'pending', reason: p?.rejectionReason),
                  loading: () => const SizedBox(),
                  error: (_, _) => const SizedBox(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodGroupCard(
    AsyncValue<AppProfile?> profileAsync,
    AsyncValue<MedicalInfo?> medicalAsync,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Blood Group', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            medicalAsync.when(
              data: (medical) => Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      medical?.bloodGroup ?? 'Not set',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (medical?.bloodGroupVerified == true)
                    Row(
                      children: [
                        Icon(Icons.verified, color: theme.colorScheme.primary, size: 24),
                        const SizedBox(width: 8),
                        Text('Verified', style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        )),
                      ],
                    )
                  else
                    Text('Not Verified', style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Text('Error loading blood group', style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalSummaryCard(
    AsyncValue<MedicalInfo?> medicalAsync,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Medical Summary', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            medicalAsync.when(
              data: (medical) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (medical?.diseases.isNotEmpty == true) ...[
                    Text('Conditions:', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: (medical?.diseases ?? []).map((d) => Chip(
                        label: Text(d),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      )).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (medical?.allergies != null && medical!.allergies!.isNotEmpty) ...[
                    Text('Allergies:', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(medical.allergies!, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 12),
                  ],
                  if (medical?.recentMedical != null && medical!.recentMedical!.isNotEmpty) ...[
                    Text('Recent Medical:', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(medical.recentMedical!, style: theme.textTheme.bodyMedium),
                  ],
                  if ((medical?.diseases.isEmpty ?? true) &&
                      (medical?.allergies?.isEmpty ?? true) &&
                      (medical?.recentMedical?.isEmpty ?? true))
                    Text('No medical information added', style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Text('Error loading medical info', style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactsCard(
    AsyncValue<List<EmergencyContact>> contactsAsync,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Emergency Contacts', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            contactsAsync.when(
              data: (contacts) {
                if (contacts.isEmpty) {
                  return Text('No emergency contacts added', style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ));
                }
                return Column(
                  children: contacts.map((contact) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.contact_emergency, color: theme.colorScheme.primary),
                    ),
                    title: Text(contact.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text('${contact.relation} • ${contact.phone}'),
                    trailing: IconButton(
                      icon: Icon(Icons.call, color: theme.colorScheme.primary),
                      onPressed: () => _callContact(contact.phone),
                      tooltip: 'Call ${contact.name}',
                    ),
                  )).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Text('Error loading contacts', style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callContact(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildQrCodeCard(
    AsyncValue<AppProfile?> profileAsync,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('My Emergency QR Code', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Scan this QR in an emergency', style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
            const SizedBox(height: 16),
            profileAsync.when(
              data: (profile) {
                if (profile == null) return const Text('Profile not loaded');
                return RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: QrImageView(
                      data: profile.qrToken,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Text('Error loading QR', style: TextStyle(color: theme.colorScheme.error)),
            ),
            const SizedBox(height: 12),
            Text('QR Token: ', style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
            profileAsync.when(
              data: (p) => Text(p?.qrToken ?? '', style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              )),
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Column(
      children: [
        PrimaryButton(
          text: 'Download / Share QR',
          icon: Icons.share,
          onPressed: () {
            _downloadQrCode();
            _shareQrCode();
          },
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          text: 'Edit Profile',
          icon: Icons.edit,
          onPressed: _navigateToEditProfile,
        ),
      ],
    );
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