// AppProfile model
class AppProfile {
  final String id;
  final String role;
  final String? fullName;
  final String? photoUrl;
  final String? phone;
  final String? gender;
  final int? age;
  final String verificationStatus;
  final String? rejectionReason;
  final String qrToken;
  final DateTime createdAt;

  AppProfile({
    required this.id,
    required this.role,
    this.fullName,
    this.photoUrl,
    this.phone,
    this.gender,
    this.age,
    required this.verificationStatus,
    this.rejectionReason,
    required this.qrToken,
    required this.createdAt,
  });

  factory AppProfile.fromJson(Map<String, dynamic> json) {
    return AppProfile(
      id: json['id'] as String,
      role: json['role'] as String,
      fullName: json['full_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      phone: json['phone'] as String?,
      gender: json['gender'] as String?,
      age: json['age'] as int?,
      verificationStatus: json['verification_status'] as String,
      rejectionReason: json['rejection_reason'] as String?,
      qrToken: json['qr_token'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'full_name': fullName,
      'photo_url': photoUrl,
      'phone': phone,
      'gender': gender,
      'age': age,
      'verification_status': verificationStatus,
      'rejection_reason': rejectionReason,
      'qr_token': qrToken,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppProfile copyWith({
    String? id,
    String? role,
    String? fullName,
    String? photoUrl,
    String? phone,
    String? gender,
    int? age,
    String? verificationStatus,
    String? rejectionReason,
    String? qrToken,
    DateTime? createdAt,
  }) {
    return AppProfile(
      id: id ?? this.id,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      qrToken: qrToken ?? this.qrToken,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isVerified => verificationStatus == 'verified';
  bool get isPending => verificationStatus == 'pending';
  bool get isRejected => verificationStatus == 'rejected';
  bool get isUser => role == 'user';
  bool get isDoctor => role == 'doctor';
  bool get isAdmin => role == 'admin';
}