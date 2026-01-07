import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class NotificationService {
  final _supabase = Supabase.instance.client;
  final _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Listen for Auth Changes to save token when user logs in
    _supabase.auth.onAuthStateChange.listen((data) async {
      if (data.session?.user != null) {
        final token = await _fcm.getToken();
        if (token != null) {
          await _saveToken(token);
        }
      }
    });

    // 1. Request Permission
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
          // You could show a local notification here if needed
        }
      });
    } else {
      debugPrint('User declined or has not accepted permission');
    }
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
