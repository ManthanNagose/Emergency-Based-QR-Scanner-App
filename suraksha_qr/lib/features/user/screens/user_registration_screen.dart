// User Registration Screen - 5-step form using PageView
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
import '../../../models/models.dart';

class UserRegistrationScreen extends ConsumerStatefulWidget {
  const UserRegistrationScreen({super.key});

  @override
  ConsumerState<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends ConsumerState<UserRegistrationScreen> {
  final _pageController = PageController();
  final _formKeys = List.generate(5, (_) => GlobalKey<FormState>());
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1: Account
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Step 2: Basic Info
  XFile? _profilePhoto;
  final _fullNameController = TextEditingController();
  String _gender = 'Male';
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();

  // Step 3: Emergency Contacts
  final List<EmergencyContact> _emergencyContacts = [];

  // Step 4: Medical
  String _bloodGroup = 'A+';
  XFile? _bloodGroupProof;
  PlatformFile? _bloodGroupProofFile;
  final _recentMedicalController = TextEditingController();
  XFile? _medicalDocument;
  PlatformFile? _medicalDocumentFile;
  final Set<String> _selectedDiseases = {};
  bool _otherDiseaseSelected = false;
  final _otherDiseaseController = TextEditingController();
  final _allergiesController = TextEditingController();

  static const List<String> _genders = ['Male', 'Female', 'Other'];
  static const List<String> _diseases = [
    'Diabetes',
    'BP',
    'Asthma',
    'Heart disease',
    'Epilepsy',
    'Other',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _recentMedicalController.dispose();
    _otherDiseaseController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep < 4) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _validateStep1();
      case 1:
        return _validateStep2();
      case 2:
        return _validateStep3();
      case 3:
        return _validateStep4();
      case 4:
        return true; // Review step
      default:
        return false;
    }
  }

  bool _validateStep1() {
    if (_emailController.text.isEmpty) {
      _showError('Email is required');
      return false;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text)) {
      _showError('Enter a valid email');
      return false;
    }
    if (_passwordController.text.isEmpty) {
      _showError('Password is required');
      return false;
    }
    if (_passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return false;
    }
    if (_confirmPasswordController.text != _passwordController.text) {
      _showError('Passwords do not match');
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_profilePhoto == null) {
      _showError('Profile photo is required');
      return false;
    }
    if (_fullNameController.text.trim().isEmpty) {
      _showError('Full name is required');
      return false;
    }
    if (_fullNameController.text.trim().length < 2) {
      _showError('Name must be at least 2 characters');
      return false;
    }
    if (_ageController.text.isEmpty) {
      _showError('Age is required');
      return false;
    }
    final age = int.tryParse(_ageController.text);
    if (age == null || age < 1 || age > 120) {
      _showError('Age must be between 1 and 120');
      return false;
    }
    if (_phoneController.text.isEmpty) {
      _showError('Contact number is required');
      return false;
    }
    if (!RegExp(r'^\d{10}$').hasMatch(_phoneController.text)) {
      _showError('Enter a valid 10-digit phone number');
      return false;
    }
    return true;
  }

  bool _validateStep3() {
    if (_emergencyContacts.isEmpty) {
      _showError('At least 1 emergency contact is required');
      return false;
    }
    if (_emergencyContacts.length > 3) {
      _showError('Maximum 3 emergency contacts allowed');
      return false;
    }
    return true;
  }

  bool _validateStep4() {
    if (_bloodGroup.isEmpty) {
      _showError('Blood group is required');
      return false;
    }
    if (_bloodGroupProof == null && _bloodGroupProofFile == null) {
      _showError('Blood group proof document is required');
      return false;
    }
    return true;
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

  Future<void> _handleSubmit() async {
    if (!_validateStep4()) return;

    setState(() => _isSubmitting = true);

    try {
      // 1. Sign up
      final authRepo = ref.read(authRepositoryProvider);
      final signUpResponse = await authRepo.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: AppConstants.roleUser,
        fullName: _fullNameController.text.trim(),
      );

      if (signUpResponse.user == null) {
        throw Exception('Sign up failed');
      }

      final userId = signUpResponse.user!.id;

      // 2. Upload files
      final storageRepo = ref.read(storageRepositoryProvider);
      
      String? photoUrl;
      if (_profilePhoto != null) {
        final photoFile = File(_profilePhoto!.path);
        final photoPath = await storageRepo.uploadFile(
          bucket: AppConstants.bucketProfilePhotos,
          file: photoFile,
          userId: userId,
        );
        photoUrl = await storageRepo.getSignedUrl(
          bucket: AppConstants.bucketProfilePhotos,
          path: photoPath,
        );
      }

      String? bloodGroupProofUrl;
      if (_bloodGroupProof != null) {
        final proofFile = File(_bloodGroupProof!.path);
        final proofPath = await storageRepo.uploadFile(
          bucket: AppConstants.bucketUserDocuments,
          file: proofFile,
          userId: userId,
        );
        bloodGroupProofUrl = await storageRepo.getSignedUrl(
          bucket: AppConstants.bucketUserDocuments,
          path: proofPath,
        );
      } else if (_bloodGroupProofFile != null) {
        // For web platform - use PlatformFile upload
        final proofPath = await storageRepo.uploadPlatformFile(
          bucket: AppConstants.bucketUserDocuments,
          file: _bloodGroupProofFile!,
          userId: userId,
        );
        bloodGroupProofUrl = await storageRepo.getSignedUrl(
          bucket: AppConstants.bucketUserDocuments,
          path: proofPath,
        );
      }

      String? medicalDocUrl;
      if (_medicalDocument != null) {
        final docFile = File(_medicalDocument!.path);
        final docPath = await storageRepo.uploadFile(
          bucket: AppConstants.bucketUserDocuments,
          file: docFile,
          userId: userId,
        );
        medicalDocUrl = await storageRepo.getSignedUrl(
          bucket: AppConstants.bucketUserDocuments,
          path: docPath,
        );
      } else if (_medicalDocumentFile != null) {
        // For web platform - use PlatformFile upload
        final docPath = await storageRepo.uploadPlatformFile(
          bucket: AppConstants.bucketUserDocuments,
          file: _medicalDocumentFile!,
          userId: userId,
        );
        medicalDocUrl = await storageRepo.getSignedUrl(
          bucket: AppConstants.bucketUserDocuments,
          path: docPath,
        );
      }

      // 3. Update profile and insert medical info & contacts
      final client = ref.read(supabaseClientProvider);
      
      // Upsert profile (creates if not exists, updates if exists)
      await client.from('profiles').upsert({
        'id': userId,
        'photo_url': photoUrl,
        'phone': _phoneController.text.trim(),
        'gender': _gender,
        'age': int.parse(_ageController.text),
      });

      // Insert medical info
      final diseasesList = _selectedDiseases.toList();
      if (_otherDiseaseSelected && _otherDiseaseController.text.trim().isNotEmpty) {
        diseasesList.add(_otherDiseaseController.text.trim());
      }

      await client.from('medical_info').insert({
        'user_id': userId,
        'blood_group': _bloodGroup,
        'blood_group_proof_url': bloodGroupProofUrl,
        'blood_group_verified': false,
        'recent_medical': _recentMedicalController.text.trim().isEmpty 
            ? null 
            : _recentMedicalController.text.trim(),
        'medical_doc_url': medicalDocUrl,
        'diseases': diseasesList,
        'allergies': _allergiesController.text.trim().isEmpty 
            ? null 
            : _allergiesController.text.trim(),
      });

      // Insert emergency contacts
      for (final contact in _emergencyContacts) {
        await client.from('emergency_contacts').insert({
          'user_id': userId,
          'name': contact.name,
          'relation': contact.relation,
          'phone': contact.phone,
        });
      }

      if (!mounted) return;
      context.go('/user-dashboard');
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

  void _addEmergencyContact() {
    if (_emergencyContacts.length >= 3) {
      _showError('Maximum 3 contacts allowed');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EmergencyContactForm(
        onSave: (name, relation, phone) {
          setState(() {
            _emergencyContacts.add(EmergencyContact(
              id: '',
              userId: '',
              name: name,
              relation: relation,
              phone: phone,
            ));
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _removeEmergencyContact(int index) {
    setState(() {
      _emergencyContacts.removeAt(index);
    });
  }

  void _editEmergencyContact(int index) {
    final contact = _emergencyContacts[index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EmergencyContactForm(
        initialName: contact.name,
        initialRelation: contact.relation,
        initialPhone: contact.phone,
        onSave: (name, relation, phone) {
          setState(() {
            _emergencyContacts[index] = EmergencyContact(
              id: contact.id,
              userId: contact.userId,
              name: name,
              relation: relation,
              phone: phone,
            );
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final steps = [
      _buildStep1(),
      _buildStep2(),
      _buildStep3(),
      _buildStep4(),
      _buildStep5(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Register - Step ${_currentStep + 1} of 5'),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousStep,
              )
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.go('/register'),
              ),
      ),
      body: AppLoadingOverlay(
        isLoading: _isSubmitting,
        message: 'Creating your account...',
        child: Column(
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Row(
                    children: List.generate(5, (index) {
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(right: index < 4 ? 8 : 0),
                          decoration: BoxDecoration(
                            color: index <= _currentStep
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getStepTitle(_currentStep),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Form content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: steps,
              ),
            ),
            // Navigation buttons
            if (!_isSubmitting)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: SecondaryButton(
                          text: 'Back',
                          icon: Icons.arrow_back,
                          onPressed: _previousStep,
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 16),
                    Expanded(
                      child: PrimaryButton(
                        text: _currentStep == 4 ? 'Submit' : 'Next',
                        icon: _currentStep == 4 ? Icons.check : Icons.arrow_forward,
                        onPressed: _currentStep == 4 ? _handleSubmit : _nextStep,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Step 1: Account Details';
      case 1:
        return 'Step 2: Basic Information';
      case 2:
        return 'Step 3: Emergency Contacts';
      case 3:
        return 'Step 4: Medical Information';
      case 4:
        return 'Step 5: Review & Submit';
      default:
        return '';
    }
  }

  // Step 1: Account
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeys[0],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Create your account', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Enter your email and password', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 32),
            AppTextField(
              label: 'Email',
              hint: 'you@example.com',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || v.isEmpty ? 'Email is required' : null,
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
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
    );
  }

  // Step 2: Basic Info
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeys[1],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Basic Information', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Upload your photo and enter your details', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            // Profile Photo
            Center(
              child: GestureDetector(
                onTap: () => _showImageSourceDialog((source) => _pickImage(source, (img) => setState(() => _profilePhoto = img))),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                    image: _profilePhoto != null
                        ? DecorationImage(
                            image: FileImage(File(_profilePhoto!.path)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _profilePhoto == null
                      ? Icon(Icons.camera_alt, size: 40, color: Theme.of(context).colorScheme.primary)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _profilePhoto == null ? 'Tap to add photo (required)' : 'Tap to change photo',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
            AppDropdownField<String>(
              label: 'Gender',
              initialValue: _gender,
              items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => setState(() => _gender = v!),
              validator: (v) => null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Age',
              hint: 'Enter your age',
              controller: _ageController,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Age is required';
                final age = int.tryParse(v);
                if (age == null || age < 1 || age > 120) return 'Age must be between 1 and 120';
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Contact Number',
              hint: '10-digit phone number',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Contact number is required';
                if (!RegExp(r'^\d{10}$').hasMatch(v)) return 'Enter a valid 10-digit phone number';
                return null;
              },
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
    );
  }

  // Step 3: Emergency Contacts
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeys[2],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Emergency Contacts', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Add 1 to 3 contacts who should be notified in an emergency', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            if (_emergencyContacts.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Icon(Icons.contact_emergency, size: 48, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('No emergency contacts added', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Add at least one contact', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              )
            else
              Column(
                children: _emergencyContacts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final contact = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Text('${index + 1}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(contact.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text('${contact.relation} • ${contact.phone}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit), onPressed: () => _editEmergencyContact(index)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeEmergencyContact(index)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),
            PrimaryButton(
              text: 'Add Emergency Contact',
              icon: Icons.add,
              onPressed: _addEmergencyContact,
            ),
            const SizedBox(height: 8),
            Text(
              '${_emergencyContacts.length} / 3 contacts added',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Step 4: Medical
  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeys[3],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Medical Information', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Upload documents and enter medical details', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            // Blood Group
            AppDropdownField<String>(
              label: 'Blood Group',
              initialValue: _bloodGroup,
              items: AppConstants.bloodGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => setState(() => _bloodGroup = v!),
              validator: (v) => v == null || v.isEmpty ? 'Blood group is required' : null,
            ),
            const SizedBox(height: 16),
            // Blood Group Proof
            _buildFileUploadCard(
              label: 'Blood Group Proof',
              fileName: _bloodGroupProof?.name ?? _bloodGroupProofFile?.name,
              onPick: () => _pickDocument((f) => setState(() {
                _bloodGroupProof = null;
                _bloodGroupProofFile = f;
              })),
              onClear: () => setState(() {
                _bloodGroupProof = null;
                _bloodGroupProofFile = null;
              }),
              required: true,
            ),
            const SizedBox(height: 16),
            // Recent Medical Details
            AppTextField(
              label: 'Recent Medical Details',
              hint: 'Current medications, conditions, etc.',
              controller: _recentMedicalController,
              maxLines: 3,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            // Medical Document
            _buildFileUploadCard(
              label: 'Medical Document / Report',
              fileName: _medicalDocument?.name ?? _medicalDocumentFile?.name,
              onPick: () => _pickDocument((f) => setState(() {
                _medicalDocument = null;
                _medicalDocumentFile = f;
              })),
              onClear: () => setState(() {
                _medicalDocument = null;
                _medicalDocumentFile = null;
              }),
              required: false,
            ),
            const SizedBox(height: 24),
            Text('Diseases / Conditions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _diseases.map((disease) {
                final isSelected = _selectedDiseases.contains(disease);
                return FilterChip(
                  label: Text(disease),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDiseases.add(disease);
                      } else {
                        _selectedDiseases.remove(disease);
                      }
                      if (disease == 'Other') {
                        _otherDiseaseSelected = selected;
                      }
                    });
                  },
                );
              }).toList(),
            ),
            if (_otherDiseaseSelected) ...[
              const SizedBox(height: 16),
              AppTextField(
                label: 'Specify Other',
                hint: 'Enter other condition',
                controller: _otherDiseaseController,
                validator: (v) {
                  if (_otherDiseaseSelected && (v == null || v.trim().isEmpty)) {
                    return 'Please specify the condition';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),
            AppTextField(
              label: 'Allergies (Optional)',
              hint: 'e.g., Penicillin, Latex, etc.',
              controller: _allergiesController,
              maxLines: 2,
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

  // Step 5: Review
  Widget _buildStep5() {
    final theme = Theme.of(context);
    final diseasesList = _selectedDiseases.toList();
    if (_otherDiseaseSelected && _otherDiseaseController.text.trim().isNotEmpty) {
      diseasesList.add(_otherDiseaseController.text.trim());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKeys[4],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Review Your Information', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Please verify all details before submitting', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            _buildReviewSection('Account', [
              _ReviewRow('Email', _emailController.text),
            ]),
            _buildReviewSection('Basic Info', [
              _ReviewRow('Name', _fullNameController.text),
              _ReviewRow('Gender', _gender),
              _ReviewRow('Age', _ageController.text),
              _ReviewRow('Phone', _phoneController.text),
              _ReviewRow('Photo', _profilePhoto != null ? 'Uploaded' : 'Not uploaded'),
            ]),
            _buildReviewSection('Emergency Contacts', _emergencyContacts.map((c) => _ReviewRow('${c.name} (${c.relation})', c.phone)).toList()),
            _buildReviewSection('Medical', [
              _ReviewRow('Blood Group', _bloodGroup),
              _ReviewRow('Blood Group Proof', _bloodGroupProof != null || _bloodGroupProofFile != null ? 'Uploaded' : 'Not uploaded'),
              _ReviewRow('Recent Medical', _recentMedicalController.text.isEmpty ? 'Not provided' : 'Provided'),
              _ReviewRow('Medical Document', _medicalDocument != null || _medicalDocumentFile != null ? 'Uploaded' : 'Not uploaded'),
              _ReviewRow('Diseases', diseasesList.isEmpty ? 'None' : diseasesList.join(', ')),
              _ReviewRow('Allergies', _allergiesController.text.isEmpty ? 'None' : _allergiesController.text),
            ]),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Important', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer)),
                  const SizedBox(height: 8),
                  Text(
                    'Your profile will be pending verification until an admin reviews your documents. You will receive a QR code immediately but it will show "Not Verified" until approved.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection(String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
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
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _EmergencyContactForm extends StatefulWidget {
  final String? initialName;
  final String? initialRelation;
  final String? initialPhone;
  final Function(String name, String relation, String phone) onSave;

  const _EmergencyContactForm({
    this.initialName,
    this.initialRelation,
    this.initialPhone,
    required this.onSave,
  });

  @override
  State<_EmergencyContactForm> createState() => _EmergencyContactFormState();
}

class _EmergencyContactFormState extends State<_EmergencyContactForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _relationController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _relationController = TextEditingController(text: widget.initialRelation ?? '');
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initialName == null ? 'Add Emergency Contact' : 'Edit Emergency Contact',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            AppTextField(
              label: 'Name',
              hint: 'Contact name',
              controller: _nameController,
              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Relation',
              hint: 'e.g., Father, Mother, Spouse',
              controller: _relationController,
              validator: (v) => v == null || v.trim().isEmpty ? 'Relation is required' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Phone Number',
              hint: '10-digit phone number',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Phone is required';
                if (!RegExp(r'^\d{10}$').hasMatch(v)) return 'Enter a valid 10-digit phone number';
                return null;
              },
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: widget.initialName == null ? 'Add Contact' : 'Save Changes',
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  widget.onSave(
                    _nameController.text.trim(),
                    _relationController.text.trim(),
                    _phoneController.text.trim(),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}