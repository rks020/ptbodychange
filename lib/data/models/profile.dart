class Profile {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? profession;
  final int? age;
  final String? hobbies;
  final String? avatarUrl;
  final String? role;
  final String? organizationId;
  final String? organizationName; // Restored
  final String? specialty; // Restored
  final DateTime? updatedAt; // Restored
  final DateTime? createdAt; // Restored
  final bool passwordChanged;
  final bool? isOnline;
  final DateTime? lastSeen;

  Profile({
    required this.id,
    this.firstName,
    this.lastName,
    this.profession,
    this.age,
    this.hobbies,
    this.avatarUrl,
    this.role,
    this.organizationId,
    this.organizationName,
    this.specialty,
    this.updatedAt,
    this.createdAt,
    this.passwordChanged = true,
    this.isOnline = false,
    this.lastSeen,
  });

  factory Profile.fromSupabase(Map<String, dynamic> map) {
    // Extract organization name safely
    String? orgName;
    if (map['organizations'] != null && map['organizations'] is Map) {
      orgName = map['organizations']['name'];
    }

    return Profile(
      id: map['id'] ?? '',
      firstName: map['first_name'],
      lastName: map['last_name'],
      profession: map['profession'],
      age: map['age'],
      hobbies: map['hobbies'],
      avatarUrl: map['avatar_url'],
      role: map['role'],
      organizationId: map['organization_id'],
      organizationName: orgName, // Mapped
      specialty: map['specialty'],
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']).toLocal() 
          : null,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']).toLocal() 
          : null,
      passwordChanged: map['password_changed'] as bool? ?? true,
      isOnline: map['is_online'] as bool? ?? false,
      lastSeen: map['last_seen'] != null 
          ? DateTime.parse(map['last_seen']).toLocal() 
          : null,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'profession': profession,
      'age': age,
      'hobbies': hobbies,
      'avatar_url': avatarUrl,
      'organization_id': organizationId, 
      'specialty': specialty,
      'password_changed': passwordChanged,
      'is_online': isOnline,
      'last_seen': lastSeen?.toUtc().toIso8601String(),
      // 'role': role, 
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      // created_at is automatic on insert
    };
  }
}
