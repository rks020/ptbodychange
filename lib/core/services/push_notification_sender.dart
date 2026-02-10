import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationSender {
  static const _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
  
  final SupabaseClient _client = Supabase.instance.client;

  Future<AutoRefreshingAuthClient> _getAuthClient() async {
    final serviceAccountJson = await rootBundle.loadString('assets/service_account.json');
    final serviceAccountCredentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
    return await clientViaServiceAccount(serviceAccountCredentials, _scopes);
  }

  Future<void> sendPush({
    required String receiverId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // Parse project_id from service account
    final serviceAccountJson = await rootBundle.loadString('assets/service_account.json');
    final jsonMap = jsonDecode(serviceAccountJson) as Map<String, dynamic>;
    final projectId = jsonMap['project_id'] as String?;
    
    if (projectId == null) {
       debugPrint('Error: project_id not found in service_account.json');
       return;
    }

    try {
      // 1. Get Service Account Access Token
      final client = await _getAuthClient();

      // 2. Get Receiver's FCM Tokens with Device Type
      final response = await _client
          .from('fcm_tokens')
          .select('token, device_type') // Fetch device_type too
          .eq('user_id', receiverId);
      
      final List<Map<String, dynamic>> tokensData = (response as List).cast<Map<String, dynamic>>();
      
      if (tokensData.isEmpty) {
        debugPrint('PushNotificationSender: No FCM tokens found for user $receiverId');
        return;
      }

      final uniqueTokens = <String>{};
      final List<Map<String, dynamic>> targets = [];

      for (var item in tokensData) {
        final token = item['token'] as String;
        if (uniqueTokens.add(token)) {
          targets.add(item);
        }
      }

      debugPrint('PushNotificationSender: Sending to ${targets.length} unique devices...');

      // Add title and body to data payload because Android will use data-only message
      final enrichedData = Map<String, dynamic>.from(data ?? {});
      enrichedData['title'] = title;
      enrichedData['body'] = body;

      // 3. Send to each token using HTTP v1 API
      for (final target in targets) {
        final token = target['token'] as String;
        final deviceType = target['device_type'] as String?;
        
        await _sendToTokenV1(client, projectId!, token, title, body, enrichedData, deviceType);
      }

      client.close();
    } catch (e) {
      debugPrint('PushNotificationSender Error: $e');
    }
  }

  Future<void> _sendToTokenV1(
    AutoRefreshingAuthClient client, 
    String projectId, 
    String token, 
    String title, 
    String body, 
    Map<String, dynamic>? data,
    String? deviceType,
  ) async {
    try {
      final url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';
      
      // Construct message
      final Map<String, dynamic> message = {
        'token': token,
        'data': data,
      };

      // For Android, we send DATA-ONLY message to prevent system from showing duplicate notification automatically.
      // We will handle the display manually in onBackgroundMessage/onMessage.
      // For iOS, we keep notification payload to ensure delivery even if app is terminated.
      
      if (deviceType != 'android') {
        message['notification'] = {
          'title': title,
          'body': body,
        };
      } else {
        debugPrint('🤖 Sending DATA-ONLY message to Android to prevent duplicates');
      }

      // Add Android specific config (high priority for data messages)
      message['android'] = {
        'priority': 'HIGH',
      };

      // Add APNs specific config
      message['apns'] = {
        'payload': {
          'aps': {
            'sound': 'default',
            'content-available': 1, // Important for background updates
          }
        }
      };

      final response = await client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode != 200) {
        debugPrint('FCM V1 Send Error: ${response.body}');
        
        try {
          final errorBody = jsonDecode(response.body);
          final error = errorBody['error'];
          
          // Check for specific error codes or message content indicating invalid token
          final errorCode = error['details'] is List && (error['details'] as List).isNotEmpty 
              ? (error['details'][0]['errorCode'] as String?) 
              : null;
              
          final status = error['status'] as String?;
          final message = error['message'] as String?;

          if (errorCode == 'UNREGISTERED' || 
              status == 'UNREGISTERED' || 
              (message != null && message.contains('UNREGISTERED')) ||
              errorCode == 'INVALID_ARGUMENT' || 
              status == 'NOT_FOUND') {
            
            debugPrint('⚠️ Token is invalid/unregistered ($errorCode/$status). Cleaning up: $token');
            await _deleteToken(token);
          }
        } catch (e) {
          debugPrint('Error parsing FCM error response: $e');
        }
      } else {
        debugPrint('✅ Message sent to token: ${token.substring(0, 5)}...');
      }
    } catch (e) {
      debugPrint('FCM V1 HTTP Error: $e');
    }
  }

  Future<void> _deleteToken(String token) async {
    try {
      await _client.from('fcm_tokens').delete().eq('token', token);
      debugPrint('🗑️ Invalid FCM Token deleted from database');
    } catch (e) {
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
      // 1. Get Access Token and project ID
      final serviceAccountJson = await rootBundle.loadString('assets/service_account.json');
      final jsonMap = jsonDecode(serviceAccountJson) as Map<String, dynamic>;
      final projectId = jsonMap['project_id'] as String?;
      
      if (projectId == null) {
         debugPrint('PushNotificationSender Error: project_id not found in service_account.json');
         return;
      }
      
      final client = await _getAuthClient();

      // 2. Get Tokens for ALL users with device_type
      final response = await _client
          .from('fcm_tokens')
          .select('token, device_type')
          .filter('user_id', 'in', userIds);
      
      final List<Map<String, dynamic>> tokensData = (response as List).cast<Map<String, dynamic>>();
      debugPrint('PushNotificationSender: Found ${tokensData.length} tokens for ${userIds.length} users');

      if (tokensData.isEmpty) {
        debugPrint('PushNotificationSender: No tokens found. Aborting.');
        client.close();
        return;
      }

      // Remove duplicates
      final uniqueTokens = <String>{};
      final List<Map<String, dynamic>> targets = [];

      for (var item in tokensData) {
        final token = item['token'] as String;
        if (uniqueTokens.add(token)) {
          targets.add(item);
        }
      }

      debugPrint('PushNotificationSender: Sending to ${targets.length} unique devices...');

      // Add title and body to data payload
      final enrichedData = Map<String, dynamic>.from(data ?? {});
      enrichedData['title'] = title;
      enrichedData['body'] = body;

      // 3. Send to each token
      int successCount = 0;
      int failCount = 0;

      for (final target in targets) { 
        final token = target['token'] as String;
        final deviceType = target['device_type'] as String?;
        
        try {
          await _sendToTokenV1(client, projectId!, token, title, body, enrichedData, deviceType);
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
}
