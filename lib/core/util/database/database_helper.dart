import 'dart:convert';

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
    // Close and reopen if the database was cached from a previous version
    // to ensure migrations run when the version is bumped.
    if (_database != null) {
      final currentVersion = await _database!.getVersion();
      if (currentVersion < 6) {
        await _database!.close();
        _database = null;
      }
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'worksmart_config.db');

    return await openDatabase(
      path,
      version: 6, // Bumped to 6 for user_profile_cache table
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
            session_issued_at INTEGER NOT NULL,
            access_token TEXT,
            refresh_token TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE user_profile_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            profile_data TEXT NOT NULL,
            cached_at INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 4) {
          try {
            await db.execute(
              'ALTER TABLE login_cache ADD COLUMN session_token TEXT',
            );
            await db.execute(
              'ALTER TABLE login_cache ADD COLUMN session_expires_at INTEGER',
            );
            await db.execute(
              'ALTER TABLE login_cache ADD COLUMN session_issued_at INTEGER',
            );
          } on DatabaseException catch (e) {
            e.toString();
          }
        }
        // New V5 Migration for OAuth Tokens
        if (oldVersion < 5) {
          try {
            await db.execute(
              'ALTER TABLE login_cache ADD COLUMN access_token TEXT',
            );
            await db.execute(
              'ALTER TABLE login_cache ADD COLUMN refresh_token TEXT',
            );
          } on DatabaseException catch (e) {
            e.toString();
          }
        }
        // New V6 Migration for user_profile_cache table
        if (oldVersion < 6) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS user_profile_cache (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                profile_data TEXT NOT NULL,
                cached_at INTEGER NOT NULL
              )
            ''');
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

  // Kept for backward compatibility if used elsewhere
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

  /// =========================
  /// NEW OAUTH TOKEN METHODS
  /// =========================

  Future<void> saveCachedLoginWithTokens(
    String username,
    String accessToken,
    String refreshToken,
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
      await prefs.setString('access_token', accessToken);
      await prefs.setString('refresh_token', refreshToken);
      await prefs.setString('password', ''); // Compatibility fallback
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
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'password': '', // Compatibility fallback
        'user_id': userId,
        'user_type': userType,
        'session_token': '',
        'session_expires_at': expiresAt.millisecondsSinceEpoch,
        'session_issued_at': issuedAt.millisecondsSinceEpoch,
      });
    }
  }

  Future<void> updateTokens(String accessToken, String refreshToken) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', accessToken);
      await prefs.setString('refresh_token', refreshToken);
    } else {
      final db = await database;
      await db!.update('login_cache', {
        'access_token': accessToken,
        'refresh_token': refreshToken,
      });
    }
  }

  Future<Map<String, dynamic>?> getCachedLogin() async {
    Map<String, dynamic>? rawCache;

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');
      final userId = prefs.getString('user_id');
      final userType = prefs.getString('user_type');

      // Look for access_token first, fallback to old password field
      final accessToken =
          prefs.getString('access_token') ?? prefs.getString('password');
      final refreshToken = prefs.getString('refresh_token');

      if (username == null ||
          accessToken == null ||
          userId == null ||
          userType == null) {
        return null;
      }

      rawCache = {
        'username': username,
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'password': accessToken, // For backward compatibility
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
        // Fallback for mobile
        rawCache['access_token'] ??= rawCache['password'];
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
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
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

  /// =========================
  /// USER PROFILE CACHE
  /// =========================

  /// Saves the user profile data to local storage (SQLite on mobile,
  /// SharedPreferences on web) so it can be loaded without a network
  /// request on subsequent app starts.
  Future<void> saveUserProfile(Map<String, dynamic> profileData) async {
    final userId =
        profileData['_id']?.toString() ??
        profileData['id']?.toString() ??
        'default';
    final cachedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    final profileJson = jsonEncode(profileData);

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile_data', profileJson);
      await prefs.setInt('user_profile_cached_at', cachedAt);
      await prefs.setString('user_profile_id', userId);
    } else {
      final db = await database;
      await db!.delete('user_profile_cache');
      await db.insert('user_profile_cache', {
        'user_id': userId,
        'profile_data': profileJson,
        'cached_at': cachedAt,
      });
    }
  }

  /// Retrieves the cached user profile data from local storage.
  /// Returns null if no cached data exists.
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile_data');
      if (profileJson == null) return null;
      try {
        return Map<String, dynamic>.from(jsonDecode(profileJson));
      } catch (e) {
        debugPrint('Failed to decode cached user profile: $e');
        return null;
      }
    } else {
      final db = await database;
      final maps = await db!.query('user_profile_cache');
      if (maps.isEmpty) return null;
      final profileJson = maps.first['profile_data'] as String;
      try {
        return Map<String, dynamic>.from(jsonDecode(profileJson));
      } catch (e) {
        debugPrint('Failed to decode cached user profile: $e');
        return null;
      }
    }
  }

  /// Clears the cached user profile data.
  Future<void> clearUserProfile() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_profile_data');
      await prefs.remove('user_profile_cached_at');
      await prefs.remove('user_profile_id');
    } else {
      final db = await database;
      await db!.delete('user_profile_cache');
    }
  }

  Future<Map<String, dynamic>?> _normalizeAndValidateCache(
    Map<String, dynamic> rawCache,
  ) async {
    final username = rawCache['username']?.toString();
    final accessToken = (rawCache['access_token'] ?? rawCache['password'])
        ?.toString();
    final refreshToken = rawCache['refresh_token']?.toString();
    final userId = rawCache['user_id']?.toString();
    final userType = rawCache['user_type']?.toString();

    if (username == null ||
        accessToken == null ||
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

      // Re-save to establish expiration
      await saveCachedLoginWithTokens(
        username,
        accessToken,
        refreshToken ?? '',
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
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'password': accessToken, // Backward compatibility
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
