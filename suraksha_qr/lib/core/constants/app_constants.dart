// App-wide constants
class AppConstants {
  static const String appName = 'Suraksha QR';
  static const String appDescription = 'Emergency QR Scanner';

  // Roles
  static const String roleUser = 'user';
  static const String roleDoctor = 'doctor';
  static const String roleAdmin = 'admin';

  // Verification statuses
  static const String statusPending = 'pending';
  static const String statusVerified = 'verified';
  static const String statusRejected = 'rejected';

  // Storage buckets
  static const String bucketProfilePhotos = 'profile-photos';
  static const String bucketUserDocuments = 'user-documents';
  static const String bucketDoctorDocuments = 'doctor-documents';

  // File constraints
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png'];
  static const List<String> allowedDocExtensions = ['pdf'];
  static const List<String> allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'pdf'
  ];

  // Validation
  static const int minAge = 1;
  static const int maxAge = 120;
  static const int phoneLength = 10;
  static const int minEmergencyContacts = 1;
  static const int maxEmergencyContacts = 3;

  // Blood groups
  static const List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

  // Common diseases
  static const List<String> commonDiseases = [
    'Diabetes',
    'BP',
    'Asthma',
    'Heart disease',
    'Epilepsy',
    'Other'
  ];
}