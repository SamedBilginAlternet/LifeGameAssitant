import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules a single daily reminder at 22:30 local time nudging Samed
/// to log a mood (and whatever else hasn't been captured yet).
///
/// The Settings → Mood prompt toggle drives whether the schedule is
/// active. When the user signs in, we ensure the schedule exists; when
/// they sign out or disable, we cancel it.
class MoodPromptService {
  MoodPromptService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const int notificationId = 1;
  static const String channelId = 'mood_prompt';
  static const String channelName = 'Evening mood prompt';
  static const String _payload = 'mood_prompt';

  /// Hour/minute we fire at, local time. 22:30 — late enough that the
  /// day's done, early enough that the user hasn't gone to bed.
  static const int hour = 22;
  static const int minute = 30;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialised = false;

  Future<void> _init() async {
    if (_initialised) return;
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: _onTap,
    );
    _initialised = true;
  }

  /// Callback bound by the router layer so a notification tap can push
  /// the capture screen. Null-safe: when no handler is set the tap just
  /// opens the app without navigating.
  static void Function(String? payload)? onTapHandler;

  static void _onTap(NotificationResponse response) {
    onTapHandler?.call(response.payload);
  }

  Future<bool> requestPermissions() async {
    await _init();
    final iOS = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iOS != null) {
      return await iOS.requestPermissions(
            alert: true,
            badge: false,
            sound: false,
          ) ??
          false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  Future<void> schedule() async {
    await _init();
    final scheduled = _nextOccurrence();
    await _plugin.zonedSchedule(
      notificationId,
      'MEMOIR_LOG · how is the day landing?',
      'Tap to log your mood, protein, or anything still loose.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Daily nudge to log mood + manual capture items',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: _payload,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel() async {
    await _init();
    await _plugin.cancel(notificationId);
  }

  tz.TZDateTime _nextOccurrence() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  @visibleForTesting
  FlutterLocalNotificationsPlugin get plugin => _plugin;
}
