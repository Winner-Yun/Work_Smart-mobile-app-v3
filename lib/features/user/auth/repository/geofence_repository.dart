import 'package:flutter_worksmart_app/features/user/auth/service/geofence_service.dart';
import 'package:flutter_worksmart_app/shared/model/geofence_model.dart';

class GeofenceRepository {
  final GeofenceService _service;

  GeofenceRepository(this._service);

  Future<GeofenceModel> getGeofence(String workspaceId) async {
    final data = await _service.fetchGeofence(workspaceId);
    return GeofenceModel.fromJson(data);
  }
}
