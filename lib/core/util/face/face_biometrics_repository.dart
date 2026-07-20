import 'package:cloud_firestore/cloud_firestore.dart';

class FaceBiometricsRepository {
  FaceBiometricsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _usersCollection = 'user_data';
  static const String _faceBiometricsCollection = 'face_biometrics';
  static const String _latestDocumentId = 'latest';

  final FirebaseFirestore _firestore;

  Future<void> saveFaceEnrollment({
    required String userId,
    required List<int> embeddingVector,
    required int embeddingScale,
    required Map<String, dynamic> metadata,
  }) async {
    final String normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty || embeddingVector.isEmpty) {
      return;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'face_embedding_vector': List<int>.from(embeddingVector),
      'face_embedding_scale': embeddingScale,
      ...metadata,
    };

    final DocumentReference<Map<String, dynamic>> userDoc = _firestore
        .collection(_usersCollection)
        .doc(normalizedUserId);
    final DocumentReference<Map<String, dynamic>> faceDoc = userDoc
        .collection(_faceBiometricsCollection)
        .doc(_latestDocumentId);

    await faceDoc.set(payload, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> fetchFaceEnrollment(String userId) async {
    final String normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return null;
    }

    final doc = await _firestore
        .collection(_usersCollection)
        .doc(normalizedUserId)
        .collection(_faceBiometricsCollection)
        .doc(_latestDocumentId)
        .get();

    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return Map<String, dynamic>.from(doc.data()!);
  }

  Map<String, dynamic> buildFaceMetadata({
    required String status,
    required String registeredDate,
    required String imageUrl,
  }) {
    return <String, dynamic>{
      'face_status': status,
      'face_count': 1,
      'registered_date': registeredDate,
      'face_image_urls': imageUrl.trim().isEmpty
          ? <String>[]
          : <String>[imageUrl.trim()],
      'has_face_embedding': true,
    };
  }
}
