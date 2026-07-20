class Biometrics {
  final String faceStatus;
  final int faceCount;
  final String registeredDate;
  final List<dynamic> faceVectors;

  Biometrics({
    required this.faceStatus,
    required this.faceCount,
    required this.registeredDate,
    required this.faceVectors,
  });

  factory Biometrics.fromJson(Map<String, dynamic> json) {
    return Biometrics(
      faceStatus: json['face_status'] ?? 'not_registered',
      faceCount: json['face_count'] ?? 0,
      registeredDate: json['registered_date'] ?? '',
      faceVectors:
          json['face_embeddings'] ??
          json['face_vectors'] ??
          json['face_embedding_vector'] ??
          [],
    );
  }
}
