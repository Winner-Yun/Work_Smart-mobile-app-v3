import 'package:flutter_worksmart_app/features/user/service/face_service.dart';

class FaceRepository {
  final FaceService _service;

  FaceRepository(this._service);

  // Existing registration logic
  Future<bool> registerFace(List<num> embeddings) async {
    await _service.registerFace(embeddings);
    return true;
  }

  //  Expose the get method
  Future<Map<String, dynamic>> getMyFaceEmbeddings() async {
    try {
      return await _service.getMyFaceEmbeddings();
    } catch (e) {
      rethrow;
    }
  }
}
