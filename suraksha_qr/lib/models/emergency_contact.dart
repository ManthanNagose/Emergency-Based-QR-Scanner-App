// EmergencyContact model
class EmergencyContact {
  final String id;
  final String userId;
  final String name;
  final String relation;
  final String phone;

  EmergencyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.relation,
    required this.phone,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      relation: json['relation'] as String,
      phone: json['phone'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'relation': relation,
      'phone': phone,
    };
  }

  EmergencyContact copyWith({
    String? id,
    String? userId,
    String? name,
    String? relation,
    String? phone,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      phone: phone ?? this.phone,
    );
  }
}