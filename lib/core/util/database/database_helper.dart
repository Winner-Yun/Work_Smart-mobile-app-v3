import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static const Duration _defaultSessionDuration = Duration(days: 1);

  static Database? _database;

  /// =========================
  /// DATABASE (MOBILE ONLY)
  /// =========================
  Future<Database?> get database async {
    if (kIsWeb) return null; // Web does not use SQLite
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'worksmart_config.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE login_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            password TEXT NOT NULL,
            user_type TEXT NOT NULL,
            user_id TEXT NOT NULL,
            session_token TEXT NOT NULL,
            session_expires_at INTEGER NOT NULL,
            session_issued_at INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 4) {
          try {
            await db.execute(
              'ALTER TABLE login_cache ADD COLUMN session_token TEXT',
            );
          } on DatabaseException catch (e) {
            e.toString();
          }

          try {
            await db.execute(
              'ALTER TABLE login_cache ADD COLUMN session_expires_at INTEGER',
            );
          } on DatabaseException catch (e) {
            e.toString();
          }

          try {
            await db.execute(
              'ALTER TABLE login_cache ADD COLUMN session_issued_at INTEGER',
            );
          } on DatabaseException catch (e) {
            e.toString();
          }
        }
      },
    );
  }

  /// =========================
  /// SETTINGS
  /// =========================
  Future<void> saveConfig(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      final db = await database;
      await db!.insert('settings', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<String?> getConfig(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      final db = await database;
      final maps = await db!.query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
      );

      if (maps.isNotEmpty) {
        return maps.first['value'] as String;
      }
      return null;
    }
  }

  /// =========================
  /// LOGIN CACHE
  /// =========================
  Future<void> saveCachedLogin(
    String username,
    String password,
    String userId,
    String userType, {
    DateTime? sessionExpiresAt,
  }) async {
    final issuedAt = DateTime.now().toUtc();
    final expiresAt =
        (sessionExpiresAt ?? issuedAt.add(_defaultSessionDuration)).toUtc();

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      await prefs.setString('password', password);
      await prefs.setString('user_id', userId);
      await prefs.setString('user_type', userType);
      await prefs.remove('session_token');
      await prefs.setInt(
        'session_expires_at',
        expiresAt.millisecondsSinceEpoch,
      );
      await prefs.setInt('session_issued_at', issuedAt.millisecondsSinceEpoch);
    } else {
      final db = await database;
      await db!.delete('login_cache');
      await db.insert('login_cache', {
        'username': username,
        'password': password,
        'user_id': userId,
        'user_type': userType,
        'session_token': '',
        'session_expires_at': expiresAt.millisecondsSinceEpoch,
        'session_issued_at': issuedAt.millisecondsSinceEpoch,
      });
    }
  }

  Future<Map<String, dynamic>?> getCachedLogin() async {
    Map<String, dynamic>? rawCache;

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');
      final password = prefs.getString('password');
      final userId = prefs.getString('user_id');
      final userType = prefs.getString('user_type');

      if (username == null ||
          password == null ||
          userId == null ||
          userType == null) {
        return null;
      }

      rawCache = {
        'username': username,
        'password': password,
        'user_id': userId,
        'user_type': userType,
        'session_expires_at': prefs.getInt('session_expires_at'),
        'session_issued_at': prefs.getInt('session_issued_at'),
      };
    } else {
      final db = await database;
      final maps = await db!.query('login_cache');

      if (maps.isNotEmpty) {
        rawCache = Map<String, dynamic>.from(maps.first);
      }
    }

    if (rawCache == null) return null;
    return _normalizeAndValidateCache(rawCache);
  }

  Future<void> clearCachedLogin() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('username');
      await prefs.remove('password');
      await prefs.remove('user_id');
      await prefs.remove('user_type');
      await prefs.remove('session_token');
      await prefs.remove('session_expires_at');
      await prefs.remove('session_issued_at');
    } else {
      final db = await database;
      await db!.delete('login_cache');
    }
  }

  Future<Map<String, dynamic>?> _normalizeAndValidateCache(
    Map<String, dynamic> rawCache,
  ) async {
    final username = rawCache['username']?.toString();
    final password = rawCache['password']?.toString();
    final userId = rawCache['user_id']?.toString();
    final userType = rawCache['user_type']?.toString();

    if (username == null ||
        password == null ||
        userId == null ||
        userType == null) {
      await clearCachedLogin();
      return null;
    }

    final nowUtc = DateTime.now().toUtc();
    var sessionExpiresAt = _toInt(rawCache['session_expires_at']);

    if (sessionExpiresAt == null) {
      sessionExpiresAt = nowUtc
          .add(_defaultSessionDuration)
          .millisecondsSinceEpoch;

      await saveCachedLogin(
        username,
        password,
        userId,
        userType,
        sessionExpiresAt: DateTime.fromMillisecondsSinceEpoch(
          sessionExpiresAt,
          isUtc: true,
        ),
      );
    }

    if (sessionExpiresAt <= nowUtc.millisecondsSinceEpoch) {
      await clearCachedLogin();
      return null;
    }

    return {
      'username': username,
      'password': password,
      'user_id': userId,
      'user_type': userType,
      'session_expires_at': sessionExpiresAt,
      'session_issued_at': _toInt(rawCache['session_issued_at']),
    };
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
