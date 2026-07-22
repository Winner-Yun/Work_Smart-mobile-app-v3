import 'package:flutter_worksmart_app/features/user/auth/service/invite_service.dart';
import 'package:flutter_worksmart_app/shared/model/invite_action_response.dart';
import 'package:flutter_worksmart_app/shared/model/invite_model.dart';

class InviteRepository {
  final InviteService _service;

  InviteRepository(this._service);

  Future<InviteResponse> getMyInvites({int page = 1, int limit = 10}) async {
    return await _service.fetchMyInvites(page: page, limit: limit);
  }

  Future<InviteActionResponse> acceptInvite(String inviteId) async {
    return await _service.acceptInvite(inviteId);
  }

  Future<InviteActionResponse> rejectInvite(String inviteId) async {
    return await _service.rejectInvite(inviteId);
  }
}
