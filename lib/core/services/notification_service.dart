import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';
import 'package:fitflow/main.dart';
import 'package:fitflow/features/chat/screens/chat_screen.dart';
import 'package:fitflow/features/dashboard/screens/announcements_screen.dart';
import 'package:fitflow/data/models/profile.dart';
import 'dart:convert';

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
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            _handleMessageMap(data);
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );

    // 0.3 Setup Interacted Message (Background/Terminated)
    // REMOVED: Called manually in main.dart after app is ready
    // setupInteractedMessage();

    // 0.2 Request Android Permissions (Android 13+)
    if (Platform.isAndroid) {
      final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
      await _createNotificationChannel();
    }

    // List for Auth Changes to save/remove token
    _supabase.auth.onAuthStateChange.listen((data) async {
      if (data.session?.user != null) {
        // Logged In
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _saveToken(token);
        }
      } else if (data.event == AuthChangeEvent.signedOut) {
        // Logged Out
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _deleteToken(token);
        }
      }
    });

    // 1. Request Permission (FCM) - Works for iOS & Android
    final fcm = FirebaseMessaging.instance;
    
    // For iOS specifically, we need to request permissions
    if (Platform.isIOS) {
      await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      // For Apple, we also need APNs token
      final apnsToken = await fcm.getAPNSToken();
      debugPrint('APNs Token: $apnsToken');
    } else {
       // Android Permission
       await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    }
        
    // 2. Get Token (Initial check if already logged in)
    final token = await fcm.getToken();
    if (token != null) {
       // If user is already logged in at startup, save token
       if (_supabase.auth.currentUser != null) {
          await _saveToken(token);
       }
    }

    // 3. Listen for token refresh
    fcm.onTokenRefresh.listen((newToken) {
       if (_supabase.auth.currentUser != null) {
         _saveToken(newToken);
       }
    });

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

  void setupInteractedMessage() async {
    // 1. Terminated State
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // 2. Background State
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) {
    debugPrint('Notification Clicked (Background/Terminated): ${message.data}');
    _handleMessageData(message.data);
  }

  void _handleMessageMap(Map<String, dynamic> data) {
    debugPrint('Notification Clicked (Foreground/Local): $data');
    _handleMessageData(data);
  }

  void _handleMessageData(Map<String, dynamic> data) {
    final type = data['type'];
    
    if (type == 'chat') {
      final senderId = data['sender_id'];
      final senderName = data['sender_name'] ?? 'Kullanıcı';
      final senderAvatar = data['sender_avatar'];
      
      if (senderId != null) {
        // Navigate to Chat Screen
        final context = navigatorKey.currentContext;
        if (context != null) {
          final dummyProfile = Profile(
            id: senderId,
            firstName: senderName.split(' ').first,
            lastName: senderName.split(' ').length > 1 ? senderName.split(' ').last : '',
            avatarUrl: senderAvatar,
          );

          navigatorKey.currentState?.push(
            MaterialPageRoute(
               builder: (_) => ChatScreen(otherUser: dummyProfile),
            ),
          );
        }
      }
    } else if (type == 'announcement') {
      // Navigate to Announcements Screen
      final context = navigatorKey.currentContext;
      if (context != null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
             builder: (_) => const AnnouncementsScreen(),
          ),
        );
      }
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;
    
    if (notification != null && android != null) { // Ensure android specifics are checked if needed, or just notification
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
        payload: jsonEncode(message.data), // Pass data as payload
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
      // Use RPC to bypass RLS and force claim the token
      await _supabase.rpc('register_fcm_token', params: {
        'p_token': token,
        'p_device_type': _getDeviceType(),
      });
      debugPrint('FCM Token registered via RPC for user $userId');
    } catch (e) {
      debugPrint('RPC Error, falling back to basic upsert: $e');
      // Fallback if RPC doesn't exist yet (in case user didn't run SQL)
      try {
         await _supabase.from('fcm_tokens').delete().eq('token', token);
         await _supabase.from('fcm_tokens').insert({
          'user_id': userId,
          'token': token,
          'device_type': _getDeviceType(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e2) {
        debugPrint('Fallback token save failed: $e2');
      }
    }
  }

  Future<void> _deleteToken(String token) async {
    try {
      await _supabase.from('fcm_tokens').delete().eq('token', token);
      debugPrint('FCM Token deleted');
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }

  String _getDeviceType() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }
}
