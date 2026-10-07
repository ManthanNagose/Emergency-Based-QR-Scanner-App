// PublicEmergencyInfo model - limited view for guest/third person
import 'emergency_contact.dart';

class PublicEmergencyInfo {
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

  PublicEmergencyInfo({
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
  });

  factory PublicEmergencyInfo.fromJson(Map<String, dynamic> json) {
    final contactsJson = json['emergency_contacts'] as List<dynamic>? ?? [];
    return PublicEmergencyInfo(
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
    };
  }

  bool get isVerified => verificationStatus == 'verified';
}