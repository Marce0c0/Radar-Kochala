import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDbProvider {
  static final LocalDbProvider _instance = LocalDbProvider._internal();
  factory LocalDbProvider() => _instance;
  LocalDbProvider._internal();

  Database? _db;

  Future<Database?> get db async {
    if (kIsWeb) return null; // SQLite no soportado en Web sin configuración ffi extra
    if (_db != null) return _db;
    _db = await _initDb();
    return _db;
  }

  Future<Database> _initDb() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'offline_reports.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE offline_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            json_data TEXT
          )
        ''');
      },
    );
  }

  Future<void> enqueue(String json) async {
    if (kIsWeb) return;
    final database = await db;
    await database?.insert('offline_queue', {'json_data': json});
  }

  Future<List<Map<String, dynamic>>> getQueue() async {
    if (kIsWeb) return [];
    final database = await db;
    if (database == null) return [];
    return await database.query('offline_queue', orderBy: 'id ASC');
  }

  Future<void> deleteFromQueue(int id) async {
    if (kIsWeb) return;
    final database = await db;
    await database?.delete('offline_queue', where: 'id = ?', whereArgs: [id]);
  }
}
