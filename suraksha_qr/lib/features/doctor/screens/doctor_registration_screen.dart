// Doctor Registration Screen - single scrollable form
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../providers/providers.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/text_fields.dart';
import '../../../widgets/loading.dart';
import '../../../core/constants/app_constants.dart';

class DoctorRegistrationScreen extends ConsumerStatefulWidget {
  const DoctorRegistrationScreen({super.key});

  @override
  ConsumerState<DoctorRegistrationScreen> createState() => _DoctorRegistrationScreenState();
}

class _DoctorRegistrationScreenState extends ConsumerState<DoctorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Step 1: Account
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Step 2: Basic Info
  XFile? _profilePhoto;
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Step 3: Professional Info
  final _degreeController = TextEditingController();
  XFile? _degreeCertificate;
  PlatformFile? _degreeCertificateFile;
  final _registrationNoController = TextEditingController();
  final _medicalCouncilController = TextEditingController();
  final _hospitalController = TextEditingController();
  XFile? _idProof;
  PlatformFile? _idProofFile;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _degreeController.dispose();
    _registrationNoController.dispose();
    _medicalCouncilController.dispose();
    _hospitalController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_profilePhoto == null) {
      _showError('Profile photo is required');
      return;
    }
    if (_degreeCertificate == null && _degreeCertificateFile == null) {
      _showError('Degree certificate is required');
      return;
    }
    if (_idProof == null && _idProofFile == null) {
      _showError('ID proof is required');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final storageRepo = ref.read(storageRepositoryProvider);
      final client = ref.read(supabaseClientProvider);

      // 1. Sign up
      final signUpResponse = await authRepo.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: AppConstants.roleDoctor,
        fullName: _fullNameController.text.trim(),
      );

      if (signUpResponse.user == null) {
        throw Exception('Sign up failed');
      }

      final userId = signUpResponse.user!.id;

      // 2. Upload files
      final photoFile = File(_profilePhoto!.path);
      final photoPath = await storageRepo.uploadFile(
        bucket: AppConstants.bucketProfilePhotos,
        file: photoFile,
        userId: userId,
      );
      final photoUrl = await storageRepo.getSignedUrl(
        bucket: AppConstants.bucketProfilePhotos,
        path: photoPath,
      );

      String? degreeDocUrl;
      if (_degreeCertificate != null) {
        final docFile = File(_degreeCertificate!.path);
        final docPath = await storageRepo.uploadFile(
          bucket: AppConstants.bucketDoctorDocuments,
          file: docFile,
          userId: userId,
        );
        degreeDocUrl = await storageRepo.getSignedUrl(
          bucket: AppConstants.bucketDoctorDocuments,
          path: docPath,
        );
      } else if (_degreeCertificateFile != null) {
        final docPath = await storageRepo.uploadPlatformFile(
          bucket: AppConstants.bucketDoctorDocuments,
          file: _degreeCertificateFile!,
          userId: userId,
        );
        degreeDocUrl = await storageRepo.getSignedUrl(
          bucket: AppConstants.bucketDoctorDocuments,
          path: docPath,
        );
      }

      String? idProofUrl;
      if (_idProof != null) {
        final proofFile = File(_idProof!.path);
        final proofPath = await storageRepo.uploadFile(
          bucket: AppConstants.bucketDoctorDocuments,
          file: proofFile,
          userId: userId,
        );
        idProofUrl = await storageRepo.getSignedUrl(
          bucket: AppConstants.bucketDoctorDocuments,
          path: proofPath,
        );
      } else if (_idProofFile != null) {
        final proofPath = await storageRepo.uploadPlatformFile(
          bucket: AppConstants.bucketDoctorDocuments,
          file: _idProofFile!,
          userId: userId,
        );
        idProofUrl = await storageRepo.getSignedUrl(
          bucket: AppConstants.bucketDoctorDocuments,
          path: proofPath,
        );
      }

      // 3. Update profile and insert doctor details
      await client.from('profiles').upsert({
        'id': userId,
        'photo_url': photoUrl,
        'phone': _phoneController.text.trim(),
      });

      await client.from('doctor_details').insert({
        'doctor_id': userId,
        'degree': _degreeController.text.trim(),
        'degree_doc_url': degreeDocUrl,
        'registration_no': _registrationNoController.text.trim(),
        'medical_council': _medicalCouncilController.text.trim(),
        'id_proof_url': idProofUrl,
        'hospital': _hospitalController.text.trim().isEmpty ? null : _hospitalController.text.trim(),
      });

      if (!mounted) return;
      context.go('/doctor-dashboard');
    } catch (e) {
      _showError(_getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _getErrorMessage(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('already registered') || msg.contains('user already exists')) {
      return 'This email is already registered';
    }
    if (msg.contains('weak password')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'No internet connection. Please try again.';
    }
    if (msg.contains('storage') || msg.contains('upload')) {
      return 'File upload failed. Check file size (max 5 MB) and type.';
    }
    // Include actual error for debugging
    return 'Registration failed: ${e.toString()}';
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

  Future<void> _pickImage(ImageSource source, Function(XFile?) onPicked) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    onPicked(picked);
  }

  Future<void> _pickDocument(Function(PlatformFile?) onPicked) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result != null && result.isNotEmpty) {
      final file = result.first;
      final fileSize = file.lengthSync() ?? 0;
      if (fileSize > AppConstants.maxFileSizeBytes) {
        _showError('File size must be less than 5 MB');
        return;
      }
      onPicked(file);
    }
  }

  void _showImageSourceDialog(Function(ImageSource) onSelected) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                onSelected(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                onSelected(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileUploadCard({
    required String label,
    required String? fileName,
    required VoidCallback onPick,
    required VoidCallback onClear,
    required bool required,
  }) {
    final theme = Theme.of(context);
    final hasFile = fileName != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              if (required) Text(' *', style: TextStyle(color: theme.colorScheme.error)),
            ],
          ),
          const SizedBox(height: 12),
          if (hasFile) ...[
            (() {
              final name = fileName!;
              return Row(
                children: [
                  Icon(
                    name.endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(name, style: theme.textTheme.bodyMedium)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClear,
                  ),
                ],
              );
            })(),
          ] else
            PrimaryButton(
              text: 'Select File',
              icon: Icons.upload_file,
              onPressed: onPick,
            ),
          Text(
            'Max 5 MB • JPG, PNG, PDF',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Registration'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/register'),
        ),
      ),
      body: AppLoadingOverlay(
        isLoading: _isSubmitting,
        message: 'Creating your account...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Section 1: Account
                Text('Account Details', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Create your login credentials', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 24),
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
                AppTextField(
                  label: 'Password',
                  hint: 'Enter password (min 6 chars)',
                  controller: _passwordController,
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Confirm Password',
                  hint: 'Re-enter password',
                  controller: _confirmPasswordController,
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm password is required';
                    if (v != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 32),

                // Section 2: Basic Info
                Text('Basic Information', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Upload your photo and enter your details', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: () => _showImageSourceDialog((source) => _pickImage(source, (img) => setState(() => _profilePhoto = img))),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surfaceContainerHighest,
                        border: Border.all(color: theme.colorScheme.primary, width: 2),
                        image: _profilePhoto != null
                            ? DecorationImage(
                                image: FileImage(File(_profilePhoto!.path)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _profilePhoto == null
                          ? Icon(Icons.camera_alt, size: 40, color: theme.colorScheme.primary)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _profilePhoto == null ? 'Tap to add photo (required)' : 'Tap to change photo',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  controller: _fullNameController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Phone Number',
                  hint: '10-digit phone number',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Phone number is required';
                    if (!RegExp(r'^\d{10}$').hasMatch(v)) return 'Enter a valid 10-digit phone number';
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 32),

                // Section 3: Professional Info
                Text('Professional Information', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Enter your medical credentials and upload documents', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 24),
                AppTextField(
                  label: 'Degree',
                  hint: 'e.g., MBBS, MD, MS',
                  controller: _degreeController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Degree is required' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                _buildFileUploadCard(
                  label: 'Degree Certificate',
                  fileName: _degreeCertificate?.name ?? _degreeCertificateFile?.name,
                  onPick: () => _pickDocument((f) => setState(() {
                    _degreeCertificate = null;
                    _degreeCertificateFile = f;
                  })),
                  onClear: () => setState(() {
                    _degreeCertificate = null;
                    _degreeCertificateFile = null;
                  }),
                  required: true,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'MBBS / Medical Registration Number',
                  hint: 'Enter your registration number',
                  controller: _registrationNoController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Registration number is required' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'State Medical Council',
                  hint: 'e.g., Karnataka Medical Council',
                  controller: _medicalCouncilController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Medical council is required' : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Hospital / Clinic (Optional)',
                  hint: 'Enter hospital or clinic name',
                  controller: _hospitalController,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                _buildFileUploadCard(
                  label: 'ID Proof (Aadhaar / Govt ID)',
                  fileName: _idProof?.name ?? _idProofFile?.name,
                  onPick: () => _pickDocument((f) => setState(() {
                    _idProof = null;
                    _idProofFile = f;
                  })),
                  onClear: () => setState(() {
                    _idProof = null;
                    _idProofFile = null;
                  }),
                  required: true,
                ),
                const SizedBox(height: 32),

                // Submit Button
                PrimaryButton(
                  text: 'Register as Doctor',
                  icon: Icons.person_add,
                  isLoading: _isSubmitting,
                  onPressed: _handleSubmit,
                ),
                const SizedBox(height: 16),

                // Back to Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Login'),
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