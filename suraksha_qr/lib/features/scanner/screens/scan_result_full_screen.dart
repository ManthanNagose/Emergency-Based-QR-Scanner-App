// Full Scan Result Screen - for verified doctors
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/providers.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/loading.dart';

class ScanResultFullScreen extends ConsumerStatefulWidget {
  final String token;

  const ScanResultFullScreen({super.key, required this.token});

  @override
  ConsumerState<ScanResultFullScreen> createState() => _ScanResultFullScreenState();
}

class _ScanResultFullScreenState extends ConsumerState<ScanResultFullScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final response = await client.rpc('get_full_medical_info', params: {
        'p_token': widget.token,
      });

      if (response == null) {
        setState(() {
          _error = 'QR code not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _result = response as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = _getErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  String _getErrorMessage(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('not found') || msg.contains('p0001')) {
      return 'Invalid QR code';
    }
    if (msg.contains('only verified doctors') || msg.contains('42501')) {
      return 'Access denied. Only verified doctors can view full medical info.';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'No internet connection. Please try again.';
    }
    return 'Failed to load data. Please try again.';
  }

  Future<void> _callContact(String phone) async {
    final uri = Uri.parse('tel:$phone');
    try {
      if (!await launchUrl(uri)) {
        throw Exception('Could not launch dialer');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open dialer: $e')),
        );
      }
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

  void _scanAgain() {
    context.go('/scanner');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Scan Result'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.go('/welcome'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(_error!, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: 'Scan Again',
                  icon: Icons.qr_code_scanner,
                  onPressed: _scanAgain,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/welcome'),
                  child: const Text('Back to Welcome'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final contacts = (_result!['emergency_contacts'] as List?) ?? [];
    final isVerified = _result!['verification_status'] == 'verified';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Full Medical Information'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/welcome'),
        ),
      ),
      body: AppLoadingOverlay(
        isLoading: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Not Verified Warning
              if (!isVerified)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange[800]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Not Verified - This information has not been verified by an admin',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.orange[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!isVerified) const SizedBox(height: 16),

              // Profile Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        backgroundImage: _result!['photo_url'] != null
                            ? NetworkImage(_result!['photo_url'] as String)
                            : null,
                        child: _result!['photo_url'] == null
                            ? Icon(Icons.person, size: 40, color: theme.colorScheme.primary)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _result!['full_name'] as String? ?? 'Unknown',
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (_result!['age'] != null) ...[
                                  Icon(Icons.cake_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text('${_result!['age']} years', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                  const SizedBox(width: 16),
                                ],
                                if (_result!['gender'] != null) ...[
                                  Icon(Icons.transgender, size: 16, color: theme.colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text(_result!['gender'] as String, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            // User's own phone number (only in full view)
                            if (_result!['phone'] != null)
                              Row(
                                children: [
                                  Icon(Icons.phone, size: 16, color: theme.colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text(_result!['phone'] as String, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Blood Group
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
                              _result!['blood_group'] as String? ?? 'Not set',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (_result!['blood_group_verified'] == true)
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Diseases/Allergies
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Medical Conditions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if ((_result!['diseases'] as List?)?.isNotEmpty == true) ...[
                        Text('Conditions:', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: ((_result!['diseases'] as List?) ?? [])
                              .map((d) => Chip(
                                    label: Text(d as String),
                                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_result!['allergies'] != null && (_result!['allergies'] as String).isNotEmpty) ...[
                        Text('Allergies:', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        Text(_result!['allergies'] as String, style: theme.textTheme.bodyMedium),
                      ],
                      if ((_result!['diseases'] as List?)?.isEmpty == true &&
                          (_result!['allergies'] as String?)?.isEmpty == true)
                        Text('No medical conditions listed', style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Emergency Contacts
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Emergency Contacts', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (contacts.isEmpty)
                        Text('No emergency contacts available', style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ))
                      else
                        ...contacts.map((contact) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: theme.colorScheme.primaryContainer,
                                    child: Icon(Icons.contact_emergency, color: theme.colorScheme.primary),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          contact['name'] as String? ?? 'Unknown',
                                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '${contact['relation']} • ${contact['phone']}',
                                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PrimaryButton(
                                    text: 'Call',
                                    icon: Icons.call,
                                    onPressed: () => _callContact(contact['phone'] as String? ?? ''),
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Full View Extras
              // Recent Medical
              if (_result!['recent_medical'] != null && (_result!['recent_medical'] as String).isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recent Medical Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(_result!['recent_medical'] as String, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Blood Group Proof
              if (_result!['blood_group_proof_url'] != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Blood Group Proof', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildDocumentViewer(
                          url: _result!['blood_group_proof_url'] as String,
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
              if (_result!['medical_doc_url'] != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Medical Document', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildDocumentViewer(
                          url: _result!['medical_doc_url'] as String,
                          label: 'Medical Document',
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 24),

              // Scan Again Button
              PrimaryButton(
                text: 'Scan Another QR',
                icon: Icons.qr_code_scanner,
                onPressed: _scanAgain,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/welcome'),
                child: const Text('Back to Welcome'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
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