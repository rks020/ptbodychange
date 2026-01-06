class ClassSession {
  final String id;
  final String name;
  final String classType; // e.g., "Yoga", "HIIT", "Strength Training"
  final DateTime dateTime;
  final int durationMinutes;
  final String trainerId;
  final String trainerName;
  final int capacity;
  final List<String> enrolledMemberIds;
  final List<String> attendedMemberIds;
  final String? description;
  final String? location;
  
  ClassSession({
    required this.id,
    required this.name,
    required this.classType,
    required this.dateTime,
    required this.durationMinutes,
    required this.trainerId,
    required this.trainerName,
    required this.capacity,
    this.enrolledMemberIds = const [],
    this.attendedMemberIds = const [],
    this.description,
    this.location,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'classType': classType,
      'dateTime': dateTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'trainerId': trainerId,
      'trainerName': trainerName,
      'capacity': capacity,
      'enrolledMemberIds': enrolledMemberIds.join(','),
      'attendedMemberIds': attendedMemberIds.join(','),
      'description': description,
      'location': location,
    };
  }
  
  factory ClassSession.fromMap(Map<String, dynamic> map) {
    return ClassSession(
      id: map['id'] as String,
      name: map['name'] as String,
      classType: map['classType'] as String,
      dateTime: DateTime.parse(map['dateTime'] as String),
      durationMinutes: map['durationMinutes'] as int,
      trainerId: map['trainerId'] as String,
      trainerName: map['trainerName'] as String,
      capacity: map['capacity'] as int,
      enrolledMemberIds: (map['enrolledMemberIds'] as String).isNotEmpty
          ? (map['enrolledMemberIds'] as String).split(',')
          : [],
      attendedMemberIds: (map['attendedMemberIds'] as String).isNotEmpty
          ? (map['attendedMemberIds'] as String).split(',')
          : [],
      description: map['description'] as String?,
      location: map['location'] as String?,
    );
  }
  
  // Helper properties
  bool get isFull => enrolledMemberIds.length >= capacity;
  int get spotsRemaining => capacity - enrolledMemberIds.length;
  double get attendanceRate => enrolledMemberIds.isEmpty 
      ? 0.0 
      : (attendedMemberIds.length / enrolledMemberIds.length) * 100;
  bool get isUpcoming => dateTime.isAfter(DateTime.now());
  bool get isInProgress {
    final now = DateTime.now();
    final endTime = dateTime.add(Duration(minutes: durationMinutes));
    return now.isAfter(dateTime) && now.isBefore(endTime);
  }
  bool get isCompleted => dateTime.add(Duration(minutes: durationMinutes)).isBefore(DateTime.now());
  
  ClassSession copyWith({
    String? id,
    String? name,
    String? classType,
    DateTime? dateTime,
    int? durationMinutes,
    String? trainerId,
    String? trainerName,
    int? capacity,
    List<String>? enrolledMemberIds,
    List<String>? attendedMemberIds,
    String? description,
    String? location,
  }) {
    return ClassSession(
      id: id ?? this.id,
      name: name ?? this.name,
      classType: classType ?? this.classType,
      dateTime: dateTime ?? this.dateTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      trainerId: trainerId ?? this.trainerId,
      trainerName: trainerName ?? this.trainerName,
      capacity: capacity ?? this.capacity,
      enrolledMemberIds: enrolledMemberIds ?? this.enrolledMemberIds,
      attendedMemberIds: attendedMemberIds ?? this.attendedMemberIds,
      description: description ?? this.description,
      location: location ?? this.location,
    );
  }
}
