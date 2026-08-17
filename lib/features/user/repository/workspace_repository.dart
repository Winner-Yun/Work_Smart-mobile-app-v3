import 'package:flutter_worksmart_app/features/user/service/workspace_service.dart';
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

    final List<Workspace> workspaces = rawList
        .map((json) => Workspace.fromJson(json as Map<String, dynamic>))
        .toList();

    // Backfill the real member count and owner name per workspace (see fetchWorkspaceMembersInfo).
    final List<WorkspaceMembersInfo> membersInfo = await Future.wait(
      workspaces.map((w) => _service.fetchWorkspaceMembersInfo(w.id)),
    );

    return [
      for (int i = 0; i < workspaces.length; i++)
        workspaces[i].copyWith(
          memberCount: membersInfo[i].total,
          ownerName: membersInfo[i].ownerName,
        ),
    ];
  }
}
