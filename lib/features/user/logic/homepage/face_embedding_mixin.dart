part of '../homepage_logic.dart';

mixin _FaceEmbeddingMixin on _HomePageLogicState {
  /// Checks local storage for a usable face embedding first, falling back to
  /// fetching from the server and caching it if nothing usable is cached yet.
  Future<void> _loadFaceEmbeddingData() async {
    if (loggedInUserId == null) {
      return;
    }

    try {
      final cachedData = await DatabaseHelper().getFaceEmbedding(
        loggedInUserId!,
      );
      final bool hasUsableLocal =
          cachedData != null &&
          FaceAttendanceVerifier.hasUsableFaceEmbedding(cachedData);

      if (hasUsableLocal) {
        hasLocalFaceEmbedding = true;
        return;
      }

      // Nothing usable locally — pull from the repository and trust its result.
      hasLocalFaceEmbedding = await _fetchAndSaveFaceEmbedding();
    } catch (e) {
      hasLocalFaceEmbedding = false;
    }
  }

  /// Fetches the face embedding from the server and saves it locally.
  Future<bool> _fetchAndSaveFaceEmbedding() async {
    if (loggedInUserId == null) return false;

    try {
      final rawData = await _faceRepo.getMyFaceEmbeddings();

      final dataMap = (rawData.containsKey('data') && rawData['data'] is Map)
          ? Map<String, dynamic>.from(rawData['data'])
          : rawData;

      if (!FaceAttendanceVerifier.hasUsableFaceEmbedding(dataMap)) {
        return false;
      }

      await DatabaseHelper().saveFaceEmbedding(loggedInUserId!, dataMap);
      return true;
    } catch (e) {
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
