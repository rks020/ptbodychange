import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart'; // Add this import
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
import '../../features/classes/screens/class_detail_screen.dart';
import '../../features/classes/screens/class_schedule_screen.dart';
import '../../data/models/class_session.dart';
import '../../data/repositories/class_repository.dart';

class NotificationService {
  final _supabase = Supabase.instance.client;
  // _fcm removed to prevent static access before init on iOS
  final _localNotifications = FlutterLocalNotificationsPlugin();
  String? _lastSavedToken;

  // 🎯 PENDING MESSAGE STORAGE (Navigation happens later when Navigator is ready)
  static RemoteMessage? pendingMessage;

  /// Get the pending notification message (if any)
  static RemoteMessage? getPendingMessage() {
    return pendingMessage;
  }

  /// Clear the pending message after handling
  static void clearPendingMessage() {
    pendingMessage = null;
  }

  Future<void> initialize() async {
    // 0. Initialize Timezone
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    
    // 0.1 Initialize Local Notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
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
            // Error parsing payload
          }
        }
      },
    );

    // 0.3 Setup Interacted Message (Background/Terminated)
    // ⚠️ IMPORTANT: We ONLY STORE the message here, NOT navigate
    // Navigation happens later in DashboardScreen when Navigator is ready
    
    // Listen for background taps (app in background)
    // Listen for background taps (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // If navigator is ready (app in background but warm), navigate immediately
      if (navigatorKey.currentState != null) {
         _handleMessageData(message.data);
      } else {
         // If navigator not ready (unlikely for onMessageOpenedApp but safe), store it
         pendingMessage = message;
      }
    });
    
    // Check for terminated-state launch (app was completely closed)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      pendingMessage = initialMessage;
    }

    // 1. Request Permissions
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
    } else {
       // Android Permission
       await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    }
        
    // 2. Get Token (Initial check removed - handled by onAuthStateChange)
    /* 
    final token = await fcm.getToken();
    if (token != null) {
       if (_supabase.auth.currentUser != null) {
          await _saveToken(token);
       }
    }
    */

    // 3. Listen for token refresh
    fcm.onTokenRefresh.listen((newToken) {
       if (_supabase.auth.currentUser != null) {
         _saveToken(newToken);
       }
    });

    // 4. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Skip showing chat/announcement/class notifications in foreground
      // (User is already in the app)
      final messageType = message.data['type'];
      if (messageType == 'chat' || messageType == 'announcement' || messageType == 'new_class' || messageType == 'class_opened') {
        return;
      }

      if (message.notification != null) {
        // iOS path: notification payload var, _showForegroundNotification sadece Android'da gösterir
        _showForegroundNotification(message);
      } else if (Platform.isAndroid) {
        // Android path: data-only mesaj, manuel göster
        final title = message.data['title'];
        final body = message.data['body'];
        if (title != null && body != null) {
          _showDataOnlyNotification(message.data);
        }
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
    // DEPRECATED: This is now handled in initialize()
    // Kept for backward compatibility but does nothing
  }

  void _handleMessage(RemoteMessage message) {
    _handleMessageData(message.data);
  }

  void _handleMessageWithDelay(Map<String, dynamic> data) {
    // For background taps, navigator should be ready
    // But add small delay to be safe
    Future.delayed(const Duration(milliseconds: 300), () {
      _handleMessageData(data);
    });
  }

  void _handleMessageMap(Map<String, dynamic> data) {
    _handleMessageData(data);
  }

  void _handleMessageData(Map<String, dynamic> data) {
    final type = data['type'];
    
    if (type == 'chat') {
      final senderId = data['sender_id'];
      final senderName = data['sender_name'] ?? 'Kullanıcı';
      final senderAvatar = data['sender_avatar'];
      
      if (senderId != null) {
        // Check if navigator is ready
        final context = navigatorKey.currentContext;
        if (context == null) {
          // Retry after a delay
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleMessageData(data);
          });
          return;
        }
        
        debugPrint('🔔 Navigating to ChatScreen for sender: $senderId');
        // Navigate to Chat Screen
        final dummyProfile = Profile(
          id: senderId,
          firstName: senderName.split(' ').first,
          lastName: senderName.split(' ').length > 1 ? senderName.split(' ').last : '',
          avatarUrl: senderAvatar,
        );

        navigatorKey.currentState?.push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => ChatScreen(otherUser: dummyProfile),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
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
      } else {
        Future.delayed(const Duration(milliseconds: 500), () {
            _handleMessageData(data);
        });
      }
    } else if (type == 'new_class' || type == 'class_opened') {
       final classId = data['classId'] ?? data['session_id'];
       
       if (classId != null) {
          final context = navigatorKey.currentContext;
           if (context != null) {
              // Fetch the class session and navigate to ClassDetailScreen
              _navigateToClassDetail(classId);
           } else {
              Future.delayed(const Duration(milliseconds: 500), () {
                 _handleMessageData(data);
              });
           }
        }
    } else {
      // Unknown type
    }
  }

  Future<void> _navigateToClassDetail(String classId) async {
    try {
      // Fetch the class session from Supabase
      final response = await _supabase
          .from('class_sessions')
          .select('*, profiles(first_name, last_name), workouts(name), class_enrollments(count)')
          .eq('id', classId)
          .single();
      
      // Count enrollments manually
      final enrollments = response['class_enrollments'] as List?;
      final enrollmentCount = enrollments?.length ?? 0;
      response['enrollments_count'] = enrollmentCount;
      
      final session = ClassSession.fromJson(response);
      
      // Navigate to ClassDetailScreen
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ClassDetailScreen(session: session),
        ),
      );
    } catch (e) {
      // Fallback: Navigate to ClassScheduleScreen if fetch fails
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const ClassScheduleScreen(),
        ),
      );
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    
    if (notification == null) return;
    
    // iOS'ta foreground'da notification payload zaten sistem tarafından gösterilir.
    // Sadece Android için manuel göster.
    if (!Platform.isAndroid) return;
    
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Android data-only mesajlar için foreground'da bildirim göster
  Future<void> _showDataOnlyNotification(Map<String, dynamic> data) async {
    final title = data['title'] as String?;
    final body = data['body'] as String?;
    if (title == null || body == null) return;

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(data),
    );
  }
  Future<void> scheduleClassReminder(int id, String title, DateTime classTime) async {
    // 5 minutes before
    // 5 minutes before (Ensure classTime is treated as Local)
    final localClassTime = classTime.toLocal();
    final scheduledDate = localClassTime.subtract(const Duration(minutes: 5));
    
    // Don't schedule if already past
    if (scheduledDate.isBefore(DateTime.now())) {
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
    
    // Force update to ensure device_type is correct in DB
    // if (_lastSavedToken == token) return; 

    try {
      // Use RPC to bypass RLS and force claim the token
      await _supabase.rpc('register_fcm_token', params: {
        'p_token': token,
        'p_device_type': _getDeviceType(),
      });
      _lastSavedToken = token; // Update local cache
    } catch (e) {
      // RPC Error, falling back to basic upsert
      try {
         await _supabase.from('fcm_tokens').delete().eq('token', token);
         await _supabase.from('fcm_tokens').insert({
          'user_id': userId,
          'token': token,
          'device_type': _getDeviceType(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        _lastSavedToken = token;
      } catch (e2) {
        // Fallback failed
      }
    }
  }

  Future<void> _deleteToken(String token) async {
    try {
      await _supabase.from('fcm_tokens').delete().eq('token', token);
    } catch (e) {
      // Error deleting token
    }
  }

  String _getDeviceType() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Only handle if message.notification is null (Data-only message)
  // And strictly for Android (iOS handles system notifications)
  if (message.notification != null) {
    // Already handled by system
    return;
  }
  
  if (!Platform.isAndroid) return;

  await Firebase.initializeApp();

  final data = message.data;
  final title = data['title'];
  final body = data['body'];
  final type = data['type'];

  if (title != null && body != null && (type == 'chat' || type == 'announcement')) {
     final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
     
     // Initialize minimal settings for Android
     const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
     
     // Note: In background, we don't need callbacks usually, just show
     await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(android: initializationSettingsAndroid),
     );

     await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecond, // Unique ID
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(data),
      );
  }
}
