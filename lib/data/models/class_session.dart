class ClassSession {
  final String? id;
  final String title;
  final String? description;
  final String? trainerId;
  final DateTime startTime;
  final DateTime endTime;
  final int capacity;
  final bool isCancelled;
  final DateTime? createdAt;
  final String status; // 'scheduled', 'completed', 'cancelled'
  final String? trainerSignatureUrl;
  final String? trainerName;
  
  // Extension for calculating duration
  int get durationMinutes => endTime.difference(startTime).inMinutes;

  final String? workoutId;
  final String? workoutName;
  final int currentEnrollments;
  final bool isPublic;

  ClassSession({
    this.id,
    required this.title,
    this.description,
    this.trainerId,
    required this.startTime,
    required this.endTime,
    this.capacity = 10,
    this.isCancelled = false,
    this.createdAt,
    this.status = 'scheduled',
    this.trainerSignatureUrl,
    this.trainerName,
    this.workoutId,
    this.workoutName,
    this.currentEnrollments = 0,
    this.isPublic = false,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'trainer_id': trainerId,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'capacity': capacity,
      'is_cancelled': isCancelled,
      'status': status,
      'trainer_signature_url': trainerSignatureUrl,
      'workout_id': workoutId,
      'is_public': isPublic,
    };
  }

  factory ClassSession.fromJson(Map<String, dynamic> json) {
    return ClassSession(
      id: json['id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      trainerId: json['trainer_id'] as String?,
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: DateTime.parse(json['end_time'] as String).toLocal(),
      capacity: json['capacity'] as int,
      isCancelled: json['is_cancelled'] as bool? ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String).toLocal() 
          : null,
      status: json['status'] as String? ?? 'scheduled',
      trainerSignatureUrl: json['trainer_signature_url'] as String?,
      trainerName: json['profiles'] != null
          ? '${json['profiles']['first_name'] ?? ''} ${json['profiles']['last_name'] ?? ''}'.trim()
          : null,
      workoutId: json['workout_id'] as String?,
      workoutName: json['workouts'] != null ? json['workouts']['name'] as String? : null,
      currentEnrollments: json['enrollments_count'] ?? 0,
      isPublic: json['is_public'] as bool? ?? false,
    );
  }
}
