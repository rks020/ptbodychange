class AssignedWorkout {
  final String id;
  final String organizationId;
  final String? workoutId;
  final String memberId;
  final String? assignedBy;
  final DateTime assignedDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? feedback;
  final DateTime createdAt;
  
  // Joins
  final String? workoutName;
  final String source; // 'manual' | 'class'
  final String? classSessionId;

  AssignedWorkout({
    required this.id,
    required this.organizationId,
    this.workoutId,
    required this.memberId,
    this.assignedBy,
    required this.assignedDate,
    this.isCompleted = false,
    this.completedAt,
    this.feedback,
    required this.createdAt,
    this.workoutName,
    this.source = 'manual',
    this.classSessionId,
  });

  factory AssignedWorkout.fromJson(Map<String, dynamic> json) {
    return AssignedWorkout(
      id: json['id'],
      organizationId: json['organization_id'],
      workoutId: json['workout_id'],
      memberId: json['member_id'],
      assignedBy: json['assigned_by'],
      assignedDate: DateTime.parse(json['assigned_date']),
      isCompleted: json['is_completed'] ?? false,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      feedback: json['feedback'],
      createdAt: DateTime.parse(json['created_at']),
      workoutName: json['workouts'] != null ? json['workouts']['name'] : null,
      source: 'manual',
    );
  }

  factory AssignedWorkout.fromClassSession(Map<String, dynamic> session, String memberId) {
    return AssignedWorkout(
      id: session['id'], // Use session ID as the main ID for these entries? NO, use session ID.
      organizationId: session['organization_id'] ?? '', // Might be missing, handle gracefully
      workoutId: session['workout_id'],
      memberId: memberId,
      assignedBy: session['trainer_id'],
      assignedDate: DateTime.parse(session['start_time']),
      isCompleted: session['status'] == 'completed',
      // createdAt: DateTime.parse(session['created_at']), 
      createdAt: DateTime.parse(session['created_at'] ?? DateTime.now().toIso8601String()),
      workoutName: session['workouts'] != null ? session['workouts']['name'] : 'Ders Programı',
      source: 'class',
      classSessionId: session['id'],
    );
  }
}
