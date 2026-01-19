import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';

class NotificationService {
  final _supabase = Supabase.instance.client;
  // _fcm removed to prevent static access before init on iOS
  final _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 0. Initialize Timezone
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    debugPrint('NotificationService initialized with timezone: $timeZoneName');

    // 0.1 Initialize Local Notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _localNotifications.initialize(initSettings);

    // 0.2 Request Android Permissions (Android 13+)
    if (Platform.isAndroid) {
      final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
      await _createNotificationChannel();
    }

    // SKIP FCM ON iOS - Only use local notifications
    if (Platform.isAndroid) {
      // Listen for Auth Changes to save token when user logs in
      _supabase.auth.onAuthStateChange.listen((data) async {
        if (data.session?.user != null) {
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            await _saveToken(token);
          }
        }
      });

      // 1. Request Permission (FCM)
      final fcm = FirebaseMessaging.instance;
      
      final settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted permission');
        
        // 2. Get Token (Initial check if already logged in)
        final token = await fcm.getToken();
        if (token != null) {
          await _saveToken(token);
        }

        // 3. Listen for token refresh
        fcm.onTokenRefresh.listen(_saveToken);

        // 4. Handle Foreground Messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Got a message whilst in the foreground!');
          debugPrint('Message data: ${message.data}');

          if (message.notification != null) {
            debugPrint('Message also contained a notification: ${message.notification}');
            // Ensure we show it locally if app is in foreground
            _showForegroundNotification(message);
          }
        });
      } else {
        debugPrint('User declined or has not accepted permission');
      }
    } else {
      debugPrint('iOS: Skipping FCM, using local notifications only');
    }
  }

  Future<void> _createNotificationChannel() async {
    const androidNotificationChannel = AndroidNotificationChannel(
      'class_reminders', // id
      'Class Reminders', // title
      description: 'Reminders for upcoming classes', // description
      importance: Importance.max,
      playSound: true,
    );
    
    final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.createNotificationChannel(androidNotificationChannel);

    const highImportanceChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
      playSound: true,
    );
    await androidImplementation?.createNotificationChannel(highImportanceChannel);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
             presentAlert: true,
             presentBadge: true,
             presentSound: true,
          ),
        ),
      );
    }
  }

  Future<void> scheduleClassReminder(int id, String title, DateTime classTime) async {
    // 5 minutes before
    // 5 minutes before (Ensure classTime is treated as Local)
    final localClassTime = classTime.toLocal();
    final scheduledDate = localClassTime.subtract(const Duration(minutes: 5));
    
    debugPrint('Scheduling notification for class "$title" at $scheduledDate (Local) / ${scheduledDate.toUtc()} (UTC)');
    
    // Don't schedule if already past
    if (scheduledDate.isBefore(DateTime.now())) {
       debugPrint('Skipping notification: Scheduled time $scheduledDate is in the past.');
       return;
    }

    await _localNotifications.zonedSchedule(
      id,
      'Ders Hatırlatıcı',
      '$title dersiniz 5 dakika içinde başlayacak.',
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'class_reminders',
          'Class Reminders',
          channelDescription: 'Reminders for upcoming classes',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  Future<void> _saveToken(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('fcm_tokens').upsert({
        'user_id': userId,
        'token': token,
        'device_type': _getDeviceType(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token'); 
      debugPrint('FCM Token saved: $token');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  String _getDeviceType() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }
}
