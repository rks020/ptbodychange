import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/assigned_workout_model.dart';
import '../../../data/repositories/profile_repository.dart';

class WorkoutAssignmentRepository {
  final _supabase = Supabase.instance.client;

  Future<void> assignWorkout({
    required String memberId,
    required String workoutId,
    required DateTime date,
  }) async {
    final profile = await ProfileRepository().getProfile();
    final orgId = profile?.organizationId;
    if (orgId == null) throw Exception('Organization ID not found');

    await _supabase.from('assigned_workouts').insert({
      'organization_id': orgId,
      'member_id': memberId,
      'workout_id': workoutId,
      'assigned_by': _supabase.auth.currentUser!.id,
      'assigned_date': date.toIso8601String().split('T')[0], // YYYY-MM-DD
    });
  }

  Future<List<AssignedWorkout>> getMemberWorkouts(String memberId) async {
    // 1. Fetch Manual Assignments
    final manualResponse = await _supabase
        .from('assigned_workouts')
        .select('*, workouts(name)')
        .eq('member_id', memberId)
        .order('assigned_date', ascending: false);

    final manualAssignments = (manualResponse as List)
        .map((e) => AssignedWorkout.fromJson(e))
        .toList();

    // 2. Fetch Class Workouts
    // We need enrollments for this member where the session has a workout assigned
    final classResponse = await _supabase
        .from('class_enrollments')
        .select('*, class_sessions!inner(*, workouts(name))')
        .eq('member_id', memberId)
        // .not('class_sessions.workout_id', 'is', null) // Only sessions with workouts
        .order('created_at', ascending: false);

    final classAssignments = (classResponse as List).map((e) {
      final session = e['class_sessions'];
      return AssignedWorkout.fromClassSession(session, memberId);
    }).toList();

    // 3. Merge and Sort
    final allAssignments = [...manualAssignments, ...classAssignments];
    allAssignments.sort((a, b) => b.assignedDate.compareTo(a.assignedDate));

    return allAssignments;
  }
  
  Future<void> completeWorkout(String assignmentId, {String? feedback}) async {
    await _supabase.from('assigned_workouts').update({
      'is_completed': true,
      'completed_at': DateTime.now().toIso8601String(),
      'feedback': feedback
    }).eq('id', assignmentId);
  }
}
