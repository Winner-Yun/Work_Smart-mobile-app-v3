import 'dart:io';

import 'package:flutter_worksmart_app/features/user/service/request_service.dart';
import 'package:flutter_worksmart_app/shared/model/request_model.dart';

class RequestRepository {
  final RequestService _service;

  RequestRepository(this._service);

  /// Tolerates a plain list or a paginated wrapper under `data`/`items`/`results`/`requests`.
  Future<List<RequestModel>> getMyRequests(
    String workspaceId, {
    int page = 1,
    int limit = 50,
    String? status,
  }) async {
    final dynamic raw = await _service.fetchMyRequests(
      workspaceId,
      page: page,
      limit: limit,
      status: status,
    );

    List<dynamic>? rawList;
    if (raw is List) {
      rawList = raw;
    } else if (raw is Map<String, dynamic>) {
      final dynamic nested =
          raw['data'] ?? raw['requests'] ?? raw['items'] ?? raw['results'];
      if (nested is List) rawList = nested;
    }

    if (rawList == null) return <RequestModel>[];

    return rawList
        .whereType<Map>()
        .map((json) => RequestModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<RequestModel> createRequest(
    String workspaceId, {
    required String title,
    required String description,
    List<File> images = const [],
  }) async {
    final json = await _service.createRequest(
      workspaceId,
      title: title,
      description: description,
      images: images,
    );
    return RequestModel.fromJson(json);
  }

  Future<void> deleteRequest(String requestId) {
    return _service.deleteRequest(requestId);
  }
}
