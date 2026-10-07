// Edit Profile Screen - allows editing name, phone, age, gender, contacts, diseases, allergies, recent medical, photo/documents
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
import '../../../models/emergency_contact.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _documentsChanged = false;

  // Profile fields
  XFile? _profilePhoto;
  final _fullNameController = TextEditingController();
  String _gender = 'Male';
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();

  // Emergency contacts
  final List<EmergencyContact> _emergencyContacts = [];

  // Medical fields
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
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    final profile = await ref.read(currentProfileProvider.future);
    final medical = await ref.read(currentMedicalInfoProvider.future);
    final contacts = await ref.read(currentEmergencyContactsProvider.future);

    if (!mounted) return;

    if (profile != null) {
      _fullNameController.text = profile.fullName ?? '';
      _gender = profile.gender ?? 'Male';
      _ageController.text = profile.age?.toString() ?? '';
      _phoneController.text = profile.phone ?? '';
    }

    if (medical != null) {
      _bloodGroup = medical.bloodGroup ?? 'A+';
      _recentMedicalController.text = medical.recentMedical ?? '';
      _selectedDiseases.addAll(medical.diseases);
      for (final disease in medical.diseases) {
        if (!_diseases.contains(disease)) {
          _otherDiseaseSelected = true;
          _otherDiseaseController.text = disease;
        }
      }
      _allergiesController.text = medical.allergies ?? '';
    }

    _emergencyContacts.addAll(contacts);
    setState(() {});
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _recentMedicalController.dispose();
    _otherDiseaseController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final storageRepo = ref.read(storageRepositoryProvider);
      final client = ref.read(supabaseClientProvider);

      final user = client.auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final userId = user.id;

      // Upload new files if changed
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
        _documentsChanged = true;
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
        _documentsChanged = true;
      } else if (_bloodGroupProofFile != null) {
        final proofPath = await storageRepo.uploadPlatformFile(
          bucket: AppConstants.bucketUserDocuments,
          file: _bloodGroupProofFile!,
          userId: userId,
        );
        bloodGroupProofUrl = await storageRepo.getSignedUrl(
          bucket: AppConstants.bucketUserDocuments,
          path: proofPath,
        );
        _documentsChanged = true;
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
        _documentsChanged = true;
      } else if (_medicalDocumentFile != null) {
        final docPath = await storageRepo.uploadPlatformFile(
          bucket: AppConstants.bucketUserDocuments,
          file: _medicalDocumentFile!,
          userId: userId,
        );
        medicalDocUrl = await storageRepo.getSignedUrl(
          bucket: AppConstants.bucketUserDocuments,
          path: docPath,
        );
        _documentsChanged = true;
      }

      // Update profile
      await client.from('profiles').update({
        if (photoUrl != null) 'photo_url': photoUrl,
        'full_name': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gender': _gender,
        'age': int.parse(_ageController.text),
      }).eq('id', userId);

      // Update medical info
      final diseasesList = _selectedDiseases.toList();
      if (_otherDiseaseSelected && _otherDiseaseController.text.trim().isNotEmpty) {
        diseasesList.add(_otherDiseaseController.text.trim());
      }

      await client.from('medical_info').upsert({
        'user_id': userId,
        'blood_group': _bloodGroup,
        if (bloodGroupProofUrl != null) 'blood_group_proof_url': bloodGroupProofUrl,
        'blood_group_verified': bloodGroupProofUrl == null,
        'recent_medical': _recentMedicalController.text.trim().isEmpty ? null : _recentMedicalController.text.trim(),
        if (medicalDocUrl != null) 'medical_doc_url': medicalDocUrl,
        'diseases': diseasesList,
        'allergies': _allergiesController.text.trim().isEmpty ? null : _allergiesController.text.trim(),
      });

      // Update emergency contacts - delete old and insert new
      await client.from('emergency_contacts').delete().eq('user_id', userId);
      for (final contact in _emergencyContacts) {
        await client.from('emergency_contacts').insert({
          'user_id': userId,
          'name': contact.name,
          'relation': contact.relation,
          'phone': contact.phone,
        });
      }

      // If documents changed, resubmit for verification
      if (_documentsChanged) {
        await client.rpc('resubmit_for_verification');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_documentsChanged 
              ? 'Profile updated. Status reset to Pending Verification.' 
              : 'Profile updated successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: AppLoadingOverlay(
        isLoading: _isLoading,
        message: 'Saving profile...',
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Section 1: Basic Info
                Text('Basic Information', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Update your personal details', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
                    _profilePhoto == null ? 'Tap to change photo' : 'Tap to change photo',
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

                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'Age',
                        hint: 'Age',
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Age is required';
                          final age = int.tryParse(v);
                          if (age == null || age < 1 || age > 120) return 'Age 1-120';
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AppDropdownField<String>(
                        label: 'Gender',
                        initialValue: _gender,
                        items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (v) => setState(() => _gender = v!),
                        validator: (v) => null,
                      ),
                    ),
                  ],
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
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 32),

                // Section 2: Emergency Contacts
                Text('Emergency Contacts', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Add 1 to 3 contacts (name, relation, phone)', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 24),

                if (_emergencyContacts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.contact_emergency, size: 48, color: theme.colorScheme.primary),
                        const SizedBox(height: 16),
                        Text('No emergency contacts added', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Add at least one contact', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text('${index + 1}', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(contact.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
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
                  '${_emergencyContacts.length} / 3 contacts',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Section 3: Medical Information
                Text('Medical Information', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Update medical details and upload documents', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 24),

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

                Text('Diseases / Conditions', style: theme.textTheme.titleMedium),
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
                const SizedBox(height: 32),

                // Warning if documents changed
                if (_documentsChanged)
                  Container(
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
                            'Documents have been changed. Your profile will be resubmitted for verification.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.orange[800]),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Save Button
                PrimaryButton(
                  text: 'Save Changes',
                  icon: Icons.save,
                  isLoading: _isLoading,
                  onPressed: _handleSave,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
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
              final name = fileName;
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