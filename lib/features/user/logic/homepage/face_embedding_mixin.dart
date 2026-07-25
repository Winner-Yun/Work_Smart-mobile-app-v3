part of '../homepage_logic.dart';

mixin _FaceEmbeddingMixin on _HomePageLogicState {
  /// Directly checks local storage for a usable face embedding — no cached
  /// state is trusted, this always re-reads the DB.
  Future<void> _loadFaceEmbeddingData() async {
    if (loggedInUserId == null) return;

    try {
      final cachedData = await DatabaseHelper().getFaceEmbedding(
        loggedInUserId!,
      );
      hasLocalFaceEmbedding =
          cachedData != null &&
          FaceAttendanceVerifier.hasUsableFaceEmbedding(cachedData);
    } catch (e) {
      debugPrint('Error reading local face embedding: $e');
      hasLocalFaceEmbedding = false;
    }
  }

  Future<void> _fetchAndSaveFaceEmbedding() async {
    if (loggedInUserId == null) return;

    try {
      final rawData = await _faceRepo.getMyFaceEmbeddings();

      final dataMap = (rawData.containsKey('data') && rawData['data'] is Map)
          ? Map<String, dynamic>.from(rawData['data'])
          : rawData;

      if (!FaceAttendanceVerifier.hasUsableFaceEmbedding(dataMap)) {
        debugPrint('Fetched face embedding has no usable vector, skipping.');
        return;
      }

      await DatabaseHelper().saveFaceEmbedding(loggedInUserId!, dataMap);
    } catch (e) {
      debugPrint('Error fetching face embedding: $e');
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
