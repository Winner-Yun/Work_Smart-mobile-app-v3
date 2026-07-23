import 'package:flutter_worksmart_app/features/user/auth/service/policy_service.dart';
import 'package:flutter_worksmart_app/shared/model/policy_model.dart';

class PolicyRepository {
  final PolicyService _service;

  PolicyRepository(this._service);

  Future<PolicyModel> getPolicy(String workspaceId) async {
    final data = await _service.fetchPolicy(workspaceId);
    return PolicyModel.fromJson(data);
  }
}
