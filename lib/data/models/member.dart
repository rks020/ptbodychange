class Member {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? photoPath;
  final bool isActive;
  final DateTime joinDate;
  final String? emergencyContact;
  final String? emergencyPhone;
  final String? notes;
  final String? trainerId;
  final String? trainerName;
  final String? subscriptionPackage;
  
  Member({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.photoPath,
    this.isActive = true,
    required this.joinDate,
    this.emergencyContact,
    this.emergencyPhone,
    this.notes,
    this.trainerId,
    this.trainerName,
    this.subscriptionPackage,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'photoPath': photoPath,
      'isActive': isActive ? 1 : 0,
      'joinDate': joinDate.toIso8601String(),
      'emergencyContact': emergencyContact,
      'emergencyPhone': emergencyPhone,
      'notes': notes,
      'subscription_package': subscriptionPackage,
    };
  }
  
  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      photoPath: map['photoPath'] as String?,
      isActive: (map['isActive'] as int) == 1,
      joinDate: DateTime.parse(map['joinDate'] as String),
      emergencyContact: map['emergencyContact'] as String?,
      emergencyPhone: map['emergencyPhone'] as String?,
      notes: map['notes'] as String?,
      subscriptionPackage: map['subscription_package'] as String?,
    );
  }

  // Supabase uses snake_case
  factory Member.fromSupabaseMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      photoPath: map['photo_url'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      joinDate: DateTime.parse(map['join_date'] as String),
      emergencyContact: map['emergency_contact'] as String?,
      emergencyPhone: map['emergency_phone'] as String?,
      notes: map['notes'] as String?,
      trainerId: map['trainer_id'] as String?,
      trainerName: map['profiles'] != null 
          ? '${map['profiles']['first_name'] ?? ''} ${map['profiles']['last_name'] ?? ''}'.trim()
          : null,
      subscriptionPackage: map['subscription_package'] as String?,
    );
  }
  
  Member copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? photoPath,
    bool? isActive,
    DateTime? joinDate,
    String? emergencyContact,
    String? emergencyPhone,
    String? notes,
    String? subscriptionPackage,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoPath: photoPath ?? this.photoPath,
      isActive: isActive ?? this.isActive,
      joinDate: joinDate ?? this.joinDate,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      notes: notes ?? this.notes,
      subscriptionPackage: subscriptionPackage ?? this.subscriptionPackage,
    );
  }
}
