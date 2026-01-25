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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  
  // Initialize Firebase (for Notifications) - ANDROID ONLY
  if (Platform.isAndroid) {
    try {
      await Firebase.initializeApp();
      debugPrint('✅ Firebase initialized for Android');
    } catch (e) {
      debugPrint('Firebase init error: $e');
    }
  } else {
    debugPrint('ℹ️ Skipping Firebase on iOS');
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

class _PTBodyChangeAppState extends State<PTBodyChangeApp> {
  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    
    // Setup Notification Interaction (Navigation)
    // Delay slightly to ensure Navigator is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().setupInteractedMessage();
    });
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
            
            // Check if user has completed invitation (changed password)
            // If password_changed is null, assume true (legacy user or standard signup)
            // Only block if explicitly set to false (invited user who hasn't accepted yet)
            final userMetadata = user.userMetadata;
            final passwordChanged = userMetadata?['password_changed'];
            
            if (passwordChanged == false) {
              // Not completed invitation - show Change Password screen for first login
              debugPrint('User password_changed is false, showing ChangePasswordScreen');
              return const ChangePasswordScreen(isFirstLogin: true);
            }
            
            // Completed invitation - check profile validity before showing dashboard
            return const AuthCheckScreen(); // Was DashboardScreen();
          }
          
          // No session - show welcome screen
          return const WelcomeScreen();
        },
      ),
    );
  }
}
