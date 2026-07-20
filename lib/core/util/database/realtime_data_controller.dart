import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_worksmart_app/config/env.dart';

class RealtimeDataController {
  static const String _usersCollection = 'user_data';
  static const String _legacyUsersCollection = 'user_records';
  static const String _officeCollection = 'office_connections';
  static const String _attendanceCollection = 'attendance_records';
  static const String _leaveRecordsSubCollection = 'leave_records';
  static const String _notificationsSubCollection = 'notifications';
  static const String _defaultOfficeId = 'office_1777372932913';
  static const String _passwordAlgorithmV1 = 'sha256-v1';
  static const String _passwordAlgorithmV2 = 'sha256-v2-pepper';
  static const String _currentPasswordAlgorithm = _passwordAlgorithmV2;
  static bool _legacyUsersMigrated = false;

  final FirebaseFirestore _firestore;

  RealtimeDataController({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> watchUserNotifications(String uid) {
    final String userId = uid.trim();
    if (userId.isEmpty) {
      return Stream<List<Map<String, dynamic>>>.value(
        const <Map<String, dynamic>>[],
      );
    }

    return _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection(_notificationsSubCollection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => _normalizeNotificationRecord(doc.id, doc.data()))
              .toList();
        });
  }

  Future<void> upsertUserNotification(
    String uid,
    Map<String, dynamic> notification, {
    String? notificationId,
  }) async {
    final String userId = uid.trim();
    if (userId.isEmpty) return;

    final bool notificationsEnabled = await isUserNotificationEnabled(userId);
    if (!notificationsEnabled) return;

    final String docId =
        (notificationId ?? notification['id']?.toString() ?? '').trim().isEmpty
        ? _generateNotificationIdFromContent(notification)
        : (notificationId ?? notification['id']?.toString() ?? '').trim();

    final Map<String, dynamic> prepared = _prepareNotificationRecordForWrite(
      docId,
      notification,
    );

    await _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection(_notificationsSubCollection)
        .doc(docId)
        .set(prepared, SetOptions(merge: true));
  }

  String _generateNotificationIdFromContent(Map<String, dynamic> notification) {
    final String title = (notification['title'] ?? '').toString().trim();
    final String message = (notification['message'] ?? '').toString().trim();
    final String type = (notification['type'] ?? '').toString().trim();

    final String contentKey = '$type::$title::$message';
    final List<int> bytes = utf8.encode(contentKey);
    final String hash = sha256.convert(bytes).toString().substring(0, 16);

    return 'notif_$hash';
  }

  Future<bool> isUserNotificationEnabled(String uid) async {
    final String userId = uid.trim();
    if (userId.isEmpty) {
      return true;
    }

    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();
      if (!doc.exists || doc.data() == null) {
        return true;
      }

      final dynamic appSettings = _resolveAppSettings(doc.data()!);
      if (appSettings is Map) {
        final bool? value = _readBool(
          appSettings['notifications_enabled'] ??
              appSettings['notification_enable'] ??
              appSettings['notification_enabled'],
        );
        return value ?? true;
      }

      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> markUserNotificationRead(
    String uid,
    String notificationId, {
    bool isRead = true,
  }) async {
    final String userId = uid.trim();
    final String docId = notificationId.trim();
    if (userId.isEmpty || docId.isEmpty) return;

    await _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection(_notificationsSubCollection)
        .doc(docId)
        .set({'isRead': isRead}, SetOptions(merge: true));
  }

  Future<void> deleteUserNotification(String uid, String notificationId) async {
    final String userId = uid.trim();
    final String docId = notificationId.trim();
    if (userId.isEmpty || docId.isEmpty) return;

    await _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection(_notificationsSubCollection)
        .doc(docId)
        .delete();
  }

  Future<void> markAllUserNotificationsRead(String uid) async {
    final String userId = uid.trim();
    if (userId.isEmpty) return;

    final CollectionReference<Map<String, dynamic>> collectionRef = _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection(_notificationsSubCollection);

    final QuerySnapshot<Map<String, dynamic>> snapshot = await collectionRef
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final WriteBatch batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.set(doc.reference, {'isRead': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> fetchUserRecords() async {
    await _migrateLegacyUsersIfNeeded();

    final snapshot = await _firestore.collection(_usersCollection).get();
    final records = snapshot.docs
        .map((doc) => _normalizeUserRecord(doc.id, doc.data()))
        .toList();

    return Future.wait(records.map(_hydrateUserRecordWithLeaveRecords));
  }

  Stream<List<Map<String, dynamic>>> watchUserRecords() async* {
    await _migrateLegacyUsersIfNeeded();

    yield* _firestore.collection(_usersCollection).snapshots().asyncMap((
      snapshot,
    ) async {
      final records = snapshot.docs
          .map((doc) => _normalizeUserRecord(doc.id, doc.data()))
          .toList();
      return Future.wait(records.map(_hydrateUserRecordWithLeaveRecords));
    });
  }

  Future<Map<String, dynamic>?> fetchOfficeConnection({
    String? officeId,
  }) async {
    final resolvedOfficeId = _resolveOfficeId(officeId);

    final doc = await _firestore
        .collection(_officeCollection)
        .doc(resolvedOfficeId)
        .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return _normalizeOfficeRecord(doc.id, doc.data()!);
  }

  Stream<Map<String, dynamic>?> watchOfficeConnection({String? officeId}) {
    final resolvedOfficeId = _resolveOfficeId(officeId);

    return _firestore
        .collection(_officeCollection)
        .doc(resolvedOfficeId)
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) {
            return null;
          }
          return _normalizeOfficeRecord(doc.id, doc.data()!);
        });
  }

  Future<List<Map<String, dynamic>>> fetchOfficeConnections() async {
    final snapshot = await _firestore.collection(_officeCollection).get();
    return snapshot.docs
        .map((doc) => _normalizeOfficeRecord(doc.id, doc.data()))
        .toList();
  }

  Stream<List<Map<String, dynamic>>> watchOfficeConnections() {
    return _firestore.collection(_officeCollection).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => _normalizeOfficeRecord(doc.id, doc.data()))
          .toList();
    });
  }

  Future<List<Map<String, dynamic>>> fetchAttendanceRecords({
    String? uid,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection(
      _attendanceCollection,
    );
    final normalizedUid = uid?.trim();
    if (normalizedUid != null && normalizedUid.isNotEmpty) {
      query = query.where('uid', isEqualTo: normalizedUid);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => _normalizeAttendanceRecord(doc.id, doc.data()))
        .toList();
  }

  Stream<List<Map<String, dynamic>>> watchAttendanceRecords({String? uid}) {
    Query<Map<String, dynamic>> query = _firestore.collection(
      _attendanceCollection,
    );
    final normalizedUid = uid?.trim();
    if (normalizedUid != null && normalizedUid.isNotEmpty) {
      query = query.where('uid', isEqualTo: normalizedUid);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => _normalizeAttendanceRecord(doc.id, doc.data()))
          .toList();
    });
  }

  Future<Map<String, dynamic>> saveAttendanceScan({
    required String uid,
    required String scanType,
    DateTime? scannedAt,
    Map<String, dynamic>? latLng,
    Map<String, dynamic>? verification,
  }) async {
    final String userId = uid.trim();
    if (userId.isEmpty) {
      throw ArgumentError('uid is required');
    }

    final String normalizedScanType =
        scanType.trim().toLowerCase() == 'check_out' ? 'check_out' : 'check_in';
    final DateTime eventAt = scannedAt ?? DateTime.now();
    Map<String, dynamic> officePolicy = <String, dynamic>{};
    try {
      officePolicy = await _readOfficePolicyForUser(userId);
    } catch (_) {
      officePolicy = <String, dynamic>{};
    }
    final String policyCheckInStart =
        _readNonEmptyString(
          officePolicy['check_in_start'] ?? officePolicy['checkInStart'],
        ) ??
        '';
    final int policyLateBufferMinutes = _parseNonNegativeInt(
      officePolicy['late_buffer_minutes'] ?? officePolicy['lateBufferMinutes'],
      fallback: 0,
    );
    final String dateKey = _formatDateKey(eventAt);
    final String recordId = '${userId}_$dateKey';
    final DocumentReference<Map<String, dynamic>> docRef = _firestore
        .collection(_attendanceCollection)
        .doc(recordId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final Map<String, dynamic> existing =
          snapshot.data() ?? <String, dynamic>{};

      String checkIn = (existing['check_in'] ?? '--:--').toString();
      String checkOut = (existing['check_out'] ?? '--:--').toString();
      final String scanTime = _format12HourTime(eventAt);

      if (normalizedScanType == 'check_in') {
        if (!_isAttendanceTimeSet(checkIn)) {
          checkIn = scanTime;
        }
      } else {
        checkOut = scanTime;
        if (!_isAttendanceTimeSet(checkIn)) {
          checkIn = scanTime;
        }
      }

      final double totalHours = _calculateAttendanceHours(checkIn, checkOut);
      final String status = _resolveAttendanceStatus(
        existingStatus: existing['status']?.toString(),
        checkInTime: checkIn,
        policyCheckInStart: policyCheckInStart,
        lateBufferMinutes: policyLateBufferMinutes,
      );

      final Map<String, dynamic> record = <String, dynamic>{
        'uid': userId,
        'date': dateKey,
        'check_in': checkIn,
        'check_out': checkOut,
        'total_hours': totalHours,
        'status': status,
        'lat_lng': _normalizeLatLng(latLng),
        if (verification != null && verification.isNotEmpty)
          'verification': verification,
      };

      transaction.set(docRef, record, SetOptions(merge: true));
      return record;
    });
  }

  Future<Map<String, dynamic>> saveAbsentAttendanceIfNotScanned({
    required String uid,
    DateTime? forDate,
  }) async {
    final String userId = uid.trim();
    if (userId.isEmpty) {
      throw ArgumentError('uid is required');
    }

    final DateTime targetDate = forDate ?? DateTime.now();
    final String dateKey = _formatDateKey(targetDate);
    final String recordId = '${userId}_$dateKey';
    final DocumentReference<Map<String, dynamic>> docRef = _firestore
        .collection(_attendanceCollection)
        .doc(recordId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final Map<String, dynamic> existing =
          snapshot.data() ?? <String, dynamic>{};

      final String checkIn = (existing['check_in'] ?? '--:--').toString();
      final String checkOut = (existing['check_out'] ?? '--:--').toString();

      final bool hasScannedAttendance =
          _isAttendanceTimeSet(checkIn) || _isAttendanceTimeSet(checkOut);

      if (hasScannedAttendance) {
        return <String, dynamic>{
          ...existing,
          'uid': existing['uid'] ?? userId,
          'date': existing['date'] ?? dateKey,
          'check_in': checkIn,
          'check_out': checkOut,
        };
      }

      final Map<String, dynamic> record = <String, dynamic>{
        'uid': userId,
        'date': dateKey,
        'check_in': '--:--',
        'check_out': '--:--',
        'total_hours': 0.0,
        'status': 'absent',
      };

      transaction.set(docRef, record, SetOptions(merge: true));
      return record;
    });
  }

  Future<Map<String, dynamic>> _readOfficePolicyForUser(String userId) async {
    final userDoc = await _firestore
        .collection(_usersCollection)
        .doc(userId)
        .get();
    final Map<String, dynamic> userData = userDoc.data() ?? <String, dynamic>{};

    final String officeId = _resolveOfficeId(
      _readNonEmptyString(userData['office_id']) ??
          _readNonEmptyString(userData['officeId']),
    );

    final officeDoc = await _firestore
        .collection(_officeCollection)
        .doc(officeId)
        .get();
    final Map<String, dynamic> officeData =
        officeDoc.data() ?? <String, dynamic>{};

    final dynamic rawPolicy = officeData['policy'];
    if (rawPolicy is Map) {
      return Map<String, dynamic>.from(rawPolicy);
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>?> authenticateUser({
    required String username,
    required String password,
  }) async {
    await _migrateLegacyUsersIfNeeded();

    final usernameInput = username.trim().toLowerCase();
    final passwordInput = password.trim();

    if (usernameInput.isEmpty || passwordInput.isEmpty) {
      return null;
    }

    final snapshot = await _firestore.collection(_usersCollection).get();
    for (final doc in snapshot.docs) {
      final user = _normalizeUserRecordForStorage(doc.id, doc.data());
      final uid = (user['uid'] ?? '').toString().toLowerCase();
      final displayName = (user['display_name'] ?? '').toString().toLowerCase();

      final matchesUsername =
          uid == usernameInput || displayName.contains(usernameInput);
      if (!matchesUsername) {
        continue;
      }

      final isPasswordValid = _verifyPassword(passwordInput, user);
      if (!isPasswordValid) {
        continue;
      }

      // Transparently upgrade old plaintext entries after successful login.
      if (_shouldUpgradePasswordStorage(user)) {
        await _upgradePasswordStorage(doc.id, passwordInput);
      }

      return _sanitizeUserRecord(user);
    }

    return null;
  }

  /// Returns the account status field for the given [uid], or null if not found.
  Future<String?> fetchUserAccountStatus(String uid) async {
    final userId = uid.trim();
    if (userId.isEmpty) return null;

    final doc = await _firestore.collection(_usersCollection).doc(userId).get();
    if (!doc.exists || doc.data() == null) return null;

    return doc.data()!['status']?.toString();
  }

  Stream<Map<String, dynamic>?> watchUserRecord(String uid) async* {
    await _migrateLegacyUsersIfNeeded();

    final userId = uid.trim();
    if (userId.isEmpty) {
      yield null;
      return;
    }

    yield* _firestore
        .collection(_usersCollection)
        .doc(userId)
        .snapshots()
        .asyncMap((doc) async {
          if (!doc.exists || doc.data() == null) {
            return null;
          }

          final record = _normalizeUserRecord(doc.id, doc.data()!);
          return _hydrateUserRecordWithLeaveRecords(record);
        });
  }

  Future<Map<String, dynamic>?> fetchUserRecordById(String uid) async {
    await _migrateLegacyUsersIfNeeded();

    final String userId = uid.trim();
    if (userId.isEmpty) {
      return null;
    }

    final doc = await _firestore.collection(_usersCollection).doc(userId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }

    final record = _normalizeUserRecord(doc.id, doc.data()!);
    return _hydrateUserRecordWithLeaveRecords(record);
  }

  Future<void> upsertUserRecord(Map<String, dynamic> userRecord) async {
    await _migrateLegacyUsersIfNeeded();

    final uid = (userRecord['uid'] ?? '').toString().trim();
    if (uid.isEmpty) return;

    final normalized = _normalizeUserRecordForStorage(uid, userRecord);
    final prepared = _prepareUserRecordForWrite(normalized);

    await _firestore
        .collection(_usersCollection)
        .doc(uid)
        .set(prepared, SetOptions(merge: true));
  }

  Future<void> updateUserRecord(
    String uid,
    Map<String, dynamic> partialData,
  ) async {
    await _migrateLegacyUsersIfNeeded();

    final userId = uid.trim();
    if (userId.isEmpty || partialData.isEmpty) return;

    final prepared = _prepareUserRecordForWrite(partialData);
    if (prepared.isEmpty) return;

    await _firestore
        .collection(_usersCollection)
        .doc(userId)
        .set(prepared, SetOptions(merge: true));
  }

  Future<void> updateUserFaceBiometrics(
    String uid,
    Map<String, dynamic> biometrics,
  ) async {
    await _migrateLegacyUsersIfNeeded();

    final userId = uid.trim();
    if (userId.isEmpty || biometrics.isEmpty) return;

    await _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection('face_biometrics')
        .doc('latest')
        .set(Map<String, dynamic>.from(biometrics), SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> fetchUserFaceBiometrics(String uid) async {
    await _migrateLegacyUsersIfNeeded();

    final userId = uid.trim();
    if (userId.isEmpty) return null;

    final doc = await _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection('face_biometrics')
        .doc('latest')
        .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return Map<String, dynamic>.from(doc.data()!);
  }

  Future<void> upsertUserLeaveRecord(
    String uid,
    Map<String, dynamic> leaveRecord,
  ) async {
    await _migrateLegacyUsersIfNeeded();

    final String userId = uid.trim();
    final String requestId = (leaveRecord['request_id'] ?? '')
        .toString()
        .trim();
    if (userId.isEmpty || requestId.isEmpty) return;

    await _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection(_leaveRecordsSubCollection)
        .doc(requestId)
        .set(
          _prepareLeaveRecordForWrite(requestId, leaveRecord),
          SetOptions(merge: true),
        );
  }

  Future<void> deleteUserLeaveRecord(String uid, String requestId) async {
    await _migrateLegacyUsersIfNeeded();

    final String userId = uid.trim();
    final String normalizedRequestId = requestId.trim();
    if (userId.isEmpty || normalizedRequestId.isEmpty) return;

    await _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection(_leaveRecordsSubCollection)
        .doc(normalizedRequestId)
        .delete();
  }

  Future<List<Map<String, dynamic>>> fetchUserLeaveRecords(String uid) async {
    await _migrateLegacyUsersIfNeeded();

    final String userId = uid.trim();
    if (userId.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final snapshot = await _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection(_leaveRecordsSubCollection)
        .get();

    return snapshot.docs
        .map((doc) => _normalizeLeaveRecord(doc.id, doc.data()))
        .toList();
  }

  Stream<List<Map<String, dynamic>>> watchUserLeaveRecords(String uid) async* {
    await _migrateLegacyUsersIfNeeded();

    final String userId = uid.trim();
    if (userId.isEmpty) {
      yield <Map<String, dynamic>>[];
      return;
    }

    yield* _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection(_leaveRecordsSubCollection)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => _normalizeLeaveRecord(doc.id, doc.data()))
              .toList();
        });
  }

  Future<void> deleteUserRecord(String uid) async {
    await _migrateLegacyUsersIfNeeded();

    final userId = uid.trim();
    if (userId.isEmpty) return;

    await _firestore.collection(_usersCollection).doc(userId).delete();
  }

  Future<void> upsertOfficeConnection(
    Map<String, dynamic> officeRecord, {
    String? officeId,
  }) async {
    final resolvedOfficeId = _resolveOfficeId(
      officeId ?? officeRecord['office_id']?.toString(),
    );

    await _firestore
        .collection(_officeCollection)
        .doc(resolvedOfficeId)
        .set(_cloneMap(officeRecord), SetOptions(merge: true));
  }

  Future<void> deleteOfficeConnection(String officeId) async {
    final resolvedOfficeId = _resolveOfficeId(officeId);

    await _firestore
        .collection(_officeCollection)
        .doc(resolvedOfficeId)
        .delete();
  }

  String _resolveOfficeId(String? officeId) {
    final trimmed = officeId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return _defaultOfficeId;
    }
    return trimmed;
  }

  Map<String, dynamic> _prepareNotificationRecordForWrite(
    String docId,
    Map<String, dynamic> source,
  ) {
    final Map<String, dynamic> record = _cloneMap(source);
    final String normalizedType = _normalizeNotificationType(
      (record['type'] ?? '').toString(),
    );

    final dynamic rawTimestamp = record['timestamp'];
    final Timestamp resolvedTimestamp = _resolveTimestamp(rawTimestamp);

    final Timestamp now = Timestamp.now();

    return <String, dynamic>{
      'id': docId,
      'title': (record['title'] ?? '').toString(),
      'message': (record['message'] ?? '').toString(),
      'type': normalizedType,
      'status': (record['status'] ?? '').toString().trim().toLowerCase(),
      'isRead': _readBool(record['isRead']) ?? false,
      'timestamp': resolvedTimestamp.millisecondsSinceEpoch > 0
          ? resolvedTimestamp
          : now,
    };
  }

  Map<String, dynamic> _normalizeNotificationRecord(
    String docId,
    Map<String, dynamic> source,
  ) {
    final Map<String, dynamic> record = _cloneMap(source);
    record['id'] = (record['id'] ?? docId).toString();
    record['title'] = (record['title'] ?? '').toString();
    record['message'] = (record['message'] ?? '').toString();
    record['type'] = _normalizeNotificationType(
      (record['type'] ?? '').toString(),
    );
    record['status'] = (record['status'] ?? '').toString().trim().toLowerCase();
    record['isRead'] = _readBool(record['isRead']) ?? false;

    final Timestamp timestamp = _resolveTimestamp(record['timestamp']);
    record['timestamp'] = timestamp.toDate();
    return record;
  }

  String _normalizeNotificationType(String type) {
    final String normalized = type.trim().toLowerCase();
    if (normalized == 'attendance' || normalized == 'leave') {
      return normalized;
    }
    return 'general';
  }

  Timestamp _resolveTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value;
    }
    if (value is DateTime) {
      return Timestamp.fromDate(value);
    }
    if (value is int) {
      return Timestamp.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      final DateTime? parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return Timestamp.fromDate(parsed);
      }
    }
    return Timestamp.now();
  }

  bool? _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    final String normalized = (value ?? '').toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    return null;
  }

  Future<void> _migrateLegacyUsersIfNeeded() async {
    if (_legacyUsersMigrated) {
      return;
    }

    if (!_legacyUsersMigrated) {
      try {
        final legacySnapshot = await _firestore
            .collection(_legacyUsersCollection)
            .get();

        // Merge every legacy document into user_data to avoid partial migrations.
        final batch = _firestore.batch();
        for (final doc in legacySnapshot.docs) {
          final normalized = _normalizeUserRecordForStorage(doc.id, doc.data());
          final prepared = _prepareUserRecordForWrite(normalized);
          batch.set(
            _firestore.collection(_usersCollection).doc(doc.id),
            prepared,
            SetOptions(merge: true),
          );
        }

        if (legacySnapshot.docs.isNotEmpty) {
          await batch.commit();
        }
        _legacyUsersMigrated = true;
      } catch (_) {
        // Allow retry on later calls if migration fails transiently.
        _legacyUsersMigrated = false;
      }
    }
  }

  Map<String, dynamic> _normalizeUserRecord(
    String docId,
    Map<String, dynamic> source,
  ) {
    return _sanitizeUserRecord(_normalizeUserRecordForStorage(docId, source));
  }

  Map<String, dynamic> _normalizeUserRecordForStorage(
    String docId,
    Map<String, dynamic> source,
  ) {
    final record = _cloneMap(source);
    record['uid'] = (record['uid'] ?? docId).toString();

    final dynamic appSettings = _resolveAppSettings(record);
    final Map<String, dynamic> normalizedAppSettings = appSettings is Map
        ? Map<String, dynamic>.from(appSettings)
        : <String, dynamic>{};
    normalizedAppSettings['notifications_enabled'] =
        _readBool(
          normalizedAppSettings['notifications_enabled'] ??
              normalizedAppSettings['notification_enable'] ??
              normalizedAppSettings['notification_enabled'],
        ) ??
        true;
    record['app_settings'] = normalizedAppSettings;
    record.remove('app_setting');

    return record;
  }

  dynamic _resolveAppSettings(Map<String, dynamic> record) {
    return record['app_settings'] ?? record['app_setting'];
  }

  Map<String, dynamic> _sanitizeUserRecord(Map<String, dynamic> source) {
    final sanitized = _cloneMap(source);
    sanitized.remove('password');
    sanitized.remove('password_hash');
    sanitized.remove('password_salt');
    sanitized.remove('password_algorithm');
    return sanitized;
  }

  Map<String, dynamic> _normalizeOfficeRecord(
    String docId,
    Map<String, dynamic> source,
  ) {
    final record = _cloneMap(source);
    record['office_id'] = (record['office_id'] ?? docId).toString();
    return record;
  }

  Map<String, dynamic> _normalizeAttendanceRecord(
    String docId,
    Map<String, dynamic> source,
  ) {
    final record = _cloneMap(source);
    final uid = (record['uid'] ?? '').toString();
    if (uid.isEmpty) {
      record['uid'] = docId;
    }
    return record;
  }

  Map<String, dynamic> _prepareLeaveRecordForWrite(
    String requestId,
    Map<String, dynamic> source,
  ) {
    final Map<String, dynamic> record = _cloneMap(source);
    record['request_id'] = requestId;
    record['type'] = (record['type'] ?? '').toString();
    record['start_date'] = (record['start_date'] ?? '').toString();
    record['end_date'] = (record['end_date'] ?? '').toString();
    record['reason'] = (record['reason'] ?? '').toString();
    record['status'] = (record['status'] ?? 'pending').toString();

    final String? attachmentUrl = _readNonEmptyString(record['attachment_url']);
    if (attachmentUrl == null) {
      record.remove('attachment_url');
    } else {
      record['attachment_url'] = attachmentUrl;
    }

    return record;
  }

  Map<String, dynamic> _normalizeLeaveRecord(
    String docId,
    Map<String, dynamic> source,
  ) {
    final Map<String, dynamic> record = _cloneMap(source);
    record['request_id'] = (record['request_id'] ?? docId).toString();
    record['type'] = (record['type'] ?? '').toString();
    record['start_date'] = (record['start_date'] ?? '').toString();
    record['end_date'] = (record['end_date'] ?? '').toString();
    record['reason'] = (record['reason'] ?? '').toString();
    record['status'] = (record['status'] ?? 'pending').toString();

    final String? attachmentUrl = _readNonEmptyString(record['attachment_url']);
    if (attachmentUrl == null) {
      record.remove('attachment_url');
    } else {
      record['attachment_url'] = attachmentUrl;
    }

    return record;
  }

  Future<Map<String, dynamic>> _hydrateUserRecordWithLeaveRecords(
    Map<String, dynamic> userRecord,
  ) async {
    final Map<String, dynamic> record = _cloneMap(userRecord);
    final String userId = (record['uid'] ?? '').toString().trim();
    if (userId.isEmpty) {
      return record;
    }

    final QuerySnapshot<Map<String, dynamic>> leaveSnapshot = await _firestore
        .collection(_usersCollection)
        .doc(userId)
        .collection(_leaveRecordsSubCollection)
        .get();

    if (leaveSnapshot.docs.isNotEmpty) {
      record['leave_records'] = leaveSnapshot.docs
          .map((doc) => _normalizeLeaveRecord(doc.id, doc.data()))
          .toList();
      return record;
    }

    final dynamic existingLeaveRecords = record['leave_records'];
    if (existingLeaveRecords is List) {
      record['leave_records'] = existingLeaveRecords
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return record;
  }

  Map<String, dynamic> _cloneMap(Map<String, dynamic> source) {
    return Map<String, dynamic>.from(source);
  }

  Map<String, dynamic> _prepareUserRecordForWrite(Map<String, dynamic> source) {
    final prepared = _cloneMap(source);

    final plainPassword = _readNonEmptyString(prepared['password']);
    final existingHash = _readNonEmptyString(prepared['password_hash']);
    final existingSalt = _readNonEmptyString(prepared['password_salt']);

    if (plainPassword != null) {
      final salt = _generateSalt();
      prepared['password_hash'] = _hashPassword(
        password: plainPassword,
        salt: salt,
        algorithm: _currentPasswordAlgorithm,
      );
      prepared['password_salt'] = salt;
      prepared['password_algorithm'] = _currentPasswordAlgorithm;
      prepared['password'] = FieldValue.delete();
      return prepared;
    }

    if (existingHash != null && existingSalt != null) {
      prepared['password_hash'] = existingHash;
      prepared['password_salt'] = existingSalt;
      final algorithm = _readNonEmptyString(prepared['password_algorithm']);
      prepared['password_algorithm'] = algorithm ?? _passwordAlgorithmV1;
    }

    return prepared;
  }

  bool _verifyPassword(String candidatePassword, Map<String, dynamic> record) {
    final hash = _readNonEmptyString(record['password_hash']);
    final salt = _readNonEmptyString(record['password_salt']);
    final algorithm =
        _readNonEmptyString(record['password_algorithm']) ??
        _passwordAlgorithmV1;

    if (hash != null && salt != null) {
      final computedHash = _hashPassword(
        password: candidatePassword,
        salt: salt,
        algorithm: algorithm,
      );
      return _secureEquals(hash, computedHash);
    }

    // Backward compatibility for legacy plaintext records.
    final legacyPlaintext = _readNonEmptyString(record['password']);
    if (legacyPlaintext == null) {
      return false;
    }

    return _secureEquals(legacyPlaintext, candidatePassword);
  }

  bool _shouldUpgradePasswordStorage(Map<String, dynamic> record) {
    if (_readNonEmptyString(record['password']) != null) {
      return true;
    }

    final hash = _readNonEmptyString(record['password_hash']);
    final salt = _readNonEmptyString(record['password_salt']);
    final algorithm = _readNonEmptyString(record['password_algorithm']);

    if (hash == null || salt == null) {
      return false;
    }

    return algorithm != _currentPasswordAlgorithm;
  }

  Future<void> _upgradePasswordStorage(String uid, String plainPassword) async {
    final salt = _generateSalt();
    final hash = _hashPassword(
      password: plainPassword,
      salt: salt,
      algorithm: _currentPasswordAlgorithm,
    );

    await _firestore.collection(_usersCollection).doc(uid).set({
      'password_hash': hash,
      'password_salt': salt,
      'password_algorithm': _currentPasswordAlgorithm,
      'password': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  String _hashPassword({
    required String password,
    required String salt,
    required String algorithm,
  }) {
    final usePepper = algorithm == _passwordAlgorithmV2;
    final pepper = usePepper ? Env.passwordPepper : '';

    final seed = utf8.encode('$salt::$password::$pepper');
    var digest = sha256.convert(seed).bytes;

    // Lightweight stretching to avoid single-round hashing.
    for (var i = 0; i < 999; i++) {
      digest = sha256.convert([...digest, ...seed]).bytes;
    }

    return base64UrlEncode(digest);
  }

  String _generateSalt([int length = 16]) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String? _readNonEmptyString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  bool _secureEquals(String a, String b) {
    if (a.length != b.length) {
      return false;
    }

    var mismatch = 0;
    for (var i = 0; i < a.length; i++) {
      mismatch |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return mismatch == 0;
  }

  String _formatDateKey(DateTime dateTime) {
    return '${dateTime.year}-'
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')}';
  }

  String _format12HourTime(DateTime dateTime) {
    final int hour12 = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    final String period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }

  bool _isAttendanceTimeSet(String value) {
    final String normalized = value.trim();
    return normalized.isNotEmpty && normalized != '--:--';
  }

  double _calculateAttendanceHours(String checkIn, String checkOut) {
    final DateTime? inTime = _parse12HourTime(checkIn);
    final DateTime? outTime = _parse12HourTime(checkOut);
    if (inTime == null || outTime == null) {
      return 0.0;
    }

    Duration diff = outTime.difference(inTime);
    if (diff.isNegative) {
      diff = const Duration();
    }

    return double.parse((diff.inMinutes / 60).toStringAsFixed(1));
  }

  DateTime? _parse12HourTime(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty || normalized == '--:--') {
      return null;
    }

    final RegExp twentyFourHour = RegExp('^([01]?\\d|2[0-3]):([0-5]\\d)\$');
    final RegExpMatch? twentyFourMatch = twentyFourHour.firstMatch(normalized);
    if (twentyFourMatch != null) {
      final int hour = int.parse(twentyFourMatch.group(1)!);
      final int minute = int.parse(twentyFourMatch.group(2)!);
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    }

    try {
      final List<String> parts = normalized.split(' ');
      if (parts.length != 2) return null;

      final List<String> hm = parts[0].split(':');
      if (hm.length != 2) return null;

      int hour = int.parse(hm[0]);
      final int minute = int.parse(hm[1]);
      final String period = parts[1].toUpperCase();

      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;

      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  String _resolveAttendanceStatus({
    required String? existingStatus,
    required String checkInTime,
    required String policyCheckInStart,
    required int lateBufferMinutes,
  }) {
    final String normalizedExisting = (existingStatus ?? '')
        .trim()
        .toLowerCase();
    if (normalizedExisting == 'late' || normalizedExisting == 'on_time') {
      return normalizedExisting;
    }

    final DateTime? checkInAt = _parse12HourTime(checkInTime);
    final DateTime? policyStartAt = _parse12HourTime(policyCheckInStart);
    if (checkInAt == null || policyStartAt == null) {
      return 'on_time';
    }

    final int normalizedLateBufferMinutes = lateBufferMinutes >= 0
        ? lateBufferMinutes
        : 0;
    final DateTime lateThreshold = policyStartAt.add(
      Duration(minutes: normalizedLateBufferMinutes),
    );
    if (checkInAt.isAfter(lateThreshold)) {
      return 'late';
    }

    return 'on_time';
  }

  int _parseNonNegativeInt(dynamic value, {int fallback = 0}) {
    if (value is num) {
      final int parsed = value.toInt();
      return parsed >= 0 ? parsed : fallback;
    }

    if (value is String) {
      final int? parsed = int.tryParse(value.trim());
      if (parsed != null && parsed >= 0) {
        return parsed;
      }
    }

    return fallback;
  }

  Map<String, double> _normalizeLatLng(Map<String, dynamic>? latLng) {
    final double lat = _asDouble(latLng?['lat']);
    final double lng = _asDouble(latLng?['lng']);
    return <String, double>{'lat': lat, 'lng': lng};
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }
}
