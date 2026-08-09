import 'package:flutter_worksmart_app/features/user/service/holiday_service.dart';
import 'package:flutter_worksmart_app/shared/model/holiday_config_model.dart';
import 'package:flutter_worksmart_app/shared/model/holiday_model.dart';

class HolidayRepository {
  final HolidayService _service;

  HolidayRepository(this._service);

  Future<HolidayConfigModel> getHolidayConfig(String workspaceId) async {
    final data = await _service.fetchHolidayConfig(workspaceId);
    return HolidayConfigModel.fromJson(data);
  }

  /// Tolerates a plain list or a paginated wrapper under `data`/`items`/`results`/`holidays`.
  Future<List<HolidayModel>> getHolidays(
    String workspaceId, {
    int page = 1,
    int limit = 100,
  }) async {
    final dynamic raw = await _service.fetchHolidays(
      workspaceId,
      page: page,
      limit: limit,
    );

    List<dynamic>? rawList;
    if (raw is List) {
      rawList = raw;
    } else if (raw is Map<String, dynamic>) {
      final dynamic nested =
          raw['data'] ?? raw['holidays'] ?? raw['items'] ?? raw['results'];
      if (nested is List) rawList = nested;
    }

    if (rawList == null) return <HolidayModel>[];

    return rawList
        .whereType<Map>()
        .map((json) => HolidayModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }
}
