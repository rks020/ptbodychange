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

  // 🎯 PENDING MESSAGE STORAGE (Navigation happens later when Navigator is ready)
  static RemoteMessage? pendingMessage;

  /// Get the pending notification message (if any)
  static RemoteMessage? getPendingMessage() {
    return pendingMessage;
  }

  /// Clear the pending message after handling
  static void clearPendingMessage() {
    debugPrint('🔔 NotificationService: Clearing pending message');
    pendingMessage = null;
  }

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
    // ⚠️ IMPORTANT: We ONLY STORE the message here, NOT navigate
    // Navigation happens later in DashboardScreen when Navigator is ready
    debugPrint('🔔 Setting up notification interaction listeners...');
    
    // Listen for background taps (app in background)
    // Listen for background taps (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📩 Background notification tapped: ${message.data}');
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
      debugPrint('📩 App opened from terminated state - STORED for later: ${initialMessage.data}');
      pendingMessage = initialMessage;
    } else {
      debugPrint('🔔 No initial notification found');
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

      // Skip showing chat/announcement notifications in foreground to prevent duplicates
      // (User is already in the app and will see the message in chat/announcement screen)
      final messageType = message.data['type'];
      if (messageType == 'chat' || messageType == 'announcement') {
        debugPrint('🔔 Skipping foreground notification for $messageType message (prevents duplicates)');
        return;
      }

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
    // DEPRECATED: This is now handled in initialize()
    // Kept for backward compatibility but does nothing
    debugPrint('⚠️ setupInteractedMessage called but is deprecated - handled in initialize()');
  }

  void _handleMessage(RemoteMessage message) {
    debugPrint('Notification Clicked (Background/Terminated): ${message.data}');
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
    debugPrint('Notification Clicked (Foreground/Local): $data');
    _handleMessageData(data);
  }

  void _handleMessageData(Map<String, dynamic> data) {
    final type = data['type'];
    
    debugPrint('🔔 _handleMessageData called with data: $data');
    debugPrint('🔔 extracted type: $type');
    
    if (type == 'chat') {
      final senderId = data['sender_id'];
      final senderName = data['sender_name'] ?? 'Kullanıcı';
      final senderAvatar = data['sender_avatar'];
      
      if (senderId != null) {
        // Check if navigator is ready
        final context = navigatorKey.currentContext;
        if (context == null) {
          debugPrint('⚠️ Navigator context not ready, retrying...');
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
      debugPrint('🔔 _handleMessageData: Detecting announcement type. Navigating...');
      // Navigate to Announcements Screen
      final context = navigatorKey.currentContext;
      if (context != null) {
        debugPrint('🔔 Pushing AnnouncementsScreen now.');
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
    } else if (type == 'new_class') {
       final classId = data['classId'];
       debugPrint('🔔 _handleMessageData: new_class detected. ID: $classId');
       
       if (classId != null) {
          final context = navigatorKey.currentContext;
          if (context != null) {
             // Fetch the class session and navigate to ClassDetailScreen
             _navigateToClassDetail(classId);
          } else {
             debugPrint('⚠️ Navigator context not ready for new_class, retrying...');
             Future.delayed(const Duration(milliseconds: 500), () {
                _handleMessageData(data);
             });
          }
       }
    } else {
      debugPrint('⚠️ Unknown notification type: $type');
    }
  }

  Future<void> _navigateToClassDetail(String classId) async {
    try {
      debugPrint('🔔 Fetching class session with ID: $classId');
      
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
      
      debugPrint('🔔 Successfully fetched class: ${session.title}');
      
      // Navigate to ClassDetailScreen
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ClassDetailScreen(session: session),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error fetching class session: $e');
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

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Only handle if message.notification is null (Data-only message)
  // And strictly for Android (iOS handles system notifications)
  if (message.notification != null) {
    // Already handled by system
    return;
  }
  
  if (!Platform.isAndroid) return;

  debugPrint('🔧 Background Handler: Handling data-only message: ${message.data}');
  await Firebase.initializeApp();

  final data = message.data;
  final title = data['title'];
  final body = data['body'];
  final type = data['type'];

  if (title != null && body != null && (type == 'chat' || type == 'announcement')) {
     final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
     
     // Initialize minimal settings for Android
     const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
     
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
      debugPrint('🔔 Background Notification Shown manually');
  }
}
