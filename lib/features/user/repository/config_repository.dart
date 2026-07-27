import 'package:flutter_worksmart_app/features/user/service/config_service.dart';
import 'package:flutter_worksmart_app/shared/model/app_config_model.dart';

class ConfigRepository {
  final ConfigService _service;

  ConfigRepository(this._service);

  Future<AppConfigModel> getConfig() async {
    final data = await _service.fetchConfig();
    return AppConfigModel.fromJson(data);
  }
}
