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
      if (currentVersion < 10) {
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
      version: 10, // Bumped to 10: added face update history/audit columns
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

        await db.execute('''
          CREATE TABLE IF NOT EXISTS face_embedding_cache (
            user_id TEXT PRIMARY KEY,
            embedding_data TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            previous_embedding_data TEXT,
            last_face_update INTEGER,
            face_update_count INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS policy_cache (
            workspace_id TEXT PRIMARY KEY,
            policy_data TEXT NOT NULL,
            cached_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS face_update_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            device_info TEXT,
            old_embedding_length INTEGER,
            new_embedding_length INTEGER
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

        if (oldVersion < 8) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS face_embedding_cache (
                user_id TEXT PRIMARY KEY,
                embedding_data TEXT NOT NULL,
                updated_at INTEGER NOT NULL
              )
            ''');
          } on DatabaseException catch (e) {
            e.toString();
          }
        }

        if (oldVersion < 9) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS policy_cache (
                workspace_id TEXT PRIMARY KEY,
                policy_data TEXT NOT NULL,
                cached_at INTEGER NOT NULL
              )
            ''');
          } on DatabaseException catch (e) {
            e.toString();
          }
        }

        // New V10 migration: face update history/audit trail (backup of the
        // previous embedding, cooldown timestamp, update counter) plus a
        // dedicated audit log table for the "Update Face" security feature.
        if (oldVersion < 10) {
          for (final String statement in const [
            'ALTER TABLE face_embedding_cache ADD COLUMN previous_embedding_data TEXT',
            'ALTER TABLE face_embedding_cache ADD COLUMN last_face_update INTEGER',
            'ALTER TABLE face_embedding_cache ADD COLUMN face_update_count INTEGER NOT NULL DEFAULT 0',
          ]) {
            try {
              await db.execute(statement);
            } on DatabaseException catch (e) {
              e.toString();
            }
          }

          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS face_update_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                updated_at INTEGER NOT NULL,
                device_info TEXT,
                old_embedding_length INTEGER,
                new_embedding_length INTEGER
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

  /// =========================
  /// POLICY CACHE
  /// =========================

  /// Saves the workspace policy to local storage (SQLite on mobile,
  /// SharedPreferences on web) so it can be loaded without a network
  /// request on subsequent app starts.
  Future<void> saveCachedPolicy(
    String workspaceId,
    Map<String, dynamic> policyData,
  ) async {
    final cachedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    final policyJson = jsonEncode(policyData);

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('policy_cache_$workspaceId', policyJson);
    } else {
      final db = await database;
      await db!.insert('policy_cache', {
        'workspace_id': workspaceId,
        'policy_data': policyJson,
        'cached_at': cachedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Retrieves the cached policy for [workspaceId] from local storage.
  /// Returns null if no cached data exists.
  Future<Map<String, dynamic>?> getCachedPolicy(String workspaceId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final policyJson = prefs.getString('policy_cache_$workspaceId');
      if (policyJson == null) return null;
      try {
        return Map<String, dynamic>.from(jsonDecode(policyJson));
      } catch (e) {
        debugPrint('Failed to decode cached policy: $e');
        return null;
      }
    } else {
      final db = await database;
      final maps = await db!.query(
        'policy_cache',
        where: 'workspace_id = ?',
        whereArgs: [workspaceId],
      );
      if (maps.isEmpty) return null;
      try {
        return Map<String, dynamic>.from(
          jsonDecode(maps.first['policy_data'] as String),
        );
      } catch (e) {
        debugPrint('Failed to decode cached policy: $e');
        return null;
      }
    }
  }

  /// Clears every cached policy (all workspaces).
  Future<void> clearPolicyCache() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith('policy_cache_'))
          .toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } else {
      final db = await database;
      await db!.delete('policy_cache');
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

  /// =========================
  /// FACE EMBEDDING CACHE
  /// =========================

  Future<void> saveFaceEmbedding(
    String userId,
    Map<String, dynamic> embeddingData,
  ) async {
    final dataJson = jsonEncode(embeddingData);
    final updatedAt = DateTime.now().toUtc().millisecondsSinceEpoch;

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('face_embedding_$userId', dataJson);
    } else {
      final db = await database;
      await db!.insert('face_embedding_cache', {
        'user_id': userId,
        'embedding_data': dataJson,
        'updated_at': updatedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<Map<String, dynamic>?> getFaceEmbedding(String userId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('face_embedding_$userId');
      if (data != null) {
        return Map<String, dynamic>.from(jsonDecode(data));
      }
    } else {
      final db = await database;
      final maps = await db!.query(
        'face_embedding_cache',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      if (maps.isNotEmpty) {
        final data = maps.first['embedding_data'] as String;
        return Map<String, dynamic>.from(jsonDecode(data));
      }
    }
    return null;
  }

  /// Saves a new face embedding while preserving the previous one as a
  /// backup and recording an audit trail entry — used by the "Update Face"
  /// flow so a re-registration never silently overwrites the old embedding
  /// without history. First-time registration (no prior embedding cached)
  /// is stored normally with no cooldown/audit entry, since there is
  /// nothing to update yet.
  Future<void> saveFaceEmbeddingWithHistory(
    String userId,
    Map<String, dynamic> newEmbeddingData, {
    String? deviceInfo,
  }) async {
    final String newJson = jsonEncode(newEmbeddingData);
    final int nowUtcMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final String? previousJson = prefs.getString('face_embedding_$userId');
      if (previousJson != null) {
        await prefs.setString(
          'face_embedding_previous_$userId',
          previousJson,
        );
        await prefs.setInt('face_last_update_$userId', nowUtcMs);
        await prefs.setInt(
          'face_update_count_$userId',
          (prefs.getInt('face_update_count_$userId') ?? 0) + 1,
        );
      }
      await prefs.setString('face_embedding_$userId', newJson);
      return;
    }

    final db = await database;
    final existingRows = await db!.query(
      'face_embedding_cache',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final bool hadPreviousEmbedding = existingRows.isNotEmpty;
    final String? previousEmbeddingJson = hadPreviousEmbedding
        ? existingRows.first['embedding_data'] as String?
        : null;
    final int previousCount = hadPreviousEmbedding
        ? ((existingRows.first['face_update_count'] as int?) ?? 0)
        : 0;

    await db.insert('face_embedding_cache', {
      'user_id': userId,
      'embedding_data': newJson,
      'updated_at': nowUtcMs,
      'previous_embedding_data': previousEmbeddingJson,
      'last_face_update': hadPreviousEmbedding ? nowUtcMs : null,
      'face_update_count': hadPreviousEmbedding ? previousCount + 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    if (hadPreviousEmbedding) {
      await db.insert('face_update_log', {
        'user_id': userId,
        'updated_at': nowUtcMs,
        'device_info': deviceInfo ?? 'unknown_device',
        'old_embedding_length': _embeddingVectorLength(previousEmbeddingJson),
        'new_embedding_length': _embeddingVectorLength(newJson),
      });
    }
  }

  int? _embeddingVectorLength(String? embeddingJson) {
    if (embeddingJson == null) return null;
    try {
      final decoded = jsonDecode(embeddingJson);
      if (decoded is Map) {
        final vector =
            decoded['face_embeddings'] ?? decoded['embeddings'] ?? decoded['vector'];
        if (vector is List) return vector.length;
      }
    } catch (_) {}
    return null;
  }

  /// Checks whether [userId] is allowed to update their face embedding now,
  /// enforcing a cooldown (default 30 days) since the last successful
  /// update. Comparisons are always done in UTC to avoid device timezone
  /// drift affecting the cooldown window.
  Future<FaceUpdateEligibility> getFaceUpdateEligibility(
    String userId, {
    Duration cooldown = const Duration(days: 30),
  }) async {
    int? lastUpdateMs;

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      lastUpdateMs = prefs.getInt('face_last_update_$userId');
    } else {
      final db = await database;
      final rows = await db!.query(
        'face_embedding_cache',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      if (rows.isNotEmpty) {
        lastUpdateMs = rows.first['last_face_update'] as int?;
      }
    }

    if (lastUpdateMs == null) {
      return const FaceUpdateEligibility(
        allowed: true,
        lastUpdateAtUtc: null,
        nextAllowedAtUtc: null,
      );
    }

    final DateTime lastUpdateUtc = DateTime.fromMillisecondsSinceEpoch(
      lastUpdateMs,
      isUtc: true,
    );
    final DateTime nextAllowedUtc = lastUpdateUtc.add(cooldown);
    final DateTime nowUtc = DateTime.now().toUtc();

    return FaceUpdateEligibility(
      allowed: !nowUtc.isBefore(nextAllowedUtc),
      lastUpdateAtUtc: lastUpdateUtc,
      nextAllowedAtUtc: nextAllowedUtc,
    );
  }

  Future<void> clearFaceEmbeddingCache() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith('face_embedding_'))
          .toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } else {
      final db = await database;
      await db!.delete('face_embedding_cache');
      await db.delete('face_update_log');
    }
  }

  /// Wipes every locally cached artifact tied to the signed-in user (session
  /// tokens, cached profile, face embeddings, workspace/geofence/policy
  /// caches) so a later login on this device — by the same or a different
  /// user — never sees stale data. Deliberately leaves device-level settings
  /// (e.g. language) untouched.
  Future<void> clearAllUserData() async {
    await clearCachedLogin();
    await clearUserProfile();
    await clearFaceEmbeddingCache();
    await clearPolicyCache();

    final prefs = await SharedPreferences.getInstance();
    const workspaceScopedKeys = [
      'selected_workspace_id',
      'cached_selected_workspace',
      'cached_workspaces',
      'cached_workspace_user',
      'cached_workspace_data_timestamp',
      'cached_homepage_geofence',
      'cached_homepage_policy', // legacy key, no longer written but cleared for old installs
    ];
    for (final key in workspaceScopedKeys) {
      await prefs.remove(key);
    }
  }
}

/// Result of a face-update cooldown check (see
/// [DatabaseHelper.getFaceUpdateEligibility]). Timestamps are always UTC;
/// convert with `.toLocal()` only when displaying to the user.
class FaceUpdateEligibility {
  final bool allowed;
  final DateTime? lastUpdateAtUtc;
  final DateTime? nextAllowedAtUtc;

  const FaceUpdateEligibility({
    required this.allowed,
    required this.lastUpdateAtUtc,
    required this.nextAllowedAtUtc,
  });
}
