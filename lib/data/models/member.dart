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
  final int? sessionCount;
  final String? organizationId;
  final bool passwordChanged; // TRUE = user has changed password, FALSE = still using temp password
  final bool isMultisport; // Added field

  
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
    this.sessionCount,
    this.organizationId,
    this.passwordChanged = true, // Default to true (assume password changed)
    this.isMultisport = false, // Default false
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
      'session_count': sessionCount,
      'is_multisport': isMultisport,
    };
  }
  
  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String? ?? '',
      photoPath: map['photoPath'] as String?,
      isActive: (map['isActive'] as int) == 1,
      joinDate: DateTime.parse(map['joinDate'] as String),
      emergencyContact: map['emergencyContact'] as String?,
      emergencyPhone: map['emergencyPhone'] as String?,
      notes: map['notes'] as String?,
      subscriptionPackage: map['subscription_package'] as String?,
      sessionCount: map['session_count'] as int?,
      passwordChanged: map['passwordChanged'] as bool? ?? true,
      isMultisport: (map['is_multisport'] ?? map['isMultisport']) as bool? ?? false,
    );
  }

  // Supabase uses snake_case
  factory Member.fromSupabaseMap(Map<String, dynamic> map) {
    // Check if profiles data is joined and available
    
    // Check if profiles data is joined and available
    // It might be in 'profiles' object or flat if view
    // Based on repository query, it will be in 'profiles' object if joined by id
    // BUT we already join 'profiles' for trainer_id.
    // We need to differentiate the joins in Repository.
    // For now, let's assume we map it from 'profile_data' or similar if we alias it.
    
    // Check for password_changed in top level (if view) or joined profile
    bool pwdChanged = true; // Default: assume password changed
    if (map['password_changed'] != null) {
        pwdChanged = map['password_changed'] as bool;
    } else if (map['auth_profile'] != null) {
        pwdChanged = map['auth_profile']['password_changed'] as bool? ?? true;
    } else {
        // Default: assume password changed
    }

    return Member(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String? ?? '',
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
      sessionCount: map['session_count'] as int?,
      organizationId: map['organization_id'] as String?,
      passwordChanged: pwdChanged,
      isMultisport: (map['is_multisport'] ?? false) as bool,
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
    int? sessionCount,
    String? organizationId,
    bool? passwordChanged,
    bool? isMultisport,
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
      sessionCount: sessionCount ?? this.sessionCount,
      organizationId: organizationId ?? this.organizationId,
      passwordChanged: passwordChanged ?? this.passwordChanged,
      isMultisport: isMultisport ?? this.isMultisport,
    );
  }
}
