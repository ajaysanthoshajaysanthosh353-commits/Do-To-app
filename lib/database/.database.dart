import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../model/task.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('todo_tasks.db');

    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    // Uses whichever databaseFactory was set in main() (web / desktop / mobile)
    final dbPath = await databaseFactory.getDatabasesPath();

    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            date TEXT NOT NULL,
            isCompleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  // INSERT TASK
  Future<int> insertTask(Task task) async {
    final db = await database;

    return await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // GET ALL TASKS
  Future<List<Task>> getTasks() async {
    final db = await database;

    final result = await db.query('tasks', orderBy: 'date ASC, id DESC');

    return result.map((map) => Task.fromMap(map)).toList();
  }

  // Same as getTasks (name used in main.dart)
  Future<List<Task>> getAllTasks() => getTasks();

  // UPDATE TASK
  Future<int> updateTask(Task task) async {
    final db = await database;

    return await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  // DELETE TASK
  Future<int> deleteTask(int id) async {
    final db = await database;

    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // CLOSE DATABASE
  Future<void> closeDatabase() async {
    final db = await database;

    await db.close();

    _database = null;
  }
}
