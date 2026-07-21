import 'package:flutter_worksmart_app/features/user/auth/service/workspace_service.dart';
import 'package:flutter_worksmart_app/shared/model/workspace_model.dart';

class WorkspaceRepository {
  final WorkspaceService _service;

  WorkspaceRepository(this._service);

  Future<List<Workspace>> getWorkspaces({
    bool onlyOwner = false,
    bool onlyMember = true,
  }) async {
    final List<dynamic> rawList = await _service.fetchWorkspaces(
      onlyOwner: onlyOwner,
      onlyMember: onlyMember,
    );

    return rawList
        .map((json) => Workspace.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
