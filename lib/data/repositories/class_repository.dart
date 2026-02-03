import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/class_session.dart';
import '../models/class_enrollment.dart';

class ClassRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Upload signature
  Future<String> uploadSignature(Uint8List bytes) async {
    final fileName = 'sig_${DateTime.now().millisecondsSinceEpoch}.png';
    // Just file name, bucket is flat
    final path = fileName;
    
    await _client.storage.from('signatures').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(contentType: 'image/png'),
    );
    
    return _client.storage.from('signatures').getPublicUrl(path);
  }

  // --- Sessions ---

  // Get sessions within a date range
  Future<List<ClassSession>> getSessions(DateTime start, DateTime end) async {
    final response = await _client
        .from('class_sessions')
        .select('*, profiles(first_name, last_name), workouts(name)')
        .gte('start_time', start.toUtc().toIso8601String())
        .lte('end_time', end.toUtc().toIso8601String())
        .order('start_time', ascending: true);
    
    return (response as List)
        .map((json) => ClassSession.fromJson(json))
        .toList();
  }

  // Create a new session
  Future<ClassSession> createSession(ClassSession session) async {
    final response = await _client
        .from('class_sessions')
        .insert(session.toJson())
        .select()
        .single();
    
    return ClassSession.fromJson(response);
  }

  // Update session
  Future<void> updateSession(ClassSession session) async {
    await _client
        .from('class_sessions')
        .update(session.toJson())
        .eq('id', session.id!);
  }

  // Cancel/Delete session
  Future<void> deleteSession(String id) async {
    await _client.from('class_sessions').delete().eq('id', id);
  }

  // Get single session
  Future<ClassSession> getSession(String id) async {
    final response = await _client
        .from('class_sessions')
        .select('*, profiles(first_name, last_name), workouts(name)')
        .eq('id', id)
        .single();
    
    return ClassSession.fromJson(response);
  }

  // Delete future sessions (Series)
  Future<void> deleteSeries(String title, String trainerId) async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    await _client
        .from('class_sessions')
        .delete()
        .eq('title', title)
        .eq('trainer_id', trainerId)
        .gte('start_time', startOfToday)
        .neq('status', 'completed'); // Don't delete completed ones
  }

  // Complete session and deduct from package
  Future<void> completeSession(String id, String? signatureUrl) async {
    // 1. Update session status
    await _client.from('class_sessions').update({
      'status': 'completed',
      'trainer_signature_url': signatureUrl,
    }).eq('id', id);

    // 2. Deduct sessions for attended members
    await _client.rpc('deduct_sessions_for_class', params: {'session_id': id});
  }

  // Update session time (Delay)
  Future<void> updateSessionTime(String id, DateTime newStart, DateTime newEnd) async {
    await _client.from('class_sessions').update({
      'start_time': newStart.toUtc().toIso8601String(),
      'end_time': newEnd.toUtc().toIso8601String(),
    }).eq('id', id);
  }

  // --- Enrollments ---

  // Get enrollments for a specific class
  Future<List<ClassEnrollment>> getEnrollments(String classId) async {
    final response = await _client
        .from('class_enrollments')
        .select('*, members(*)') // Fetch member details
        .eq('class_id', classId)
        .order('created_at', ascending: true);
    
    return (response as List)
        .map((json) => ClassEnrollment.fromSupabaseMap(json))
        .toList();
  }

  // Enroll a member
  Future<void> enrollMember(String classId, String memberId) async {
    await _client.from('class_enrollments').insert({
      'class_id': classId,
      'member_id': memberId,
      'status': 'booked',
    });
  }

  // Update enrollment status (attended, cancelled, etc.)
  Future<void> updateEnrollmentStatus(String enrollmentId, String status) async {
    await _client
        .from('class_enrollments')
        .update({'status': status})
        .eq('id', enrollmentId);
  }

  // Remove enrollment
  Future<void> removeEnrollment(String enrollmentId) async {
    await _client.from('class_enrollments').delete().eq('id', enrollmentId);
  }

  // Update enrollment signature
  Future<void> updateEnrollmentSignature(String enrollmentId, String signatureUrl) async {
    await _client.from('class_enrollments').update({
      'student_signature_url': signatureUrl,
    }).eq('id', enrollmentId);
  }

  // Check capacity
  Future<int> getEnrollmentCount(String classId) async {
    final response = await _client
        .from('class_enrollments')
        .select('*')
        .eq('class_id', classId)
        .count();
    return response.count;
  }

  // Get count of sessions for today
  Future<int> getTodaySessionCount() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final response = await _client
        .from('class_sessions')
        .select('*')
        .gte('start_time', startOfDay.toUtc().toIso8601String())
        .lte('end_time', endOfDay.toUtc().toIso8601String())
        .count();
        
    return response.count;
  }


  // Get upcoming classes for a member
  Future<List<ClassSession>> getMemberUpcomingClasses(String memberId) async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    
    // We need to join enrollments with sessions and filter
    final response = await _client
        .from('class_enrollments')
        .select('class_sessions!inner(*)')
        .eq('member_id', memberId)
        .gte('class_sessions.start_time', startOfToday)
        .neq('status', 'cancelled')
        .order('class_sessions(start_time)', ascending: true);

    return (response as List)
        .map((e) => ClassSession.fromJson(e['class_sessions'] as Map<String, dynamic>))
        .toList();
  }

  // Check if member has any upcoming scheduled classes
  Future<bool> hasUpcomingSchedule(String memberId) async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    
    final response = await _client
        .from('class_enrollments')
        .select('id')
        .eq('member_id', memberId)
        .gte('class_sessions.start_time', startOfToday)
        .neq('status', 'cancelled')
        .limit(1);
    
    return (response as List).isNotEmpty;
  }

  // Get completed history (Signature Log)
  Future<List<ClassSession>> getCompletedHistory() async {
    final response = await _client
        .from('class_sessions')
        .select('*, class_enrollments(*, members(name, photo_url))') // Fetch enrollments and member names
        .eq('status', 'completed')
        .order('start_time', ascending: false);

    return (response as List)
        .map((e) {
             final session = ClassSession.fromJson(e);
             // Manually attach enrollments if needed, or rely on UI fetching them separately.
             // But wait, ClassSession doesn't store enrollments list.
             // We might need a DTO or just return list of Maps if complex, 
             // but cleaner is to return ClassSession and fetch enrollments or extend ClassSession.
             // For now, let's keep it simple: The UI might need to fetch enrollments per session or we extend ClassSession?
             // Actually, `ClassSession` model doesn't have `enrollments` list.
             // I will modify this to just return sessions, and let UI fetch enrollments, OR
             // better: Modify ClassSession to include optional `enrollments`.
             // Providing `enrollments` in ClassSession is better for performance (1 query).
             return session; 
        }) 
        .toList();
  }

  // Get completed history with enrollments
  Future<List<Map<String, dynamic>>> getCompletedHistoryWithDetails({String? trainerId}) async {
    var query = _client
        .from('class_sessions')
        .select('*, class_enrollments(*, members(name, photo_url))')
        .eq('status', 'completed');

    if (trainerId != null) {
      query = query.eq('trainer_id', trainerId);
    }

    final response = await query.order('start_time', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  // Get completed history for a specific member
  Future<List<Map<String, dynamic>>> getMemberCompletedHistory(String memberId) async {
    // We need to fetch sessions where this member is enrolled AND status is completed.
    // Querying through class_enrollments is easier.
    final response = await _client
        .from('class_enrollments')
        .select('''
          *,
          class_sessions!inner(*),
          members(name, photo_url)
        ''')
        .eq('member_id', memberId)
        .eq('class_sessions.status', 'completed') // specific status filter on joined table
        .order('created_at', ascending: false);
    
    // Transform to match the structure expected by the UI (List of Sessions)
    // The UI expects a list of Session objects which contain 'class_enrollments'.
    // Here we have specific enrollments. We should reconstruct the session object
    // and attach the enrollment to it.
    
    return (response as List).map((enrollment) {
      final session = enrollment['class_sessions'] as Map<String, dynamic>;
      // Attach this specific enrollment to the session so the UI shows it
      // Note: The UI expects 'class_enrollments' to be a list
      session['class_enrollments'] = [enrollment];
      return session;
    }).toList();
  }

  // Check for conflicting sessions
  Future<List<Map<String, dynamic>>> findConflictingSessions(DateTime start, DateTime end) async {
    final startStr = start.toUtc().toIso8601String();
    final endStr = end.toUtc().toIso8601String();

    // Overlap formula: (StartA < EndB) and (EndA > StartB)
    final response = await _client
        .from('class_sessions')
        .select()
        .neq('status', 'cancelled') // Ignore cancelled
        .lt('start_time', endStr)
        .gt('end_time', startStr);
    
    return List<Map<String, dynamic>>.from(response);
  }

  // Get conflict details with trainer and member information
  Future<List<Map<String, dynamic>>> findConflictsWithDetails(
    DateTime start, 
    DateTime end,
    {String? excludeTrainerId}
  ) async {
    final startStr = start.toUtc().toIso8601String();
    final endStr = end.toUtc().toIso8601String();

    // Query sessions with trainer profile and enrollments
    var query = _client
        .from('class_sessions')
        .select('''
          *,
          profiles!trainer_id(first_name, last_name),
          class_enrollments(
            id,
            member_id,
            members(name)
          )
        ''')
        .neq('status', 'cancelled')
        .lt('start_time', endStr)
        .gt('end_time', startStr);

    // Exclude current trainer's sessions if provided
    if (excludeTrainerId != null) {
      query = query.neq('trainer_id', excludeTrainerId);
    }

    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }

  // Find next available slot for a given day
  Future<DateTime?> findNextAvailableSlot(DateTime date, int durationMinutes) async {
    // Search between 09:00 and 22:00
    final startOfDay = DateTime(date.year, date.month, date.day);
    var searchTime = startOfDay.add(const Duration(hours: 9)); 
    final endLimit = startOfDay.add(const Duration(hours: 22));

    // Get all sessions for that day
    final response = await _client
        .from('class_sessions')
        .select('start_time, end_time')
        .neq('status', 'cancelled')
        .lt('start_time', startOfDay.add(const Duration(days: 1)).toIso8601String())
        .gte('end_time', startOfDay.toIso8601String())
        .order('start_time');

    final sessions = List<Map<String, dynamic>>.from(response);

    while (searchTime.add(Duration(minutes: durationMinutes)).isBefore(endLimit)) {
      final potentialEnd = searchTime.add(Duration(minutes: durationMinutes));
      bool hasConflict = false;

      for (final session in sessions) {
        final SessionStart = DateTime.parse(session['start_time']).toLocal();
        final SessionEnd = DateTime.parse(session['end_time']).toLocal();

        if (searchTime.isBefore(SessionEnd) && potentialEnd.isAfter(SessionStart)) {
          hasConflict = true;
          // Jump to end of conflicting session to optimize search
          if (SessionEnd.isAfter(searchTime)) {
             searchTime = SessionEnd;
          }
          break;
        }
      }

      if (!hasConflict) {
        return searchTime;
      }
      
      // If we didn't jump, move forward by 30 mins
      if (hasConflict) {
         // Determine next check time (round to next 30 min)
         final minutes = searchTime.minute;
         final remainder = minutes % 30;
         final addMinutes = 30 - remainder;
         searchTime = searchTime.add(Duration(minutes: addMinutes));
      }
    }

    return null;
  }
}

