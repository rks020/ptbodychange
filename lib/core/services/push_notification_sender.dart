import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class PushNotificationSender {
  static const _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
  
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> sendPush({
    required String receiverId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 1. Get Access Token via Service Account
      final serviceAccountJson = await rootBundle.loadString('assets/service_account.json');
      final serviceAccountCredentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
      
      // Parse project_id manually as it might not be exposed on credentials object
      final jsonMap = jsonDecode(serviceAccountJson) as Map<String, dynamic>;
      final projectId = jsonMap['project_id'] as String?;
      
      if (projectId == null) {
         debugPrint('Error: project_id not found in service_account.json');
         return;
      }
      
      final client = await clientViaServiceAccount(serviceAccountCredentials, _scopes);

      // 2. Get Receiver's FCM Tokens
      final response = await _client
          .from('fcm_tokens')
          .select('token')
          .eq('user_id', receiverId);
      
      final tokens = (response as List).map((e) => e['token'] as String).toList();

      if (tokens.isEmpty) {
        client.close();
        return;
      }

      // 3. Send to each token using HTTP v1 API
      for (final token in tokens) {
        await _sendToTokenV1(client, projectId!, token, title, body, data);
      }
      
      client.close();
      
    } catch (e) {
      debugPrint('Error sending push notification: $e');
    }
  }

  Future<void> sendToMultipleUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    debugPrint('PushNotificationSender: Starting batch send to ${userIds.length} users');
    if (userIds.isEmpty) return;

    try {
      // 1. Get Access Token
      debugPrint('PushNotificationSender: Loading service_account.json...');
      final serviceAccountJson = await rootBundle.loadString('assets/service_account.json');
      debugPrint('PushNotificationSender: Loaded service_account.json (length: ${serviceAccountJson.length})');
      
      final serviceAccountCredentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
      
      final jsonMap = jsonDecode(serviceAccountJson) as Map<String, dynamic>;
      final projectId = jsonMap['project_id'] as String?;
      debugPrint('PushNotificationSender: Project ID resolved: $projectId');
      
      if (projectId == null) {
         debugPrint('PushNotificationSender Error: project_id not found in service_account.json');
         return;
      }
      
      debugPrint('PushNotificationSender: Authenticating with Google...');
      final client = await clientViaServiceAccount(serviceAccountCredentials, _scopes);
      debugPrint('PushNotificationSender: Authenticated successfully.');

      // 2. Get Tokens for ALL users in one query
      debugPrint('PushNotificationSender: Fetching tokens from Supabase...');
      final response = await _client
          .from('fcm_tokens')
          .select('token')
          .filter('user_id', 'in', userIds);
      
      final tokens = (response as List).map((e) => e['token'] as String).toList();
      debugPrint('PushNotificationSender: Found ${tokens.length} tokens for ${userIds.length} users');

      if (tokens.isEmpty) {
        debugPrint('PushNotificationSender: No tokens found. Aborting.');
        client.close();
        return;
      }

      // 3. Send to each token
      int successCount = 0;
      int failCount = 0;
      final uniqueTokens = tokens.toSet();
      debugPrint('PushNotificationSender: Sending to ${uniqueTokens.length} unique devices...');

      for (final token in uniqueTokens) { 
        try {
          await _sendToTokenV1(client, projectId!, token, title, body, data);
          successCount++;
        } catch (e) {
          debugPrint('PushNotificationSender: Failed to send to token: $e');
          failCount++;
        }
      }
      
      debugPrint('PushNotificationSender: Batch finished. Success: $successCount, Fail: $failCount');
      client.close();
      
    } catch (e, stack) {
      debugPrint('PushNotificationSender Error: $e');
      debugPrint(stack.toString());
    }
  }

  Future<void> _sendToTokenV1(
    AutoRefreshingAuthClient client, 
    String projectId, 
    String token, 
    String title, 
    String body,
    Map<String, dynamic>? data,
  ) async {
    try {
      final url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';
      
      final response = await client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': {
            'token': token,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'id': '1',
              'status': 'done',
              ...(data ?? {}),
            },
            'android': {
              'priority': 'HIGH',
              'notification': {
                  'sound': 'default',
                  'channel_id': 'class_reminders'
              }
            },
            'apns': {
              'payload': {
                'aps': {
                  'sound': 'default',
                  'content-available': 1
                }
              }
            }
          }
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('FCM V1 Send Error: ${response.body}');
      }
    } catch (e) {
      debugPrint('FCM V1 HTTP Error: $e');
    }
  }
}
