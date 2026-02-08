import 'package:firebase_core/firebase_core.dart';
import 'core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io';
import 'dart:async';
import 'core/theme/app_theme.dart';
import 'core/constants/supabase_config.dart';
import 'package:fitflow/features/auth/screens/welcome_screen.dart';

import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/profile/screens/change_password_screen.dart';
import 'features/auth/screens/account_pending_screen.dart';
import 'features/auth/screens/auth_check_screen.dart';

// Helper function to check password_changed from database
Future<bool> _checkPasswordChanged(String userId) async {
  try {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('password_changed')
        .eq('id', userId)
        .maybeSingle();
    
    if (response == null) {
      debugPrint('Profile not found for user $userId, defaulting to true');
      return true; // Default to true if profile not found
    }
    
    final passwordChanged = response['password_changed'] as bool? ?? true;
    debugPrint('Fetched password_changed from DB: $passwordChanged for user $userId');
    return passwordChanged;
  } catch (e) {
    debugPrint('Error fetching password_changed: $e');
    return true; // Default to true on error to avoid blocking users
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  
  // Initialize Firebase (for Notifications)
  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Initialize Notification Service (handles platform internally)
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Notification service error: $e');
  }

  await initializeDateFormatting('tr_TR', null);
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  
  // Wrap in runZonedGuarded to catch async errors (like expired links)
  runZonedGuarded(() {
    runApp(const PTBodyChangeApp());
  }, (error, stack) {
    debugPrint('Global error caught: $error');
    if (error.toString().contains('Email link is invalid or has expired')) {
       // We can't use context here easily, but we can log it.
       // In a real app we might use a global key to show a snackbar.
       debugPrint('USER ALERT: Email link expired.');
       final context = navigatorKey.currentContext;
       if (context != null) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('Bağlantı süresi dolmuş. Lütfen yeni bir şifre sıfırlama bağlantısı isteyin.'),
             backgroundColor: Colors.red,
             behavior: SnackBarBehavior.floating,
             duration: Duration(seconds: 4),
           ),
         );
       }
    }
  });
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class PTBodyChangeApp extends StatefulWidget {
  const PTBodyChangeApp({super.key});

  @override
  State<PTBodyChangeApp> createState() => _PTBodyChangeAppState();
}

class _PTBodyChangeAppState extends State<PTBodyChangeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add observer
    _setupAuthListener();
    _updateUserPresence(true); // Set online on start

    // Setup Notification Interaction (Navigation) - MOVED TO DASHBOARD
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   NotificationService().setupInteractedMessage();
    // });
    // This prevents race condition where ChatScreen is pushed before AuthCheck/Dashboard is ready
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _updateUserPresence(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _updateUserPresence(false);
        break;
      case AppLifecycleState.hidden:
        // Do nothing for hidden (iOS specific mostly)
        break;
    }
  }

  // Helper to update presence safely
  Future<void> _updateUserPresence(bool isOnline) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.from('profiles').update({
          'is_online': isOnline,
          'last_seen': isOnline ? null : DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', user.id);
      } catch (e) {
        debugPrint('Error updating presence: $e');
      }
    }
  }

  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      debugPrint('Auth event: ${data.event}'); // Debug log
      
      final user = data.session?.user;
      if (user != null) {
         debugPrint('Auth User Metadata: ${user.userMetadata}');
      }

      if (data.event == AuthChangeEvent.passwordRecovery) {
        debugPrint('Password recovery detected!'); // Debug log
        
        // Ignore if provider is google
        // Google accounts don't use password recovery flow in this app
        final provider = user?.appMetadata['provider'];
        if (provider == 'google') {
          debugPrint('Ignoring password recovery for Google provider');
          return;
        }

        // User is completing invitation - mark password as changed
        if (user != null) {
          try {
            debugPrint('Invitation link clicked. Updating password_changed to true...');
            
            // 1. Update Profile (CRITICAL: GymOwnerLoginScreen checks this)
            await Supabase.instance.client
                .from('profiles')
                .update({
                  'password_changed': true, 
                  'updated_at': DateTime.now().toIso8601String()
                })
                .eq('id', user.id);
            debugPrint('✅ Profile table updated: password_changed = true');

            // 2. Update Auth Metadata (Best effort)
            await Supabase.instance.client.auth.updateUser(
              UserAttributes(
                data: {'password_changed': true},
              ),
            );
            debugPrint('✅ Auth metadata updated: password_changed = true');
            
          } catch (e) {
            debugPrint('❌ Failed to update password_changed status: $e');
            // We continue anyway so they can change their password
          }
        }
        
        _navigateToChangePassword();
      }
    });
  }

  void _navigateToChangePassword() {
    Future.delayed(const Duration(milliseconds: 500), () {
      final context = navigatorKey.currentContext;
      if (context != null && navigatorKey.currentState != null) {
        debugPrint('Navigating to ChangePasswordScreen'); // Debug log
        navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
        );
      } else {
        debugPrint('Navigator not ready yet'); // Debug log
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'PT Body Change',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = Supabase.instance.client.auth.currentSession;
          
          // User is logged in
          if (session != null) {
            final user = session.user;
            
            // Fetch fresh password_changed value from database instead of stale session metadata
            return FutureBuilder<bool>(
              future: _checkPasswordChanged(user.id),
              builder: (context, passwordSnapshot) {
                // Show loading while checking
                if (passwordSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                
                // Default to true if error (allow access to avoid blocking users)
                final passwordChanged = passwordSnapshot.data ?? true;
                
                if (passwordChanged == false) {
                  // Not completed invitation - show Change Password screen for first login
                  debugPrint('User password_changed is false, showing ChangePasswordScreen');
                  return const ChangePasswordScreen(isFirstLogin: true);
                }
                
                // Completed invitation - check profile validity before showing dashboard
                return const AuthCheckScreen();
              },
            );  
          }
          
          // No session - show welcome screen
          return const WelcomeScreen();
        },
      ),
    );
  }
}
