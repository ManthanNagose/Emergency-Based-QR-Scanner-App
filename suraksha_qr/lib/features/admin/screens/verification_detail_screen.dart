// Verification Detail Screen - for admin to verify users and doctors
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/providers.dart';
import '../../../widgets/buttons.dart';
import '../../../models/app_profile.dart';
import '../../../models/medical_info.dart';
import '../../../models/doctor_details.dart';

class VerificationDetailScreen extends ConsumerStatefulWidget {
  final String targetId;
  final String targetType; // 'user' or 'doctor'

  const VerificationDetailScreen({
    super.key,
    required this.targetId,
    required this.targetType,
  });

  @override
  ConsumerState<VerificationDetailScreen> createState() => _VerificationDetailScreenState();
}

class _VerificationDetailScreenState extends ConsumerState<VerificationDetailScreen> {
  bool _isProcessing = false;

  Future<void> _handleApprove() async {
    await _verify('verified', '');
  }

  Future<void> _handleReject() async {
    final reason = await _showRejectDialog();
    if (reason != null && reason.trim().isNotEmpty) {
      await _verify('rejected', reason.trim());
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'Enter reason...',
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          PrimaryButton(
            text: 'Reject',
            onPressed: () => Navigator.pop(context, controller.text),
          ),
        ],
      ),
    );
  }

  Future<void> _verify(String status, String reason) async {
    setState(() => _isProcessing = true);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.rpc('set_verification', params: {
        'p_target': widget.targetId,
        'p_status': status,
        'p_reason': reason,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(status == 'verified' ? 'Approved successfully' : 'Rejected')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _openFile(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch URL');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = widget.targetType == 'user';

    final profileAsync = ref.watch(profileByIdProvider(widget.targetId));
    
    if (isUser) {
      return _buildUserVerification(profileAsync, theme);
    } else {
      return _buildDoctorVerification(profileAsync, theme);
    }
  }

  Widget _buildUserVerification(AsyncValue<AppProfile?> profileAsync, ThemeData theme) {
    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(title: const Text('Error')), body: Center(child: Text('Error: $e'))),
      data: (profile) {
        if (profile == null) {
          return Scaffold(appBar: AppBar(title: const Text('User')), body: const Center(child: Text('User not found')));
        }

        final medicalAsync = ref.watch(medicalInfoByUserIdProvider(widget.targetId));

        return Scaffold(
          appBar: AppBar(title: Text('Verify ${profile.fullName ?? 'User'}')),
          body: medicalAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading medical info: $e')),
            data: (medical) => _buildUserContent(profile, medical, theme),
          ),
        );
      },
    );
  }

  Widget _buildUserContent(AppProfile profile, MedicalInfo? medical, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
                    child: profile.photoUrl == null ? Icon(Icons.person, size: 40, color: theme.colorScheme.primary) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.fullName ?? 'Unknown', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (profile.age != null) ...[
                              Icon(Icons.cake_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text('${profile.age} years', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              const SizedBox(width: 16),
                            ],
                            if (profile.gender != null) ...[
                              Icon(Icons.transgender, size: 16, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(profile.gender!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ],
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

          // Blood Group
          if (medical != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Blood Group', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            medical.bloodGroup ?? 'Not set',
                            style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (medical.bloodGroupVerified)
                          Row(
                            children: [
                              Icon(Icons.verified, color: theme.colorScheme.primary, size: 24),
                              const SizedBox(width: 8),
                              Text('Verified', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                            ],
                          )
                        else
                          Text('Not Verified', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Blood Group Proof
            if (medical.bloodGroupProofUrl != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Blood Group Proof', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildDocumentViewer(
                        url: medical.bloodGroupProofUrl!,
                        label: 'Blood Group Proof',
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Medical Document
            if (medical.medicalDocUrl != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Medical Document', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildDocumentViewer(
                        url: medical.medicalDocUrl!,
                        label: 'Medical Document',
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Recent Medical
            if (medical.recentMedical != null && medical.recentMedical!.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recent Medical Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(medical.recentMedical!, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  text: 'Reject',
                  icon: Icons.cancel,
                  isLoading: _isProcessing,
                  onPressed: _isProcessing ? null : _handleReject,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PrimaryButton(
                  text: 'Approve',
                  icon: Icons.check,
                  isLoading: _isProcessing,
                  onPressed: _isProcessing ? null : _handleApprove,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDoctorVerification(AsyncValue<AppProfile?> profileAsync, ThemeData theme) {
    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(title: const Text('Error')), body: Center(child: Text('Error: $e'))),
      data: (profile) {
        if (profile == null) {
          return Scaffold(appBar: AppBar(title: const Text('Doctor')), body: const Center(child: Text('Doctor not found')));
        }

        final doctorDetailsAsync = ref.watch(doctorDetailsByIdProvider(widget.targetId));

        return Scaffold(
          appBar: AppBar(title: Text('Verify Dr. ${profile.fullName ?? 'Doctor'}')),
          body: doctorDetailsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading doctor details: $e')),
            data: (details) => _buildDoctorContent(profile, details, theme),
          ),
        );
      },
    );
  }

  Widget _buildDoctorContent(AppProfile profile, DoctorDetails? details, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
                    child: profile.photoUrl == null ? Icon(Icons.person, size: 40, color: theme.colorScheme.primary) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dr. ${profile.fullName ?? 'Unknown'}', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        if (profile.phone != null && profile.phone!.isNotEmpty)
                          Text(profile.phone!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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

          // Doctor Details
          if (details != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Professional Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildDetailRow('Degree', details.degree, theme),
                    const SizedBox(height: 8),
                    _buildDetailRow('MBBS Registration No.', details.registrationNo, theme),
                    const SizedBox(height: 8),
                    _buildDetailRow('Medical Council', details.medicalCouncil, theme),
                    if (details.hospital != null && details.hospital!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow('Hospital / Clinic', details.hospital!, theme),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Degree Certificate
            if (details.degreeDocUrl != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Degree Certificate', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildDocumentViewer(
                        url: details.degreeDocUrl!,
                        label: 'Degree Certificate',
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ID Proof
            if (details.idProofUrl != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ID Proof', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildDocumentViewer(
                        url: details.idProofUrl!,
                        label: 'ID Proof',
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  text: 'Reject',
                  icon: Icons.cancel,
                  isLoading: _isProcessing,
                  onPressed: _isProcessing ? null : _handleReject,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PrimaryButton(
                  text: 'Approve',
                  icon: Icons.check,
                  isLoading: _isProcessing,
                  onPressed: _isProcessing ? null : _handleApprove,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
      ],
    );
  }

  Widget _buildDocumentViewer({
    required String url,
    required String label,
    required ThemeData theme,
  }) {
    final isPdf = url.toLowerCase().contains('.pdf');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isPdf ? Icons.picture_as_pdf : Icons.image, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
            ],
          ),
          const SizedBox(height: 12),
          if (!isPdf)
            Image.network(
              url,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                height: 200,
                alignment: Alignment.center,
                child: Text('Failed to load image', style: TextStyle(color: theme.colorScheme.error)),
              ),
            )
          else
            Container(
              height: 100,
              alignment: Alignment.center,
              child: Text('PDF Document', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 12),
          PrimaryButton(
            text: isPdf ? 'Open PDF' : 'Open Image',
            icon: isPdf ? Icons.picture_as_pdf : Icons.open_in_new,
            onPressed: () => _openFile(url),
          ),
        ],
      ),
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
                style: theme.textTheme.labelMedium?.copyWith(color: textColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(reason!, style: theme.textTheme.bodySmall?.copyWith(color: textColor), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}