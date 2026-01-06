import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pt_body_change.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Members Table
    await db.execute('''
      CREATE TABLE members (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT NOT NULL,
        photoPath TEXT,
        isActive INTEGER NOT NULL DEFAULT 1,
        joinDate TEXT NOT NULL,
        emergencyContact TEXT,
        emergencyPhone TEXT,
        notes TEXT
      )
    ''');

    // Measurements Table
    await db.execute('''
      CREATE TABLE measurements (
        id TEXT PRIMARY KEY,
        memberId TEXT NOT NULL,
        date TEXT NOT NULL,
        weight REAL NOT NULL,
        height REAL NOT NULL,
        bodyFatPercentage REAL,
        chest REAL,
        waist REAL,
        hips REAL,
        leftArm REAL,
        rightArm REAL,
        leftThigh REAL,
        rightThigh REAL,
        leftCalf REAL,
        rightCalf REAL,
        shoulders REAL,
        neck REAL,
        frontPhotoPath TEXT,
        sidePhotoPath TEXT,
        backPhotoPath TEXT,
        notes TEXT,
        FOREIGN KEY (memberId) REFERENCES members (id) ON DELETE CASCADE
      )
    ''');

    // Class Sessions Table
    await db.execute('''
      CREATE TABLE class_sessions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        classType TEXT NOT NULL,
        dateTime TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL,
        trainerId TEXT NOT NULL,
        trainerName TEXT NOT NULL,
        capacity INTEGER NOT NULL,
        enrolledMemberIds TEXT,
        attendedMemberIds TEXT,
        description TEXT,
        location TEXT
      )
    ''');

    // Create indexes for better query performance
    await db.execute('CREATE INDEX idx_measurements_member ON measurements(memberId)');
    await db.execute('CREATE INDEX idx_measurements_date ON measurements(date)');
    await db.execute('CREATE INDEX idx_class_sessions_date ON class_sessions(dateTime)');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
