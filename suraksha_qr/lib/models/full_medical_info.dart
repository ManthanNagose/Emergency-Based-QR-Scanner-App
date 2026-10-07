// FullMedicalInfo model - full view for verified doctors
import 'emergency_contact.dart';
import 'public_emergency_info.dart';

class FullMedicalInfo {
  final String fullName;
  final String? photoUrl;
  final int? age;
  final String? gender;
  final String? bloodGroup;
  final bool bloodGroupVerified;
  final List<String> diseases;
  final String? allergies;
  final String verificationStatus;
  final List<EmergencyContact> emergencyContacts;
  final String? phone;
  final String? recentMedical;
  final String? medicalDocUrl;
  final String? bloodGroupProofUrl;

  FullMedicalInfo({
    required this.fullName,
    this.photoUrl,
    this.age,
    this.gender,
    this.bloodGroup,
    required this.bloodGroupVerified,
    required this.diseases,
    this.allergies,
    required this.verificationStatus,
    required this.emergencyContacts,
    this.phone,
    this.recentMedical,
    this.medicalDocUrl,
    this.bloodGroupProofUrl,
  });

  factory FullMedicalInfo.fromJson(Map<String, dynamic> json) {
    final contactsJson = json['emergency_contacts'] as List<dynamic>? ?? [];
    return FullMedicalInfo(
      fullName: json['full_name'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      bloodGroup: json['blood_group'] as String?,
      bloodGroupVerified: json['blood_group_verified'] as bool? ?? false,
      diseases: (json['diseases'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      allergies: json['allergies'] as String?,
      verificationStatus: json['verification_status'] as String? ?? 'pending',
      emergencyContacts:
          contactsJson.map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>)).toList(),
      phone: json['phone'] as String?,
      recentMedical: json['recent_medical'] as String?,
      medicalDocUrl: json['medical_doc_url'] as String?,
      bloodGroupProofUrl: json['blood_group_proof_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'photo_url': photoUrl,
      'age': age,
      'gender': gender,
      'blood_group': bloodGroup,
      'blood_group_verified': bloodGroupVerified,
      'diseases': diseases,
      'allergies': allergies,
      'verification_status': verificationStatus,
      'emergency_contacts': emergencyContacts.map((e) => e.toJson()).toList(),
      'phone': phone,
      'recent_medical': recentMedical,
      'medical_doc_url': medicalDocUrl,
      'blood_group_proof_url': bloodGroupProofUrl,
    };
  }

  factory FullMedicalInfo.fromPublicInfo(
    PublicEmergencyInfo public, {
    required String? phone,
    required String? recentMedical,
    required String? medicalDocUrl,
    required String? bloodGroupProofUrl,
  }) {
    return FullMedicalInfo(
      fullName: public.fullName,
      photoUrl: public.photoUrl,
      age: public.age,
      gender: public.gender,
      bloodGroup: public.bloodGroup,
      bloodGroupVerified: public.bloodGroupVerified,
      diseases: public.diseases,
      allergies: public.allergies,
      verificationStatus: public.verificationStatus,
      emergencyContacts: public.emergencyContacts,
      phone: phone,
      recentMedical: recentMedical,
      medicalDocUrl: medicalDocUrl,
      bloodGroupProofUrl: bloodGroupProofUrl,
    );
  }
}