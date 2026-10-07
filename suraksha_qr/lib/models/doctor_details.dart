// DoctorDetails model
class DoctorDetails {
  final String doctorId;
  final String degree;
  final String? degreeDocUrl;
  final String registrationNo;
  final String medicalCouncil;
  final String? idProofUrl;
  final String? hospital;

  DoctorDetails({
    required this.doctorId,
    required this.degree,
    this.degreeDocUrl,
    required this.registrationNo,
    required this.medicalCouncil,
    this.idProofUrl,
    this.hospital,
  });

  factory DoctorDetails.fromJson(Map<String, dynamic> json) {
    return DoctorDetails(
      doctorId: json['doctor_id'] as String,
      degree: json['degree'] as String,
      degreeDocUrl: json['degree_doc_url'] as String?,
      registrationNo: json['registration_no'] as String,
      medicalCouncil: json['medical_council'] as String,
      idProofUrl: json['id_proof_url'] as String?,
      hospital: json['hospital'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doctor_id': doctorId,
      'degree': degree,
      'degree_doc_url': degreeDocUrl,
      'registration_no': registrationNo,
      'medical_council': medicalCouncil,
      'id_proof_url': idProofUrl,
      'hospital': hospital,
    };
  }

  DoctorDetails copyWith({
    String? doctorId,
    String? degree,
    String? degreeDocUrl,
    String? registrationNo,
    String? medicalCouncil,
    String? idProofUrl,
    String? hospital,
  }) {
    return DoctorDetails(
      doctorId: doctorId ?? this.doctorId,
      degree: degree ?? this.degree,
      degreeDocUrl: degreeDocUrl ?? this.degreeDocUrl,
      registrationNo: registrationNo ?? this.registrationNo,
      medicalCouncil: medicalCouncil ?? this.medicalCouncil,
      idProofUrl: idProofUrl ?? this.idProofUrl,
      hospital: hospital ?? this.hospital,
    );
  }
}