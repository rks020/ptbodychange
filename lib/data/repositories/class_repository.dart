import '../local/database_helper.dart';
import '../models/class_session.dart';

class ClassRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Create
  Future<void> create(ClassSession classSession) async {
    final db = await _dbHelper.database;
    await db.insert('class_sessions', classSession.toMap());
  }

  // Get all classes
  Future<List<ClassSession>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'class_sessions',
      orderBy: 'dateTime DESC',
    );
    return List.generate(maps.length, (i) => ClassSession.fromMap(maps[i]));
  }

  // Get upcoming classes
  Future<List<ClassSession>> getUpcoming() async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final List<Map<String, dynamic>> maps = await db.query(
      'class_sessions',
      where: 'dateTime >= ?',
      whereArgs: [now],
      orderBy: 'dateTime ASC',
    );
    return List.generate(maps.length, (i) => ClassSession.fromMap(maps[i]));
  }

  // Get classes for a specific date
  Future<List<ClassSession>> getByDate(DateTime date) async {
    final db = await _dbHelper.database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    final List<Map<String, dynamic>> maps = await db.query(
      'class_sessions',
      where: 'dateTime >= ? AND dateTime <= ?',
      whereArgs: [
        startOfDay.toIso8601String(),
        endOfDay.toIso8601String(),
      ],
      orderBy: 'dateTime ASC',
    );
    return List.generate(maps.length, (i) => ClassSession.fromMap(maps[i]));
  }

  // Get classes by date range
  Future<List<ClassSession>> getByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'class_sessions',
      where: 'dateTime >= ? AND dateTime <= ?',
      whereArgs: [
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'dateTime ASC',
    );
    return List.generate(maps.length, (i) => ClassSession.fromMap(maps[i]));
  }

  // Get class by ID
  Future<ClassSession?> getById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'class_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return ClassSession.fromMap(maps.first);
  }

  // Get classes for a member
  Future<List<ClassSession>> getByMemberId(String memberId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT * FROM class_sessions 
      WHERE enrolledMemberIds LIKE ? 
      ORDER BY dateTime DESC
      ''',
      ['%$memberId%'],
    );
    return List.generate(maps.length, (i) => ClassSession.fromMap(maps[i]));
  }

  // Update
  Future<void> update(ClassSession classSession) async {
    final db = await _dbHelper.database;
    await db.update(
      'class_sessions',
      classSession.toMap(),
      where: 'id = ?',
      whereArgs: [classSession.id],
    );
  }

  // Delete
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'class_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Enroll member
  Future<void> enrollMember(String classId, String memberId) async {
    final classSession = await getById(classId);
    if (classSession == null) return;
    
    if (!classSession.enrolledMemberIds.contains(memberId)) {
      final updatedClass = classSession.copyWith(
        enrolledMemberIds: [...classSession.enrolledMemberIds, memberId],
      );
      await update(updatedClass);
    }
  }

  // Unenroll member
  Future<void> unenrollMember(String classId, String memberId) async {
    final classSession = await getById(classId);
    if (classSession == null) return;
    
    final updatedEnrolled = classSession.enrolledMemberIds
        .where((id) => id != memberId)
        .toList();
    final updatedAttended = classSession.attendedMemberIds
        .where((id) => id != memberId)
        .toList();
    
    final updatedClass = classSession.copyWith(
      enrolledMemberIds: updatedEnrolled,
      attendedMemberIds: updatedAttended,
    );
    await update(updatedClass);
  }

  // Mark attendance
  Future<void> markAttendance(String classId, String memberId, bool attended) async {
    final classSession = await getById(classId);
    if (classSession == null) return;
    
    List<String> updatedAttended = [...classSession.attendedMemberIds];
    
    if (attended && !updatedAttended.contains(memberId)) {
      updatedAttended.add(memberId);
    } else if (!attended) {
      updatedAttended.remove(memberId);
    }
    
    final updatedClass = classSession.copyWith(
      attendedMemberIds: updatedAttended,
    );
    await update(updatedClass);
  }

  // Get today's classes count
  Future<int> getTodayCount() async {
    final today = DateTime.now();
    final classes = await getByDate(today);
    return classes.length;
  }
}
