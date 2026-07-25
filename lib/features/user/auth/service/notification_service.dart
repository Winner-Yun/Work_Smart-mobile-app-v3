import 'package:flutter_worksmart_app/core/util/database/realtime_data_controller.dart';

class NotificationService {
  final RealtimeDataController _dataController;

  NotificationService({RealtimeDataController? dataController})
    : _dataController = dataController ?? RealtimeDataController();

  Stream<List<Map<String, dynamic>>> watchUserNotifications(String uid) {
    return _dataController.watchUserNotifications(uid);
  }
}
