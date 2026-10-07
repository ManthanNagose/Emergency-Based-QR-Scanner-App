// MedicalInfo model
class MedicalInfo {
  final String userId;
  final String? bloodGroup;
  final String? bloodGroupProofUrl;
  final bool bloodGroupVerified;
  final String? recentMedical;
  final String? medicalDocUrl;
  final List<String> diseases;
  final String? allergies;

  MedicalInfo({
    required this.userId,
    this.bloodGroup,
    this.bloodGroupProofUrl,
    required this.bloodGroupVerified,
    this.recentMedical,
    this.medicalDocUrl,
    required this.diseases,
    this.allergies,
  });

  factory MedicalInfo.fromJson(Map<String, dynamic> json) {
    return MedicalInfo(
      userId: json['user_id'] as String,
      bloodGroup: json['blood_group'] as String?,
      bloodGroupProofUrl: json['blood_group_proof_url'] as String?,
      bloodGroupVerified: json['blood_group_verified'] as bool? ?? false,
      recentMedical: json['recent_medical'] as String?,
      medicalDocUrl: json['medical_doc_url'] as String?,
      diseases: (json['diseases'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      allergies: json['allergies'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'blood_group': bloodGroup,
      'blood_group_proof_url': bloodGroupProofUrl,
      'blood_group_verified': bloodGroupVerified,
      'recent_medical': recentMedical,
      'medical_doc_url': medicalDocUrl,
      'diseases': diseases,
      'allergies': allergies,
    };
  }

  MedicalInfo copyWith({
    String? userId,
    String? bloodGroup,
    String? bloodGroupProofUrl,
    bool? bloodGroupVerified,
    String? recentMedical,
    String? medicalDocUrl,
    List<String>? diseases,
    String? allergies,
  }) {
    return MedicalInfo(
      userId: userId ?? this.userId,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      bloodGroupProofUrl: bloodGroupProofUrl ?? this.bloodGroupProofUrl,
      bloodGroupVerified: bloodGroupVerified ?? this.bloodGroupVerified,
      recentMedical: recentMedical ?? this.recentMedical,
      medicalDocUrl: medicalDocUrl ?? this.medicalDocUrl,
      diseases: diseases ?? this.diseases,
      allergies: allergies ?? this.allergies,
    );
  }
}