import 'package:flutter_worksmart_app/features/user/auth/service/notification_service.dart';

class NotificationRepository {
  final NotificationService _service;

  NotificationRepository(this._service);

  Stream<List<Map<String, dynamic>>> watchUserNotifications(String uid) {
    return _service.watchUserNotifications(uid);
  }
}
