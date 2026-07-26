part of '../homepage_logic.dart';

mixin _FaceEmbeddingMixin on _HomePageLogicState {
  /// Checks local storage for a usable face embedding first. If nothing
  /// usable is cached yet (fresh install, cleared app data, new device —
  /// but the server already has an approved embedding), falls back to
  /// fetching it from the server and saving it locally so this doesn't need
  /// a network round trip on every future load. Runs on both the initial
  /// homepage load and pull-to-refresh (see `_loadData` in
  /// data_loading_mixin.dart), so a missing local copy gets backfilled
  /// either way.
  Future<void> _loadFaceEmbeddingData() async {
    if (loggedInUserId == null) {
      debugPrint('[FaceEmbedding] Skipped load: loggedInUserId is null');
      return;
    }

    try {
      final cachedData = await DatabaseHelper().getFaceEmbedding(
        loggedInUserId!,
      );
      final bool hasUsableLocal =
          cachedData != null &&
          FaceAttendanceVerifier.hasUsableFaceEmbedding(cachedData);
      debugPrint(
        '[FaceEmbedding] user=$loggedInUserId cachedRowPresent=${cachedData != null} hasUsableLocal=$hasUsableLocal',
      );

      if (hasUsableLocal) {
        hasLocalFaceEmbedding = true;
        return;
      }

      // Nothing usable locally — pull it from the repository. Trust its
      // own success/failure result instead of re-reading the DB entry we
      // just asked it to write.
      debugPrint(
        '[FaceEmbedding] No usable local embedding, fetching from server for user=$loggedInUserId',
      );
      hasLocalFaceEmbedding = await _fetchAndSaveFaceEmbedding();
      debugPrint(
        '[FaceEmbedding] Server fetch finished, hasLocalFaceEmbedding=$hasLocalFaceEmbedding',
      );
    } catch (e) {
      debugPrint('[FaceEmbedding] Error reading local face embedding: $e');
      hasLocalFaceEmbedding = false;
    }
  }

  /// Fetches the face embedding from [FaceRepository.getMyFaceEmbeddings]
  /// and saves it locally. Returns whether a usable embedding was fetched
  /// and saved.
  Future<bool> _fetchAndSaveFaceEmbedding() async {
    if (loggedInUserId == null) return false;

    try {
      final rawData = await _faceRepo.getMyFaceEmbeddings();
      debugPrint('[FaceEmbedding] Raw response keys: ${rawData.keys}');

      final dataMap = (rawData.containsKey('data') && rawData['data'] is Map)
          ? Map<String, dynamic>.from(rawData['data'])
          : rawData;
      debugPrint('[FaceEmbedding] Parsed dataMap keys: ${dataMap.keys}');

      if (!FaceAttendanceVerifier.hasUsableFaceEmbedding(dataMap)) {
        debugPrint(
          '[FaceEmbedding] Fetched data has no usable vector, skipping. dataMap=$dataMap',
        );
        return false;
      }

      await DatabaseHelper().saveFaceEmbedding(loggedInUserId!, dataMap);
      debugPrint('[FaceEmbedding] Saved fetched embedding locally.');
      return true;
    } catch (e) {
      debugPrint('[FaceEmbedding] Error fetching face embedding: $e');
      return false;
    }
  }

  Future<void> updateFaceEmbeddingVector() async {
    if (loggedInUserId == null) return;

    setState(() {
      isFaceEmbeddingUpdating = true;
    });

    //  Fetch from API & write to local DB
    await _fetchAndSaveFaceEmbedding();

    //  Refresh the local state flag
    await _loadFaceEmbeddingData();

    if (mounted) {
      setState(() {
        isFaceEmbeddingUpdating = false;
      });
    }
  }
}
