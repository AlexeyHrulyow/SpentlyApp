// lib/services/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Синглтон-обёртка над flutter_local_notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // права запросим отдельно, явно
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // ⚠️ В версии 22.x параметр стал именованным: settings: ...
    await _plugin.initialize(settings: initSettings);
    _initialized = true;
  }

  /// На Android 13+ (API 33+) без явного запроса показ уведомлений будет
  /// молча игнорироваться. На iOS без запроса пользователь не увидит
  /// системный диалог разрешения.
  Future<void> requestPermissions() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation
        <AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    final iosImpl = _plugin.resolvePlatformSpecificImplementation
        <IOSFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> showBudgetNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'budget_alerts',
      'Бюджет',
      channelDescription: 'Уведомления о приближении/превышении бюджета',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // ⚠️ В версии 22.x параметры тоже стали именованными.
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}