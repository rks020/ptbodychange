import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';

class NotificationService {
  final _supabase = Supabase.instance.client;
  final _fcm = FirebaseMessaging.instance;
  final _localNotifications = fln.FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 0. Initialize Timezone
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    debugPrint('NotificationService initialized with timezone: $timeZoneName');

    // 0.1 Initialize Local Notifications
    const androidSettings = fln.AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = fln.DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = fln.InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _localNotifications.initialize(initSettings);


    // Listen for Auth Changes to save token when user logs in
    _supabase.auth.onAuthStateChange.listen((data) async {
      if (data.session?.user != null) {
        final token = await _fcm.getToken();
        if (token != null) {
          await _saveToken(token);
        }
      }
    });

    // 1. Request Permission (FCM)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
      
      // 2. Get Token (Initial check if already logged in)
      final token = await _fcm.getToken();
      if (token != null) {
        await _saveToken(token);
      }

      // 3. Listen for token refresh
      _fcm.onTokenRefresh.listen(_saveToken);

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
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        fln.NotificationDetails(
          android: fln.AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            importance: fln.Importance.max,
            priority: fln.Priority.high,
          ),
          iOS: const fln.DarwinNotificationDetails(),
        ),
      );
    }
  }

  Future<void> scheduleClassReminder(int id, String title, DateTime classTime) async {
    // 5 minutes before
    final scheduledDate = classTime.subtract(const Duration(minutes: 5));
    
    debugPrint('Scheduling notification for class "$title" at $scheduledDate (Local)');
    
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
      fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          'class_reminders',
          'Class Reminders',
          channelDescription: 'Reminders for upcoming classes',
          importance: fln.Importance.max,
          priority: fln.Priority.high,
        ),
        iOS: const fln.DarwinNotificationDetails(),
      ),
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
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
