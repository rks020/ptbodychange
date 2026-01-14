import 'package:firebase_core/firebase_core.dart';
import 'core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io';
import 'core/theme/app_theme.dart';
import 'core/constants/supabase_config.dart';
import 'package:pt_body_change/features/auth/screens/welcome_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/profile/screens/change_password_screen.dart';

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
  
  runApp(const PTBodyChangeApp());
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
  }

  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      debugPrint('Auth event: ${data.event}'); // Debug log
      
      if (data.event == AuthChangeEvent.passwordRecovery) {
        debugPrint('Password recovery detected!'); // Debug log
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
          if (session != null) {
            return const DashboardScreen();
          }
           return const WelcomeScreen();
        },
      ),
    );
  }
}
