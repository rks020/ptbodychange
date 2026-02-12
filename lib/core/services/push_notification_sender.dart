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
       return;
    }

    try {
      // 1. Get Service Account Access Token
      final client = await _getAuthClient();

      // 2. Get Receiver's FCM Tokens with Device Type via RPC
      final response = await _client.rpc('get_fcm_tokens_batch', params: {
        'user_ids': [receiverId]
      });
      
      final List<Map<String, dynamic>> tokensData = (response as List).cast<Map<String, dynamic>>();
      
      if (tokensData.isEmpty) {
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

      // 3. Send to each token using HTTP v1 API
      for (final target in targets) {
        final token = target['token'] as String;
        final deviceType = target['device_type'] as String?;
        
        await _sendToTokenV1(client, projectId!, token, title, body, data, deviceType);
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
      
      // Data payload - navigation bilgisi her zaman gerekli
      final enrichedData = Map<String, dynamic>.from(data ?? {});
      // Convert all values to String (FCM data payload requirement)
      final stringData = enrichedData.map((k, v) => MapEntry(k, v.toString()));
      
      final Map<String, dynamic> message = {
        'token': token,
      };

      // ═══════════════════════════════════════════════════════════
      // UNIVERSAL PAYLOAD STRATEGY:
      // Send 'notification' block for BOTH iOS and Android.
      // - iOS: System shows it.
      // - Android: System shows it (background/killed). Foreground handled by onMessage.
      // ═══════════════════════════════════════════════════════════
      
      // 1. Add Notification Block (Visible Title/Body)
      message['notification'] = {
        'title': title,
        'body': body,
      };

      // 2. Add Data Block (Navigation & Logic)
      // Android requires title/body in data too for some custom handlers, optional but safe.
      stringData['title'] = title;
      stringData['body'] = body;
      message['data'] = stringData;
      
      if (deviceType == 'ios') {
        // iOS Specifics
        message['apns'] = {
          'payload': {
            'aps': {
              'sound': 'default',
              'content-available': 1,
            }
          }
        };
      } else {
        // Android Specifics
        message['android'] = {
          'priority': 'HIGH',
          'notification': {
             'click_action': 'FLUTTER_NOTIFICATION_CLICK',
             'channel_id': 'high_importance_channel', // Match channel ID in NotificationService
          }
        };
      }

      final response = await client.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode != 200) {
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
            
            // debugPrint('⚠️ Token is invalid/unregistered ($errorCode/$status). Cleaning up: $token');
            await _deleteToken(token);
          }
        } catch (e) {
          // debugPrint('Error parsing FCM error response: $e');
        }
      } else {
        // debugPrint('✅ Message sent to token: ${token.substring(0, 5)}...');
      }
    } catch (e) {
      // debugPrint('FCM V1 HTTP Error: $e');
    }
  }

  Future<void> _deleteToken(String token) async {
    try {
      await _client.from('fcm_tokens').delete().eq('token', token);
    } catch (e) {
    }
  }

  Future<void> sendToMultipleUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (userIds.isEmpty) return;

    try {
      // 1. Get Access Token and project ID
      final serviceAccountJson = await rootBundle.loadString('assets/service_account.json');
      final jsonMap = jsonDecode(serviceAccountJson) as Map<String, dynamic>;
      final projectId = jsonMap['project_id'] as String?;
      
      if (projectId == null) {
         return;
      }
      
      final client = await _getAuthClient();

      // 2. Get Tokens for ALL users with device_type via RPC
      final response = await _client.rpc('get_fcm_tokens_batch', params: {
        'user_ids': userIds
      });
      
      final List<Map<String, dynamic>> tokensData = (response as List).cast<Map<String, dynamic>>();

      if (tokensData.isEmpty) {
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

      // 3. Send to each token (platform-aware enrichment handled inside _sendToTokenV1)
      int successCount = 0;
      int failCount = 0;

      for (final target in targets) { 
        final token = target['token'] as String;
        final deviceType = target['device_type'] as String?;
        
        try {
          await _sendToTokenV1(client, projectId!, token, title, body, data, deviceType);
          successCount++;
        } catch (e) {
          failCount++;
        }
      }
      
      client.close();
      
    } catch (e, stack) {
      // Error in batch push
    }
  }
}
